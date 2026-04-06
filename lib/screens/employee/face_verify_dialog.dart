import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../theme/app_colors.dart';
import '../../services/face_recognition_service.dart';

/// Shows a camera dialog that verifies the user's face.
Future<Map<String, dynamic>?> showFaceVerifyDialog(BuildContext context, String uid) async {
  return await showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _FaceVerifyDialog(uid: uid),
  );
}

class _FaceVerifyDialog extends StatefulWidget {
  final String uid;
  const _FaceVerifyDialog({required this.uid});
  @override
  State<_FaceVerifyDialog> createState() => _FaceVerifyDialogState();
}

class _FaceVerifyDialogState extends State<_FaceVerifyDialog> {
  CameraController? _camCtrl;
  bool _initialized = false;
  bool _processing = false;
  bool _verifying = false;
  String _status = 'جارٍ تشغيل الكاميرا...';
  Color _statusColor = C.pri;
  int _attempts = 0;
  static const _maxAttempts = 5; // more attempts

  // Skip blink — go straight to face verify for SPEED
  bool _blinkDetected = true;
  bool _waitingForBlink = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      // Request camera permission before accessing the hardware
      final perm = await Permission.camera.request();
      if (!perm.isGranted) {
        if (mounted) {
          setState(() { _status = 'يجب السماح باستخدام الكاميرا'; _statusColor = C.red; });
          if (perm.isPermanentlyDenied) openAppSettings();
        }
        return;
      }

      final cameras = await availableCameras();
      final frontCam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      // LOW resolution = faster capture + faster ML Kit processing for verification
      _camCtrl = CameraController(frontCam, ResolutionPreset.low, enableAudio: false, imageFormatGroup: ImageFormatGroup.nv21);
      await _camCtrl!.initialize();
      if (mounted) {
        setState(() { _initialized = true; _status = 'انظر للكاميرا'; _statusColor = C.pri; });
        _startDetection();
      }
    } catch (e) {
      if (mounted) setState(() { _status = 'خطأ في الكاميرا'; _statusColor = C.red; });
    }
  }

  Timer? _detectTimer;

  void _startDetection() {
    if (_camCtrl == null || !_camCtrl!.value.isInitialized) return;
    // Use periodic takePicture instead of image stream — works on ALL devices.
    _detectTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (_processing || _verifying || !mounted) return;
      _processing = true;
      _captureAndProcess();
    });
  }

  Future<void> _captureAndProcess() async {
    try {
      if (_camCtrl == null || !_camCtrl!.value.isInitialized) { _processing = false; return; }

      final xfile = await _camCtrl!.takePicture();
      final filePath = xfile.path;
      final inputImage = InputImage.fromFilePath(filePath);
      final faces = await FaceRecognitionService.detectFaces(inputImage);

      if (!mounted) return;

      if (faces.isEmpty) {
        setState(() { _status = 'وجّه الكاميرا لوجهك'; _statusColor = C.orange; });
        _processing = false;
        try { File(filePath).deleteSync(); } catch (_) {}
        return;
      }

      if (faces.length > 1) {
        setState(() { _status = 'يجب وجه واحد فقط'; _statusColor = C.red; });
        _processing = false;
        try { File(filePath).deleteSync(); } catch (_) {}
        return;
      }

      final face = faces.first;
      final yAngle = (face.headEulerAngleY ?? 0).abs();
      final xAngle = (face.headEulerAngleX ?? 0).abs();
      final bbox = face.boundingBox;

      if (bbox.width < 50 || bbox.height < 50) {
        setState(() { _status = 'قرّب وجهك'; _statusColor = C.orange; });
        _processing = false;
        try { File(filePath).deleteSync(); } catch (_) {}
        return;
      }

      if (yAngle > 35 || xAngle > 35) {
        setState(() { _status = 'انظر للأمام'; _statusColor = C.orange; });
        _processing = false;
        try { File(filePath).deleteSync(); } catch (_) {}
        return;
      }

      // Face is good — verify!
      _detectTimer?.cancel();
      setState(() { _verifying = true; _status = 'جارٍ التحقق...'; _statusColor = C.pri; });

      final photoBytes = await File(filePath).readAsBytes();
      try { File(filePath).deleteSync(); } catch (_) {}

      final features = FaceRecognitionService.extractFaceFeatures(face);
      final result = await FaceRecognitionService.verifyFace(uid: widget.uid, currentFeatures: features, photoBytes: photoBytes);

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() { _status = '✓ تم التحقق'; _statusColor = C.green; });
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) Navigator.pop(context, result);
      } else {
        _attempts++;
        if (_attempts >= _maxAttempts) {
          setState(() { _status = 'فشل التحقق'; _statusColor = C.red; });
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) Navigator.pop(context, {'success': false, 'error': 'فشل التحقق من الوجه'});
        } else {
          setState(() {
            _status = 'حاول تاني — $_attempts/$_maxAttempts';
            _statusColor = C.orange;
            _verifying = false;
          });
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) _startDetection();
        }
      }
    } catch (_) {}
    _processing = false;
  }

  @override
  void dispose() {
    _detectTimer?.cancel();
    _camCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Center(child: Container(
      width: screenWidth < 360 ? screenWidth - 40 : 340, height: 480,
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.hardEdge,
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            InkWell(onTap: () => Navigator.pop(context, null), child: const Icon(Icons.close, size: 20, color: Colors.white54)),
            const Spacer(),
            Text('التحقق من الوجه', style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(width: 8),
            const Icon(Icons.face, size: 18, color: Colors.white70),
          ]),
        ),

        // Camera
        Expanded(child: _initialized && _camCtrl != null
          ? Stack(alignment: Alignment.center, children: [
              CameraPreview(_camCtrl!),
              IgnorePointer(child: Container(
                width: 180, height: 240,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(90),
                  border: Border.all(color: _statusColor.withValues(alpha: 0.8), width: 3),
                ),
              )),
            ])
          : const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
        ),

        // Status
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: Row(children: [
              if (_verifying) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              else Icon(_statusColor == C.green ? Icons.check_circle : Icons.info_outline, size: 16, color: _statusColor),
              const SizedBox(width: 8),
              Expanded(child: Text(_status, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white), textAlign: TextAlign.right)),
            ]),
          ),
        ),
      ]),
    ));
  }
}
