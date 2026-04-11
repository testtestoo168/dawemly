import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_colors.dart';
import '../../theme/shimmer.dart';
import '../../services/attendance_service.dart';
import '../../services/face_recognition_service.dart';
import '../../services/api_service.dart';
import '../../services/server_time_service.dart';
import 'face_registration_page.dart';
import 'face_verify_dialog.dart';
import '../../l10n/app_locale.dart';

class EmpHomePage extends StatefulWidget {
  final Map<String, dynamic> user;
  final Function(int)? onTabChange;
  const EmpHomePage({super.key, required this.user, this.onTabChange});
  @override
  State<EmpHomePage> createState() => EmpHomePageState();
}

class EmpHomePageState extends State<EmpHomePage> {
  // Called externally (e.g. from FCM handler) to trigger verification
  void triggerVerification({dynamic verificationId}) {
    final uid = widget.user['uid'] ?? '';
    if (uid.isEmpty || _verifyDialogShowing) return;
    _verifyDialogShowing = true;
    _respondToVerification(uid, verificationId: verificationId);
  }
  final _attService = AttendanceService();
  Map<String, dynamic>? _todayRecord;
  bool _loadingRecord = true;
  Timer? _timer;
  final ValueNotifier<Duration> _elapsed = ValueNotifier(Duration.zero);
  final ValueNotifier<String> _currentTime = ValueNotifier('');
  int _unreadNotifCount = 0;

  // ═══ Location selection ═══
  List<Map<String, dynamic>> _allLocations = [];
  String? _selectedLocationId;
  bool _loadingLocations = true;

  double _standardHours = 8.0;

  // Live map
  Position? _livePosition;
  GoogleMapController? _liveMapController;
  Timer? _locationTimer;
  StreamSubscription<Position>? _locationStreamSub;

  // Verification polling
  Timer? _verifyPollTimer;
  bool _verifyDialogShowing = false;
  final Set<dynamic> _respondedVerificationIds = {};

  // Cached auth requirements (loaded once on init)
  bool _cachedRequireBiometric = true;
  bool _cachedRequireLocation = true;
  bool _cachedFaceRequired = false;
  bool _authReqsLoaded = false;

  final _months = L.months;
  final _days = L.dayNamesFull;

  @override
  void initState() {
    super.initState();
    _startClock();
    // Fire ALL network calls in parallel for fastest startup
    Future.wait([
      Future(() => _loadToday()),
      Future(() => _loadLocations()),
      Future(() => _loadAuthRequirements()),
      Future(() => _loadUnreadNotifCount()),
      Future(() => _checkPendingVerification()),
    ]);
    _verifyPollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkPendingVerification());
    _startLiveLocation();
  }

  void _loadUnreadNotifCount() async {
    final uid = widget.user['uid'] ?? '';
    if (uid.isEmpty) return;
    try {
      final res = await ApiService.get('admin.php?action=get_notifications', cacheTtl: const Duration(seconds: 30));
      if (res['success'] == true && mounted) {
        final all = (res['notifications'] as List? ?? []).cast<Map<String, dynamic>>();
        final mine = all.where((n) => n['uid'] == uid);
        final unread = mine.where((n) => n['is_read'] != 1 && n['is_read'] != true).length;
        setState(() => _unreadNotifCount = unread);
      }
    } catch (_) {}
  }

  void _loadAuthRequirements() async {
    final uid = widget.user['uid'] ?? '';
    if (uid.isEmpty) return;
    try {
      // Run the two reads in parallel. Both share the same session cache in
      // AttendanceService, so only ONE pair of network calls actually happens.
      final results = await Future.wait([
        _attService.getAuthRequirements(uid),
        FaceRecognitionService.isFaceAuthRequired(uid),
      ]);
      final reqs = results[0] as ({bool requireBiometric, bool requireLocation});
      final faceReq = results[1] as bool;
      if (mounted) {
        _cachedRequireBiometric = reqs.requireBiometric;
        _cachedRequireLocation = reqs.requireLocation;
        _cachedFaceRequired = faceReq;
        _authReqsLoaded = true;
      }
      // Load standard hours from settings
      try {
        final settingsRes = await ApiService.get('admin.php?action=get_settings', cacheTtl: const Duration(minutes: 5));
        if (settingsRes['success'] == true && mounted) {
          final s = settingsRes['settings'] as Map<String, dynamic>? ?? {};
          final h = double.tryParse('${s['generalH'] ?? s['general']?['generalH'] ?? ''}');
          if (h != null && h > 0) _standardHours = h;
        }
      } catch (_) {}
      // Warm up the face features cache in the background so the first
      // check-in has zero latency on local comparison.
      if (faceReq == true) {
        // ignore: unawaited_futures
        FaceRecognitionService.preloadFeatures(uid);
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
          (v['status'] == 'pending') &&
          !_respondedVerificationIds.contains(v['id'])
        ).toList();
        if (pending.isNotEmpty && mounted && !_verifyDialogShowing) {
          _verifyDialogShowing = true;
          final verificationId = pending.first['id'];
          _respondToVerification(uid, verificationId: verificationId);
        }
      }
    } catch (_) {}
  }

  bool _gpsReady = false;

  void _startLiveLocation() async {
    if (kIsWeb) return;
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;

      // Try last known first (instant) — so UI shows something immediately
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null && mounted) {
          setState(() { _livePosition = last; _gpsReady = true; });
        }
      } catch (_) {}

      // Then get fresh accurate position
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: AttendanceService.bestSettings(),
      );
      if (mounted) setState(() { _livePosition = pos; _gpsReady = true; });

      // Stream continuous updates
      _locationStreamSub = Geolocator.getPositionStream(
        locationSettings: AttendanceService.streamSettings(),
      ).listen((p) {
        if (mounted) setState(() { _livePosition = p; _gpsReady = true; });
      });
    } catch (_) {}
  }

  /// Get best available position for check-in/out
  Future<({Position? position, bool isMocked})> _getBestPosition() async {
    // Use live position if available and not too old (< 30s)
    if (_livePosition != null) {
      final ageMs = DateTime.now().millisecondsSinceEpoch - _livePosition!.timestamp.millisecondsSinceEpoch;
      if (ageMs < 30000) {
        return (position: _livePosition!, isMocked: _livePosition!.isMocked);
      }
    }
    // Otherwise get a fresh fix
    return await _attService.getCurrentLocation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _locationTimer?.cancel();
    _locationStreamSub?.cancel();
    _verifyPollTimer?.cancel();
    _liveMapController?.dispose();
    _currentTime.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  void _startClock() {
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTime();
      _updateElapsed();
      // Reload at midnight
      final now = DateTime.now();
      if (now.hour == 0 && now.minute == 0 && now.second == 0) {
        _loadToday();
      }
    });
  }

  void _updateTime() {
    final now = ServerTimeService().now;
    final h = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    if (mounted) {
      _currentTime.value = '${h.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} ${now.hour >= 12 ? L.tr('pm') : L.tr('am')}';
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
        if (mounted) _elapsed.value = Duration(minutes: totalWorkedMinutes) + Duration(seconds: liveSeconds);
      } else {
        if (mounted) _elapsed.value = Duration(minutes: totalWorkedMinutes);
      }
    } else {
      // All sessions complete — just show total
      if (mounted) _elapsed.value = Duration(minutes: totalWorkedMinutes);
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
      final result = await ApiService.get('admin.php?action=get_locations', cacheTtl: const Duration(minutes: 5));
      if (result['success'] == true) {
        // Server already filters: employees only see assigned locations
        final locs = (result['locations'] as List? ?? []).cast<Map<String, dynamic>>();
        if (mounted) {
          setState(() {
            _allLocations = locs;
            _loadingLocations = false;
            if (locs.length == 1) _selectedLocationId = locs.first['id'].toString();
          });
          // Animate map camera to admin-defined location once loaded
          _animateMapToAdminLocation();
        }
      } else {
        if (mounted) setState(() => _loadingLocations = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLocations = false);
    }
  }

  // ═══ Animate map to admin location ═══
  void _animateMapToAdminLocation() {
    final loc = _selectedLocation;
    final lat = (loc?['lat'] as num?)?.toDouble();
    final lng = (loc?['lng'] as num?)?.toDouble();
    if (lat != null && lng != null && _liveMapController != null) {
      _liveMapController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15),
      );
    }
  }

  // ═══ Get selected location data ═══
  Map<String, dynamic>? get _selectedLocation {
    if (_selectedLocationId == null) return _allLocations.isNotEmpty ? _allLocations.first : null;
    try {
      return _allLocations.firstWhere((l) => l['id'].toString() == _selectedLocationId);
    } catch (_) {
      return _allLocations.isNotEmpty ? _allLocations.first : null;
    }
  }

  double get _workedHours => _elapsed.value.inMinutes / 60.0;
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

    // ─── SPEED OPTIMIZATION ───
    // Kick off the location fetch in parallel with the biometric/face prompt.
    // The GPS fix and the fingerprint prompt happen at the same wall-clock time
    // instead of one-after-the-other — typically saves 0.5-2 seconds on a real
    // device because GPS warmup runs while the user taps their finger.
    final loc = _selectedLocation;
    final bool showLocCheck = loc != null && loc.isNotEmpty;
    final locFuture = showLocCheck ? _getBestPosition() : null;

    // ─── Step 1: Biometric (instant dialog, while GPS warms up in background) ───
    if (requireBiometric && !faceRequired) {
      final bioResult = await _attService.authenticateBiometricWithDetails();
      if (!mounted) return;
      if (!bioResult.success) {
        _showResultDialog(false, L.tr('err_biometric_failed'), bioResult.error);
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
          userName: L.localName(widget.user).isNotEmpty ? L.localName(widget.user) : (widget.user['name'] ?? ''),
          onComplete: () { if (mounted) _checkIn(); },
        )));
        return;
      }
      if (!mounted) return;
      final faceResult = await showFaceVerifyDialog(context, uid);
      if (faceResult == null || faceResult['success'] != true) {
        if (mounted) _showResultDialog(false, L.tr('face_verify_failed'), faceResult?['error'] ?? L.tr('verify_cancelled'));
        return;
      }
      facePhotoUrl = faceResult['photoUrl'] as String?;
      usedFaceAuth = true;
    }

    // ─── Step 3: Location check (already in-flight from above, just await it) ───
    if (showLocCheck) {
      _showLoadingDialog(L.tr('verifying_location'), L.tr('determining_location'), C.green);
      final locResult = await locFuture!;
      final pos = locResult.position;
      if (pos == null) {
        if (mounted) Navigator.pop(context);
        _showResultDialog(false, L.tr('location_failed'), L.tr('enable_gps_retry'));
        return;
      }
      if (locResult.isMocked) {
        if (mounted) Navigator.pop(context);
        _showResultDialog(false, L.tr('fake_location'), L.tr('spoofing_check_in_block'));
        return;
      }
      savedLat = pos.latitude;
      savedLng = pos.longitude;
      savedAccuracy = pos.accuracy;
      if (mounted) Navigator.pop(context);
      // Reject if accuracy is too poor (matches server threshold of 30m)
      if (pos.accuracy > 30) {
        _showResultDialog(false, L.tr('low_gps'), L.tr('gps_accuracy_warning', args: {'meters': pos.accuracy.round().toString()}));
        return;
      }
      final adminLat = (loc['lat'] as num?)?.toDouble() ?? 0;
      final adminLng = (loc['lng'] as num?)?.toDouble() ?? 0;
      final radius = (loc['radius'] as num?)?.toDouble() ?? 300;
      final distance = Geolocator.distanceBetween(pos.latitude, pos.longitude, adminLat, adminLng);
      // Same formula as server: distance + accuracy must be within radius
      final effectiveDistance = distance + pos.accuracy;
      if (effectiveDistance > radius) {
        _showOutOfRangeDialog(pos.latitude, pos.longitude, adminLat, adminLng, radius, distance, L.localName(loc).isNotEmpty ? L.localName(loc) : L.tr('selected_location'));
        return;
      }
    }

    // ─── Step 4: Send check-in to API ───
    final authMethod = usedFaceAuth ? 'face' : 'fingerprint';
    _showLoadingDialog(L.tr('checking_in'), L.tr('please_wait'), C.green);

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
        _showResultDialog(false, L.tr('err_check_in'), e.toString());
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
        _todayRecord!['status'] = L.tr('present');
        _loadingRecord = false;
      });
      _updateElapsed();
      // Also refresh from server in background
      _loadToday();
      _showLocationResultDialog(true, L.tr('checked_in_success'), result['time'] ?? '', result['lat'], result['lng']);
    } else {
      _showResultDialog(false, L.tr('check_in_failed'), result['error'] ?? L.tr('unknown_error'));
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

    // ─── SPEED: start GPS fetch in parallel with biometric prompt ───
    final loc2 = _selectedLocation;
    final bool showLocCheck2 = loc2 != null && loc2.isNotEmpty;
    final locFuture2 = showLocCheck2 ? _getBestPosition() : null;

    // ─── Step 1: Biometric (while GPS warms up in background) ───
    if (requireBiometric && !faceRequired) {
      final bioResult = await _attService.authenticateBiometricWithDetails();
      if (!mounted) return;
      if (!bioResult.success) {
        _showResultDialog(false, L.tr('err_biometric_failed'), bioResult.error);
        return;
      }
    }

    // ─── Step 2: Face auth if required ───
    if (faceRequired) {
      final hasRegistered = await FaceRecognitionService.hasFaceRegistered(uid);
      if (!hasRegistered) {
        if (!mounted) return;
        _showResultDialog(false, L.tr('face_not_registered_yet'), L.tr('must_register_face_first'));
        return;
      }
      if (!mounted) return;
      final faceResult = await showFaceVerifyDialog(context, uid);
      if (faceResult == null || faceResult['success'] != true) {
        if (mounted) _showResultDialog(false, L.tr('face_verify_failed'), faceResult?['error'] ?? L.tr('verify_cancelled'));
        return;
      }
      facePhotoUrl = faceResult['photoUrl'] as String?;
      usedFaceAuth = true;
    }

    // ─── Step 3: Location check (await the fetch kicked off at the top) ───
    if (showLocCheck2) {
      _showLoadingDialog(L.tr('verifying_location'), L.tr('determining_location'), C.red);
      final locResult2 = await locFuture2!;
      final pos = locResult2.position;
      if (pos == null) {
        if (mounted) Navigator.pop(context);
        _showResultDialog(false, L.tr('location_failed'), L.tr('enable_gps_retry'));
        return;
      }
      if (locResult2.isMocked) {
        if (mounted) Navigator.pop(context);
        _showResultDialog(false, L.tr('fake_location'), L.tr('spoofing_check_out_block'));
        return;
      }
      savedLat = pos.latitude;
      savedLng = pos.longitude;
      savedAccuracy = pos.accuracy;
      if (mounted) Navigator.pop(context);
      // Reject if accuracy is too poor (matches server threshold of 30m)
      if (pos.accuracy > 30) {
        _showResultDialog(false, L.tr('low_gps'), L.tr('gps_accuracy_warning', args: {'meters': pos.accuracy.round().toString()}));
        return;
      }
      final adminLat = (loc2['lat'] as num?)?.toDouble() ?? 0;
      final adminLng = (loc2['lng'] as num?)?.toDouble() ?? 0;
      final radius = (loc2['radius'] as num?)?.toDouble() ?? 300;
      final distance = Geolocator.distanceBetween(pos.latitude, pos.longitude, adminLat, adminLng);
      // Same formula as server: distance + accuracy must be within radius
      final effectiveDistance = distance + pos.accuracy;
      if (effectiveDistance > radius) {
        _showOutOfRangeDialog(pos.latitude, pos.longitude, adminLat, adminLng, radius, distance, L.localName(loc2).isNotEmpty ? L.localName(loc2) : L.tr('selected_location'));
        return;
      }
    }

    // ─── Step 4: Send check-out to API ───
    final authMethod = usedFaceAuth ? 'face' : 'fingerprint';
    _showLoadingDialog(L.tr('checking_out'), L.tr('please_wait'), C.red);

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
        _showResultDialog(false, L.tr('err_check_out'), e.toString());
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
          _todayRecord!['status'] = L.tr('complete');
        }
      });
      _updateElapsed();
      _loadToday();
      _showLocationResultDialog(true, L.tr('checked_out_success'), result['time'] ?? '', result['lat'], result['lng']);
    } else {
      _showResultDialog(false, L.tr('check_out_failed'), result['error'] ?? L.tr('unknown_error'));
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
        Text(L.tr('outside_range'), style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w700, color: C.red)),
        Text(L.tr('enter_range_to_check_in'), style: GoogleFonts.tajawal(fontSize: 13, color: C.sub)),
        const SizedBox(height: 14),
        ClipRRect(borderRadius: BorderRadius.circular(DS.radiusMd), child: SizedBox(width: double.infinity, height: 200, child: GoogleMap(
          initialCameraPosition: CameraPosition(target: LatLng(adminLat, adminLng), zoom: 14),
          markers: {
            Marker(markerId: const MarkerId('emp'), position: LatLng(empLat, empLng), infoWindow: InfoWindow(title: L.tr('your_location_label', args: {'meters': distance.round().toString()})), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)),
            Marker(markerId: const MarkerId('work'), position: LatLng(adminLat, adminLng), infoWindow: InfoWindow(title: locName), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)),
          },
          circles: {
            Circle(circleId: const CircleId('zone'), center: LatLng(adminLat, adminLng), radius: radius, fillColor: C.green.withValues(alpha: 0.15), strokeColor: C.green, strokeWidth: 2),
          },
          myLocationEnabled: false, zoomControlsEnabled: false, liteModeEnabled: false,
        ))),
        const SizedBox(height: 10),
        Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: C.redL, borderRadius: BorderRadius.circular(DS.radiusMd)),
          child: Column(children: [
            Text(L.tr('you_away_meters', args: {'meters': distance.round().toString(), 'name': locName}), style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: C.red)),
            Text(L.tr('allowed_range', args: {'meters': radius.round().toString()}), style: GoogleFonts.tajawal(fontSize: 12, color: C.red.withOpacity(0.7))),
          ]),
        ),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(ctx), style: ElevatedButton.styleFrom(backgroundColor: C.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd)), padding: const EdgeInsets.symmetric(vertical: 12)),
          child: Text(L.tr('understood'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w600)))),
      ]),
    ))));
  }

  void _showLoadingDialog(String title, String sub, Color color) {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => Center(child: Material(color: Colors.transparent, child: Container(
      width: 300, padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(DS.radiusMd)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 50, height: 50, child: CircularProgressIndicator(strokeWidth: 3, color: color)),
        const SizedBox(height: 16),
        Text(title, style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: C.text)),
        const SizedBox(height: 4),
        Text(sub, style: GoogleFonts.tajawal(fontSize: 12, color: C.sub)),
      ]),
    ))));
  }

  void _showResultDialog(bool success, String title, String sub) {
    showDialog(context: context, builder: (ctx) => Center(child: Material(color: Colors.transparent, child: Container(
      width: 300, padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(DS.radiusMd)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 60, height: 60, decoration: BoxDecoration(color: success ? C.greenL : C.redL, shape: BoxShape.circle), child: Icon(success ? Icons.check : Icons.close, size: 30, color: success ? C.green : C.red)),
        const SizedBox(height: 16),
        Text(title, style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: C.text)),
        const SizedBox(height: 4),
        Text(sub, style: GoogleFonts.tajawal(fontSize: 13, color: C.sub)),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(ctx), style: ElevatedButton.styleFrom(backgroundColor: success ? C.green : C.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd))), child: Text(L.tr('ok'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w600)))),
      ]),
    ))));
  }

  void _showLocationResultDialog(bool success, String title, String time, dynamic lat, dynamic lng) async {
    Map<String, dynamic>? adminLoc = _selectedLocation;
    final adminLat = (adminLoc?['lat'] as num?)?.toDouble();
    final adminLng = (adminLoc?['lng'] as num?)?.toDouble();
    final adminRadius = (adminLoc?['radius'] as num?)?.toDouble() ?? 300.0;
    final adminName = adminLoc != null ? (L.localName(adminLoc).isNotEmpty ? L.localName(adminLoc) : L.tr('selected_location')) : L.tr('selected_location');
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
        Text(L.tr('time_colon', args: {'time': time}), style: GoogleFonts.tajawal(fontSize: 13, color: C.sub)),
        const SizedBox(height: 14),
        if (lat != null && lng != null) ClipRRect(borderRadius: BorderRadius.circular(DS.radiusMd), child: SizedBox(width: double.infinity, height: 200, child: GoogleMap(
          initialCameraPosition: CameraPosition(target: LatLng(adminLat ?? empLat, adminLng ?? empLng), zoom: 15),
          markers: {
            Marker(markerId: const MarkerId('employee'), position: LatLng(empLat, empLng), infoWindow: InfoWindow(title: L.tr('attendance_punch')), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)),
            if (adminLat != null) Marker(markerId: const MarkerId('work'), position: LatLng(adminLat, adminLng!), infoWindow: InfoWindow(title: adminName), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)),
          },
          circles: {
            if (adminLat != null) Circle(circleId: const CircleId('workZone'), center: LatLng(adminLat, adminLng!), radius: adminRadius, fillColor: C.green.withValues(alpha: 0.15), strokeColor: C.green, strokeWidth: 2),
          },
          myLocationEnabled: false, zoomControlsEnabled: false, mapToolbarEnabled: false, liteModeEnabled: false,
        ))),
        const SizedBox(height: 8),
        Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: C.greenL, borderRadius: BorderRadius.circular(4)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(L.tr('location_verified'), style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.green)),
            const SizedBox(width: 6), const Icon(Icons.check_circle, size: 16, color: C.green),
          ])),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(ctx), style: ElevatedButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd)), padding: const EdgeInsets.symmetric(vertical: 12)), child: Text(L.tr('ok'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w600)))),
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
    return '${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? L.tr('pm') : L.tr('am')}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dayName = _days[now.weekday % 7];
    final monthName = _months[now.month - 1];
    final greeting = now.hour < 12 ? L.tr('good_morning') : L.tr('good_evening');
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
    final status = hasCheckOut && !isCurrentlyCheckedIn ? L.tr('complete') : isCurrentlyCheckedIn ? L.tr('present') : hasCheckIn ? L.tr('present') : L.tr('not_registered');
    final stColor = isCurrentlyCheckedIn ? C.green : (hasCheckOut && !isCurrentlyCheckedIn) ? C.green : hasCheckIn ? C.pri : C.muted;
    final _dispName = L.localName(widget.user);
    final av = _dispName.length >= 2 ? _dispName.substring(0, 2) : L.tr('pm');

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
            InkWell(
              onTap: () => _showNotifications(),
              child: Stack(clipBehavior: Clip.none, children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(DS.radiusMd)), child: const Icon(Icons.notifications_none_rounded, size: 20, color: Colors.white)),
                if (_unreadNotifCount > 0)
                  Positioned(top: -4, left: -4, child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: C.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text('$_unreadNotifCount', style: GoogleFonts.ibmPlexMono(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white), textAlign: TextAlign.center),
                  )),
              ]),
            ),
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(greeting, style: GoogleFonts.tajawal(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                Text(_dispName, style: GoogleFonts.tajawal(fontSize: 13, color: Colors.white.withOpacity(0.65))),
              ]),
              const SizedBox(width: 12),
              Stack(children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(DS.radiusMd), border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5)),
                  child: Center(child: Text(av, style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)))),
                Positioned(bottom: -1, right: -1, child: Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: isCurrentlyCheckedIn ? C.green : C.red, border: Border.all(color: Colors.white, width: 2)))),
              ]),
            ]),
          ]),
          const SizedBox(height: 20),

          // Live Clock
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(DS.radiusMd)),
            child: Column(children: [
              ValueListenableBuilder<String>(valueListenable: _currentTime, builder: (_, t, __) => Text(t, style: GoogleFonts.ibmPlexMono(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 3))),
              const SizedBox(height: 4),
              Text('$dayName ${now.day} $monthName — ${L.localDept(widget.user)}', style: GoogleFonts.tajawal(fontSize: 12, color: Colors.white.withOpacity(0.5))),
            ]),
          ),
          const SizedBox(height: 16),

          // ═══ LOCATION DROPDOWN ═══
          if (_allLocations.length > 1) ...[
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(L.tr('select_specific_location'), style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.6))),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(DS.radiusMd), border: Border.all(color: Colors.white.withOpacity(0.2))),
              child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedLocationId ?? (_allLocations.isNotEmpty ? _allLocations.first['id'].toString() : null),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
                dropdownColor: const Color(0xFF0F4199),
                style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                hint: Text(L.tr('choose_punch_location'), style: GoogleFonts.tajawal(fontSize: 13, color: Colors.white60)),
                items: _allLocations.map((loc) => DropdownMenuItem<String>(
                  value: loc['id'].toString(),
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Flexible(child: Text(L.localName(loc), style: GoogleFonts.tajawal(fontSize: 13, color: Colors.white), overflow: TextOverflow.ellipsis, maxLines: 1, textAlign: TextAlign.right)),
                    const SizedBox(width: 8),
                    const Icon(Icons.location_on_rounded, size: 16, color: Colors.white70),
                  ]),
                )).toList(),
                onChanged: (v) {
                  setState(() => _selectedLocationId = v);
                  _animateMapToAdminLocation();
                },
              )),
            ),
            const SizedBox(height: 12),
          ] else if (_allLocations.length == 1) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(DS.radiusMd)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Flexible(child: Text(L.localName(_allLocations.first), style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white), overflow: TextOverflow.ellipsis, maxLines: 1, textAlign: TextAlign.center)),
                const SizedBox(width: 8),
                const Icon(Icons.location_on_rounded, size: 16, color: Colors.white70),
              ]),
            ),
            const SizedBox(height: 12),
          ],

          // Live distance check — disable button if outside range
          Builder(builder: (ctx) {
            final loc = _selectedLocation;
            final adminLat = (loc?['lat'] as num?)?.toDouble();
            final adminLng = (loc?['lng'] as num?)?.toDouble();
            final radius = (loc?['radius'] as num?)?.toDouble() ?? 300;
            final empLat = _livePosition?.latitude;
            final empLng = _livePosition?.longitude;

            // GPS not ready yet — show loading
            if (adminLat != null && !_gpsReady) {
              return Column(children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: C.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: C.orange)),
                    const SizedBox(width: 8),
                    Text(L.tr('determining_location_gps'), style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.orange)),
                  ]),
                ),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: Opacity(
                  opacity: 0.4,
                  child: isCurrentlyCheckedIn
                    ? _clockBtn(L.tr('check_out_confirm'), Icons.logout_rounded, C.red, Colors.white, () {})
                    : _clockBtn(L.tr('check_in_confirm'), Icons.fingerprint_rounded, Colors.white, C.pri, () {}),
                )),
              ]);
            }

            bool isInRange = true;
            double? distance;
            if (adminLat != null && adminLng != null && empLat != null && empLng != null) {
              distance = Geolocator.distanceBetween(empLat, empLng, adminLat, adminLng);
              isInRange = (distance + (_livePosition?.accuracy ?? 0)) <= radius;
            }

            // Outside range
            if (adminLat != null && distance != null && !isInRange)
              return Column(children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: C.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(L.tr('outside_range_distance', args: {'meters': distance.round().toString()}), style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w700, color: C.red)),
                    const SizedBox(width: 6),
                    const Icon(Icons.location_off_rounded, size: 16, color: C.red),
                  ]),
                ),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: Opacity(
                  opacity: 0.4,
                  child: isCurrentlyCheckedIn
                    ? _clockBtn(L.tr('check_out_confirm'), Icons.logout_rounded, C.red, Colors.white, () {})
                    : _clockBtn(L.tr('check_in_confirm'), Icons.fingerprint_rounded, Colors.white, C.pri, () {}),
                )),
              ]);

            // In range — show normal button
            return Column(children: [
              if (adminLat != null && distance != null) Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: C.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(L.tr('inside_range_distance', args: {'meters': distance.round().toString()}), style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: C.green)),
                  const SizedBox(width: 6),
                  const Icon(Icons.check_circle_rounded, size: 14, color: C.green),
                ]),
              ),
              if (isCurrentlyCheckedIn)
                SizedBox(width: double.infinity, child: _clockBtn(L.tr('check_out_confirm'), Icons.logout_rounded, C.red, Colors.white, _checkOut))
              else
                SizedBox(width: double.infinity, child: _clockBtn(L.tr('check_in_confirm'), Icons.fingerprint_rounded, Colors.white, C.pri, _checkIn)),
            ]);
          }),
        ]),
      ),

      // ═══ QUICK ACTIONS — Connected to tabs ═══
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(DS.radiusMd), border: Border.all(color: C.border)),
          child: Row(children: [
            _empQuickBtn(Icons.calendar_today_rounded, L.tr('my_attendance'), () => widget.onTabChange?.call(1)),
            _empQuickBtn(Icons.description_outlined, L.tr('my_requests'), () => widget.onTabChange?.call(3)),
            _empQuickBtn(Icons.add_circle_outline_rounded, L.tr('new_request'), () => widget.onTabChange?.call(2)),
            _empQuickBtn(Icons.person_outline_rounded, L.tr('mob_more'), () => widget.onTabChange?.call(4)),
          ]),
        ),
      ),

      // ═══ LIVE MAP ═══
      if (!kIsWeb) _buildLiveMap(),

      // ═══ WORK TIMER ═══
      if (hasCheckIn) Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Container(
          decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(DS.radiusMd), border: Border.all(color: C.border)),
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: stColor.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                child: Text(status, style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: stColor))),
              const Spacer(),
              Text(hasCheckOut ? L.tr('total_hours') : L.tr('elapsed_time_label'), style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: C.text)),
            ]),
            const SizedBox(height: 14),
            ValueListenableBuilder<Duration>(valueListenable: _elapsed, builder: (_, e, __) => Text(_fmtDuration(e), style: GoogleFonts.ibmPlexMono(fontSize: 40, fontWeight: FontWeight.w700, color: hasCheckOut ? C.green : C.pri, letterSpacing: 4))),
            const SizedBox(height: 14),
            Row(children: [
              _statBox(L.tr('overtime_extra'), _hasOvertime ? L.tr('overtime_hours_display', args: {'h': _overtime.toStringAsFixed(1)}) : '—', _hasOvertime ? C.orange : C.muted),
              const SizedBox(width: 10),
              _statBox(L.tr('work_hours'), '${_workedHours.toStringAsFixed(1)}h / ${_standardHours.toStringAsFixed(0)}h', _workedHours >= _standardHours ? C.green : C.pri),
            ]),
            if (_hasOvertime && !hasCheckOut) ...[
              const SizedBox(height: 12),
              Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: C.orangeL, borderRadius: BorderRadius.circular(DS.radiusMd)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(L.tr('exceeded_standard'), style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.orange)),
                  const SizedBox(width: 8), const Icon(Icons.warning_amber_rounded, size: 18, color: C.orange),
                ])),
            ],
          ]),
        ),
      ),

      // ═══ TODAY RECORD ═══
      Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: Container(
        decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(DS.radiusMd), border: Border.all(color: C.border)),
        child: Column(children: [
          Padding(padding: const EdgeInsets.all(16), child: Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: stColor.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
              child: Text(status, style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: stColor))),
            const Spacer(),
            Text(L.tr('daily_attendance_log'), style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: C.text)),
            const SizedBox(width: 8),
            Container(width: 28, height: 28, decoration: BoxDecoration(color: C.priLight, borderRadius: BorderRadius.circular(4)), child: const Icon(Icons.history_rounded, size: 14, color: C.pri)),
          ])),
          Container(height: 1, color: C.div),
          if (_loadingRecord) const ShimmerAttendanceCard()
          else if (_todayRecord == null)
            Padding(padding: const EdgeInsets.all(30), child: Column(children: [
              Container(width: 56, height: 56, decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(DS.radiusMd)), child: const Icon(Icons.fingerprint_rounded, size: 30, color: C.hint)),
              const SizedBox(height: 12),
              Text(L.tr('not_checked_in'), style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w600, color: C.text)),
              const SizedBox(height: 4),
              Text(L.tr('tap_check_in'), style: GoogleFonts.tajawal(fontSize: 12, color: C.muted)),
            ]))
          else Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            if (hasCheckIn) _entryRow(L.tr('first_check_in'), _formatTimestamp(_todayRecord!['firstCheckIn'] ?? _todayRecord!['first_check_in'] ?? _todayRecord!['checkIn'] ?? _todayRecord!['check_in']), C.pri, Icons.login_rounded),
            if (hasCheckOut) _entryRow(L.tr('last_check_out'), _formatTimestamp(_todayRecord!['lastCheckOut'] ?? _todayRecord!['last_check_out'] ?? _todayRecord!['checkOut'] ?? _todayRecord!['check_out']), C.red, Icons.logout_rounded),
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
    final authName = loc != null ? (L.localName(loc).isNotEmpty ? L.localName(loc) : L.tr('authorized_location')) : L.tr('authorized_location');

    final empLat = _livePosition?.latitude;
    final empLng = _livePosition?.longitude;

    // Determine initial camera target
    final centerLat = authLat ?? empLat ?? 24.7136;
    final centerLng = authLng ?? empLng ?? 46.6753;

    // Determine if employee is inside zone
    bool? insideZone;
    if (empLat != null && empLng != null && authLat != null && authLng != null) {
      final dist = Geolocator.distanceBetween(empLat, empLng, authLat, authLng);
      insideZone = (dist + (_livePosition?.accuracy ?? 0)) <= authRadius;
    }

    final zoneColor = insideZone == true ? C.green : C.red;

    final markers = <Marker>{};
    if (empLat != null && empLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('employee'),
        position: LatLng(empLat, empLng),
        infoWindow: InfoWindow(title: L.tr('current_location')),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          insideZone == true ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
        ),
      ));
    }
    if (authLat != null && authLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('auth'),
        position: LatLng(authLat, authLng),
        infoWindow: InfoWindow(title: authName),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          insideZone == true ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
        ),
      ));
    }

    final circles = <Circle>{};
    if (authLat != null && authLng != null) {
      circles.add(Circle(
        circleId: const CircleId('authZone'),
        center: LatLng(authLat, authLng),
        radius: authRadius,
        fillColor: zoneColor.withValues(alpha: 0.12),
        strokeColor: zoneColor,
        strokeWidth: 2,
      ));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.circular(DS.radiusMd),
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
                  color: insideZone ? C.greenL : C.redL,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(insideZone ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 12, color: insideZone ? C.green : C.red),
                  const SizedBox(width: 4),
                  Text(insideZone ? L.tr('inside_range_label') : L.tr('outside_range_label'), style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600, color: insideZone ? C.green : C.red)),
                ]),
              ),
              const Spacer(),
              const Icon(Icons.location_on_rounded, size: 14, color: C.sub),
              const SizedBox(width: 4),
              Flexible(child: Text(authName, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.text), overflow: TextOverflow.ellipsis, maxLines: 1, textAlign: TextAlign.right)),
            ]),
          ),
          // Map — wrapped in RepaintBoundary to isolate repaints
          RepaintBoundary(child: ClipRRect(
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
            child: SizedBox(
              height: 220,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: LatLng(centerLat, centerLng), zoom: 15),
                markers: markers,
                circles: circles,
                onMapCreated: (c) {
                  _liveMapController = c;
                  _animateMapToAdminLocation();
                },
                myLocationEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                liteModeEnabled: false,
              ),
            ),
          )),
        ]),
      ),
    );
  }

  // ─── Quick action button — CONNECTED ───
  Widget _empQuickBtn(IconData icon, String label, VoidCallback onTap) {
    return Expanded(child: InkWell(
      onTap: onTap,
      splashColor: C.pri.withOpacity(0.08),
      highlightColor: Colors.transparent,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 52, height: 52, decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(DS.radiusMd), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 1))]),
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
    return Material(color: bg, borderRadius: BorderRadius.circular(DS.radiusMd), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(DS.radiusMd), child: Container(padding: const EdgeInsets.symmetric(vertical: 13), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 18, color: fg), const SizedBox(width: 6), Text(text, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: fg))]))));
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
              Text(L.tr('mob_notifications'), style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
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
              if (docs.isEmpty) return Padding(padding: const EdgeInsets.all(40), child: Center(child: Column(children: [const Icon(Icons.notifications_off, size: 40, color: C.hint), const SizedBox(height: 8), Text(L.tr('no_notifications'), style: GoogleFonts.tajawal(color: C.muted))])));
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
                    decoration: BoxDecoration(color: isRead ? Colors.transparent : (isVerifyRequest ? C.orangeL : isUrgent ? C.redL : C.priLight), border: const Border(bottom: BorderSide(color: C.div))),
                    child: Row(children: [
                      if (isVerifyRequest && !isRead) ...[
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: C.orange, borderRadius: BorderRadius.circular(DS.radiusMd)),
                          child: Text(L.tr('verify_now'), style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white))),
                        const SizedBox(width: 8),
                      ] else if (!isRead) ...[Container(width: 8, height: 8, decoration: BoxDecoration(color: isUrgent ? C.red : C.pri, shape: BoxShape.circle)), const SizedBox(width: 8)],
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(L.serverText(n['title'] ?? ''), style: GoogleFonts.tajawal(fontSize: 13, fontWeight: isRead ? FontWeight.w500 : FontWeight.w700, color: C.text)),
                        Text(L.serverText(n['body'] ?? ''), style: GoogleFonts.tajawal(fontSize: 11, color: C.sub)),
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
          Text(L.tr('verify_request_title'), style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w700, color: C.text)),
          const SizedBox(height: 6),
          Text(L.tr('admin_requests_verify'), style: GoogleFonts.tajawal(fontSize: 13, color: C.sub, height: 1.5), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
            onPressed: () async { Navigator.pop(ctx); _doVerificationResponse(uid, verificationId: verificationId); },
            style: ElevatedButton.styleFrom(backgroundColor: C.orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd)), elevation: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.my_location, size: 20), const SizedBox(width: 8), Text(L.tr('verify_my_location'), style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700))]),
          )),
        ]),
      )),
    )).then((_) => _verifyDialogShowing = false);
  }

  void _doVerificationResponse(String uid, {dynamic verificationId}) async {
    _showLoadingDialog(L.tr('verifying_status'), L.tr('calculating_distance'), C.orange);
    try {
      final locResultV = await _getBestPosition();
      final pos = locResultV.position;
      if (pos == null) { if (mounted) Navigator.pop(context); _showResultDialog(false, L.tr('location_failed'), L.tr('enable_gps')); return; }
      if (locResultV.isMocked) { if (mounted) Navigator.pop(context); _showResultDialog(false, L.tr('fake_location'), L.tr('spoofing_detected')); return; }

      final loc = _selectedLocation;
      double adminLat = 0, adminLng = 0, radius = 300;
      String locName = L.tr('selected_location');
      if (loc != null && loc.isNotEmpty) {
        adminLat = (loc['lat'] as num?)?.toDouble() ?? 0;
        adminLng = (loc['lng'] as num?)?.toDouble() ?? 0;
        radius = (loc['radius'] as num?)?.toDouble() ?? 300;
        locName = L.localName(loc).isNotEmpty ? L.localName(loc) : L.tr('selected_location');
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
              locName = L.localName(l).isNotEmpty ? L.localName(l) : L.tr('selected_location');
            }
          }
        } catch (_) {}
      }

      final distance = Geolocator.distanceBetween(pos.latitude, pos.longitude, adminLat, adminLng);
      final inRange = (distance + pos.accuracy) <= radius;

      // Respond to verification via API + mark as responded so it won't repeat
      _respondedVerificationIds.add(verificationId);
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
          Text(inRange ? L.tr('inside_range') : L.tr('outside_range_warning'), style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w700, color: inRange ? C.green : C.red)),
          Text(L.tr('distance_info', args: {'meters': distance.round().toString(), 'name': locName}), style: GoogleFonts.tajawal(fontSize: 13, color: C.sub)),
          const SizedBox(height: 14),
          ClipRRect(borderRadius: BorderRadius.circular(DS.radiusMd), child: SizedBox(width: double.infinity, height: 220, child: GoogleMap(
            initialCameraPosition: CameraPosition(target: LatLng(adminLat, adminLng), zoom: 15),
            markers: {
              Marker(markerId: const MarkerId('employee'), position: LatLng(pos.latitude, pos.longitude), infoWindow: InfoWindow(title: L.tr('your_location_label', args: {'meters': distance.round().toString()})), icon: BitmapDescriptor.defaultMarkerWithHue(inRange ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed)),
              Marker(markerId: const MarkerId('work'), position: LatLng(adminLat, adminLng), infoWindow: InfoWindow(title: locName), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue)),
            },
            circles: { Circle(circleId: const CircleId('workZone'), center: LatLng(adminLat, adminLng), radius: radius, fillColor: C.green.withOpacity(0.15), strokeColor: C.green, strokeWidth: 2) },
            myLocationEnabled: false, zoomControlsEnabled: false, mapToolbarEnabled: false, liteModeEnabled: true,
          ))),
          const SizedBox(height: 10),
          Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: inRange ? C.greenL : C.redL, borderRadius: BorderRadius.circular(4)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(inRange ? L.tr('verify_success') : L.tr('out_range_by_meters', args: {'meters': (distance - radius).round().toString()}), style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: inRange ? C.green : C.red)),
              const SizedBox(width: 6), Icon(inRange ? Icons.check_circle : Icons.error, size: 16, color: inRange ? C.green : C.red),
            ])),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(ctx), style: ElevatedButton.styleFrom(backgroundColor: inRange ? C.green : C.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusMd)), padding: const EdgeInsets.symmetric(vertical: 12)),
            child: Text(L.tr('ok'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w600)))),
        ]),
      ))));
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showResultDialog(false, L.tr('err_verify'), L.tr('error_occurred_msg', args: {'error': e.toString()}));
    }
  }
}
