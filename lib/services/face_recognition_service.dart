import 'dart:math';
import 'dart:typed_data';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'api_service.dart';

class FaceRecognitionService {
  static final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: true,
      enableClassification: true,
      enableTracking: false,
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.3,
    ),
  );

  // ═══ Check if user has registered face ═══
  static Future<bool> hasFaceRegistered(String uid) async {
    try {
      final result = await ApiService.get('face.php?action=status&uid=$uid');
      return result['registered'] == true;
    } catch (_) {
      return false;
    }
  }

  // ═══ Check if face auth is required for this user ═══
  static Future<bool> isFaceAuthRequired(String uid) async {
    try {
      final settings = await ApiService.get('admin.php?action=get_settings');
      final settingsData = settings['settings'] ?? settings;
      final globalFace = settingsData['authFace'] ?? false;

      final userResult = await ApiService.get('users.php?action=get&uid=$uid');
      final userData = userResult['user'] ?? userResult;
      final hasOverride = userData['authOverride'] == true;
      if (hasOverride) {
        return userData['authFace'] ?? globalFace;
      }
      return globalFace == true;
    } catch (_) {
      return false;
    }
  }

  // ═══ Detect face from camera image ═══
  static Future<List<Face>> detectFaces(InputImage inputImage) async {
    try {
      return await _faceDetector.processImage(inputImage);
    } catch (e) {
      return [];
    }
  }

  // ═══ Validate face quality for registration ═══
  static Map<String, dynamic> validateFaceForRegistration(Face face) {
    final issues = <String>[];

    final yAngle = face.headEulerAngleY ?? 0;
    final xAngle = face.headEulerAngleX ?? 0;

    if (yAngle.abs() > 25) issues.add('وجّه رأسك للأمام');
    if (xAngle.abs() > 20) issues.add('ارفع/انزل رأسك قليلاً');

    final leftEyeOpen = face.leftEyeOpenProbability ?? 1.0;
    final rightEyeOpen = face.rightEyeOpenProbability ?? 1.0;
    if (leftEyeOpen < 0.5 || rightEyeOpen < 0.5) issues.add('افتح عينيك');

    final bbox = face.boundingBox;
    if (bbox.width < 100 || bbox.height < 100) issues.add('قرّب وجهك من الكاميرا');

    final smile = face.smilingProbability ?? 0;

    return {
      'valid': issues.isEmpty,
      'issues': issues,
      'yAngle': yAngle,
      'xAngle': xAngle,
      'zAngle': face.headEulerAngleZ ?? 0,
      'leftEye': leftEyeOpen,
      'rightEye': rightEyeOpen,
      'smile': smile,
      'faceWidth': bbox.width,
      'faceHeight': bbox.height,
    };
  }

  // ═══ Extract face embedding/landmarks as a simple feature vector ═══
  static List<double> extractFaceFeatures(Face face) {
    final features = <double>[];

    final landmarks = [
      FaceLandmarkType.leftEye,
      FaceLandmarkType.rightEye,
      FaceLandmarkType.noseBase,
      FaceLandmarkType.leftMouth,
      FaceLandmarkType.rightMouth,
      FaceLandmarkType.bottomMouth,
      FaceLandmarkType.leftEar,
      FaceLandmarkType.rightEar,
      FaceLandmarkType.leftCheek,
      FaceLandmarkType.rightCheek,
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

    if (w > 0 && h > 0) {
      features.add(w / h);
    }

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
    final similarity = 1.0 / (1.0 + distance * 5);
    return similarity;
  }

  // ═══ Register face — upload photo + save features via API ═══
  static Future<Map<String, dynamic>> registerFace({
    required String uid,
    required String userName,
    required List<double> faceFeatures,
    required Uint8List photoBytes,
  }) async {
    try {
      // Upload photo via admin upload endpoint
      final uploadResult = await ApiService.uploadFile(
        'admin.php?action=upload',
        photoBytes,
        'registration_$uid.jpg',
      );
      final photoUrl = uploadResult['url'] ?? uploadResult['file_url'] ?? '';

      // Register face via face API
      final result = await ApiService.post('face.php?action=register', body: {
        'features': faceFeatures,
        'photo_url': photoUrl,
      });

      return {'success': true, 'photoUrl': photoUrl, ...result};
    } catch (e) {
      return {'success': false, 'error': 'فشل حفظ بصمة الوجه: $e'};
    }
  }

  // ═══ Verify face against registered features ═══
  static Future<Map<String, dynamic>> verifyFace({
    required String uid,
    required List<double> currentFeatures,
    required Uint8List photoBytes,
  }) async {
    try {
      // Upload verification photo
      final uploadResult = await ApiService.uploadFile(
        'admin.php?action=upload',
        photoBytes,
        'verify_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final photoUrl = uploadResult['url'] ?? uploadResult['file_url'] ?? '';

      // Verify face
      final result = await ApiService.post('face.php?action=verify', body: {
        'features': currentFeatures,
        'photo_url': photoUrl,
      });

      final success = result['matched'] == true || result['success'] == true;
      if (success) {
        return {'success': true, 'similarity': result['similarity'], 'photoUrl': photoUrl};
      } else {
        return {
          'success': false,
          'error': result['error'] ?? 'الوجه غير مطابق — تأكد من الإضاءة وأعد المحاولة',
          'similarity': result['similarity'],
          'photoUrl': photoUrl,
          'needsRegistration': result['needsRegistration'] ?? false,
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'خطأ في التحقق: $e'};
    }
  }

  // ═══ Reset face registration (admin action) ═══
  static Future<void> resetFaceRegistration(String uid) async {
    await ApiService.post('face.php?action=reset', body: {'uid': uid});
  }

  // ═══ Get registration info ═══
  static Future<Map<String, dynamic>?> getFaceRegistrationInfo(String uid) async {
    try {
      final result = await ApiService.get('face.php?action=status&uid=$uid');
      return result;
    } catch (_) {
      return null;
    }
  }

  // ═══ Get verification history for admin ═══
  static Future<List<Map<String, dynamic>>> getVerificationHistory(String uid, {int limit = 20}) async {
    try {
      final result = await ApiService.get('face.php?action=history&uid=$uid&limit=$limit');
      final list = result['history'] ?? result['data'] ?? [];
      return (list as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static void dispose() {
    _faceDetector.close();
  }
}
