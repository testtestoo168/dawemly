import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://187.124.177.100/attendance/api';
  static String? _token;
  static Map<String, dynamic>? _currentUser;

  // Persistent HTTP client — reuses TCP connections (keep-alive)
  static final http.Client _client = http.Client();

  // Simple in-memory cache for GET requests (TTL-based)
  static final Map<String, _CacheEntry> _cache = {};
  static const _defaultCacheTtl = Duration(seconds: 10);

  // Callback for 401 — set by AuthGate to trigger auto-logout
  static void Function()? onUnauthorized;

  // ─── Token Management ───
  static Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('api_token');
    final userStr = prefs.getString('current_user');
    if (userStr != null) {
      _currentUser = jsonDecode(userStr);
    }
  }

  static Future<void> saveToken(String token, Map<String, dynamic> user) async {
    _token = token;
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_token', token);
    await prefs.setString('current_user', jsonEncode(user));
  }

  static Future<void> clearToken() async {
    _token = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_token');
    await prefs.remove('current_user');
  }

  static String? get token => _token;
  static Map<String, dynamic>? get currentUser => _currentUser;
  static bool get isLoggedIn => _token != null;

  static void updateCurrentUser(Map<String, dynamic> user) {
    _currentUser = user;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('current_user', jsonEncode(user));
    });
  }

  // ─── Headers ───
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
  };

  // ─── GET (with optional cache) ───
  static Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? params,
    Duration? cacheTtl,
  }) async {
    try {
      var uri = Uri.parse('$baseUrl/$endpoint');
      if (params != null && params.isNotEmpty) {
        final merged = Map<String, String>.from(uri.queryParameters)..addAll(params);
        uri = uri.replace(queryParameters: merged);
      }

      // Check cache
      final cacheKey = uri.toString();
      if (cacheTtl != null) {
        final cached = _cache[cacheKey];
        if (cached != null && !cached.isExpired) return cached.data;
      }

      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      final result = _handleResponse(response);

      // Store in cache if requested
      if (cacheTtl != null && result['success'] == true) {
        _cache[cacheKey] = _CacheEntry(result, cacheTtl);
      }

      return result;
    } catch (e) {
      // Return stale cache if available
      if (cacheTtl != null) {
        final cacheKey = Uri.parse('$baseUrl/$endpoint').toString();
        final cached = _cache[cacheKey];
        if (cached != null) return cached.data;
      }
      return {'success': false, 'error': 'لا يوجد اتصال بالسيرفر'};
    }
  }

  /// Clear all cached responses
  static void clearCache() => _cache.clear();

  // ─── POST ───
  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl/$endpoint');
      final response = await _client
          .post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'لا يوجد اتصال بالسيرفر'};
    }
  }

  // ─── POST Multipart (for file uploads) ───
  static Future<Map<String, dynamic>> postMultipart(
    String endpoint,
    Map<String, String> fields, {
    String? filePath,
    String? fileField,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/$endpoint');
      final request = http.MultipartRequest('POST', uri);
      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      request.fields.addAll(fields);
      if (fileBytes != null && fileField != null && fileName != null) {
        request.files.add(http.MultipartFile.fromBytes(
          fileField,
          fileBytes,
          filename: fileName,
        ));
      } else if (filePath != null && fileField != null) {
        request.files.add(await http.MultipartFile.fromPath(fileField, filePath));
      }
      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'فشل رفع الملف'};
    }
  }

  // ─── Handle Response ───
  static Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode == 401) {
      // Auto-logout: clear token and notify the app
      clearToken();
      _cache.clear();
      onUnauthorized?.call();
      return {'success': false, 'error': 'انتهت الجلسة — يرجى تسجيل الدخول مرة أخرى', 'unauthorized': true};
    }
    if (response.statusCode == 403) {
      return {'success': false, 'error': 'غير مصرح لك بهذا الإجراء'};
    }
    if (response.statusCode >= 500) {
      return {'success': false, 'error': 'خطأ في السيرفر (${response.statusCode})'};
    }
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      return {'success': false, 'error': 'استجابة غير صحيحة من السيرفر'};
    } catch (_) {
      return {
        'success': false,
        'error': 'خطأ في السيرفر (${response.statusCode})',
      };
    }
  }
}

class _CacheEntry {
  final Map<String, dynamic> data;
  final DateTime _expiry;
  _CacheEntry(this.data, Duration ttl) : _expiry = DateTime.now().add(ttl);
  bool get isExpired => DateTime.now().isAfter(_expiry);
}
