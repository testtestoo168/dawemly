import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://187.124.177.100/attendance/api';
  static String? _token;
  static String? _uid;
  static Map<String, dynamic>? _currentUser;

  // ─── Token Management ───
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _uid = prefs.getString('auth_uid');
    final userJson = prefs.getString('auth_user');
    if (userJson != null) {
      _currentUser = jsonDecode(userJson);
    }
  }

  static String? get token => _token;
  static String? get uid => _uid;
  static Map<String, dynamic>? get currentUser => _currentUser;
  static bool get isLoggedIn => _token != null && _uid != null;

  static Future<void> saveSession(String token, Map<String, dynamic> user) async {
    _token = token;
    _uid = user['uid']?.toString() ?? '';
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('auth_uid', _uid!);
    await prefs.setString('auth_user', jsonEncode(user));
  }

  static Future<void> clearSession() async {
    _token = null;
    _uid = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_uid');
    await prefs.remove('auth_user');
  }

  static Future<void> updateCurrentUser(Map<String, dynamic> user) async {
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_user', jsonEncode(user));
  }

  // ─── HTTP Methods ───
  static Map<String, String> _headers({bool isJson = true}) {
    final h = <String, String>{};
    if (isJson) h['Content-Type'] = 'application/json';
    if (_token != null) h['Authorization'] = 'Bearer $_token';
    return h;
  }

  static Future<Map<String, dynamic>> get(String endpoint, {Map<String, String>? params}) async {
    var uri = Uri.parse('$baseUrl/$endpoint');
    if (params != null) {
      uri = uri.replace(queryParameters: {...uri.queryParameters, ...params});
    }
    final response = await http.get(uri, headers: _headers());
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> post(String endpoint, {Map<String, dynamic>? body, Map<String, String>? params}) async {
    var uri = Uri.parse('$baseUrl/$endpoint');
    if (params != null) {
      uri = uri.replace(queryParameters: {...uri.queryParameters, ...params});
    }
    final response = await http.post(uri, headers: _headers(), body: body != null ? jsonEncode(body) : null);
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> uploadFile(String endpoint, Uint8List fileBytes, String filename, {Map<String, String>? fields}) async {
    final uri = Uri.parse('$baseUrl/$endpoint');
    final request = http.MultipartRequest('POST', uri);
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    if (fields != null) request.fields.addAll(fields);
    request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: filename));
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (response.statusCode == 401) {
        // Token expired - clear session
        clearSession();
        throw ApiException('انتهت الجلسة — يرجى تسجيل الدخول مرة أخرى', 401);
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (data is Map<String, dynamic>) return data;
        return {'data': data};
      }
      final msg = data is Map ? (data['message'] ?? data['error'] ?? 'خطأ غير معروف') : 'خطأ غير معروف';
      throw ApiException(msg.toString(), response.statusCode);
    } catch (e) {
      if (e is ApiException) rethrow;
      if (response.statusCode == 401) {
        clearSession();
        throw ApiException('انتهت الجلسة — يرجى تسجيل الدخول مرة أخرى', 401);
      }
      throw ApiException('خطأ في الاتصال بالسيرفر: ${response.statusCode}', response.statusCode);
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);
  @override
  String toString() => message;
}
