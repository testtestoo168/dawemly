import 'package:flutter/foundation.dart' show kIsWeb;
import 'api_service.dart';
import 'device_info_service.dart';

class AuthService {
  String? get currentUid => ApiService.uid;
  Map<String, dynamic>? get currentUser => ApiService.currentUser;
  bool get isLoggedIn => ApiService.isLoggedIn;

  // ─── Email Login ───
  Future<Map<String, dynamic>?> loginWithEmail(String email, String password) async {
    final deviceDetails = await DeviceInfoService.getDeviceDetails();
    final platform = deviceDetails['platform'] ?? (kIsWeb ? 'web' : 'mobile');

    final result = await ApiService.post('auth.php?action=login', body: {
      'email': email,
      'password': password,
      'platform': platform,
      'device_model': deviceDetails['deviceModel'] ?? 'unknown',
      'os_version': deviceDetails['osVersion'] ?? '',
      'device_brand': deviceDetails['deviceBrand'] ?? '',
      'device_id': '${DateTime.now().millisecondsSinceEpoch}_${email.hashCode}',
    });

    final token = result['token']?.toString();
    if (token == null) return null;

    final user = Map<String, dynamic>.from(result['user'] ?? result);
    await ApiService.saveSession(token, user);
    return user;
  }

  // ─── Email Register (Admin creates users) ───
  Future<Map<String, dynamic>?> registerWithEmail(String email, String password, Map<String, dynamic> userData) async {
    final result = await ApiService.post('auth.php?action=register', body: {
      'email': email,
      'password': password,
      'name': userData['name'] ?? '',
      'dept': userData['dept'] ?? '',
      'role': userData['role'] ?? 'employee',
      'phone': userData['phone'] ?? '',
      'emp_id': userData['empId'] ?? 'EMP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    });

    return result['user'] != null ? Map<String, dynamic>.from(result['user']) : result;
  }

  // ─── Get current user data ───
  Future<Map<String, dynamic>?> getMe() async {
    try {
      final result = await ApiService.get('auth.php?action=me');
      final user = Map<String, dynamic>.from(result['user'] ?? result);
      await ApiService.updateCurrentUser(user);
      return user;
    } catch (_) {
      return null;
    }
  }

  // ─── Password Reset ───
  Future<void> resetPassword(String currentPassword, String newPassword) async {
    await ApiService.post('auth.php?action=reset_password', body: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  // ─── Update FCM Token ───
  Future<void> updateFcmToken(String fcmToken) async {
    try {
      await ApiService.post('auth.php?action=update_fcm', body: {
        'fcm_token': fcmToken,
      });
    } catch (_) {}
  }

  // ─── Clear active session ───
  Future<void> clearSession(String uid) async {
    // Server handles session cleanup on logout
  }

  // ─── Logout ───
  Future<void> logout() async {
    try {
      await ApiService.post('auth.php?action=logout');
    } catch (_) {}
    await ApiService.clearSession();
  }
}
