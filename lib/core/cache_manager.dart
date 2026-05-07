import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheManager {
  static const String _cachePrefix = 'api_cache_';
  static const String _expiryPrefix = 'api_expiry_';

  /// Saves a response to cache with a specified TTL (Time To Live).
  static Future<void> save(String key, dynamic data, Duration ttl) async {
    final prefs = await SharedPreferences.getInstance();
    final expiry = DateTime.now().add(ttl).millisecondsSinceEpoch;
    
    await prefs.setString('$_cachePrefix$key', json.encode(data));
    await prefs.setInt('$_expiryPrefix$key', expiry);
  }

  /// Retrieves data from cache if it exists and has not expired.
  static Future<dynamic> get(String key) async {
    final prefs = await SharedPreferences.getInstance();
    
    final expiry = prefs.getInt('$_expiryPrefix$key');
    if (expiry == null) return null;
    
    if (DateTime.now().millisecondsSinceEpoch > expiry) {
      // Cache expired, clean up
      await prefs.remove('$_cachePrefix$key');
      await prefs.remove('$_expiryPrefix$key');
      return null;
    }
    
    final data = prefs.getString('$_cachePrefix$key');
    return data != null ? json.decode(data) : null;
  }

  /// Clears specific cache entry
  static Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_cachePrefix$key');
    await prefs.remove('$_expiryPrefix$key');
  }

  /// Clears all API caches
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_cachePrefix) || k.startsWith(_expiryPrefix));
    for (var key in keys) {
      await prefs.remove(key);
    }
  }
}
