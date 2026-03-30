import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://187.124.177.100/attendance/api';
  static String? _token;
  static Map<String, dynamic>? _currentUser;

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
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // ─── GET ───
  static Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? params,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/$endpoint').replace(
        queryParameters: params,
      );
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 30));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'لا يوجد اتصال بالسيرفر'};
    }
  }

  // ─── POST ───
  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl/$endpoint');
      final response = await http
          .post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
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
