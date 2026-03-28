import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../theme/app_colors.dart';
import '../../services/face_recognition_service.dart';

/// Shows a camera dialog that verifies the user's face.
/// Returns a Map with 'success', 'photoUrl', etc.
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
  static const _maxAttempts = 3;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _camCtrl = CameraController(frontCam, ResolutionPreset.medium, enableAudio: false, imageFormatGroup: ImageFormatGroup.nv21);
      await _camCtrl!.initialize();
      if (mounted) {
        setState(() { _initialized = true; _status = 'انظر للكاميرا للتحقق من وجهك'; _statusColor = C.pri; });
        _startDetection();
      }
    } catch (e) {
      if (mounted) setState(() { _status = 'خطأ في الكاميرا'; _statusColor = C.red; });
    }
  }

  void _startDetection() {
    if (_camCtrl == null || !_camCtrl!.value.isInitialized) return;
    _camCtrl!.startImageStream((image) {
      if (_processing || _verifying) return;
      _processing = true;
      _processFrame(image);
    });
  }

  Future<void> _processFrame(CameraImage image) async {
    try {
      final inputImage = _convertToInputImage(image);
      if (inputImage == null) { _processing = false; return; }

      final faces = await FaceRecognitionService.detectFaces(inputImage);
      if (!mounted) return;

      if (faces.isEmpty) {
        setState(() { _status = 'وجّه الكاميرا لوجهك'; _statusColor = C.orange; });
        _processing = false;
        return;
      }

      if (faces.length > 1) {
        setState(() { _status = 'يجب وجه واحد فقط'; _statusColor = C.red; });
        _processing = false;
        return;
      }

      final face = faces.first;
      final yAngle = (face.headEulerAngleY ?? 0).abs();
      final xAngle = (face.headEulerAngleX ?? 0).abs();
      final leftEye = face.leftEyeOpenProbability ?? 1;
      final rightEye = face.rightEyeOpenProbability ?? 1;
      final bbox = face.boundingBox;

      if (bbox.width < 80 || bbox.height < 80) {
        setState(() { _status = 'قرّب وجهك'; _statusColor = C.orange; });
        _processing = false;
        return;
      }

      if (leftEye < 0.3 || rightEye < 0.3) {
        setState(() { _status = 'افتح عينيك'; _statusColor = C.orange; });
        _processing = false;
        return;
      }

      if (yAngle > 20 || xAngle > 20) {
        setState(() { _status = 'انظر للأمام'; _statusColor = C.orange; });
        _processing = false;
        return;
      }

      // Face is good — verify!
      setState(() { _verifying = true; _status = 'جارٍ التحقق...'; _statusColor = C.pri; });

      // Stop stream and take photo
      try { await _camCtrl?.stopImageStream(); } catch (_) {}

      Uint8List? photoBytes;
      try {
        final xfile = await _camCtrl!.takePicture();
        photoBytes = await xfile.readAsBytes();
      } catch (_) {}

      if (photoBytes == null) {
        setState(() { _status = 'فشل التقاط الصورة'; _statusColor = C.red; _verifying = false; });
        _processing = false;
        // Restart stream
        try { _startDetection(); } catch (_) {}
        return;
      }

      final features = FaceRecognitionService.extractFaceFeatures(face);
      final result = await FaceRecognitionService.verifyFace(uid: widget.uid, currentFeatures: features, photoBytes: photoBytes);

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() { _status = '✓ تم التحقق بنجاح'; _statusColor = C.green; });
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context, result);
      } else {
        _attempts++;
        if (_attempts >= _maxAttempts) {
          setState(() { _status = 'فشل التحقق — تجاوزت الحد المسموح'; _statusColor = C.red; });
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) Navigator.pop(context, {'success': false, 'error': 'فشل التحقق من الوجه بعد $_maxAttempts محاولات'});
        } else {
          setState(() {
            _status = 'الوجه غير مطابق — المحاولة $_attempts من $_maxAttempts';
            _statusColor = C.red;
            _verifying = false;
          });
          // Restart stream for another attempt
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            setState(() { _status = 'انظر للكاميرا مرة أخرى'; _statusColor = C.pri; });
            try { _startDetection(); } catch (_) {}
          }
        }
      }
    } catch (_) {}
    _processing = false;
  }

  InputImage? _convertToInputImage(CameraImage image) {
    try {
      final camera = _camCtrl!.description;
      final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
      if (rotation == null) return null;
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;
      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (_) { return null; }
  }

  @override
  void dispose() {
    _camCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(child: Container(
      width: 340, height: 500,
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.hardEdge,
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            InkWell(onTap: () => Navigator.pop(context, null), child: const Icon(Icons.close, size: 20, color: Colors.white54)),
            const Spacer(),
            Text('التحقق من الوجه', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(width: 8),
            const Icon(Icons.face, size: 20, color: Colors.white70),
          ]),
        ),

        // Camera
        Expanded(child: _initialized && _camCtrl != null
          ? Stack(alignment: Alignment.center, children: [
              CameraPreview(_camCtrl!),
              // Oval guide
              IgnorePointer(child: Container(
                width: 200, height: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: _statusColor.withOpacity(0.8), width: 3),
                ),
              )),
            ])
          : const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
        ),

        // Status
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: _statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
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
