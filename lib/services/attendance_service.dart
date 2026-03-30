import 'package:geolocator/geolocator.dart';
import 'package:local_auth/local_auth.dart';
import 'api_service.dart';

class AttendanceService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  // ─── Biometric check ───
  Future<bool> authenticateBiometric() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    final isSupported = await _localAuth.isDeviceSupported();
    if (!canCheck || !isSupported) return true;
    return await _localAuth.authenticate(
      localizedReason: 'يرجى استخدام بصمة الإصبع لإثبات الهوية',
      options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
    );
  }

  // ─── Get current location ───
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return null;
    }
    if (perm == LocationPermission.deniedForever) return null;
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<Map<String, dynamic>> _loadSettings() async {
    final res = await ApiService.get('admin.php?action=get_settings');
    return res['settings'] as Map<String, dynamic>? ?? {};
  }

  // ─── Check In ───
  Future<Map<String, dynamic>> checkIn(
    String uid, String empId, String name, {
    String? facePhotoUrl,
    String authMethod = 'fingerprint',
    String? locationId,
  }) async {
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

    if (requireBiometric == true) {
      final bioOk = await authenticateBiometric();
      if (!bioOk) return {'success': false, 'error': 'فشل التحقق من البصمة'};
    }

    Position? pos;
    if (requireLocation == true) {
      pos = await getCurrentLocation();
      if (pos == null) return {'success': false, 'error': 'لا يمكن تحديد الموقع — فعّل GPS'};
    }

    final body = <String, dynamic>{
      'uid': uid, 'emp_id': empId, 'name': name,
      'lat': pos?.latitude, 'lng': pos?.longitude,
      'accuracy': pos?.accuracy,
      'biometric': requireBiometric == true,
      'auth_method': authMethod,
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
  }) async {
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

    if (requireBiometric == true) {
      final bioOk = await authenticateBiometric();
      if (!bioOk) return {'success': false, 'error': 'فشل التحقق من البصمة'};
    }

    Position? pos;
    if (requireLocation == true) {
      pos = await getCurrentLocation();
      if (pos == null) return {'success': false, 'error': 'لا يمكن تحديد الموقع — فعّل GPS'};
    }

    final body = <String, dynamic>{
      'uid': uid, 'emp_id': empId, 'name': name,
      'lat': pos?.latitude, 'lng': pos?.longitude,
      'accuracy': pos?.accuracy,
      'biometric': requireBiometric == true,
      'auth_method': authMethod,
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
        params: {'uid': uid, 'date': dateKey});
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
