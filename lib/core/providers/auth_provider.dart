import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:watch_track/core/appwrite_client.dart';

enum AuthStatus { authenticated, unauthenticated, authenticating, initial }

class AuthProvider extends ChangeNotifier {
  final Account _account = Account(client);
  
  AuthStatus _status = AuthStatus.initial;
  models.User? _user;
  String? _error;

  AuthStatus get status => _status;
  models.User? get user => _user;
  String? get error => _error;

  AuthProvider() {
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final startTime = DateTime.now();
    try {
      _user = await _account.get();
      _status = AuthStatus.authenticated;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
    }
    
    // Ensure splash screen remains visible for at least 1800ms for premium luxury UX
    final elapsed = DateTime.now().difference(startTime);
    if (elapsed.inMilliseconds < 1800) {
      await Future.delayed(Duration(milliseconds: 1800 - elapsed.inMilliseconds));
    }
    
    notifyListeners();
  }

  Future<bool> register(String email, String password, String name) async {
    _status = AuthStatus.authenticating;
    _error = null;
    notifyListeners();
    try {
      await _account.create(
        userId: ID.unique(),
        email: email,
        password: password,
        name: name,
      );
      // Auto login after register
      return await login(email, password);
    } on AppwriteException catch (e) {
      if (e.code == 429) {
        _error = 'Rate limit exceeded. Please wait a few minutes before trying to create an account again.';
      } else {
        _error = e.message ?? e.toString();
      }
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _status = AuthStatus.authenticating;
    _error = null;
    notifyListeners();
    try {
      debugPrint('Attempting login for: $email');
      await _account.createEmailPasswordSession(
        email: email,
        password: password,
      );
      _user = await _account.get();
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on AppwriteException catch (e) {
      // 409 means session already exists
      if (e.code == 409 || (e.message?.contains('session_already_exists') ?? false)) {
        debugPrint('Session already exists, fetching user data...');
        try {
          _user = await _account.get();
          _status = AuthStatus.authenticated;
          notifyListeners();
          return true;
        } catch (getErr) {
          _error = 'Failed to fetch user data: $getErr';
        }
      }
      debugPrint('Appwrite Login Error [${e.code}]: ${e.message}');
      if (e.code == 429) {
        _error = '⏱️ Cooldown Active: Too many attempts. Please wait a few minutes before trying again.';
      } else {
        _error = e.message ?? 'An unexpected error occurred';
      }
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Generic Login Error: $e');
      _error = e.toString();
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _account.deleteSession(sessionId: 'current');
      _user = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    } catch (e) {
      debugPrint(e.toString());
    }
  }
}
