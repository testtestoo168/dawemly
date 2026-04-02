import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:local_auth/local_auth.dart';
import 'api_service.dart';

class AttendanceService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  // ─── Biometric check ───
  Future<bool> authenticateBiometric() async {
    if (kIsWeb) return true; // Biometrics not available on web
    final canCheck = await _localAuth.canCheckBiometrics;
    final isSupported = await _localAuth.isDeviceSupported();
    if (!canCheck || !isSupported) return false;
    return await _localAuth.authenticate(
      localizedReason: 'يرجى استخدام بصمة الإصبع لإثبات الهوية',
      options: const AuthenticationOptions(stickyAuth: false, biometricOnly: false),
    );
  }

  // ─── Biometric check with detailed error ───
  Future<({bool success, String error})> authenticateBiometricWithDetails() async {
    if (kIsWeb) return (success: true, error: ''); // Skip biometrics on web
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!isSupported) {
        return (success: false, error: 'جهازك لا يدعم البصمة — استخدم قفل الشاشة');
      }
      if (!canCheck) {
        return (success: false, error: 'لم يتم تسجيل بصمة على الجهاز — سجّل بصمة من إعدادات الجهاز');
      }
      final result = await _localAuth.authenticate(
        localizedReason: 'يرجى استخدام بصمة الإصبع لإثبات الهوية',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
      );
      if (result) return (success: true, error: '');
      return (success: false, error: 'تم إلغاء التحقق — حاول مرة أخرى');
    } catch (e) {
      return (success: false, error: 'خطأ في البصمة: $e');
    }
  }

  // ─── Get current location with mock detection ───
  Future<({Position? position, bool isMocked})> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return (position: null, isMocked: false);
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return (position: null, isMocked: false);
    }
    if (perm == LocationPermission.deniedForever) return (position: null, isMocked: false);
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    // If accuracy is poor, wait and try once more with best accuracy
    if (pos.accuracy > 100) {
      try {
        final betterPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
        ).timeout(const Duration(seconds: 8));
        if (betterPos.accuracy < pos.accuracy) {
          return (position: betterPos, isMocked: betterPos.isMocked);
        }
      } catch (_) {}
    }
    return (position: pos, isMocked: pos.isMocked);
  }

  Future<Map<String, dynamic>> _loadSettings() async {
    final res = await ApiService.get('admin.php?action=get_settings');
    final settings = res['settings'] as Map<String, dynamic>? ?? {};
    return settings['general'] as Map<String, dynamic>? ?? {};
  }

  // ─── Get auth requirements for a user (call BEFORE showing loading dialog) ───
  Future<({bool requireBiometric, bool requireLocation})> getAuthRequirements(String uid) async {
    final settings = await _loadSettings();
    final userRes = await ApiService.get('users.php?action=get', params: {'uid': uid});
    final userData = userRes['user'] as Map<String, dynamic>? ?? {};
    final hasOverride = userData['authOverride'] == true;
    final requireBiometric = hasOverride
        ? (userData['authBiometric'] ?? settings['authFinger'] ?? true)
        : (settings['authFinger'] ?? true);
    final requireLocation = hasOverride
        ? (userData['authLoc'] ?? settings['authLoc'] ?? true)
        : (settings['authLoc'] ?? true);
    return (
      requireBiometric: requireBiometric == true,
      requireLocation: requireLocation == true,
    );
  }

  // ─── Check In ───
  Future<Map<String, dynamic>> checkIn(
    String uid, String empId, String name, {
    String? facePhotoUrl,
    String authMethod = 'fingerprint',
    String? locationId,
    bool requireBiometric = false,
    bool requireLocation = true,
    double? lat,
    double? lng,
    double? accuracy,
  }) async {
    // Use provided coordinates if available, otherwise fetch location
    double? finalLat = lat;
    double? finalLng = lng;
    double? finalAccuracy = accuracy;
    if (requireLocation && finalLat == null) {
      final locResult = await getCurrentLocation();
      final pos = locResult.position;
      if (pos == null) return {'success': false, 'error': 'لا يمكن تحديد الموقع — فعّل GPS'};
      if (locResult.isMocked) return {'success': false, 'error': 'تم اكتشاف تطبيق تزوير موقع — لا يمكن تسجيل الحضور'};
      finalLat = pos.latitude;
      finalLng = pos.longitude;
      finalAccuracy = pos.accuracy;
    }

    final body = <String, dynamic>{
      'uid': uid, 'emp_id': empId, 'name': name,
      'lat': finalLat, 'lng': finalLng,
      'accuracy': finalAccuracy,
      'biometric': requireBiometric,
      'auth_method': authMethod,
      'is_mocked': false,
      'client_time': DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' '),
    };
    if (facePhotoUrl != null) body['face_photo_url'] = facePhotoUrl;
    if (locationId != null) body['location_id'] = locationId;

    return await ApiService.post('attendance.php?action=checkIn', body);
  }

  // ─── Check Out ───
  Future<Map<String, dynamic>> checkOut(
    String uid, String empId, String name, {
    String? facePhotoUrl,
    String authMethod = 'fingerprint',
    String? locationId,
    bool requireBiometric = false,
    bool requireLocation = true,
    double? lat,
    double? lng,
    double? accuracy,
  }) async {
    // Use provided coordinates if available, otherwise fetch location
    double? finalLat = lat;
    double? finalLng = lng;
    double? finalAccuracy = accuracy;
    if (requireLocation && finalLat == null) {
      final locResult = await getCurrentLocation();
      final pos = locResult.position;
      if (pos == null) return {'success': false, 'error': 'لا يمكن تحديد الموقع — فعّل GPS'};
      if (locResult.isMocked) return {'success': false, 'error': 'تم اكتشاف تطبيق تزوير موقع — لا يمكن تسجيل الانصراف'};
      finalLat = pos.latitude;
      finalLng = pos.longitude;
      finalAccuracy = pos.accuracy;
    }

    final body = <String, dynamic>{
      'uid': uid, 'emp_id': empId, 'name': name,
      'lat': finalLat, 'lng': finalLng,
      'accuracy': finalAccuracy,
      'biometric': requireBiometric,
      'auth_method': authMethod,
      'is_mocked': false,
      'client_time': DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' '),
    };
    if (facePhotoUrl != null) body['face_photo_url'] = facePhotoUrl;
    if (locationId != null) body['location_id'] = locationId;

    return await ApiService.post('attendance.php?action=checkOut', body);
  }

  // ─── Today record ───
  Future<Map<String, dynamic>?> getTodayRecord(String uid) async {
    final result = await ApiService.get('attendance.php?action=today', params: {'uid': uid});
    if (result['success'] == true) return result['record'] as Map<String, dynamic>?;
    return null;
  }

  // ─── Day punches ───
  Future<List<Map<String, dynamic>>> getDayPunches(String uid, String dateKey) async {
    final result = await ApiService.get('attendance.php?action=punches',
        params: {'uid': uid, 'date_key': dateKey});
    if (result['success'] == true) {
      return (result['punches'] as List? ?? []).cast<Map<String, dynamic>>();
    }
    return [];
  }

  // ─── Monthly attendance ───
  Future<List<Map<String, dynamic>>> getMonthlyAttendance(String uid, int year, int month) async {
    final result = await ApiService.get('attendance.php?action=monthly',
        params: {'uid': uid, 'year': year.toString(), 'month': month.toString()});
    if (result['success'] == true) {
      return (result['records'] as List? ?? []).cast<Map<String, dynamic>>();
    }
    return [];
  }

  // ─── All today (admin) ───
  Future<List<Map<String, dynamic>>> getAllTodayRecords() async {
    final result = await ApiService.get('attendance.php?action=all_today');
    if (result['success'] == true) {
      return (result['records'] as List? ?? []).cast<Map<String, dynamic>>();
    }
    return [];
  }

  // ─── All records (admin) ───
  Future<List<Map<String, dynamic>>> getAllRecords() async {
    final result = await ApiService.get('attendance.php?action=all_records');
    if (result['success'] == true) {
      return (result['records'] as List? ?? []).cast<Map<String, dynamic>>();
    }
    return [];
  }
}
