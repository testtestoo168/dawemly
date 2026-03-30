import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';
import 'device_info_service.dart';

class AuthService {
  // ─── Login ───
  Future<Map<String, dynamic>?> loginWithEmail(
    String email,
    String password,
  ) async {
    final deviceDetails = await DeviceInfoService.getDeviceDetails();
    final result = await ApiService.post('auth.php?action=login', {
      'email': email,
      'password': password,
      'platform': kIsWeb ? 'web' : (deviceDetails['platform'] ?? 'mobile'),
      'device_model': deviceDetails['deviceModel'] ?? '',
      'os_version': deviceDetails['osVersion'] ?? '',
      'device_brand': deviceDetails['deviceBrand'] ?? '',
    });

    if (result['success'] == true) {
      final token = result['token'] as String?;
      final user = result['user'] as Map<String, dynamic>?;
      if (token != null && user != null) {
        await ApiService.saveToken(token, user);
        _saveFcmToken();
        return user;
      }
    }

    final error = result['error'] ?? result['message'] ?? 'خطأ في تسجيل الدخول';
    throw Exception(error);
  }

  // ─── Register (Admin creates users) ───
  Future<Map<String, dynamic>?> registerWithEmail(
    String email,
    String password,
    Map<String, dynamic> userData,
  ) async {
    final result = await ApiService.post('auth.php?action=register', {
      'email': email,
      'password': password,
      'name': userData['name'] ?? '',
      'dept': userData['dept'] ?? '',
      'role': userData['role'] ?? 'employee',
      'phone': userData['phone'] ?? '',
      'emp_id': userData['empId'] ?? '',
    });

    if (result['success'] == true) {
      return result['user'] as Map<String, dynamic>?;
    }
    throw Exception(result['error'] ?? 'فشل إنشاء الحساب');
  }

  // ─── Logout ───
  Future<void> logout() async {
    await ApiService.post('auth.php?action=logout', {});
    await ApiService.clearToken();
  }

  // ─── Get current user ───
  Future<Map<String, dynamic>?> getCurrentUser() async {
    if (!ApiService.isLoggedIn) return null;
    final result = await ApiService.get('auth.php?action=me');
    if (result['success'] == true) {
      final user = result['user'] as Map<String, dynamic>?;
      if (user != null) {
        ApiService.updateCurrentUser(user);
        return user;
      }
    }
    return null;
  }

  // ─── Change password ───
  Future<bool> changePassword(String currentPass, String newPass) async {
    final result = await ApiService.post('auth.php?action=reset_password', {
      'current_password': currentPass,
      'new_password': newPass,
    });
    return result['success'] == true;
  }

  // ─── Clear session (admin) ───
  Future<void> clearSession(String uid) async {
    await ApiService.post('users.php?action=clear_session', {'uid': uid});
  }

  // ─── Save FCM token ───
  void _saveFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await ApiService.post('auth.php?action=update_fcm', {'fcm_token': token});
      }
    } catch (_) {}
  }

  // ─── Static refresh FCM ───
  static void refreshFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await ApiService.post('auth.php?action=update_fcm', {'fcm_token': token});
      }
    } catch (_) {}
  }
}
