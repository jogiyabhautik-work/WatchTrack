import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:watch_track/core/appwrite_client.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AuthStatus { authenticatedOnline, authenticatedOffline, unauthenticated, authenticating, initial }

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

  Future<void> _saveLocalUser(models.User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userId', user.$id);
      await prefs.setString('userEmail', user.email);
      await prefs.setString('userName', user.name);
    } catch (e) {
      debugPrint('Failed to save local user: $e');
    }
  }

  Future<void> _clearLocalUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isLoggedIn');
      await prefs.remove('userId');
      await prefs.remove('userEmail');
      await prefs.remove('userName');
    } catch (e) {
      debugPrint('Failed to clear local user: $e');
    }
  }

  Future<bool> _hasLocalSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('isLoggedIn') ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _hasInternet() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return !connectivityResult.contains(ConnectivityResult.none);
    } catch (e) {
      return false;
    }
  }

  Future<void> _checkStatus() async {
    final startTime = DateTime.now();

    try {
      // ── 1. Always try to get the live session first.
      //      Appwrite persists the session cookie natively, so this works
      //      across hot restarts AND normal app re-opens without reinstall.
      _user = await _account.get();
      await _saveLocalUser(_user!);          // keep SharedPrefs in sync
      _status = AuthStatus.authenticatedOnline;
    } on AppwriteException catch (e) {
      // 401 = genuinely logged out / session expired
      if (e.code == 401 || (e.message?.contains('session') ?? false)) {
        await _clearLocalUser();
        _status = AuthStatus.unauthenticated;
      } else {
        // Network / server error — check if the user was previously logged in
        final hasLocalSession = await _hasLocalSession();
        _status = hasLocalSession
            ? AuthStatus.authenticatedOffline
            : AuthStatus.unauthenticated;
      }
    } catch (_) {
      // Generic error (e.g. no internet, timeout)
      final hasLocalSession = await _hasLocalSession();
      _status = hasLocalSession
          ? AuthStatus.authenticatedOffline
          : AuthStatus.unauthenticated;
    }

    // Keep splash visible for at least 1800 ms for premium UX
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
    
    // Clear any stuck sessions before registering
    try {
      await _account.deleteSession(sessionId: 'current');
    } catch (_) {}

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
      await _saveLocalUser(_user!);
      _status = AuthStatus.authenticatedOnline;
      notifyListeners();
      return true;
    } on AppwriteException catch (e) {
      final isSessionError = e.code == 409 || 
          (e.message?.contains('session_already_exists') ?? false) ||
          (e.message?.contains('Creation of a session is prohibited') ?? false);
          
      if (isSessionError) {
        debugPrint('Session already exists. Attempting to clear old session and retry...');
        try {
          try {
            await _account.deleteSession(sessionId: 'current');
          } catch (_) {}
          
          await _account.createEmailPasswordSession(
            email: email,
            password: password,
          );
          _user = await _account.get();
          await _saveLocalUser(_user!);
          _status = AuthStatus.authenticatedOnline;
          notifyListeners();
          return true;
        } on AppwriteException catch (retryErr) {
          _error = retryErr.message ?? 'An unexpected error occurred during retry.';
          _status = AuthStatus.unauthenticated;
          notifyListeners();
          return false;
        } catch (retryErr) {
          _error = retryErr.toString();
          _status = AuthStatus.unauthenticated;
          notifyListeners();
          return false;
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
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      await _clearLocalUser();
      _user = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<bool> sendPasswordRecovery(String email) async {
    try {
      await _account.createRecovery(
        email: email,
        url: 'appwrite-callback-693d20f1002b63c1bffd://reset-password',
      );
      return true;
    } on AppwriteException catch (e) {
      _error = e.message ?? e.toString();
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword({
    required String userId,
    required String secret,
    required String newPassword,
  }) async {
    try {
      await _account.updateRecovery(
        userId: userId,
        secret: secret,
        password: newPassword,
      );
      return true;
    } on AppwriteException catch (e) {
      _error = e.message ?? e.toString();
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendEmailVerification() async {
    try {
      await _account.createVerification(
        url: 'appwrite-callback-693d20f1002b63c1bffd://verify-email',
      );
      return true;
    } on AppwriteException catch (e) {
      _error = e.message ?? e.toString();
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> checkEmailVerification() async {
    try {
      if (_user != null) {
        _user = await _account.get();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to refresh user for verification check: $e');
    }
  }

  Future<bool> updateUserName(String newName) async {
    try {
      _user = await _account.updateName(name: newName);
      if (_user != null) {
        await _saveLocalUser(_user!);
      }
      notifyListeners();
      return true;
    } on AppwriteException catch (e) {
      _error = e.message ?? e.toString();
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePassword({required String oldPassword, required String newPassword}) async {
    try {
      await _account.updatePassword(password: newPassword, oldPassword: oldPassword);
      return true;
    } on AppwriteException catch (e) {
      _error = e.message ?? e.toString();
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
