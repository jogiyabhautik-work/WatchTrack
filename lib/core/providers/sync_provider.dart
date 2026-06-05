import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:appwrite/appwrite.dart';
import 'package:watch_track/core/appwrite_client.dart';
import 'package:watch_track/core/appwrite_constants.dart';
import 'package:watch_track/data/models/sync_action_model.dart';

class SyncProvider extends ChangeNotifier {
  List<SyncAction> _queue = [];
  static const String _queueKey = 'sync_queue';
  final Databases _databases = Databases(client);
  
  bool _isProcessing = false;
  Timer? _debounceTimer;
  StreamSubscription? _connectivitySubscription;
  bool _isOnline = true;
  String? _currentUserId;

  SyncProvider() {
    _loadQueue();
    _initConnectivity();
  }

  void setUserId(String? userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      if (userId == null) {
        clearQueue();
      }
    }
  }

  void clearQueue() {
    _queue.clear();
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) => prefs.remove(_queueKey));
  }

  List<SyncAction> get queue => _queue;
  bool get isProcessing => _isProcessing;
  bool get isOnline => _isOnline;

  Future<void> _initConnectivity() async {
    final connectivity = Connectivity();
    final result = await connectivity.checkConnectivity();
    _updateOnlineStatus(result);

    _connectivitySubscription = connectivity.onConnectivityChanged.listen((results) {
      _updateOnlineStatus(results);
      if (_isOnline && _queue.isNotEmpty) {
        processQueue();
      }
    });
  }

  void _updateOnlineStatus(List<ConnectivityResult> results) {
    _isOnline = results.any((result) => result != ConnectivityResult.none);
    notifyListeners();
  }

  Future<void> addToQueue({
    required String userId,
    required int itemId,
    required String mediaType,
    required SyncActionType actionType,
    required Map<String, dynamic> payload,
  }) async {
    // Debounce: if same item and same action type within a short time, update the payload instead of adding new
    final existingIndex = _queue.indexWhere((a) => 
      a.itemId == itemId && 
      a.actionType == actionType && 
      a.status == SyncActionStatus.pending
    );

    if (existingIndex != -1) {
      // Merge payload
      final existingAction = _queue[existingIndex];
      final newPayload = {...existingAction.payload, ...payload};
      _queue[existingIndex] = SyncAction(
        id: existingAction.id,
        userId: userId,
        itemId: itemId,
        mediaType: mediaType,
        actionType: actionType,
        payload: newPayload,
        createdAt: DateTime.now(),
        status: SyncActionStatus.pending,
      );
    } else {
      final action = SyncAction(
        id: const Uuid().v4(),
        userId: userId,
        itemId: itemId,
        mediaType: mediaType,
        actionType: actionType,
        payload: payload,
        createdAt: DateTime.now(),
      );
      _queue.add(action);
    }

    _saveQueue();
    notifyListeners();

    // Start debounce timer for processing
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
      if (_isOnline) {
        processQueue();
      }
    });
  }

  Future<void> processQueue() async {
    if (_isProcessing || !_isOnline || _queue.isEmpty) return;

    _isProcessing = true;
    notifyListeners();

    final pendingActions = _queue.where((a) => a.status != SyncActionStatus.done).toList();
    
    // Group by itemId to batch updates for the same item
    final groupedActions = <int, List<SyncAction>>{};
    for (var action in pendingActions) {
      groupedActions.putIfAbsent(action.itemId, () => []).add(action);
    }

    for (var itemId in groupedActions.keys) {
      final actions = groupedActions[itemId]!;
      // For simplicity, we process one group at a time. 
      // If there are multiple actions for same item, we can merge them.
      final latestAction = actions.last;
      
      try {
        await _syncToCloud(latestAction);
        
        // Mark all actions in this group as done
        for (var action in actions) {
          final index = _queue.indexWhere((a) => a.id == action.id);
          if (index != -1) {
            _queue[index] = action.copyWith(status: SyncActionStatus.done);
          }
        }
      } catch (e) {
        debugPrint('Sync failed for item $itemId: $e');
        for (var action in actions) {
          final index = _queue.indexWhere((a) => a.id == action.id);
          if (index != -1) {
            final newRetryCount = action.retryCount + 1;
            _queue[index] = action.copyWith(
              status: SyncActionStatus.failed,
              retryCount: newRetryCount,
              lastError: e.toString(),
            );
          }
        }
      }
    }

    // Remove done actions
    _queue.removeWhere((a) => a.status == SyncActionStatus.done);
    _saveQueue();
    _isProcessing = false;
    notifyListeners();
  }

  Future<void> _syncToCloud(SyncAction action) async {
    final String collectionId = (action.actionType == SyncActionType.updateFolder ||
            action.actionType == SyncActionType.deleteFolder)
        ? AppwriteConstants.foldersCollectionId
        : AppwriteConstants.trackingCollectionId;

    final data = Map<String, dynamic>.from(action.payload);
    data.remove('id'); // Remove routing ID

    try {
      // 1. Handle Deletions
      if (action.actionType == SyncActionType.deleteTracking || 
          action.actionType == SyncActionType.deleteFolder) {
        
        List<String> queries = [
          Query.equal(AppwriteConstants.attrUserId, action.userId),
        ];

        if (action.actionType == SyncActionType.deleteFolder) {
           // For folders, we use the 'name' or the provided local id in payload
           final name = data[AppwriteConstants.attrFolderName];
           if (name != null) queries.add(Query.equal(AppwriteConstants.attrFolderName, name));
        } else {
          queries.add(Query.equal(AppwriteConstants.attrTmdbId, action.itemId));
        }

        final existingDocs = await _databases.listDocuments(
          databaseId: AppwriteConstants.databaseId,
          collectionId: collectionId,
          queries: queries,
        );

        for (var doc in existingDocs.documents) {
          await _databases.deleteDocument(
            databaseId: AppwriteConstants.databaseId,
            collectionId: collectionId,
            documentId: doc.$id,
          );
          debugPrint('🗑️ Deleted cloud document: ${doc.$id}');
        }
        return;
      }

      // 2. Handle Updates/Creates
      List<String> queries = [
        Query.equal(AppwriteConstants.attrUserId, action.userId),
      ];

      if (action.actionType == SyncActionType.updateFolder) {
        // If we have a name, match by name. 
        // Ideally we should match by a persistent local ID attribute.
        final name = data[AppwriteConstants.attrFolderName];
        if (name != null) queries.add(Query.equal(AppwriteConstants.attrFolderName, name));
      } else {
        queries.add(Query.equal(AppwriteConstants.attrTmdbId, action.itemId));
      }

      final existingDocs = await _databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: collectionId,
        queries: queries,
      );

      if (existingDocs.documents.isNotEmpty) {
        // Update existing
        final docId = existingDocs.documents.first.$id;
        await _databases.updateDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: collectionId,
          documentId: docId,
          data: data,
        );
        debugPrint('✅ Updated cloud document: $docId');
      } else {
        // Create new
        final docId = ID.unique();
        await _databases.createDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: collectionId,
          documentId: docId,
          data: data,
        );
        debugPrint('✅ Created new cloud document: $docId');
      }
    } catch (e) {
      debugPrint('❌ Cloud Sync Error: $e');
      rethrow;
    }
  }

  Future<void> _saveQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(_queue.map((e) => e.toJson()).toList());
    await prefs.setString(_queueKey, encoded);
  }

  Future<void> _loadQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_queueKey);
    if (encoded != null) {
      final List<dynamic> decoded = json.decode(encoded);
      _queue = decoded.map((e) => SyncAction.fromJson(e)).toList();
      notifyListeners();
      
      // Auto process if online
      if (_isOnline && _queue.isNotEmpty) {
        processQueue();
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
