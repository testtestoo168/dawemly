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
        localizedReason: 'بصمة الحضور',
        options: const AuthenticationOptions(stickyAuth: false, biometricOnly: false, sensitiveTransaction: false),
      );
      if (result) return (success: true, error: '');
      return (success: false, error: 'تم إلغاء التحقق — حاول مرة أخرى');
    } catch (e) {
      return (success: false, error: 'خطأ في البصمة: $e');
    }
  }

  // ─── Get current location — HIGH ACCURACY ───
  // Strategy: try lastKnownPosition first (instant cache). Accept ONLY if very
  // fresh (< 5 seconds) and very accurate (< 30m). Otherwise get a fresh fix
  // with high accuracy and 8-second timeout. This ensures the position is
  // reliable for geofence checks while still being fast.
  Future<({Position? position, bool isMocked})> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return (position: null, isMocked: false);
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return (position: null, isMocked: false);
    }
    if (perm == LocationPermission.deniedForever) return (position: null, isMocked: false);

    // 1) Fast path — accept cached fix ONLY if very fresh and accurate
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        final ageMs = DateTime.now().millisecondsSinceEpoch - last.timestamp.millisecondsSinceEpoch;
        if (ageMs < 5000 && last.accuracy <= 30) {
          return (position: last, isMocked: last.isMocked);
        }
      }
    } catch (_) {}

    // 2) Fresh high-accuracy fix with 8-second timeout
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return (position: pos, isMocked: pos.isMocked);
    } catch (_) {
      // 3) Fallback: try high (not best) accuracy with shorter timeout
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
        return (position: pos, isMocked: pos.isMocked);
      } catch (_) {
        // Last resort — any cached position
        try {
          final fallback = await Geolocator.getLastKnownPosition();
          if (fallback != null) return (position: fallback, isMocked: fallback.isMocked);
        } catch (_) {}
        return (position: null, isMocked: false);
      }
    }
  }

  // Session cache: settings + user row are fetched once per app session and reused.
  // Prevents 4 redundant API calls on every home screen mount.
  static Map<String, dynamic>? _cachedGeneralSettings;
  static String? _cachedSettingsForUid;
  static Map<String, dynamic>? _cachedUser;

  static void clearAuthCache() {
    _cachedGeneralSettings = null;
    _cachedSettingsForUid = null;
    _cachedUser = null;
  }

  Future<Map<String, dynamic>> _loadSettings() async {
    if (_cachedGeneralSettings != null) return _cachedGeneralSettings!;
    final res = await ApiService.get('admin.php?action=get_settings');
    final settings = res['settings'] as Map<String, dynamic>? ?? {};
    _cachedGeneralSettings = settings['general'] as Map<String, dynamic>? ?? settings;
    return _cachedGeneralSettings!;
  }

  Future<Map<String, dynamic>> _loadUser(String uid) async {
    if (_cachedUser != null && _cachedSettingsForUid == uid) return _cachedUser!;
    final res = await ApiService.get('users.php?action=get', params: {'uid': uid});
    _cachedUser = res['user'] as Map<String, dynamic>? ?? {};
    _cachedSettingsForUid = uid;
    return _cachedUser!;
  }

  // ─── Get auth requirements — parallel fetch + session cache ───
  Future<({bool requireBiometric, bool requireLocation})> getAuthRequirements(String uid) async {
    // Fetch settings and user row in parallel (instead of sequential awaits)
    final results = await Future.wait([_loadSettings(), _loadUser(uid)]);
    final settings = results[0];
    final userData = results[1];
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

  // Public accessor used by FaceRecognitionService.isFaceAuthRequired to avoid
  // re-fetching settings and user that AttendanceService already cached.
  Future<({Map<String, dynamic> settings, Map<String, dynamic> user})> loadAuthContext(String uid) async {
    final results = await Future.wait([_loadSettings(), _loadUser(uid)]);
    return (settings: results[0], user: results[1]);
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
    bool isMocked = false;
    if (requireLocation && finalLat == null) {
      final locResult = await getCurrentLocation();
      final pos = locResult.position;
      if (pos == null) return {'success': false, 'error': 'لا يمكن تحديد الموقع — فعّل GPS'};
      if (locResult.isMocked) return {'success': false, 'error': 'تم اكتشاف تطبيق تزوير موقع — لا يمكن تسجيل الحضور'};
      finalLat = pos.latitude;
      finalLng = pos.longitude;
      finalAccuracy = pos.accuracy;
      isMocked = locResult.isMocked;
    }

    final body = <String, dynamic>{
      'uid': uid, 'emp_id': empId, 'name': name,
      'lat': finalLat, 'lng': finalLng,
      'accuracy': finalAccuracy,
      'biometric': requireBiometric,
      'auth_method': authMethod,
      'is_mocked': isMocked,
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
    bool isMocked = false;
    if (requireLocation && finalLat == null) {
      final locResult = await getCurrentLocation();
      final pos = locResult.position;
      if (pos == null) return {'success': false, 'error': 'لا يمكن تحديد الموقع — فعّل GPS'};
      if (locResult.isMocked) return {'success': false, 'error': 'تم اكتشاف تطبيق تزوير موقع — لا يمكن تسجيل الانصراف'};
      finalLat = pos.latitude;
      finalLng = pos.longitude;
      finalAccuracy = pos.accuracy;
      isMocked = locResult.isMocked;
    }

    final body = <String, dynamic>{
      'uid': uid, 'emp_id': empId, 'name': name,
      'lat': finalLat, 'lng': finalLng,
      'accuracy': finalAccuracy,
      'biometric': requireBiometric,
      'auth_method': authMethod,
      'is_mocked': isMocked,
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
