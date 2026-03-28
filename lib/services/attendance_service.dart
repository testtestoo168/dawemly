import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_auth/local_auth.dart';

class AttendanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
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

  // ─── Check in (حضور) ───
  Future<Map<String, dynamic>> checkIn(String uid, String empId, String name, {String? facePhotoUrl, String authMethod = 'fingerprint'}) async {
    // Load auth settings
    final settings = await _loadAuthSettings();
    final empOverrides = await _loadEmpAuthOverrides(uid);
    
    final requireBiometric = empOverrides?['authBiometric'] ?? (settings['authFinger'] ?? true);
    final requireLocation = empOverrides?['authLoc'] ?? (settings['authLoc'] ?? true);

    if (requireBiometric) {
      final bioOk = await authenticateBiometric();
      if (!bioOk) return {'success': false, 'error': 'فشل التحقق من البصمة'};
    }

    Position? pos;
    if (requireLocation) {
      pos = await getCurrentLocation();
      if (pos == null) return {'success': false, 'error': 'لا يمكن تحديد الموقع — فعّل GPS'};
    }

    final now = DateTime.now();
    final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Save every punch to attendance log
    final record = {
      'uid': uid,
      'empId': empId,
      'name': name,
      'type': 'checkIn',
      'timestamp': FieldValue.serverTimestamp(),
      'localTime': Timestamp.fromDate(now),
      'dateKey': dateKey,
      'lat': pos?.latitude,
      'lng': pos?.longitude,
      'accuracy': pos?.accuracy,
      'biometric': requireBiometric,
      'authMethod': authMethod,
      'facePhotoUrl': facePhotoUrl,
    };

    await _db.collection('attendance').add(record);

    // Update daily summary
    final dailyRef = _db.collection('attendance_daily').doc('${uid}_$dateKey');
    final dailyDoc = await dailyRef.get();

    if (!dailyDoc.exists) {
      await dailyRef.set({
        'uid': uid,
        'empId': empId,
        'name': name,
        'dateKey': dateKey,
        'firstCheckIn': Timestamp.fromDate(now),
        'firstCheckInLat': pos?.latitude,
        'firstCheckInLng': pos?.longitude,
        'lastCheckOut': null,
        'totalWorkedMinutes': 0,
        'sessions': 1,
        'currentSessionStart': Timestamp.fromDate(now),
        'isCheckedIn': true,
        'status': 'حاضر',
        'checkIn': Timestamp.fromDate(now),
        'checkInLat': pos?.latitude,
        'checkInLng': pos?.longitude,
      });
    } else {
      await dailyRef.update({
        'currentSessionStart': Timestamp.fromDate(now),
        'isCheckedIn': true,
        'sessions': FieldValue.increment(1),
        'status': 'حاضر',
      });
    }

    return {
      'success': true,
      'time': '${now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour)}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'م' : 'ص'}',
      'lat': pos?.latitude,
      'lng': pos?.longitude,
    };
  }

  // ─── Check out (خروج) ───
  Future<Map<String, dynamic>> checkOut(String uid, String empId, String name, {String? facePhotoUrl, String authMethod = 'fingerprint'}) async {
    final settings = await _loadAuthSettings();
    final empOverrides = await _loadEmpAuthOverrides(uid);
    
    final requireBiometric = empOverrides?['authBiometric'] ?? (settings['authFinger'] ?? true);
    final requireLocation = empOverrides?['authLoc'] ?? (settings['authLoc'] ?? true);

    if (requireBiometric) {
      final bioOk = await authenticateBiometric();
      if (!bioOk) return {'success': false, 'error': 'فشل التحقق من البصمة'};
    }

    Position? pos;
    if (requireLocation) {
      pos = await getCurrentLocation();
      if (pos == null) return {'success': false, 'error': 'لا يمكن تحديد الموقع — فعّل GPS'};
    }

    final now = DateTime.now();
    final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final record = {
      'uid': uid,
      'empId': empId,
      'name': name,
      'type': 'checkOut',
      'timestamp': FieldValue.serverTimestamp(),
      'localTime': Timestamp.fromDate(now),
      'dateKey': dateKey,
      'lat': pos?.latitude,
      'lng': pos?.longitude,
      'accuracy': pos?.accuracy,
      'biometric': requireBiometric,
      'authMethod': authMethod,
      'facePhotoUrl': facePhotoUrl,
    };

    await _db.collection('attendance').add(record);

    // Calculate this session's minutes
    final dailyRef = _db.collection('attendance_daily').doc('${uid}_$dateKey');
    final dailyDoc = await dailyRef.get();

    int sessionMinutes = 0;
    if (dailyDoc.exists) {
      final data = dailyDoc.data()!;
      final sessionStart = data['currentSessionStart'] as Timestamp?;
      if (sessionStart != null) {
        sessionMinutes = now.difference(sessionStart.toDate()).inMinutes;
        if (sessionMinutes < 0) sessionMinutes = 0;
      }
    }

    // Always update lastCheckOut + accumulate worked minutes
    await dailyRef.set({
      'lastCheckOut': Timestamp.fromDate(now),
      'lastCheckOutLat': pos?.latitude,
      'lastCheckOutLng': pos?.longitude,
      'totalWorkedMinutes': FieldValue.increment(sessionMinutes),
      'isCheckedIn': false,
      'status': 'مكتمل',
      'checkOut': Timestamp.fromDate(now),
      'checkOutLat': pos?.latitude,
      'checkOutLng': pos?.longitude,
    }, SetOptions(merge: true));

    return {
      'success': true,
      'time': '${now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour)}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'م' : 'ص'}',
      'lat': pos?.latitude,
      'lng': pos?.longitude,
    };
  }

  // ─── Get today's record for user ───
  Future<Map<String, dynamic>?> getTodayRecord(String uid) async {
    final now = DateTime.now();
    final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final doc = await _db.collection('attendance_daily').doc('${uid}_$dateKey').get();
    return doc.exists ? doc.data() : null;
  }

  // ─── Get detailed punches for a specific day ───
  Future<List<Map<String, dynamic>>> getDayPunches(String uid, String dateKey) async {
    final snap = await _db.collection('attendance')
        .where('uid', isEqualTo: uid)
        .where('dateKey', isEqualTo: dateKey)
        .get();

    final punches = snap.docs.map((d) {
      final data = d.data();
      data['id'] = d.id;
      return data;
    }).toList();

    // Sort by time
    punches.sort((a, b) {
      final aTime = a['localTime'] as Timestamp? ?? a['timestamp'] as Timestamp?;
      final bTime = b['localTime'] as Timestamp? ?? b['timestamp'] as Timestamp?;
      if (aTime == null || bTime == null) return 0;
      return aTime.compareTo(bTime);
    });

    return punches;
  }

  // ─── Get attendance history for a month ───
  Stream<QuerySnapshot> getMonthlyAttendance(String uid, int year, int month) {
    return _db.collection('attendance_daily')
        .where('uid', isEqualTo: uid)
        .snapshots();
  }

  // ─── Get all today's records (for admin) ───
  Stream<QuerySnapshot> getAllTodayRecords() {
    final now = DateTime.now();
    final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return _db.collection('attendance_daily')
        .where('dateKey', isEqualTo: dateKey)
        .snapshots();
  }

  // ─── Get all records (for overtime/reports) ───
  Stream<QuerySnapshot> getAllRecords() {
    return _db.collection('attendance_daily').snapshots();
  }

  // ─── Load global auth settings ───
  Future<Map<String, dynamic>> _loadAuthSettings() async {
    try {
      final doc = await _db.collection('settings').doc('general').get();
      return doc.data() ?? {};
    } catch (_) {
      return {};
    }
  }

  // ─── Load per-employee auth overrides ───
  Future<Map<String, dynamic>?> _loadEmpAuthOverrides(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data();
      if (data != null && data['authOverride'] == true) {
        return data;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
