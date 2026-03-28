import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FaceRecognitionService {
  static final _db = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

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
      final doc = await _db.collection('face_data').doc(uid).get();
      return doc.exists && (doc.data()?['registered'] == true);
    } catch (_) {
      return false;
    }
  }

  // ═══ Check if face auth is required for this user ═══
  static Future<bool> isFaceAuthRequired(String uid) async {
    try {
      // Check global settings
      final settings = await _db.collection('settings').doc('general').get();
      final globalFace = settings.data()?['authFace'] ?? false;

      // Check per-employee override
      final userDoc = await _db.collection('users').doc(uid).get();
      final hasOverride = userDoc.data()?['authOverride'] == true;
      if (hasOverride) {
        return userDoc.data()?['authFace'] ?? globalFace;
      }
      return globalFace;
    } catch (_) {
      return false;
    }
  }

  // ═══ Detect face from camera image (InputImage) ═══
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

    // Check face angle - must be relatively frontal
    final yAngle = face.headEulerAngleY ?? 0;
    final xAngle = face.headEulerAngleX ?? 0;
    final zAngle = face.headEulerAngleZ ?? 0;

    if (yAngle.abs() > 25) issues.add('وجّه رأسك للأمام');
    if (xAngle.abs() > 20) issues.add('ارفع/انزل رأسك قليلاً');

    // Check eyes open
    final leftEyeOpen = face.leftEyeOpenProbability ?? 1.0;
    final rightEyeOpen = face.rightEyeOpenProbability ?? 1.0;
    if (leftEyeOpen < 0.5 || rightEyeOpen < 0.5) issues.add('افتح عينيك');

    // Check face size (should be reasonably large in frame)
    final bbox = face.boundingBox;
    if (bbox.width < 100 || bbox.height < 100) issues.add('قرّب وجهك من الكاميرا');

    // Check smile probability (just informational)
    final smile = face.smilingProbability ?? 0;

    return {
      'valid': issues.isEmpty,
      'issues': issues,
      'yAngle': yAngle,
      'xAngle': xAngle,
      'zAngle': zAngle,
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

    // Use landmark positions as features
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

    // Normalize relative to bounding box
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

    // Add ratios
    if (w > 0 && h > 0) {
      features.add(w / h); // face aspect ratio
    }

    // Add contour-based features if available
    final noseContour = face.contours[FaceContourType.noseBridge];
    if (noseContour != null && noseContour.points.length >= 2) {
      final noseLen = (noseContour.points.last.y - noseContour.points.first.y).abs();
      features.add(noseLen / h);
    }

    // Add classification features
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
    // Convert distance to similarity score (0-1)
    final similarity = 1.0 / (1.0 + distance * 5);
    return similarity;
  }

  // ═══ Register face - save features + photo to Firebase ═══
  static Future<Map<String, dynamic>> registerFace({
    required String uid,
    required String userName,
    required List<double> faceFeatures,
    required Uint8List photoBytes,
  }) async {
    try {
      // Upload photo to Firebase Storage
      final photoRef = _storage.ref('face_registrations/$uid/registration.jpg');
      await photoRef.putData(photoBytes, SettableMetadata(contentType: 'image/jpeg'));
      final photoUrl = await photoRef.getDownloadURL();

      // Save face data to Firestore
      await _db.collection('face_data').doc(uid).set({
        'uid': uid,
        'userName': userName,
        'registered': true,
        'features': faceFeatures,
        'photoUrl': photoUrl,
        'registeredAt': FieldValue.serverTimestamp(),
        'featureCount': faceFeatures.length,
      });

      // Also save photo URL to user document for easy access
      await _db.collection('users').doc(uid).update({
        'facePhotoUrl': photoUrl,
        'faceRegistered': true,
      }).catchError((_) {});

      return {'success': true, 'photoUrl': photoUrl};
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
      final doc = await _db.collection('face_data').doc(uid).get();
      if (!doc.exists || doc.data()?['registered'] != true) {
        return {'success': false, 'error': 'لم يتم تسجيل بصمة الوجه بعد', 'needsRegistration': true};
      }

      final registeredFeatures = (doc.data()?['features'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];
      if (registeredFeatures.isEmpty) {
        return {'success': false, 'error': 'بيانات الوجه تالفة — أعد التسجيل', 'needsRegistration': true};
      }

      final similarity = compareFaces(registeredFeatures, currentFeatures);
      final threshold = 0.65; // Adjustable threshold
      final matched = similarity >= threshold;

      // Upload verification photo regardless of match
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final photoRef = _storage.ref('face_verifications/$uid/$timestamp.jpg');
      await photoRef.putData(photoBytes, SettableMetadata(contentType: 'image/jpeg'));
      final photoUrl = await photoRef.getDownloadURL();

      // Log the verification attempt
      await _db.collection('face_verifications').add({
        'uid': uid,
        'photoUrl': photoUrl,
        'similarity': similarity,
        'matched': matched,
        'threshold': threshold,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (matched) {
        return {'success': true, 'similarity': similarity, 'photoUrl': photoUrl};
      } else {
        return {
          'success': false,
          'error': 'الوجه غير مطابق — تأكد من الإضاءة وأعد المحاولة',
          'similarity': similarity,
          'photoUrl': photoUrl,
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'خطأ في التحقق: $e'};
    }
  }

  // ═══ Reset face registration (admin action) ═══
  static Future<void> resetFaceRegistration(String uid) async {
    await _db.collection('face_data').doc(uid).delete();
    // Clear from user doc
    await _db.collection('users').doc(uid).update({
      'facePhotoUrl': FieldValue.delete(),
      'faceRegistered': false,
    }).catchError((_) {});
    // Delete photos from storage
    try {
      await _storage.ref('face_registrations/$uid/registration.jpg').delete();
    } catch (_) {}
  }

  // ═══ Get registration info ═══
  static Future<Map<String, dynamic>?> getFaceRegistrationInfo(String uid) async {
    try {
      final doc = await _db.collection('face_data').doc(uid).get();
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  // ═══ Get verification history for admin ═══
  static Future<List<Map<String, dynamic>>> getVerificationHistory(String uid, {int limit = 20}) async {
    try {
      final snap = await _db.collection('face_verifications')
          .where('uid', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((d) {
        final data = d.data();
        data['_id'] = d.id;
        return data;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static void dispose() {
    _faceDetector.close();
  }
}
