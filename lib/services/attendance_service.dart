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
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: false,
      ),
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

  // ─── Check in ───
  Future<Map<String, dynamic>> checkIn(String uid, String empId, String name, {String? facePhotoUrl, String authMethod = 'fingerprint'}) async {
    // Load auth settings from API
    final settings = await _loadAuthSettings();
    final empOverrides = await _loadEmpAuthOverrides(uid);

    final requireBiometric = empOverrides?['authBiometric'] ?? (settings['authFinger'] ?? true);
    final requireLocation = empOverrides?['authLoc'] ?? (settings['authLoc'] ?? true);

    if (requireBiometric == true) {
      final bioOk = await authenticateBiometric();
      if (!bioOk) return {'success': false, 'error': 'فشل التحقق من البصمة'};
    }

    Position? pos;
    if (requireLocation == true) {
      pos = await getCurrentLocation();
      if (pos == null) return {'success': false, 'error': 'لا يمكن تحديد الموقع — فعّل GPS'};
    }

    try {
      final result = await ApiService.post('attendance.php?action=checkIn', body: {
        'lat': pos?.latitude,
        'lng': pos?.longitude,
        'accuracy': pos?.accuracy,
        'biometric': requireBiometric == true,
        'auth_method': authMethod,
        'face_photo_url': facePhotoUrl,
      });

      final now = DateTime.now();
      return {
        'success': true,
        'time': '${now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour)}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'م' : 'ص'}',
        'lat': pos?.latitude,
        'lng': pos?.longitude,
        ...result,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─── Check out ───
  Future<Map<String, dynamic>> checkOut(String uid, String empId, String name, {String? facePhotoUrl, String authMethod = 'fingerprint'}) async {
    final settings = await _loadAuthSettings();
    final empOverrides = await _loadEmpAuthOverrides(uid);

    final requireBiometric = empOverrides?['authBiometric'] ?? (settings['authFinger'] ?? true);
    final requireLocation = empOverrides?['authLoc'] ?? (settings['authLoc'] ?? true);

    if (requireBiometric == true) {
      final bioOk = await authenticateBiometric();
      if (!bioOk) return {'success': false, 'error': 'فشل التحقق من البصمة'};
    }

    Position? pos;
    if (requireLocation == true) {
      pos = await getCurrentLocation();
      if (pos == null) return {'success': false, 'error': 'لا يمكن تحديد الموقع — فعّل GPS'};
    }

    try {
      final result = await ApiService.post('attendance.php?action=checkOut', body: {
        'lat': pos?.latitude,
        'lng': pos?.longitude,
        'accuracy': pos?.accuracy,
        'biometric': requireBiometric == true,
        'auth_method': authMethod,
        'face_photo_url': facePhotoUrl,
      });

      final now = DateTime.now();
      return {
        'success': true,
        'time': '${now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour)}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'م' : 'ص'}',
        'lat': pos?.latitude,
        'lng': pos?.longitude,
        ...result,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─── Get today's record for user ───
  Future<Map<String, dynamic>?> getTodayRecord(String uid) async {
    try {
      final result = await ApiService.get('attendance.php?action=today');
      if (result['record'] != null) return Map<String, dynamic>.from(result['record']);
      return result.containsKey('uid') ? result : null;
    } catch (_) {
      return null;
    }
  }

  // ─── Get detailed punches for a specific day ───
  Future<List<Map<String, dynamic>>> getDayPunches(String uid, String dateKey) async {
    try {
      final result = await ApiService.get('attendance.php?action=punches&date_key=$dateKey');
      final list = result['punches'] ?? result['data'] ?? [];
      return (list as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ─── Get attendance history for a month ───
  Future<List<Map<String, dynamic>>> getMonthlyAttendance(String uid, int year, int month) async {
    try {
      final result = await ApiService.get('attendance.php?action=monthly&year=$year&month=$month');
      final list = result['records'] ?? result['data'] ?? [];
      return (list as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ─── Get all today's records (for admin) ───
  Future<List<Map<String, dynamic>>> getAllTodayRecords() async {
    try {
      final result = await ApiService.get('attendance.php?action=all_today');
      final list = result['records'] ?? result['data'] ?? [];
      return (list as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ─── Get all records (for overtime/reports) ───
  Future<List<Map<String, dynamic>>> getAllRecords({int limit = 500, int offset = 0}) async {
    try {
      final result = await ApiService.get('attendance.php?action=all_records&limit=$limit&offset=$offset');
      final list = result['records'] ?? result['data'] ?? [];
      return (list as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ─── Load global auth settings ───
  Future<Map<String, dynamic>> _loadAuthSettings() async {
    try {
      final result = await ApiService.get('admin.php?action=get_settings');
      return result['settings'] != null ? Map<String, dynamic>.from(result['settings']) : result;
    } catch (_) {
      return {};
    }
  }

  // ─── Load per-employee auth overrides ───
  Future<Map<String, dynamic>?> _loadEmpAuthOverrides(String uid) async {
    try {
      final result = await ApiService.get('users.php?action=get&uid=$uid');
      final data = result['user'] != null ? Map<String, dynamic>.from(result['user']) : result;
      if (data['authOverride'] == true) return data;
      return null;
    } catch (_) {
      return null;
    }
  }
}
