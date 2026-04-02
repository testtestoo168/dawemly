import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_colors.dart';
import '../../services/attendance_service.dart';
import '../../services/face_recognition_service.dart';
import '../../services/api_service.dart';
import '../../services/server_time_service.dart';
import 'face_registration_page.dart';
import 'face_verify_dialog.dart';

class EmpHomePage extends StatefulWidget {
  final Map<String, dynamic> user;
  final Function(int)? onTabChange;
  const EmpHomePage({super.key, required this.user, this.onTabChange});
  @override
  State<EmpHomePage> createState() => _EmpHomePageState();
}

class _EmpHomePageState extends State<EmpHomePage> {
  final _attService = AttendanceService();
  Map<String, dynamic>? _todayRecord;
  bool _loadingRecord = true;
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  String _currentTime = '';

  // ═══ Location selection ═══
  List<Map<String, dynamic>> _allLocations = [];
  String? _selectedLocationId;
  bool _loadingLocations = true;

  static const double _standardHours = 8.0;

  // Live map
  Position? _livePosition;
  GoogleMapController? _liveMapController;
  Timer? _locationTimer;

  // Verification polling
  Timer? _verifyPollTimer;
  bool _verifyDialogShowing = false;

  // Cached auth requirements (loaded once on init)
  bool _cachedRequireBiometric = true;
  bool _cachedRequireLocation = true;
  bool _cachedFaceRequired = false;
  bool _authReqsLoaded = false;

  final _months = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
  final _days = ['الأحد','الإثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت'];

  @override
  void initState() {
    super.initState();
    _loadToday();
    _loadLocations();
    _loadAuthRequirements(); // Pre-cache so biometric is instant
    _startClock();
    _checkPendingVerification();
    _verifyPollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkPendingVerification());
    _startLiveLocation();
  }

  void _loadAuthRequirements() async {
    final uid = widget.user['uid'] ?? '';
    if (uid.isEmpty) return;
    try {
      final reqs = await _attService.getAuthRequirements(uid);
      final faceReq = await FaceRecognitionService.isFaceAuthRequired(uid);
      if (mounted) {
        _cachedRequireBiometric = reqs.requireBiometric;
        _cachedRequireLocation = reqs.requireLocation;
        _cachedFaceRequired = faceReq;
        _authReqsLoaded = true;
      }
    } catch (_) {}
  }

  // Auto-check for pending verification requests and show banner immediately
  // Uses polling every 30 seconds
  void _checkPendingVerification() async {
    if (_verifyDialogShowing) return;
    final uid = widget.user['uid'] ?? '';
    if (uid.isEmpty) return;
    try {
      final result = await ApiService.get('admin.php?action=get_verifications');
      if (result['success'] == true) {
        final verifications = (result['verifications'] as List? ?? []).cast<Map<String, dynamic>>();
        final pending = verifications.where((v) =>
          (v['uid'] == uid) &&
          (v['status'] == 'pending')
        ).toList();
        if (pending.isNotEmpty && mounted && !_verifyDialogShowing) {
          _verifyDialogShowing = true;
          final verificationId = pending.first['id'];
          _respondToVerification(uid, verificationId: verificationId);
        }
      }
    } catch (_) {}
  }

  void _startLiveLocation() async {
    if (kIsWeb) return;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
      // Get initial position once
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      if (mounted) setState(() => _livePosition = pos);
      // Only update when user actually moves 15+ meters
      final stream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 15,
        ),
      );
      _locationTimer = Timer(Duration.zero, () {}); // placeholder so dispose works
      stream.listen((p) {
        if (mounted) setState(() => _livePosition = p);
      });
    } catch (_) {}
  }

  @override
  void dispose() { _timer?.cancel(); _locationTimer?.cancel(); _verifyPollTimer?.cancel(); _liveMapController?.dispose(); super.dispose(); }

  void _startClock() {
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTime();
      _updateElapsed();
    });
  }

  void _updateTime() {
    final now = ServerTimeService().now;
    final h = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    if (mounted) {
      setState(() => _currentTime = '${h.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'م' : 'ص'}');
    }
  }

  void _updateElapsed() {
    if (_todayRecord == null) return;
    final firstIn = _todayRecord!['firstCheckIn'] ?? _todayRecord!['first_check_in'] ?? _todayRecord!['checkIn'] ?? _todayRecord!['check_in'];
    if (firstIn == null) return;

    // Base: accumulated minutes from completed sessions
    final totalWorkedMinutes = ((_todayRecord!['totalWorkedMinutes'] ?? _todayRecord!['total_worked_minutes']) as int?) ?? 0;
    final isCheckedIn = _toBool(_todayRecord!['isCheckedIn']) || _toBool(_todayRecord!['is_checked_in']);

    if (isCheckedIn) {
      // Currently in a session — add live elapsed from currentSessionStart
      final sessionStartRaw = _todayRecord!['currentSessionStart'] ?? _todayRecord!['current_session_start'];
      final sessionStart = _parseTs(sessionStartRaw);
      if (sessionStart != null) {
        final liveSeconds = ServerTimeService().now.difference(sessionStart).inSeconds;
        if (mounted) setState(() => _elapsed = Duration(minutes: totalWorkedMinutes) + Duration(seconds: liveSeconds));
      } else {
        if (mounted) setState(() => _elapsed = Duration(minutes: totalWorkedMinutes));
      }
    } else {
      // All sessions complete — just show total
      if (mounted) setState(() => _elapsed = Duration(minutes: totalWorkedMinutes));
    }
  }

  void _loadToday() async {
    try {
      final rec = await _attService.getTodayRecord(widget.user['uid'] ?? '');
      if (mounted) {
        setState(() { _todayRecord = rec; _loadingRecord = false; });
        _updateElapsed();
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRecord = false);
    }
  }

  // ═══ Load locations assigned to this employee ═══
  void _loadLocations() async {
    try {
      final uid = widget.user['uid'] ?? '';
      final result = await ApiService.get('admin.php?action=get_locations');
      if (result['success'] == true) {
        final allLocs = (result['locations'] as List? ?? []).cast<Map<String, dynamic>>();
        final locs = allLocs.where((loc) {
          final active = loc['active'];
          if (active == false || active == 0) return false;
          final assigned = (loc['assignedEmployees'] as List?)?.cast<String>() ??
              (loc['assigned_employees'] as List?)?.cast<String>() ?? [];
          return assigned.isEmpty || assigned.contains(uid);
        }).toList();
        if (mounted) {
          setState(() {
            _allLocations = locs;
            _loadingLocations = false;
            if (locs.length == 1) _selectedLocationId = locs.first['id'].toString();
          });
        }
      } else {
        if (mounted) setState(() => _loadingLocations = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLocations = false);
    }
  }

  // ═══ Get selected location data ═══
  Map<String, dynamic>? get _selectedLocation {
    if (_selectedLocationId == null) return _allLocations.isNotEmpty ? _allLocations.first : null;
    return _allLocations.firstWhere((l) => l['id'].toString() == _selectedLocationId, orElse: () => _allLocations.isNotEmpty ? _allLocations.first : {});
  }

  double get _workedHours => _elapsed.inMinutes / 60.0;
  double get _overtime => (_workedHours - _standardHours).clamp(0, 24);
  bool get _hasOvertime => _workedHours > _standardHours;

  String _fmtDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  // ═══════════════════════════════════════════════
  //  CHECK IN — checks against SELECTED location
  // ═══════════════════════════════════════════════
  void _checkIn() async {
    final uid = widget.user['uid'] ?? '';
    String? facePhotoUrl;
    bool usedFaceAuth = false;
    double? savedLat, savedLng, savedAccuracy;

    // Use cached requirements (loaded at init) — no API delay
    final requireBiometric = _cachedRequireBiometric;
    final requireLocation = _cachedRequireLocation;
    final faceRequired = _cachedFaceRequired;

    // ─── Step 1: Biometric FIRST (instant, no API calls before this) ───
    if (requireBiometric && !faceRequired) {
      final bioResult = await _attService.authenticateBiometricWithDetails();
      if (!mounted) return;
      if (!bioResult.success) {
        _showResultDialog(false, 'فشل التحقق من البصمة', bioResult.error);
        return;
      }
    }

    // ─── Step 2: Face auth if required (instead of fingerprint) ───
    if (faceRequired) {
      final hasRegistered = await FaceRecognitionService.hasFaceRegistered(uid);
      if (!hasRegistered) {
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => FaceRegistrationPage(
          uid: uid,
          userName: widget.user['name'] ?? '',
          onComplete: () { if (mounted) _checkIn(); },
        )));
        return;
      }
      if (!mounted) return;
      final faceResult = await showFaceVerifyDialog(context, uid);
      if (faceResult == null || faceResult['success'] != true) {
        if (mounted) _showResultDialog(false, 'فشل التحقق من الوجه', faceResult?['error'] ?? 'تم إلغاء التحقق');
        return;
      }
      facePhotoUrl = faceResult['photoUrl'] as String?;
      usedFaceAuth = true;
    }

    // ─── Step 3: Location check ───
    final loc = _selectedLocation;
    bool showLocCheck = loc != null && loc.isNotEmpty;
    if (showLocCheck) {
      _showLoadingDialog('جارٍ التحقق من الموقع...', 'تحديد موقعك الحالي', C.green);
      final locResult = await _attService.getCurrentLocation();
      final pos = locResult.position;
      if (pos == null) {
        if (mounted) Navigator.pop(context);
        _showResultDialog(false, 'فشل تحديد الموقع', 'يرجى تفعيل GPS والمحاولة مرة أخرى');
        return;
      }
      if (locResult.isMocked) {
        if (mounted) Navigator.pop(context);
        _showResultDialog(false, 'موقع مزيف', 'تم اكتشاف تطبيق تزوير موقع — لا يمكن تسجيل الحضور');
        return;
      }
      savedLat = pos.latitude;
      savedLng = pos.longitude;
      savedAccuracy = pos.accuracy;
      final adminLat = (loc['lat'] as num?)?.toDouble() ?? 0;
      final adminLng = (loc['lng'] as num?)?.toDouble() ?? 0;
      final radius = (loc['radius'] as num?)?.toDouble() ?? 300;
      final distance = Geolocator.distanceBetween(pos.latitude, pos.longitude, adminLat, adminLng);
      if (distance > radius) {
        if (mounted) Navigator.pop(context);
        _showOutOfRangeDialog(pos.latitude, pos.longitude, adminLat, adminLng, radius, distance, loc['name'] ?? 'الموقع المحدد');
        return;
      }
      if (mounted) Navigator.pop(context);
      // Warn if GPS accuracy is poor (allowed but unreliable)
      if (pos.accuracy > 80) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('دقة GPS منخفضة (${pos.accuracy.round()}م) — قد يُرفض الطلب',
              style: GoogleFonts.tajawal()),
            backgroundColor: C.orange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ));
        }
      }
    }

    // ─── Step 4: Send check-in to API ───
    final authMethod = usedFaceAuth ? 'face' : 'fingerprint';
    _showLoadingDialog('جارٍ إثبات الحضور...', 'يرجى الانتظار', C.green);

    // ─── Step 5: Record attendance ───
    Map<String, dynamic> result;
    try {
      result = await _attService.checkIn(
        uid, widget.user['empId'] ?? '', widget.user['name'] ?? '',
        facePhotoUrl: facePhotoUrl,
        authMethod: authMethod,
        requireBiometric: requireBiometric,
        requireLocation: requireLocation,
        lat: savedLat,
        lng: savedLng,
        accuracy: savedAccuracy,
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showResultDialog(false, 'خطأ في إثبات الحضور', e.toString());
      }
      return;
    }
    if (mounted) Navigator.pop(context);
    if (result['success'] == true) {
      // Immediately update local state so UI reflects check-in NOW
      final now = DateTime.now();
      setState(() {
        _todayRecord ??= {};
        _todayRecord!['is_checked_in'] = 1;
        _todayRecord!['first_check_in'] ??= now.toIso8601String();
        _todayRecord!['check_in'] ??= now.toIso8601String();
        _todayRecord!['current_session_start'] = now.toIso8601String();
        _todayRecord!['status'] = 'حاضر';
        _loadingRecord = false;
      });
      _updateElapsed();
      // Also refresh from server in background
      _loadToday();
      _showLocationResultDialog(true, 'تم إثبات الحضور ✓', result['time'] ?? '', result['lat'], result['lng']);
    } else {
      _showResultDialog(false, 'فشل إثبات الحضور', result['error'] ?? 'خطأ غير معروف');
    }
  }

  // ═══════════════════════════════════════════════
  //  CHECK OUT — checks against SELECTED location
  // ═══════════════════════════════════════════════
  void _checkOut() async {
    final uid = widget.user['uid'] ?? '';
    String? facePhotoUrl;
    bool usedFaceAuth = false;
    double? savedLat, savedLng, savedAccuracy;

    // Use cached requirements — no API delay
    final requireBiometric = _cachedRequireBiometric;
    final requireLocation = _cachedRequireLocation;
    final faceRequired = _cachedFaceRequired;

    // ─── Step 1: Biometric FIRST (instant) ───
    if (requireBiometric && !faceRequired) {
      final bioResult = await _attService.authenticateBiometricWithDetails();
      if (!mounted) return;
      if (!bioResult.success) {
        _showResultDialog(false, 'فشل التحقق من البصمة', bioResult.error);
        return;
      }
    }

    // ─── Step 2: Face auth if required ───
    if (faceRequired) {
      final hasRegistered = await FaceRecognitionService.hasFaceRegistered(uid);
      if (!hasRegistered) {
        if (!mounted) return;
        _showResultDialog(false, 'بصمة الوجه غير مسجلة', 'يجب تسجيل بصمة الوجه أولاً من خلال تسجيل الحضور');
        return;
      }
      if (!mounted) return;
      final faceResult = await showFaceVerifyDialog(context, uid);
      if (faceResult == null || faceResult['success'] != true) {
        if (mounted) _showResultDialog(false, 'فشل التحقق من الوجه', faceResult?['error'] ?? 'تم إلغاء التحقق');
        return;
      }
      facePhotoUrl = faceResult['photoUrl'] as String?;
      usedFaceAuth = true;
    }

    // ─── Step 3: Location check ───
    final loc2 = _selectedLocation;
    bool showLocCheck2 = loc2 != null && loc2.isNotEmpty;
    if (showLocCheck2) {
      _showLoadingDialog('جارٍ التحقق من الموقع...', 'تحديد موقعك الحالي', C.red);
      final locResult2 = await _attService.getCurrentLocation();
      final pos = locResult2.position;
      if (pos == null) {
        if (mounted) Navigator.pop(context);
        _showResultDialog(false, 'فشل تحديد الموقع', 'يرجى تفعيل GPS والمحاولة مرة أخرى');
        return;
      }
      if (locResult2.isMocked) {
        if (mounted) Navigator.pop(context);
        _showResultDialog(false, 'موقع مزيف', 'تم اكتشاف تطبيق تزوير موقع — لا يمكن تسجيل الانصراف');
        return;
      }
      savedLat = pos.latitude;
      savedLng = pos.longitude;
      savedAccuracy = pos.accuracy;
      final adminLat = (loc2['lat'] as num?)?.toDouble() ?? 0;
      final adminLng = (loc2['lng'] as num?)?.toDouble() ?? 0;
      final radius = (loc2['radius'] as num?)?.toDouble() ?? 300;
      final distance = Geolocator.distanceBetween(pos.latitude, pos.longitude, adminLat, adminLng);
      if (distance > radius) {
        if (mounted) Navigator.pop(context);
        _showOutOfRangeDialog(pos.latitude, pos.longitude, adminLat, adminLng, radius, distance, loc2['name'] ?? 'الموقع المحدد');
        return;
      }
      if (mounted) Navigator.pop(context);
      // Warn if GPS accuracy is poor (allowed but unreliable)
      if (pos.accuracy > 80) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('دقة GPS منخفضة (${pos.accuracy.round()}م) — قد يُرفض الطلب',
              style: GoogleFonts.tajawal()),
            backgroundColor: C.orange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ));
        }
      }
    }

    // ─── Step 4: Send check-out to API ───
    final authMethod = usedFaceAuth ? 'face' : 'fingerprint';
    _showLoadingDialog('جارٍ إثبات الخروج...', 'يرجى الانتظار', C.red);

    // ─── Step 5: Record checkout ───
    Map<String, dynamic> result;
    try {
      result = await _attService.checkOut(
        uid, widget.user['empId'] ?? '', widget.user['name'] ?? '',
        facePhotoUrl: facePhotoUrl,
        authMethod: authMethod,
        requireBiometric: requireBiometric,
        requireLocation: requireLocation,
        lat: savedLat,
        lng: savedLng,
        accuracy: savedAccuracy,
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showResultDialog(false, 'خطأ في إثبات الخروج', e.toString());
      }
      return;
    }
    if (mounted) Navigator.pop(context);
    if (result['success'] == true) {
      // Immediately update local state so UI reflects check-out NOW
      setState(() {
        if (_todayRecord != null) {
          _todayRecord!['is_checked_in'] = 0;
          _todayRecord!['last_check_out'] = DateTime.now().toIso8601String();
          _todayRecord!['check_out'] = DateTime.now().toIso8601String();
          _todayRecord!['status'] = 'مكتمل';
        }
      });
      _updateElapsed();
      _loadToday();
      _showLocationResultDialog(true, 'تم إثبات الخروج ✓', result['time'] ?? '', result['lat'], result['lng']);
    } else {
      _showResultDialog(false, 'فشل إثبات الخروج', result['error'] ?? 'خطأ غير معروف');
    }
  }

  // ═══ Out of range dialog with map ═══
  void _showOutOfRangeDialog(double empLat, double empLng, double adminLat, double adminLng, double radius, double distance, String locName) {
    showDialog(context: context, builder: (ctx) => Center(child: SingleChildScrollView(child: Container(
      width: 340, margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(18)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 60, height: 60, decoration: BoxDecoration(color: C.redL, shape: BoxShape.circle), child: const Icon(Icons.location_off, size: 30, color: C.red)),
        const SizedBox(height: 12),
        Text('أنت خارج نطاق العمل', style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w700, color: C.red)),
        Text('ادخل النطاق لتسجيل الحضور', style: GoogleFonts.tajawal(fontSize: 13, color: C.sub)),
        const SizedBox(height: 14),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedBox(width: double.infinity, height: 200, child: GoogleMap(
          initialCameraPosition: CameraPosition(target: LatLng(adminLat, adminLng), zoom: 14),
          markers: {
            Marker(markerId: const MarkerId('emp'), position: LatLng(empLat, empLng), infoWindow: InfoWindow(title: 'موقعك — ${distance.round()}م'), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)),
            Marker(markerId: const MarkerId('work'), position: LatLng(adminLat, adminLng), infoWindow: InfoWindow(title: locName), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)),
          },
          circles: {
            Circle(circleId: const CircleId('zone'), center: LatLng(adminLat, adminLng), radius: radius, fillColor: const Color(0xFF17B26A).withValues(alpha: 0.15), strokeColor: const Color(0xFF17B26A), strokeWidth: 2),
          },
          myLocationEnabled: false, zoomControlsEnabled: false, liteModeEnabled: false,
        ))),
        const SizedBox(height: 10),
        Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: C.redL, borderRadius: BorderRadius.circular(6)),
          child: Column(children: [
            Text('أنت تبعد ${distance.round()} متر عن $locName', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: C.red)),
            Text('النطاق المسموح: ${radius.round()} متر', style: GoogleFonts.tajawal(fontSize: 12, color: C.red.withOpacity(0.7))),
          ]),
        ),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(ctx), style: ElevatedButton.styleFrom(backgroundColor: C.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), padding: const EdgeInsets.symmetric(vertical: 12)),
          child: Text('فهمت', style: GoogleFonts.tajawal(fontWeight: FontWeight.w600)))),
      ]),
    ))));
  }

  void _showLoadingDialog(String title, String sub, Color color) {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => Center(child: Container(
      width: 300, padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(6)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 50, height: 50, child: CircularProgressIndicator(strokeWidth: 3, color: color)),
        const SizedBox(height: 16),
        Text(title, style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: C.text)),
        const SizedBox(height: 4),
        Text(sub, style: GoogleFonts.tajawal(fontSize: 12, color: C.sub)),
      ]),
    )));
  }

  void _showResultDialog(bool success, String title, String sub) {
    showDialog(context: context, builder: (ctx) => Center(child: Container(
      width: 300, padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(6)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 60, height: 60, decoration: BoxDecoration(color: success ? const Color(0xFFECFDF3) : const Color(0xFFFEF3F2), shape: BoxShape.circle), child: Icon(success ? Icons.check : Icons.close, size: 30, color: success ? C.green : C.red)),
        const SizedBox(height: 16),
        Text(title, style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: C.text)),
        const SizedBox(height: 4),
        Text(sub, style: GoogleFonts.tajawal(fontSize: 13, color: C.sub)),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(ctx), style: ElevatedButton.styleFrom(backgroundColor: success ? C.green : C.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))), child: Text('حسناً', style: GoogleFonts.tajawal(fontWeight: FontWeight.w600)))),
      ]),
    )));
  }

  void _showLocationResultDialog(bool success, String title, String time, dynamic lat, dynamic lng) async {
    Map<String, dynamic>? adminLoc = _selectedLocation;
    final adminLat = (adminLoc?['lat'] as num?)?.toDouble();
    final adminLng = (adminLoc?['lng'] as num?)?.toDouble();
    final adminRadius = (adminLoc?['radius'] as num?)?.toDouble() ?? 300.0;
    final adminName = adminLoc?['name'] ?? 'الموقع المحدد';
    if (!mounted) return;
    final empLat = (lat as num?)?.toDouble() ?? 0;
    final empLng = (lng as num?)?.toDouble() ?? 0;

    showDialog(context: context, builder: (ctx) => Center(child: SingleChildScrollView(child: Container(
      width: 340, margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(18)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 50, height: 50, decoration: BoxDecoration(color: C.greenL, shape: BoxShape.circle), child: const Icon(Icons.check, size: 24, color: C.green)),
        const SizedBox(height: 10),
        Text(title, style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: C.text)),
        Text('الوقت: $time', style: GoogleFonts.tajawal(fontSize: 13, color: C.sub)),
        const SizedBox(height: 14),
        if (lat != null && lng != null) ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedBox(width: double.infinity, height: 200, child: GoogleMap(
          initialCameraPosition: CameraPosition(target: LatLng(adminLat ?? empLat, adminLng ?? empLng), zoom: 15),
          markers: {
            Marker(markerId: const MarkerId('employee'), position: LatLng(empLat, empLng), infoWindow: const InfoWindow(title: 'موقع البصمة'), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)),
            if (adminLat != null) Marker(markerId: const MarkerId('work'), position: LatLng(adminLat, adminLng!), infoWindow: InfoWindow(title: adminName), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)),
          },
          circles: {
            if (adminLat != null) Circle(circleId: const CircleId('workZone'), center: LatLng(adminLat, adminLng!), radius: adminRadius, fillColor: const Color(0xFF17B26A).withValues(alpha: 0.15), strokeColor: const Color(0xFF17B26A), strokeWidth: 2),
          },
          myLocationEnabled: false, zoomControlsEnabled: false, mapToolbarEnabled: false, liteModeEnabled: false,
        ))),
        const SizedBox(height: 8),
        Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: C.greenL, borderRadius: BorderRadius.circular(4)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('تم تسجيل موقعك بنجاح', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.green)),
            const SizedBox(width: 6), const Icon(Icons.check_circle, size: 16, color: C.green),
          ])),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(ctx), style: ElevatedButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), padding: const EdgeInsets.symmetric(vertical: 12)), child: Text('حسناً', style: GoogleFonts.tajawal(fontWeight: FontWeight.w600)))),
      ]),
    ))));
  }

  // Handle PHP returning 1/0 (int) or true/false (bool) for boolean fields
  bool _toBool(dynamic v) => v == true || v == 1 || v == '1';

  DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is String) { try { return DateTime.parse(v); } catch(_) { return null; } }
    if (v is DateTime) return v;
    return null;
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '—';
    final dt = _parseTs(ts);
    if (dt == null) return '—';
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'م' : 'ص'}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dayName = _days[now.weekday % 7];
    final monthName = _months[now.month - 1];
    final greeting = now.hour < 12 ? 'صباح الخير' : 'مساء الخير';
    final hasCheckIn = (_todayRecord?['firstCheckIn'] ?? _todayRecord?['first_check_in'] ?? _todayRecord?['checkIn'] ?? _todayRecord?['check_in']) != null;
    final hasCheckOut = (_todayRecord?['lastCheckOut'] ?? _todayRecord?['last_check_out'] ?? _todayRecord?['checkOut'] ?? _todayRecord?['check_out']) != null;
    // isCheckedIn: use new field if available, otherwise fallback to old logic
    final bool isCurrentlyCheckedIn;
    if (_todayRecord != null && (_todayRecord!.containsKey('isCheckedIn') || _todayRecord!.containsKey('is_checked_in'))) {
      isCurrentlyCheckedIn = _toBool(_todayRecord!['isCheckedIn']) || _toBool(_todayRecord!['is_checked_in']);
    } else {
      // Old data fallback: checked in if has checkIn but no checkOut
      isCurrentlyCheckedIn = hasCheckIn && !hasCheckOut;
    }
    final status = hasCheckOut && !isCurrentlyCheckedIn ? 'مكتمل' : isCurrentlyCheckedIn ? 'حاضر' : hasCheckIn ? 'حاضر' : 'لم يسجّل';
    final stColor = isCurrentlyCheckedIn ? C.green : (hasCheckOut && !isCurrentlyCheckedIn) ? C.green : hasCheckIn ? C.pri : C.muted;
    final av = (widget.user['name'] ?? 'م').toString().length >= 2 ? (widget.user['name'] ?? 'م').toString().substring(0, 2) : 'م';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light),
      child: SingleChildScrollView(child: Column(children: [
      // ═══ HEADER ═══
      Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0F4199), C.pri]),
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
        child: Column(children: [
          // Top row
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            GestureDetector(
              onTap: () => _showNotifications(),
              child: Stack(children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.notifications_none_rounded, size: 20, color: Colors.white)),
              ]),
            ),
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(greeting, style: GoogleFonts.tajawal(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                Text(widget.user['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 13, color: Colors.white.withOpacity(0.65))),
              ]),
              const SizedBox(width: 12),
              Stack(children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5)),
                  child: Center(child: Text(av, style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)))),
                Positioned(bottom: -1, right: -1, child: Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: isCurrentlyCheckedIn ? const Color(0xFF17B26A) : const Color(0xFFEF4444), border: Border.all(color: Colors.white, width: 2)))),
              ]),
            ]),
          ]),
          const SizedBox(height: 20),

          // Live Clock
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
            child: Column(children: [
              Text(_currentTime, style: GoogleFonts.ibmPlexMono(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 3)),
              const SizedBox(height: 4),
              Text('$dayName ${now.day} $monthName — ${widget.user['dept'] ?? ''}', style: GoogleFonts.tajawal(fontSize: 12, color: Colors.white.withOpacity(0.5))),
            ]),
          ),
          const SizedBox(height: 16),

          // ═══ LOCATION DROPDOWN ═══
          if (_allLocations.length > 1) ...[
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('اختر الموقع المحدد', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.6))),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white.withOpacity(0.2))),
              child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedLocationId ?? (_allLocations.isNotEmpty ? _allLocations.first['id'].toString() : null),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
                dropdownColor: const Color(0xFF0F4199),
                style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                hint: Text('اختر موقع البصمة', style: GoogleFonts.tajawal(fontSize: 13, color: Colors.white60)),
                items: _allLocations.map((loc) => DropdownMenuItem<String>(
                  value: loc['id'].toString(),
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text(loc['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 13, color: Colors.white)),
                    const SizedBox(width: 8),
                    const Icon(Icons.location_on_rounded, size: 16, color: Colors.white70),
                  ]),
                )).toList(),
                onChanged: (v) => setState(() => _selectedLocationId = v),
              )),
            ),
            const SizedBox(height: 12),
          ] else if (_allLocations.length == 1) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(_allLocations.first['name'] ?? '', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(width: 8),
                const Icon(Icons.location_on_rounded, size: 16, color: Colors.white70),
              ]),
            ),
            const SizedBox(height: 12),
          ],

          // Check-in / Check-out buttons — show only ONE at a time
          if (isCurrentlyCheckedIn)
            SizedBox(width: double.infinity, child: _clockBtn('إثبات الخروج', Icons.logout_rounded, const Color(0xFFFF4D4D), Colors.white, _checkOut))
          else
            SizedBox(width: double.infinity, child: _clockBtn('إثبات الحضور', Icons.fingerprint_rounded, Colors.white, C.pri, _checkIn)),
        ]),
      ),

      // ═══ QUICK ACTIONS — Connected to tabs ═══
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: C.border)),
          child: Row(children: [
            _empQuickBtn(Icons.calendar_today_rounded, 'سجل\nحضوري', () => widget.onTabChange?.call(1)),
            _empQuickBtn(Icons.description_outlined, 'طلباتي', () => widget.onTabChange?.call(3)),
            _empQuickBtn(Icons.add_circle_outline_rounded, 'طلب\nجديد', () => widget.onTabChange?.call(2)),
            _empQuickBtn(Icons.person_outline_rounded, 'المزيد', () => widget.onTabChange?.call(4)),
          ]),
        ),
      ),

      // ═══ LIVE MAP ═══
      if (!kIsWeb) _buildLiveMap(),

      // ═══ WORK TIMER ═══
      if (hasCheckIn) Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Container(
          decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: _hasOvertime ? C.orange.withOpacity(0.4) : C.border)),
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: stColor.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                child: Text(status, style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: stColor))),
              const Spacer(),
              Text(hasCheckOut ? 'إجمالي ساعات العمل' : 'الوقت المنقضي', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: C.text)),
            ]),
            const SizedBox(height: 14),
            Text(_fmtDuration(_elapsed), style: GoogleFonts.ibmPlexMono(fontSize: 40, fontWeight: FontWeight.w700, color: hasCheckOut ? C.green : C.pri, letterSpacing: 4)),
            const SizedBox(height: 14),
            Row(children: [
              _statBox('أوفر تايم', _hasOvertime ? '${_overtime.toStringAsFixed(1)} ساعة' : '—', _hasOvertime ? C.orange : C.muted),
              const SizedBox(width: 10),
              _statBox('ساعات العمل', '${_workedHours.toStringAsFixed(1)}h / ${_standardHours.toStringAsFixed(0)}h', _workedHours >= _standardHours ? C.green : C.pri),
            ]),
            if (_hasOvertime && !hasCheckOut) ...[
              const SizedBox(height: 12),
              Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: C.orangeL, borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('تجاوزت ساعات العمل الأساسية', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.orange)),
                  const SizedBox(width: 8), const Icon(Icons.warning_amber_rounded, size: 18, color: C.orange),
                ])),
            ],
          ]),
        ),
      ),

      // ═══ TODAY RECORD ═══
      Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: Container(
        decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: C.border)),
        child: Column(children: [
          Padding(padding: const EdgeInsets.all(16), child: Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: stColor.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
              child: Text(status, style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: stColor))),
            const Spacer(),
            Text('سجل الحضور اليومي', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: C.text)),
            const SizedBox(width: 8),
            Container(width: 28, height: 28, decoration: BoxDecoration(color: C.priLight, borderRadius: BorderRadius.circular(4)), child: const Icon(Icons.history_rounded, size: 14, color: C.pri)),
          ])),
          Container(height: 1, color: C.div),
          if (_loadingRecord) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          else if (_todayRecord == null)
            Padding(padding: const EdgeInsets.all(30), child: Column(children: [
              Container(width: 56, height: 56, decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.fingerprint_rounded, size: 30, color: C.hint)),
              const SizedBox(height: 12),
              Text('لم تسجّل بعد اليوم', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w600, color: C.text)),
              const SizedBox(height: 4),
              Text('اضغط "إثبات الحضور" للبدء', style: GoogleFonts.tajawal(fontSize: 12, color: C.muted)),
            ]))
          else Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            if (hasCheckIn) _entryRow('أول حضور', _formatTimestamp(_todayRecord!['firstCheckIn'] ?? _todayRecord!['first_check_in'] ?? _todayRecord!['checkIn'] ?? _todayRecord!['check_in']), C.pri, Icons.login_rounded),
            if (hasCheckOut) _entryRow('آخر خروج', _formatTimestamp(_todayRecord!['lastCheckOut'] ?? _todayRecord!['last_check_out'] ?? _todayRecord!['checkOut'] ?? _todayRecord!['check_out']), C.red, Icons.logout_rounded),
          ])),
        ]),
      )),
      const SizedBox(height: 24),
    ])));
  }

  Widget _buildLiveMap() {
    final loc = _selectedLocation;
    final authLat = (loc?['lat'] as num?)?.toDouble();
    final authLng = (loc?['lng'] as num?)?.toDouble();
    final authRadius = (loc?['radius'] as num?)?.toDouble() ?? 300.0;
    final authName = loc?['name'] ?? 'الموقع المصرح';

    final empLat = _livePosition?.latitude;
    final empLng = _livePosition?.longitude;

    // Determine initial camera target
    final centerLat = authLat ?? empLat ?? 24.7136;
    final centerLng = authLng ?? empLng ?? 46.6753;

    final markers = <Marker>{};
    if (empLat != null && empLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('employee'),
        position: LatLng(empLat, empLng),
        infoWindow: const InfoWindow(title: 'موقعي الحالي'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }
    if (authLat != null && authLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('auth'),
        position: LatLng(authLat, authLng),
        infoWindow: InfoWindow(title: authName),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ));
    }

    final circles = <Circle>{};
    if (authLat != null && authLng != null) {
      circles.add(Circle(
        circleId: const CircleId('authZone'),
        center: LatLng(authLat, authLng),
        radius: authRadius,
        fillColor: const Color(0xFFFF9500).withValues(alpha: 0.15),
        strokeColor: const Color(0xFFFF9500),
        strokeWidth: 2,
      ));
    }

    // Determine if employee is inside zone
    bool? insideZone;
    if (empLat != null && empLng != null && authLat != null && authLng != null) {
      final dist = Geolocator.distanceBetween(empLat, empLng, authLat, authLng);
      insideZone = dist <= authRadius;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: C.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(children: [
              if (insideZone != null) Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: insideZone ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(insideZone ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 12, color: insideZone ? C.green : C.red),
                  const SizedBox(width: 4),
                  Text(insideZone ? 'داخل النطاق' : 'خارج النطاق', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: insideZone ? C.green : C.red)),
                ]),
              ),
              const Spacer(),
              const Icon(Icons.location_on_rounded, size: 14, color: C.sub),
              const SizedBox(width: 4),
              Text(authName, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.text)),
            ]),
          ),
          // Map
          ClipRRect(
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
            child: SizedBox(
              height: 220,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: LatLng(centerLat, centerLng), zoom: 15),
                markers: markers,
                circles: circles,
                onMapCreated: (c) => _liveMapController = c,
                myLocationEnabled: false,
                zoomControlsEnabled: true,
                mapToolbarEnabled: false,
                liteModeEnabled: false,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ─── Quick action button — CONNECTED ───
  Widget _empQuickBtn(IconData icon, String label, VoidCallback onTap) {
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 52, height: 52, decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(6), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 1))]),
          child: Icon(icon, size: 22, color: C.pri)),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: C.text, height: 1.4), textAlign: TextAlign.center),
      ]),
    ));
  }

  Widget _statBox(String label, String value, Color color) {
    return Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(4)),
      child: Column(children: [Text(value, style: GoogleFonts.ibmPlexMono(fontSize: 11, fontWeight: FontWeight.w700, color: color)), const SizedBox(height: 2), Text(label, style: GoogleFonts.tajawal(fontSize: 9, color: C.muted))])));
  }

  Widget _entryRow(String type, String time, Color color, IconData icon) {
    return Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.div))),
      child: Row(children: [
        Container(width: 28, height: 28, decoration: const BoxDecoration(color: C.bg, shape: BoxShape.circle), child: const Icon(Icons.location_on_outlined, size: 14, color: C.sub)),
        const SizedBox(width: 6), Text(time, style: GoogleFonts.ibmPlexMono(fontSize: 13, fontWeight: FontWeight.w600, color: C.text)),
        const Spacer(), Text(type, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: C.text)),
        const SizedBox(width: 10), Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withOpacity(0.07), borderRadius: BorderRadius.circular(4)), child: Icon(icon, size: 16, color: color)),
        const SizedBox(width: 8), Container(width: 4, height: 36, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      ]));
  }

  Widget _clockBtn(String text, IconData icon, Color bg, Color fg, VoidCallback onTap) {
    return Material(color: bg, borderRadius: BorderRadius.circular(6), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(6), child: Container(padding: const EdgeInsets.symmetric(vertical: 13), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 18, color: fg), const SizedBox(width: 6), Text(text, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: fg))]))));
  }

  // ═══════════════════════════════════════════════
  //  NOTIFICATIONS — API-based
  // ═══════════════════════════════════════════════
  void _showNotifications() {
    final uid = widget.user['uid'] ?? '';
    showDialog(context: context, builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(18), decoration: const BoxDecoration(gradient: LinearGradient(colors: [C.priDark, C.pri]), borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
            child: Row(children: [
              InkWell(onTap: () => Navigator.pop(ctx), child: const Icon(Icons.close, size: 18, color: Colors.white70)),
              const Spacer(),
              Text('الإشعارات', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(width: 8), const Icon(Icons.notifications, size: 18, color: Colors.white),
            ])),
          Flexible(child: FutureBuilder<Map<String, dynamic>>(
            future: ApiService.get('admin.php?action=get_notifications'),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
              }
              final allNotifs = (snap.data?['notifications'] as List? ?? []).cast<Map<String, dynamic>>();
              final docs = allNotifs.where((n) => n['uid'] == uid).toList();
              docs.sort((a, b) {
                final aT = _parseTs(a['timestamp']); final bT = _parseTs(b['timestamp']);
                if (aT == null || bT == null) return 0; return bT.compareTo(aT);
              });
              if (docs.isEmpty) return Padding(padding: const EdgeInsets.all(40), child: Center(child: Column(children: [const Icon(Icons.notifications_off, size: 40, color: C.hint), const SizedBox(height: 8), Text('لا توجد إشعارات', style: GoogleFonts.tajawal(color: C.muted))])));
              return ListView.builder(shrinkWrap: true, itemCount: docs.length, itemBuilder: (ctx, i) {
                final n = docs[i];
                final docId = n['id']?.toString() ?? '';
                final isRead = _toBool(n['read']) || _toBool(n['is_read']);
                final isVerifyRequest = n['type'] == 'verify_request';
                final isUrgent = n['type'] == 'urgent' || isVerifyRequest;
                return InkWell(
                  onTap: () {
                    if (!isRead && docId.isNotEmpty) ApiService.post('admin.php?action=mark_read', {'id': docId}).catchError((_) => <String, dynamic>{});
                    if (isVerifyRequest) { Navigator.pop(ctx); _respondToVerification(uid, verificationId: n['verification_id'] ?? n['id']); }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(color: isRead ? Colors.transparent : (isVerifyRequest ? const Color(0xFFFFF3E0) : isUrgent ? C.redL : C.priLight), border: const Border(bottom: BorderSide(color: C.div))),
                    child: Row(children: [
                      if (isVerifyRequest && !isRead) ...[
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: C.orange, borderRadius: BorderRadius.circular(6)),
                          child: Text('إثبات الآن', style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white))),
                        const SizedBox(width: 8),
                      ] else if (!isRead) ...[Container(width: 8, height: 8, decoration: BoxDecoration(color: isUrgent ? C.red : C.pri, shape: BoxShape.circle)), const SizedBox(width: 8)],
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(n['title'] ?? '', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: isRead ? FontWeight.w500 : FontWeight.w700, color: C.text)),
                        Text(n['body'] ?? '', style: GoogleFonts.tajawal(fontSize: 11, color: C.sub)),
                      ])),
                      const SizedBox(width: 10),
                      Icon(isVerifyRequest ? Icons.wifi_tethering : (isUrgent ? Icons.notifications_active : Icons.notifications), size: 18, color: isVerifyRequest ? C.orange : (isUrgent ? C.red : C.pri)),
                    ]),
                  ),
                );
              });
            },
          )),
        ]),
      ),
    ));
  }

  // ═══ Verification response — FORCED dialog ═══
  void _respondToVerification(String uid, {dynamic verificationId}) async {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => PopScope(
      canPop: false,
      child: Center(child: Container(
        width: 340, margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(18)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 60, height: 60, decoration: BoxDecoration(color: C.orangeL, shape: BoxShape.circle), child: const Icon(Icons.wifi_tethering, size: 30, color: C.orange)),
          const SizedBox(height: 14),
          Text('طلب إثبات حالة', style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w700, color: C.text)),
          const SizedBox(height: 6),
          Text('الإدارة تطلب إثبات تواجدك في نطاق العمل الآن', style: GoogleFonts.tajawal(fontSize: 13, color: C.sub, height: 1.5), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
            onPressed: () async { Navigator.pop(ctx); _doVerificationResponse(uid, verificationId: verificationId); },
            style: ElevatedButton.styleFrom(backgroundColor: C.orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), elevation: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.my_location, size: 20), const SizedBox(width: 8), Text('إثبات موقعي الآن', style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700))]),
          )),
        ]),
      )),
    )).then((_) => _verifyDialogShowing = false);
  }

  void _doVerificationResponse(String uid, {dynamic verificationId}) async {
    _showLoadingDialog('جارٍ إثبات الحالة...', 'جاري تحديد موقعك وحساب المسافة', C.orange);
    try {
      final locResultV = await _attService.getCurrentLocation();
      final pos = locResultV.position;
      if (pos == null) { if (mounted) Navigator.pop(context); _showResultDialog(false, 'فشل تحديد الموقع', 'يرجى تفعيل GPS'); return; }
      if (locResultV.isMocked) { if (mounted) Navigator.pop(context); _showResultDialog(false, 'موقع مزيف', 'تم اكتشاف تطبيق تزوير موقع'); return; }

      final loc = _selectedLocation;
      double adminLat = 0, adminLng = 0, radius = 300;
      String locName = 'الموقع المحدد';
      if (loc != null && loc.isNotEmpty) {
        adminLat = (loc['lat'] as num?)?.toDouble() ?? 0;
        adminLng = (loc['lng'] as num?)?.toDouble() ?? 0;
        radius = (loc['radius'] as num?)?.toDouble() ?? 300;
        locName = loc['name'] ?? 'الموقع المحدد';
      } else {
        // Fallback: load locations from API
        try {
          final locResult = await ApiService.get('admin.php?action=get_locations');
          if (locResult['success'] == true) {
            final locs = (locResult['locations'] as List? ?? []).cast<Map<String, dynamic>>();
            final active = locs.where((l) => l['active'] != false && l['active'] != 0).toList();
            if (active.isNotEmpty) {
              final l = active.first;
              adminLat = (l['lat'] as num?)?.toDouble() ?? 0;
              adminLng = (l['lng'] as num?)?.toDouble() ?? 0;
              radius = (l['radius'] as num?)?.toDouble() ?? 300;
              locName = l['name'] ?? 'الموقع المحدد';
            }
          }
        } catch (_) {}
      }

      final distance = Geolocator.distanceBetween(pos.latitude, pos.longitude, adminLat, adminLng);
      final inRange = distance <= radius;

      // Respond to verification via API
      try {
        await ApiService.post('admin.php?action=respond_verification', {
          'id': verificationId,
          'uid': uid,
          'lat': pos.latitude,
          'lng': pos.longitude,
        });
      } catch (_) {}

      if (mounted) Navigator.pop(context);

      showDialog(context: context, builder: (ctx) => Center(child: SingleChildScrollView(child: Container(
        width: 340, margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(18)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 56, height: 56, decoration: BoxDecoration(color: inRange ? C.greenL : C.redL, shape: BoxShape.circle),
            child: Icon(inRange ? Icons.check : Icons.warning_amber, size: 28, color: inRange ? C.green : C.red)),
          const SizedBox(height: 12),
          Text(inRange ? 'أنت داخل النطاق ✓' : 'أنت خارج النطاق ⚠', style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w700, color: inRange ? C.green : C.red)),
          Text('المسافة: ${distance.round()} متر من $locName', style: GoogleFonts.tajawal(fontSize: 13, color: C.sub)),
          const SizedBox(height: 14),
          ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedBox(width: double.infinity, height: 220, child: GoogleMap(
            initialCameraPosition: CameraPosition(target: LatLng(adminLat, adminLng), zoom: 15),
            markers: {
              Marker(markerId: const MarkerId('employee'), position: LatLng(pos.latitude, pos.longitude), infoWindow: InfoWindow(title: 'موقعك — ${distance.round()}م'), icon: BitmapDescriptor.defaultMarkerWithHue(inRange ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed)),
              Marker(markerId: const MarkerId('work'), position: LatLng(adminLat, adminLng), infoWindow: InfoWindow(title: locName), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue)),
            },
            circles: { Circle(circleId: const CircleId('workZone'), center: LatLng(adminLat, adminLng), radius: radius, fillColor: const Color(0xFF17B26A).withOpacity(0.15), strokeColor: const Color(0xFF17B26A), strokeWidth: 2) },
            myLocationEnabled: false, zoomControlsEnabled: false, mapToolbarEnabled: false, liteModeEnabled: true,
          ))),
          const SizedBox(height: 10),
          Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: inRange ? C.greenL : C.redL, borderRadius: BorderRadius.circular(4)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(inRange ? 'تم إثبات تواجدك بنجاح' : 'أنت خارج نطاق العمل بـ ${(distance - radius).round()} متر', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: inRange ? C.green : C.red)),
              const SizedBox(width: 6), Icon(inRange ? Icons.check_circle : Icons.error, size: 16, color: inRange ? C.green : C.red),
            ])),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(ctx), style: ElevatedButton.styleFrom(backgroundColor: inRange ? C.green : C.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), padding: const EdgeInsets.symmetric(vertical: 12)),
            child: Text('حسناً', style: GoogleFonts.tajawal(fontWeight: FontWeight.w600)))),
        ]),
      ))));
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showResultDialog(false, 'خطأ في الإثبات', 'حدث خطأ: $e');
    }
  }
}
