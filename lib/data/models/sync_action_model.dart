enum SyncActionType {
  updateTracking,
  deleteTracking,
  updateProgress,
  updateFolder,
  deleteFolder
}

enum SyncActionStatus {
  pending,
  processing,
  failed,
  done
}

class SyncAction {
  final String id;
  final String userId;
  final int itemId;
  final String mediaType;
  final SyncActionType actionType;
  final Map<String, dynamic> payload;
  final SyncActionStatus status;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;

  SyncAction({
    required this.id,
    required this.userId,
    required this.itemId,
    required this.mediaType,
    required this.actionType,
    required this.payload,
    this.status = SyncActionStatus.pending,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'item_id': itemId,
      'media_type': mediaType,
      'action_type': actionType.name,
      'payload': payload,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'retry_count': retryCount,
      'last_error': lastError,
    };
  }

  factory SyncAction.fromJson(Map<String, dynamic> json) {
    return SyncAction(
      id: json['id'],
      userId: json['user_id'],
      itemId: json['item_id'],
      mediaType: json['media_type'],
      actionType: SyncActionType.values.firstWhere((e) => e.name == json['action_type']),
      payload: Map<String, dynamic>.from(json['payload']),
      status: SyncActionStatus.values.firstWhere((e) => e.name == json['status']),
      createdAt: DateTime.parse(json['created_at']),
      retryCount: json['retry_count'] ?? 0,
      lastError: json['last_error'],
    );
  }

  SyncAction copyWith({
    SyncActionStatus? status,
    int? retryCount,
    String? lastError,
  }) {
    return SyncAction(
      id: id,
      userId: userId,
      itemId: itemId,
      mediaType: mediaType,
      actionType: actionType,
      payload: payload,
      status: status ?? this.status,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
    );
  }
}
