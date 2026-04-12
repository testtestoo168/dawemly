import 'dart:io' show InternetAddress, SocketException;
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:geolocator_apple/geolocator_apple.dart';
import 'package:local_auth/local_auth.dart';
import 'api_service.dart';
import 'offline_queue_service.dart';
import '../l10n/app_locale.dart';

class AttendanceService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  // ─── Biometric check ───
  Future<bool> authenticateBiometric() async {
    if (kIsWeb) return true; // Biometrics not available on web
    final canCheck = await _localAuth.canCheckBiometrics;
    final isSupported = await _localAuth.isDeviceSupported();
    if (!canCheck || !isSupported) return false;
    return await _localAuth.authenticate(
      localizedReason: L.tr('fingerprint_verify'),
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
        return (success: false, error: L.tr('device_no_fingerprint'));
      }
      if (!canCheck) {
        return (success: false, error: L.tr('no_fingerprint_registered'));
      }
      final result = await _localAuth.authenticate(
        localizedReason: L.tr('attendance_punch'),
        options: const AuthenticationOptions(stickyAuth: false, biometricOnly: false, sensitiveTransaction: false),
      );
      if (result) return (success: true, error: '');
      return (success: false, error: L.tr('verify_cancelled_retry'));
    } catch (e) {
      return (success: false, error: L.tr('error_occurred', args: {'error': e.toString()}));
    }
  }

  // ─── Platform-optimized location settings ───
  static LocationSettings bestSettings({Duration timeout = const Duration(seconds: 10)}) {
    if (kIsWeb) {
      return LocationSettings(accuracy: LocationAccuracy.best, timeLimit: timeout);
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        // FusedLocationProvider combines GPS + WiFi + Cell for fastest accurate fix
        forceLocationManager: false,
        // Request updates every 1 second for maximum freshness
        intervalDuration: const Duration(seconds: 1),
        timeLimit: timeout,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        activityType: ActivityType.other,
        // Don't pause — keep GPS hot for instant reads
        pauseLocationUpdatesAutomatically: false,
        timeLimit: timeout,
      );
    }
    return LocationSettings(accuracy: LocationAccuracy.best, timeLimit: timeout);
  }

  static LocationSettings streamSettings() {
    if (kIsWeb) {
      return const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 3);
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 2),
        // Update every 2 meters for precise tracking
        distanceFilter: 2,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        activityType: ActivityType.other,
        distanceFilter: 2,
        pauseLocationUpdatesAutomatically: false,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 2);
  }

  // ─── Get current location — HIGH ACCURACY ───
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
        if (ageMs < 3000 && last.accuracy <= 15) {
          return (position: last, isMocked: last.isMocked);
        }
      }
    } catch (_) {}

    // 2) Fresh fix with platform-optimized settings (10s timeout)
    try {
      final pos = await Geolocator.getCurrentPosition(locationSettings: bestSettings());
      if (pos.accuracy <= 25) return (position: pos, isMocked: pos.isMocked);
      // Got a fix but accuracy is poor — try once more
    } catch (_) {}

    // 3) Second attempt (6s timeout)
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: bestSettings(timeout: const Duration(seconds: 6)),
      );
      return (position: pos, isMocked: pos.isMocked);
    } catch (_) {
      return (position: null, isMocked: false);
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

  /// Fast connectivity probe — resolves one DNS lookup, no-op on web.
  /// Returns false only when we're confident there's no reachable network.
  Future<bool> _hasInternet() async {
    if (kIsWeb) return true; // Browsers manage offline/online directly.
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      // DNS failure, timeout, airplane mode → treat as offline
      return false;
    }
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
      if (pos == null) return {'success': false, 'error': L.tr('cant_determine_location')};
      if (locResult.isMocked) return {'success': false, 'error': L.tr('spoofing_check_in_block')};
      finalLat = pos.latitude;
      finalLng = pos.longitude;
      finalAccuracy = pos.accuracy;
      isMocked = locResult.isMocked;
    }

    // ─── Offline path ───
    // If we have no internet, try to queue locally (only if offline mode
    // was previously enabled by admin for this user). GPS validation already
    // happened locally at the call site (caller checks geofence).
    if (!await _hasInternet()) {
      final queue = OfflineQueueService.instance;
      if (await queue.isEnabledFor(uid)) {
        try {
          await queue.queuePunch(
            uid: uid, empId: empId, name: name, type: 'checkIn',
            lat: finalLat ?? 0.0, lng: finalLng ?? 0.0,
            accuracy: finalAccuracy ?? 0.0,
            authMethod: authMethod, facePhotoUrl: facePhotoUrl,
            biometric: requireBiometric,
          );
          return {
            'success': true,
            'offline': true,
            'message': L.tr('offline_check_in_saved'),
            'lat': finalLat, 'lng': finalLng,
          };
        } catch (_) {
          return {'success': false, 'error': L.tr('offline_not_allowed')};
        }
      }
      return {'success': false, 'error': L.tr('offline_not_allowed')};
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
      if (pos == null) return {'success': false, 'error': L.tr('cant_determine_location')};
      if (locResult.isMocked) return {'success': false, 'error': L.tr('spoofing_check_out_block')};
      finalLat = pos.latitude;
      finalLng = pos.longitude;
      finalAccuracy = pos.accuracy;
      isMocked = locResult.isMocked;
    }

    // ─── Offline path ───
    if (!await _hasInternet()) {
      final queue = OfflineQueueService.instance;
      if (await queue.isEnabledFor(uid)) {
        try {
          await queue.queuePunch(
            uid: uid, empId: empId, name: name, type: 'checkOut',
            lat: finalLat ?? 0.0, lng: finalLng ?? 0.0,
            accuracy: finalAccuracy ?? 0.0,
            authMethod: authMethod, facePhotoUrl: facePhotoUrl,
            biometric: requireBiometric,
          );
          return {
            'success': true,
            'offline': true,
            'message': L.tr('offline_check_in_saved'),
            'lat': finalLat, 'lng': finalLng,
          };
        } catch (_) {
          return {'success': false, 'error': L.tr('offline_not_allowed')};
        }
      }
      return {'success': false, 'error': L.tr('offline_not_allowed')};
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
  Future<List<Map<String, dynamic>>> getAllRecords({int? limit, int? offset}) async {
    final params = <String, String>{};
    if (limit != null) params['limit'] = limit.toString();
    if (offset != null) params['offset'] = offset.toString();
    final result = await ApiService.get('attendance.php?action=all_records', params: params);
    if (result['success'] == true) {
      return (result['records'] as List? ?? []).cast<Map<String, dynamic>>();
    }
    return [];
  }

  // ─── All records count (admin) ───
  Future<int> getAllRecordsCount() async {
    final result = await ApiService.get('attendance.php?action=all_records', params: {'limit': '1', 'offset': '0'});
    if (result['success'] == true) {
      return (result['total'] as int?) ?? 0;
    }
    return 0;
  }
}
