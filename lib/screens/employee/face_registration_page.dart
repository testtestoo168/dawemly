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

class FaceRegistrationPage extends StatefulWidget {
  final String uid;
  final String userName;
  final VoidCallback onComplete;
  const FaceRegistrationPage({super.key, required this.uid, required this.userName, required this.onComplete});
  @override
  State<FaceRegistrationPage> createState() => _FaceRegistrationPageState();
}

class _FaceRegistrationPageState extends State<FaceRegistrationPage> {
  CameraController? _camCtrl;
  bool _initialized = false;
  bool _processing = false;
  bool _saving = false;
  String _status = 'جارٍ تشغيل الكاميرا...';
  String _instruction = '';
  Color _statusColor = C.pri;

  // Multi-angle capture steps
  int _currentStep = 0;
  static const _steps = [
    {'label': 'انظر للأمام', 'icon': '😐', 'yMin': -15.0, 'yMax': 15.0, 'xMin': -15.0, 'xMax': 15.0},
    {'label': 'أدر رأسك لليمين', 'icon': '👉', 'yMin': 10.0, 'yMax': 45.0, 'xMin': -20.0, 'xMax': 20.0},
    {'label': 'أدر رأسك لليسار', 'icon': '👈', 'yMin': -45.0, 'yMax': -10.0, 'xMin': -20.0, 'xMax': 20.0},
  ];

  final List<List<double>> _capturedFeatures = [];
  Uint8List? _bestPhoto;
  bool _stepCaptured = false;
  Timer? _captureDelay;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      // Request camera permission before accessing the hardware
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          setState(() => _status = 'يجب السماح باستخدام الكاميرا لتسجيل بصمة الوجه');
          if (status.isPermanentlyDenied) {
            openAppSettings(); // Open system settings so user can enable manually
          }
        }
        return;
      }

      final cameras = await availableCameras();
      final frontCam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _camCtrl = CameraController(frontCam, ResolutionPreset.medium, enableAudio: false, imageFormatGroup: ImageFormatGroup.nv21);
      await _camCtrl!.initialize();
      if (mounted) {
        setState(() {
          _initialized = true;
          _status = _steps[0]['label'] as String;
          _instruction = 'ضع وجهك داخل الإطار في إضاءة جيدة';
        });
        _startDetection();
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'خطأ في تشغيل الكاميرا: $e');
    }
  }

  Timer? _detectTimer;

  void _startDetection() {
    if (_camCtrl == null || !_camCtrl!.value.isInitialized) return;
    // Use periodic takePicture instead of image stream.
    // Image stream has format conversion issues across Android devices (YUV_420_888
    // vs NV21, plane padding, rotation mismatches). takePicture returns a proper
    // JPEG that InputImage.fromFilePath handles correctly on ALL devices.
    _detectTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (_processing || _saving || _stepCaptured || !mounted) return;
      _processing = true;
      _captureAndProcess();
    });
  }

  Future<void> _captureAndProcess() async {
    try {
      if (_camCtrl == null || !_camCtrl!.value.isInitialized) { _processing = false; return; }

      final xfile = await _camCtrl!.takePicture();
      final inputImage = InputImage.fromFilePath(xfile.path);
      final faces = await FaceRecognitionService.detectFaces(inputImage);

      if (!mounted) return;

      if (faces.isEmpty) {
        setState(() { _instruction = 'لم يتم العثور على وجه — وجّه الكاميرا لوجهك'; _statusColor = C.orange; });
        _processing = false;
        return;
      }

      if (faces.length > 1) {
        setState(() { _instruction = 'تم اكتشاف أكثر من وجه — يجب وجه واحد فقط'; _statusColor = C.red; });
        _processing = false;
        return;
      }

      final face = faces.first;
      final step = _steps[_currentStep];
      final yAngle = face.headEulerAngleY ?? 0;
      final xAngle = face.headEulerAngleX ?? 0;

      final yMin = step['yMin'] as double;
      final yMax = step['yMax'] as double;
      final xMin = step['xMin'] as double;
      final xMax = step['xMax'] as double;

      bool angleOk = yAngle >= yMin && yAngle <= yMax && xAngle >= xMin && xAngle <= xMax;

      // Check eyes are open
      final leftEye = face.leftEyeOpenProbability ?? 1;
      final rightEye = face.rightEyeOpenProbability ?? 1;
      final eyesOpen = leftEye > 0.3 && rightEye > 0.3;

      // Check face size
      final bbox = face.boundingBox;
      final faceOk = bbox.width > 60 && bbox.height > 60;

      if (!faceOk) {
        setState(() { _instruction = 'قرّب وجهك من الكاميرا'; _statusColor = C.orange; });
      } else if (!eyesOpen) {
        setState(() { _instruction = 'افتح عينيك'; _statusColor = C.orange; });
      } else if (!angleOk) {
        setState(() { _instruction = step['label'] as String; _statusColor = C.pri; });
      } else {
        // Step passed!
        final features = FaceRecognitionService.extractFaceFeatures(face);
        _capturedFeatures.add(features);

        // Save best photo from first frontal step
        if (_currentStep == 0 && _bestPhoto == null) {
          try { _bestPhoto = await File(xfile.path).readAsBytes(); } catch (_) {}
        }

        setState(() {
          _stepCaptured = true;
          _instruction = '✓ تم التقاط الخطوة ${_currentStep + 1} من ${_steps.length}';
          _statusColor = C.green;
        });

        _captureDelay = Timer(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          if (_currentStep < _steps.length - 1) {
            setState(() {
              _currentStep++;
              _stepCaptured = false;
              _status = _steps[_currentStep]['label'] as String;
              _instruction = _steps[_currentStep]['label'] as String;
              _statusColor = C.pri;
            });
          } else {
            _saveRegistration();
          }
        });
      }
      // Clean up temp file
      try { File(xfile.path).deleteSync(); } catch (_) {}
    } catch (_) {}
    _processing = false;
  }

  Future<void> _saveRegistration() async {
    if (_saving) return;
    setState(() { _saving = true; _instruction = 'جارٍ حفظ بصمة الوجه...'; _statusColor = C.pri; });

    // Stop camera stream
    _detectTimer?.cancel();

    // Take final photo if we don't have one
    if (_bestPhoto == null) {
      try {
        final xfile = await _camCtrl!.takePicture();
        _bestPhoto = await xfile.readAsBytes();
      } catch (_) {}
    }

    if (_bestPhoto == null || _capturedFeatures.isEmpty) {
      if (mounted) setState(() { _instruction = 'فشل التقاط الصورة — أعد المحاولة'; _statusColor = C.red; _saving = false; });
      return;
    }

    // Average all captured features for a robust template
    final avgFeatures = _averageFeatures(_capturedFeatures);

    final result = await FaceRecognitionService.registerFace(
      uid: widget.uid,
      userName: widget.userName,
      faceFeatures: avgFeatures,
      photoBytes: _bestPhoto!,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() { _instruction = '✓ تم تسجيل بصمة الوجه بنجاح!'; _statusColor = C.green; });
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.pop(context);
        widget.onComplete();
      }
    } else {
      setState(() { _instruction = result['error'] ?? 'فشل الحفظ'; _statusColor = C.red; _saving = false; });
    }
  }

  List<double> _averageFeatures(List<List<double>> allFeatures) {
    if (allFeatures.isEmpty) return [];
    final len = allFeatures.first.length;
    final avg = List<double>.filled(len, 0);
    for (final f in allFeatures) {
      for (int i = 0; i < len && i < f.length; i++) {
        avg[i] += f[i];
      }
    }
    for (int i = 0; i < len; i++) avg[i] /= allFeatures.length;
    return avg;
  }

  @override
  void dispose() {
    _detectTimer?.cancel();
    _captureDelay?.cancel();
    _camCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          color: Colors.black,
          child: Row(children: [
            InkWell(onTap: () => Navigator.pop(context), child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.close, size: 18, color: Colors.white),
            )),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('تسجيل بصمة الوجه', style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              Text(widget.userName, style: GoogleFonts.tajawal(fontSize: 13, color: Colors.white60)),
            ]),
            const SizedBox(width: 12),
            Container(width: 40, height: 40, decoration: BoxDecoration(color: C.pri.withOpacity(0.3), borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.face, size: 22, color: Colors.white)),
          ]),
        ),

        // Progress dots
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_steps.length, (i) {
            final done = i < _currentStep || (i == _currentStep && _stepCaptured);
            final active = i == _currentStep;
            return Container(
              width: active ? 28 : 12, height: 12,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: done ? C.green : active ? C.pri : Colors.white24,
                borderRadius: BorderRadius.circular(6),
              ),
              child: done ? const Icon(Icons.check, size: 10, color: Colors.white) : null,
            );
          })),
        ),

        // Camera preview
        Expanded(child: _initialized && _camCtrl != null
          ? Stack(alignment: Alignment.center, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CameraPreview(_camCtrl!),
              ),
              // Face guide oval
              IgnorePointer(child: Container(
                width: 260, height: 340,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(130),
                  border: Border.all(color: _statusColor.withOpacity(0.7), width: 3),
                ),
              )),
              // Step emoji
              Positioned(top: 20, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  _steps[_currentStep]['icon'] as String,
                  style: const TextStyle(fontSize: 32),
                ),
              )),
            ])
          : const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
        ),

        // Status bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          color: Colors.black,
          child: Column(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _statusColor.withOpacity(0.3)),
              ),
              child: Row(children: [
                if (_saving) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                if (!_saving) Icon(_stepCaptured ? Icons.check_circle : Icons.info_outline, size: 18, color: _statusColor),
                const SizedBox(width: 10),
                Expanded(child: Text(_instruction.isNotEmpty ? _instruction : _status,
                  style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                  textAlign: TextAlign.right,
                )),
              ]),
            ),
            const SizedBox(height: 8),
            Text('الخطوة ${_currentStep + 1} من ${_steps.length}', style: GoogleFonts.tajawal(fontSize: 12, color: Colors.white38)),
          ]),
        ),
      ])),
    );
  }
}
