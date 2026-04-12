import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'api_service.dart';
import 'attendance_service.dart';
import '../l10n/app_locale.dart';

class FaceRecognitionService {
  static final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableClassification: true, // needed for eye-open + smile detection in features
      enableTracking: false,
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.1, // detect faces even at arm's length on low-res cameras
    ),
  );

  // Cache of registered face features per uid so verifyFace can do a local
  // comparison first without any network round-trip on every check-in.
  static final Map<String, List<double>> _featuresCache = {};

  // Threshold mirrors the server-side check in face.php handleVerify()
  static const double _matchThreshold = 0.65;

  // Fetch registered features from the server and cache them. Call once at
  // login / screen mount so the first check-in has zero network latency on
  // the comparison step.
  static Future<List<double>?> preloadFeatures(String uid) async {
    if (_featuresCache.containsKey(uid)) return _featuresCache[uid];
    try {
      final res = await ApiService.get('face.php?action=features', params: {'uid': uid});
      if (res['success'] != true) return null;
      final raw = res['features'];
      List<double>? list;
      if (raw is List) {
        list = raw.map<double>((e) => (e as num).toDouble()).toList();
      } else if (raw is String && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          list = decoded.map<double>((e) => (e as num).toDouble()).toList();
        }
      }
      if (list != null && list.isNotEmpty) {
        _featuresCache[uid] = list;
        return list;
      }
    } catch (_) {}
    return null;
  }

  static void clearFeaturesCache([String? uid]) {
    if (uid == null) { _featuresCache.clear(); } else { _featuresCache.remove(uid); }
  }

  // ═══ Check if user has registered face ═══
  // Fast path: if features cache is populated, the answer is yes without any network call.
  static Future<bool> hasFaceRegistered(String uid) async {
    if (_featuresCache.containsKey(uid) && _featuresCache[uid]!.isNotEmpty) return true;
    try {
      final result = await ApiService.get('face.php?action=status', params: {'uid': uid});
      return result['registered'] == true;
    } catch (_) {
      return false;
    }
  }

  // ═══ Check if face auth is required ═══
  // Reuses the shared AuthContext cache from AttendanceService — zero extra API
  // calls after the first fetch on screen mount.
  static Future<bool> isFaceAuthRequired(String uid) async {
    try {
      final ctx = await AttendanceService().loadAuthContext(uid);
      final settings = ctx.settings;
      final userData = ctx.user;
      final globalFace = settings['authFace'] ?? false;
      final hasOverride = userData['authOverride'] == true;
      if (hasOverride) return userData['authFace'] ?? globalFace;
      return globalFace == true;
    } catch (_) {
      return false;
    }
  }

  // ═══ Detect face from camera image ═══
  static Future<List<Face>> detectFaces(InputImage inputImage) async {
    try {
      return await _faceDetector.processImage(inputImage);
    } catch (_) {
      return [];
    }
  }

  // ═══ Validate face quality for registration ═══
  static Map<String, dynamic> validateFaceForRegistration(Face face) {
    final issues = <String>[];
    final yAngle = face.headEulerAngleY ?? 0;
    final xAngle = face.headEulerAngleX ?? 0;
    final zAngle = face.headEulerAngleZ ?? 0;

    if (yAngle.abs() > 25) issues.add(L.tr('face_forward'));
    if (xAngle.abs() > 20) issues.add(L.tr('tilt_head'));

    final leftEyeOpen = face.leftEyeOpenProbability ?? 1.0;
    final rightEyeOpen = face.rightEyeOpenProbability ?? 1.0;
    if (leftEyeOpen < 0.5 || rightEyeOpen < 0.5) issues.add(L.tr('open_eyes'));

    final bbox = face.boundingBox;
    if (bbox.width < 100 || bbox.height < 100) issues.add(L.tr('move_closer_camera'));

    final smile = face.smilingProbability ?? 0;

    return {
      'valid': issues.isEmpty,
      'issues': issues,
      'yAngle': yAngle, 'xAngle': xAngle, 'zAngle': zAngle,
      'leftEye': leftEyeOpen, 'rightEye': rightEyeOpen,
      'smile': smile,
      'faceWidth': bbox.width, 'faceHeight': bbox.height,
    };
  }

  // ═══ Extract face features ═══
  static List<double> extractFaceFeatures(Face face) {
    final features = <double>[];
    final landmarks = [
      FaceLandmarkType.leftEye, FaceLandmarkType.rightEye,
      FaceLandmarkType.noseBase, FaceLandmarkType.leftMouth,
      FaceLandmarkType.rightMouth, FaceLandmarkType.bottomMouth,
      FaceLandmarkType.leftEar, FaceLandmarkType.rightEar,
      FaceLandmarkType.leftCheek, FaceLandmarkType.rightCheek,
    ];

    final bbox = face.boundingBox;
    final cx = bbox.center.dx;
    final cy = bbox.center.dy;
    final w = bbox.width;
    final h = bbox.height;

    for (final lmType in landmarks) {
      final lm = face.landmarks[lmType];
      if (lm != null) {
        features.add((lm.position.x - cx) / w);
        features.add((lm.position.y - cy) / h);
      } else {
        features.add(0);
        features.add(0);
      }
    }

    if (w > 0 && h > 0) features.add(w / h);

    final noseContour = face.contours[FaceContourType.noseBridge];
    if (noseContour != null && noseContour.points.length >= 2) {
      final noseLen = (noseContour.points.last.y - noseContour.points.first.y).abs();
      features.add(noseLen / h);
    }

    features.add(face.leftEyeOpenProbability ?? 0);
    features.add(face.rightEyeOpenProbability ?? 0);

    return features;
  }

  // ═══ Compare two face feature vectors ═══
  static double compareFaces(List<double> registered, List<double> current) {
    if (registered.isEmpty || current.isEmpty) return 0;
    final len = min(registered.length, current.length);
    double sumSq = 0;
    for (int i = 0; i < len; i++) {
      sumSq += (registered[i] - current[i]) * (registered[i] - current[i]);
    }
    final distance = sqrt(sumSq / len);
    return 1.0 / (1.0 + distance * 5);
  }

  // ═══ Register face - upload to API ═══
  static Future<Map<String, dynamic>> registerFace({
    required String uid,
    required String userName,
    required List<double> faceFeatures,
    required Uint8List photoBytes,
  }) async {
    try {
      // Upload photo via API multipart
      final uploadRes = await ApiService.postMultipart(
        'admin.php?action=upload',
        {'uid': uid, 'type': 'face_registration'},
        fileBytes: photoBytes,
        fileField: 'photo',
        fileName: 'face_$uid.jpg',
      );

      final photoUrl = uploadRes['url'] as String? ?? '';

      // Save face features to API
      final result = await ApiService.post('face.php?action=register', {
        'uid': uid,
        'user_name': userName,
        'features': faceFeatures,
        'photo_url': photoUrl,
      });

      if (result['success'] == true) {
        return {'success': true, 'photoUrl': photoUrl};
      }
      return {'success': false, 'error': result['error'] ?? L.tr('face_save_failed')};
    } catch (e) {
      return {'success': false, 'error': L.tr('face_save_error', args: {'error': e.toString()})};
    }
  }

  // ═══ Verify face — FAST PATH ═══
  // Strategy:
  //   1) Use cached registered features (fetched via preloadFeatures at screen mount).
  //      If not cached, fetch them once via face.php?action=features.
  //   2) Compare on-device (milliseconds, zero network). Decision is instant.
  //   3) If matched: fire-and-forget upload + server verify call for audit log.
  //      User proceeds immediately without waiting for upload (typical 2-5s saved).
  //   4) If not matched: return instantly, skip upload entirely (saves bandwidth + time).
  static Future<Map<String, dynamic>> verifyFace({
    required String uid,
    required List<double> currentFeatures,
    required Uint8List photoBytes,
  }) async {
    // 1) Resolve registered features (cache-first)
    List<double>? registered = _featuresCache[uid];
    registered ??= await preloadFeatures(uid);
    if (registered == null || registered.isEmpty) {
      return {
        'success': false,
        'error': L.tr('face_not_registered_msg'),
        'needsRegistration': true,
      };
    }

    // 2) Local comparison — instant
    final similarity = compareFaces(registered, currentFeatures);
    final matched = similarity >= _matchThreshold;

    if (!matched) {
      // Fast fail: no upload, no server round-trip
      return {
        'success': false,
        'error': L.tr('face_not_matching'),
        'similarity': similarity,
      };
    }

    // 3) Match — upload photo and wait for URL so check-in can save it
    String photoUrl = '';
    try {
      final uploadRes = await ApiService.postMultipart(
        'admin.php?action=upload',
        {'uid': uid, 'type': 'face_verification'},
        fileBytes: photoBytes,
        fileField: 'photo',
        fileName: 'verify_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      photoUrl = uploadRes['url'] as String? ?? '';
    } catch (_) {}

    // Log verification in background — don't block
    // ignore: unawaited_futures
    ApiService.post('face.php?action=verify', {
      'uid': uid,
      'features': currentFeatures,
      'photo_url': photoUrl,
    });

    return {'success': true, 'similarity': similarity, 'photoUrl': photoUrl};
  }

  // Background: upload the verification photo and notify the server.
  // Failures here are silent — the user has already been authenticated locally.
  static Future<void> _uploadAndLogVerification(
    String uid,
    List<double> currentFeatures,
    Uint8List photoBytes,
    double similarity,
  ) async {
    try {
      final uploadRes = await ApiService.postMultipart(
        'admin.php?action=upload',
        {'uid': uid, 'type': 'face_verification'},
        fileBytes: photoBytes,
        fileField: 'photo',
        fileName: 'verify_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final photoUrl = uploadRes['url'] as String? ?? '';
      // Fire the server-side verify too so server logs a row in face_verifications
      await ApiService.post('face.php?action=verify', {
        'uid': uid,
        'features': currentFeatures,
        'photo_url': photoUrl,
      });
    } catch (_) {
      // Swallow — audit trail is best-effort
    }
  }

  // ═══ Reset face registration (admin) ═══
  static Future<void> resetFaceRegistration(String uid) async {
    await ApiService.post('face.php?action=reset', {'uid': uid});
  }

  // ═══ Get registration info ═══
  static Future<Map<String, dynamic>?> getFaceRegistrationInfo(String uid) async {
    try {
      final result = await ApiService.get('face.php?action=status', params: {'uid': uid});
      if (result['success'] == true) return result['data'] as Map<String, dynamic>?;
      return null;
    } catch (_) {
      return null;
    }
  }

  // ═══ Get verification history ═══
  static Future<List<Map<String, dynamic>>> getVerificationHistory(String uid, {int limit = 20}) async {
    try {
      final result = await ApiService.get('face.php?action=history',
          params: {'uid': uid, 'limit': limit.toString()});
      if (result['success'] == true) {
        return (result['history'] as List? ?? []).cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static void dispose() {
    _faceDetector.close();
  }
}
