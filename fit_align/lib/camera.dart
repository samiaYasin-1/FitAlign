import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_image_compress/flutter_image_compress.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  // ==================== CAMERA & ML ====================
  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  bool _isInitializing = true;
  bool _isProcessing = false;
  bool _isDisposed = false;
  bool _isFrontCamera = true;

  // ==================== EXERCISE STATE ====================
  String _selectedExercise = "Bicep Curls";
  int _repCount = 0;
  int _targetReps = 10;
  String _repState = "up";
  double _currentAngle = 0;
  bool _exerciseComplete = false;

  // ==================== POSITION STATE ====================
  String _guidance = "Stand in front of camera";
  String _status = "Position yourself";
  Color _statusColor = Colors.orange;
  bool _isCorrectPosition = false;
  int _holdCount = 0;
  static const int _holdRequired = 20;

  // ==================== TUTORIAL STATE ====================
  bool _showTutorial = true;
  int _tutorialStep = 0;
  final List<Map<String, dynamic>> _tutorialSteps = [
    {
      'icon': Icons.camera_alt,
      'title': 'Welcome to PostureGuard!',
      'description': 'This app helps you exercise with proper form using AI pose detection.',
      'color': Colors.blue,
    },
    {
      'icon': Icons.person,
      'title': 'Step 1: Stand in Front',
      'description': 'Stand facing the camera with your full body visible in the frame.',
      'color': Colors.orange,
    },
    {
      'icon': Icons.center_focus_strong,
      'title': 'Step 2: Center Yourself',
      'description': 'Follow the on-screen guidance to position yourself correctly.',
      'color': Colors.orange,
    },
    {
      'icon': Icons.fitness_center,
      'title': 'Step 3: Start Exercising',
      'description': 'Once positioned, follow the exercise instructions and watch your reps count!',
      'color': Colors.green,
    },
  ];

  // ==================== EXERCISE CONFIG ====================
  final List<Map<String, dynamic>> _exercises = [
    {
      'name': 'Bicep Curls',
      'icon': Icons.fitness_center,
      'upAngle': 150,
      'downAngle': 50,
      'targetReps': 10,
      'instruction': 'Curl your arm up and down',
      'emoji': '💪',
    },
    {
      'name': 'Squats',
      'icon': Icons.accessibility_new,
      'upAngle': 160,
      'downAngle': 100,
      'targetReps': 12,
      'instruction': 'Squat down and stand up',
      'emoji': '🏋️',
    },
    {
      'name': 'Push-ups',
      'icon': Icons.sports_gymnastics,
      'upAngle': 160,
      'downAngle': 90,
      'targetReps': 8,
      'instruction': 'Push up and lower down',
      'emoji': '💪',
    },
    {
      'name': 'Shoulder Press',
      'icon': Icons.arrow_upward,
      'upAngle': 170,
      'downAngle': 100,
      'targetReps': 10,
      'instruction': 'Press up and lower down',
      'emoji': '🏋️',
    },
    {
      'name': 'Lunges',
      'icon': Icons.directions_walk,
      'upAngle': 170,
      'downAngle': 90,
      'targetReps': 10,
      'instruction': 'Lunge forward and back',
      'emoji': '🚶',
    },
    {
      'name': 'Tricep Extensions',
      'icon': Icons.arrow_downward,
      'upAngle': 170,
      'downAngle': 100,
      'targetReps': 10,
      'instruction': 'Extend up and lower',
      'emoji': '💪',
    },
    {
      'name': 'Calf Raises',
      'icon': Icons.vertical_align_top,
      'upAngle': 160,
      'downAngle': 130,
      'targetReps': 15,
      'instruction': 'Rise up on toes and down',
      'emoji': '🦵',
    },
    {
      'name': 'Glute Bridges',
      'icon': Icons.vertical_align_center,
      'upAngle': 160,
      'downAngle': 110,
      'targetReps': 12,
      'instruction': 'Bridge up and down',
      'emoji': '🔄',
    },
  ];

  // ==================== UI STATE ====================
  String _error = "";
  List<CameraDescription>? _cameras;
  CameraDescription? _frontCamera;
  CameraDescription? _backCamera;
  bool _showExerciseSelector = false;

  // ==================== PERFORMANCE ====================
  Timer? _frameTimer;
  CameraImage? _latestImage;
  static const int _processIntervalMs = 150;

  // ==================== POSE DATA ====================
  Pose? _currentPose;
  bool _poseVisible = false;

  // ==================== LIFECYCLE ====================
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initialize();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _restartCamera();
    else if (state == AppLifecycleState.paused) _pauseCamera();
  }

  Map<String, dynamic> get _config => _exercises.firstWhere(
    (e) => e['name'] == _selectedExercise,
    orElse: () => _exercises[0],
  );

  // ==================== INITIALIZATION ====================
  Future<void> _initialize() async {
    try {
      final status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        setState(() { 
          _error = "Camera permission required"; 
          _isInitializing = false; 
        });
        return;
      }

      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;

      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() { 
          _error = "No camera found"; 
          _isInitializing = false; 
        });
        return;
      }

      _frontCamera = _cameras!.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _backCamera = _cameras!.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      await _initCamera(_frontCamera!);
      
    } catch (e) {
      setState(() { 
        _error = "Failed to initialize: $e"; 
        _isInitializing = false; 
      });
    }
  }

  Future<void> _initCamera(CameraDescription camera) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid 
          ? ImageFormatGroup.yuv420 
          : ImageFormatGroup.bgra8888,
    );

    await _cameraController!.initialize();
    
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.accurate,
      ),
    );

    await _cameraController!.startImageStream(_processCameraImage);

    _frameTimer?.cancel();
    _frameTimer = Timer.periodic(
      Duration(milliseconds: _processIntervalMs),
      (timer) {
        if (!mounted || _isDisposed) {
          timer.cancel();
          return;
        }
        if (_latestImage != null && !_isProcessing) {
          _processImage(_latestImage!);
        }
      },
    );

    setState(() {
      _isInitializing = false;
      _targetReps = _config['targetReps'] as int;
      _guidance = "Stand in front of camera";
      _status = "Position yourself";
      _statusColor = Colors.orange;
      _poseVisible = false;
    });
  }

  // ==================== IMAGE PROCESSING ====================
  void _processCameraImage(CameraImage image) {
    if (_isDisposed) return;
    _latestImage = image;
  }

  Future<void> _processImage(CameraImage image) async {
    if (_poseDetector == null || _cameraController == null || _isDisposed || _isProcessing) return;
    if (_exerciseComplete) return;
    
    _isProcessing = true;
    
    try {
      final inputImage = await _convertCameraImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final poses = await _poseDetector!.processImage(inputImage);
      
      if (poses.isNotEmpty && mounted && !_isDisposed) {
        _currentPose = poses.first;
        _poseVisible = true;
        _checkPositionAndExercise(_currentPose!);
        setState(() {});
      } else {
        setState(() {
          _poseVisible = false;
          _guidance = "Move into frame";
          _status = "No person detected";
          _statusColor = Colors.red;
          _isCorrectPosition = false;
          _holdCount = 0;
        });
      }
      
    } catch (e) {
      debugPrint('Processing Error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  // ==================== POSITION & EXERCISE LOGIC ====================
  void _checkPositionAndExercise(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    
    if (leftShoulder == null || rightShoulder == null || leftHip == null || rightHip == null) {
      setState(() {
        _guidance = "Stand in front of camera";
        _status = "Can't detect body";
        _statusColor = Colors.red;
        _isCorrectPosition = false;
        _holdCount = 0;
      });
      return;
    }
    
    // Position checks - using normalized coordinates (0-1)
    final shoulderWidth = (rightShoulder.x - leftShoulder.x).abs();
    final bodyCenterX = (leftShoulder.x + rightShoulder.x) / 2;
    final isCentered = (bodyCenterX - 0.5).abs() < 0.15;
    final isGoodDistance = shoulderWidth > 0.2 && shoulderWidth < 0.6;
    final isUpright = (leftShoulder.y - leftHip.y).abs() > 0.1;
    
    if (!isGoodDistance) {
      setState(() {
        _guidance = shoulderWidth < 0.2 ? "Step Closer" : "Step Back";
        _status = "Adjust distance";
        _statusColor = Colors.orange;
        _isCorrectPosition = false;
        _holdCount = 0;
      });
      return;
    }
    
    if (!isCentered) {
      setState(() {
        _guidance = bodyCenterX < 0.5 ? "Move Right ➡️" : "Move Left ⬅️";
        _status = "Center yourself";
        _statusColor = Colors.orange;
        _isCorrectPosition = false;
        _holdCount = 0;
      });
      return;
    }
    
    if (!isUpright) {
      setState(() {
        _guidance = "Stand Upright";
        _status = "Straighten up";
        _statusColor = Colors.orange;
        _isCorrectPosition = false;
        _holdCount = 0;
      });
      return;
    }
    
    // Good position - hold
    setState(() {
      _holdCount++;
    });
    
    if (_holdCount < _holdRequired) {
      setState(() {
        _guidance = "Hold Position";
        _status = "${(_holdCount / _holdRequired * 100).toInt()}%";
        _statusColor = Colors.green;
        _isCorrectPosition = false;
      });
      return;
    }
    
    // Position held - start exercise
    if (!_isCorrectPosition) {
      setState(() {
        _isCorrectPosition = true;
        _guidance = "Start!";
        _status = "Exercise";
        _statusColor = Colors.green;
        _holdCount = _holdRequired; // Keep it at max
      });
    }
    
    _evaluateExercise(pose);
  }

  void _evaluateExercise(Pose pose) {
    final String name = _selectedExercise;
    
    if (name == "Bicep Curls") {
      _evaluateBicepCurl(pose);
    } else if (name == "Squats") {
      _evaluateSquats(pose);
    } else if (name == "Push-ups") {
      _evaluatePushups(pose);
    } else if (name == "Shoulder Press") {
      _evaluateShoulderPress(pose);
    } else if (name == "Lunges") {
      _evaluateLunges(pose);
    } else if (name == "Tricep Extensions") {
      _evaluateTricepExtensions(pose);
    } else if (name == "Calf Raises") {
      _evaluateCalfRaises(pose);
    } else if (name == "Glute Bridges") {
      _evaluateGluteBridges(pose);
    }
  }

  // ==================== EXERCISE EVALUATIONS ====================
  void _evaluateBicepCurl(Pose pose) {
    final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final elbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final wrist = pose.landmarks[PoseLandmarkType.leftWrist];
    
    if (shoulder != null && elbow != null && wrist != null) {
      _currentAngle = _calculateAngle(shoulder, elbow, wrist);
      final upAngle = _config['upAngle'] as double;
      final downAngle = _config['downAngle'] as double;
      
      setState(() {
        if (_currentAngle > upAngle && _repState != "down") {
          _repState = "down";
          _guidance = "⬆️ Curl Up";
          _statusColor = Colors.orange;
        }
        if (_currentAngle < downAngle && _repState == "down") {
          _repState = "up";
          _repCount++;
          _guidance = "✅ $_repCount/$_targetReps";
          _statusColor = Colors.green;
          // Haptic feedback
          HapticFeedback.lightImpact();
        }
        _checkCompletion();
      });
    }
  }

  void _evaluateSquats(Pose pose) {
    final hip = pose.landmarks[PoseLandmarkType.leftHip];
    final knee = pose.landmarks[PoseLandmarkType.leftKnee];
    final ankle = pose.landmarks[PoseLandmarkType.leftAnkle];
    
    if (hip != null && knee != null && ankle != null) {
      _currentAngle = _calculateAngle(hip, knee, ankle);
      final upAngle = _config['upAngle'] as double;
      final downAngle = _config['downAngle'] as double;
      
      setState(() {
        if (_currentAngle > upAngle && _repState != "up") {
          _repState = "up";
          _guidance = "⬇️ Squat Down";
          _statusColor = Colors.orange;
        }
        if (_currentAngle < downAngle && _repState == "up") {
          _repState = "down";
          _repCount++;
          _guidance = "✅ $_repCount/$_targetReps";
          _statusColor = Colors.green;
          HapticFeedback.lightImpact();
        }
        _checkCompletion();
      });
    }
  }

  void _evaluatePushups(Pose pose) {
    final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final elbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final wrist = pose.landmarks[PoseLandmarkType.leftWrist];
    
    if (shoulder != null && elbow != null && wrist != null) {
      _currentAngle = _calculateAngle(shoulder, elbow, wrist);
      final upAngle = _config['upAngle'] as double;
      final downAngle = _config['downAngle'] as double;
      
      setState(() {
        if (_currentAngle > upAngle && _repState != "up") {
          _repState = "up";
          _guidance = "⬇️ Push Up";
          _statusColor = Colors.orange;
        }
        if (_currentAngle < downAngle && _repState == "up") {
          _repState = "down";
          _repCount++;
          _guidance = "✅ $_repCount/$_targetReps";
          _statusColor = Colors.green;
          HapticFeedback.lightImpact();
        }
        _checkCompletion();
      });
    }
  }

  void _evaluateShoulderPress(Pose pose) {
    final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final elbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final wrist = pose.landmarks[PoseLandmarkType.leftWrist];
    
    if (shoulder != null && elbow != null && wrist != null) {
      _currentAngle = _calculateAngle(shoulder, elbow, wrist);
      final upAngle = _config['upAngle'] as double;
      final downAngle = _config['downAngle'] as double;
      
      setState(() {
        if (_currentAngle < downAngle && _repState != "up") {
          _repState = "up";
          _guidance = "⬆️ Press Up";
          _statusColor = Colors.orange;
        }
        if (_currentAngle > upAngle && _repState == "up") {
          _repState = "down";
          _repCount++;
          _guidance = "✅ $_repCount/$_targetReps";
          _statusColor = Colors.green;
          HapticFeedback.lightImpact();
        }
        _checkCompletion();
      });
    }
  }

  void _evaluateLunges(Pose pose) {
    final hip = pose.landmarks[PoseLandmarkType.leftHip];
    final knee = pose.landmarks[PoseLandmarkType.leftKnee];
    final ankle = pose.landmarks[PoseLandmarkType.leftAnkle];
    
    if (hip != null && knee != null && ankle != null) {
      _currentAngle = _calculateAngle(hip, knee, ankle);
      final upAngle = _config['upAngle'] as double;
      final downAngle = _config['downAngle'] as double;
      
      setState(() {
        if (_currentAngle > upAngle && _repState != "up") {
          _repState = "up";
          _guidance = "⬇️ Lunge Down";
          _statusColor = Colors.orange;
        }
        if (_currentAngle < downAngle && _repState == "up") {
          _repState = "down";
          _repCount++;
          _guidance = "✅ $_repCount/$_targetReps";
          _statusColor = Colors.green;
          HapticFeedback.lightImpact();
        }
        _checkCompletion();
      });
    }
  }

  void _evaluateTricepExtensions(Pose pose) {
    final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final elbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final wrist = pose.landmarks[PoseLandmarkType.leftWrist];
    
    if (shoulder != null && elbow != null && wrist != null) {
      _currentAngle = _calculateAngle(shoulder, elbow, wrist);
      final upAngle = _config['upAngle'] as double;
      final downAngle = _config['downAngle'] as double;
      
      setState(() {
        if (_currentAngle < downAngle && _repState != "up") {
          _repState = "up";
          _guidance = "⬆️ Extend Up";
          _statusColor = Colors.orange;
        }
        if (_currentAngle > upAngle && _repState == "up") {
          _repState = "down";
          _repCount++;
          _guidance = "✅ $_repCount/$_targetReps";
          _statusColor = Colors.green;
          HapticFeedback.lightImpact();
        }
        _checkCompletion();
      });
    }
  }

  void _evaluateCalfRaises(Pose pose) {
    final ankle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final knee = pose.landmarks[PoseLandmarkType.leftKnee];
    final hip = pose.landmarks[PoseLandmarkType.leftHip];
    
    if (ankle != null && knee != null && hip != null) {
      _currentAngle = _calculateAngle(ankle, knee, hip);
      final upAngle = _config['upAngle'] as double;
      final downAngle = _config['downAngle'] as double;
      
      setState(() {
        if (_currentAngle > upAngle && _repState != "up") {
          _repState = "up";
          _guidance = "⬆️ Rise Up";
          _statusColor = Colors.orange;
        }
        if (_currentAngle < downAngle && _repState == "up") {
          _repState = "down";
          _repCount++;
          _guidance = "✅ $_repCount/$_targetReps";
          _statusColor = Colors.green;
          HapticFeedback.lightImpact();
        }
        _checkCompletion();
      });
    }
  }

  void _evaluateGluteBridges(Pose pose) {
    final hip = pose.landmarks[PoseLandmarkType.leftHip];
    final knee = pose.landmarks[PoseLandmarkType.leftKnee];
    final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    
    if (hip != null && knee != null && shoulder != null) {
      _currentAngle = _calculateAngle(shoulder, hip, knee);
      final upAngle = _config['upAngle'] as double;
      final downAngle = _config['downAngle'] as double;
      
      setState(() {
        if (_currentAngle > upAngle && _repState != "up") {
          _repState = "up";
          _guidance = "⬆️ Bridge Up";
          _statusColor = Colors.orange;
        }
        if (_currentAngle < downAngle && _repState == "up") {
          _repState = "down";
          _repCount++;
          _guidance = "✅ $_repCount/$_targetReps";
          _statusColor = Colors.green;
          HapticFeedback.lightImpact();
        }
        _checkCompletion();
      });
    }
  }

  void _checkCompletion() {
    if (_repCount >= _targetReps) {
      _exerciseComplete = true;
      _guidance = "🎉 Complete!";
      _status = "Done";
      _statusColor = Colors.green;
    }
  }

  // ==================== UTILITY FUNCTIONS ====================
  double _calculateAngle(PoseLandmark first, PoseLandmark mid, PoseLandmark last) {
    final radians = math.atan2(last.y - mid.y, last.x - mid.x) -
                    math.atan2(first.y - mid.y, first.x - mid.x);
    double angle = (radians * 180.0 / math.pi).abs();
    if (angle > 180.0) angle = 360.0 - angle;
    return angle;
  }

  // ==================== IMAGE CONVERSION ====================
  Future<InputImage?> _convertCameraImage(CameraImage image) async {
    if (_cameraController == null) return null;
    try {
      final rotation = InputImageRotationValue.fromRawValue(
        _cameraController!.description.sensorOrientation
      );
      if (rotation == null || image.planes.isEmpty) return null;

      img.Image? convertedImage;
      if (Platform.isAndroid) {
        convertedImage = _convertYUV420ToImage(image);
      } else {
        convertedImage = _convertBGRAToImage(image);
      }
      if (convertedImage == null) return null;

      final compressedBytes = await _compressImage(convertedImage);
      if (compressedBytes == null) return null;

      return InputImage.fromBytes(
        bytes: compressedBytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  img.Image? _convertYUV420ToImage(CameraImage image) {
    try {
      final yPlane = image.planes[0];
      final uvPlane = image.planes[1];
      final yBytes = yPlane.bytes;
      final uvBytes = uvPlane.bytes;
      final width = image.width;
      final height = image.height;
      final img.Image rgbaImage = img.Image(width: width, height: height);
      
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final yIndex = y * yPlane.bytesPerRow + x;
          final uvIndex = (y ~/ 2) * uvPlane.bytesPerRow + (x ~/ 2) * 2;
          if (yIndex >= yBytes.length || uvIndex + 1 >= uvBytes.length) continue;
          final yValue = yBytes[yIndex] & 0xFF;
          final uValue = uvBytes[uvIndex] & 0xFF;
          final vValue = uvBytes[uvIndex + 1] & 0xFF;
          int r = (yValue + 1.402 * (vValue - 128)).toInt();
          int g = (yValue - 0.344 * (uValue - 128) - 0.714 * (vValue - 128)).toInt();
          int b = (yValue + 1.772 * (uValue - 128)).toInt();
          r = r.clamp(0, 255); 
          g = g.clamp(0, 255); 
          b = b.clamp(0, 255);
          rgbaImage.setPixelRgb(x, y, r, g, b);
        }
      }
      return rgbaImage;
    } catch (e) {
      return null;
    }
  }

  img.Image? _convertBGRAToImage(CameraImage image) {
    try {
      final bytes = image.planes[0].bytes;
      final width = image.width;
      final height = image.height;
      final img.Image rgbaImage = img.Image(width: width, height: height);
      for (int i = 0; i < bytes.length - 3; i += 4) {
        final int b = bytes[i] & 0xFF;
        final int g = bytes[i + 1] & 0xFF;
        final int r = bytes[i + 2] & 0xFF;
        final int a = bytes[i + 3] & 0xFF;
        final int x = (i ~/ 4) % width;
        final int y = (i ~/ 4) ~/ width;
        if (x < width && y < height) {
          rgbaImage.setPixelRgba(x, y, r, g, b, a);
        }
      }
      return rgbaImage;
    } catch (e) {
      return null;
    }
  }

  Future<Uint8List?> _compressImage(img.Image image) async {
    try {
      final resized = img.copyResize(
        image,
        width: image.width ~/ 2,
        height: image.height ~/ 2,
      );
      final jpgBytes = img.encodeJpg(resized, quality: 70);
      try {
        final compressed = await FlutterImageCompress.compressWithList(
          jpgBytes,
          minHeight: 300,
          minWidth: 300,
          quality: 70,
        );
        return compressed ?? jpgBytes;
      } catch (_) {
        return jpgBytes;
      }
    } catch (e) {
      return null;
    }
  }

  // ==================== CAMERA CONTROL ====================
  void _restartCamera() async {
    if (_cameraController != null && !_cameraController!.value.isInitialized) {
      try {
        await _cameraController!.initialize();
        await _cameraController!.startImageStream(_processCameraImage);
      } catch (e) {}
    }
  }

  void _pauseCamera() {
    _cameraController?.stopImageStream();
  }

  // ==================== SWITCH CAMERA ====================
  Future<void> _switchCamera() async {
    if (_isDisposed) return;
    
    setState(() {
      _isInitializing = true;
    });

    try {
      final camera = _isFrontCamera ? _backCamera : _frontCamera;
      if (camera != null) {
        _isFrontCamera = !_isFrontCamera;
        await _initCamera(camera);
      }
    } catch (e) {
      debugPrint('Camera switch error: $e');
      setState(() {
        _isInitializing = false;
      });
    }
  }

  // ==================== RESET ====================
  void _reset() {
    setState(() {
      _repCount = 0;
      _repState = "up";
      _guidance = "Stand in front of camera";
      _status = "Position yourself";
      _statusColor = Colors.orange;
      _isCorrectPosition = false;
      _holdCount = 0;
      _exerciseComplete = false;
      _currentAngle = 0;
      _poseVisible = false;
    });
  }

  void _changeExercise(String exercise) {
    setState(() {
      _selectedExercise = exercise;
      _targetReps = _exercises.firstWhere((e) => e['name'] == exercise)['targetReps'] as int;
      _reset();
      _showExerciseSelector = false;
    });
  }

  // ==================== DISPOSE ====================
  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _frameTimer?.cancel();
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _poseDetector?.close();
    super.dispose();
  }

  // ==================== BUILD UI ====================
  @override
  Widget build(BuildContext context) {
    if (_error.isNotEmpty) return _buildErrorScreen();
    if (_isInitializing) return _buildLoadingScreen();
    return _buildMainScreen();
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 20),
              Text(_error, style: const TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () { 
                  setState(() { _error = ""; _isInitializing = true; }); 
                  _initialize(); 
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFFF),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: const Text("Retry", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF00BFFF)),
            SizedBox(height: 20),
            Text("Initializing Camera...", style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildMainScreen() {
    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 400;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ==================== CAMERA PREVIEW ====================
          if (_cameraController != null && _cameraController!.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _cameraController!.value.aspectRatio,
                child: CameraPreview(_cameraController!),
              ),
            ),

          // ==================== POSE SKELETON ====================
          if (_currentPose != null && _poseVisible && _cameraController != null)
            CustomPaint(
              size: size,
              painter: PoseSkeletonPainter(
                pose: _currentPose!,
                isValid: _isCorrectPosition,
                color: _statusColor,
                isFrontCamera: _isFrontCamera,
              ),
            ),

          // ==================== TUTORIAL OVERLAY ====================
          if (_showTutorial)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.85),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Step indicator dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _tutorialSteps.length,
                            (index) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: index == _tutorialStep 
                                    ? const Color(0xFF00BFFF) 
                                    : Colors.white.withOpacity(0.3),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Icon
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: (_tutorialSteps[_tutorialStep]['color'] as Color).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _tutorialSteps[_tutorialStep]['icon'] as IconData,
                            color: _tutorialSteps[_tutorialStep]['color'] as Color,
                            size: 50,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Title
                        Text(
                          _tutorialSteps[_tutorialStep]['title'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        
                        // Description
                        Text(
                          _tutorialSteps[_tutorialStep]['description'] as String,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        
                        // Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (_tutorialStep > 0)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _tutorialStep--;
                                  });
                                },
                                child: const Text(
                                  "Back",
                                  style: TextStyle(color: Colors.white54),
                                ),
                              )
                            else
                              const SizedBox(width: 60),
                            
                            ElevatedButton(
                              onPressed: () {
                                if (_tutorialStep < _tutorialSteps.length - 1) {
                                  setState(() {
                                    _tutorialStep++;
                                  });
                                } else {
                                  setState(() {
                                    _showTutorial = false;
                                  });
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00BFFF),
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                _tutorialStep < _tutorialSteps.length - 1 ? "Next" : "Get Started",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            
                            if (_tutorialStep < _tutorialSteps.length - 1)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _showTutorial = false;
                                  });
                                },
                                child: const Text(
                                  "Skip",
                                  style: TextStyle(color: Colors.white54),
                                ),
                              )
                            else
                              const SizedBox(width: 60),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ==================== TOP BAR ====================
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(top: isSmall ? 40 : 50, left: 16, right: 16, bottom: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Exercise Selector Button
                  GestureDetector(
                    onTap: () => setState(() => _showExerciseSelector = !_showExerciseSelector),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            "${_config['emoji']} $_selectedExercise",
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _showExerciseSelector ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Right side buttons
                  Row(
                    children: [
                      // Camera Switch Button
                      GestureDetector(
                        onTap: _switchCamera,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            _isFrontCamera ? Icons.camera_front : Icons.camera_rear,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Reps counter
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: _statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _statusColor, width: 1),
                        ),
                        child: Text(
                          "$_repCount/$_targetReps",
                          style: TextStyle(
                            color: _statusColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ==================== EXERCISE SELECTOR DROPDOWN ====================
          if (_showExerciseSelector)
            Positioned(
              top: isSmall ? 80 : 90,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _exercises.map((exercise) {
                    final isSelected = _selectedExercise == exercise['name'];
                    return GestureDetector(
                      onTap: () => _changeExercise(exercise['name'] as String),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF00BFFF) : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF00BFFF) : Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              exercise['emoji'] as String,
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              exercise['name'] as String,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          // ==================== MAIN GUIDANCE ====================
          if (!_exerciseComplete && !_showTutorial)
            Positioned(
              top: size.height * 0.28,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _statusColor, width: 2),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _guidance,
                          style: TextStyle(
                            color: _statusColor,
                            fontSize: isSmall ? 24 : 32,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _status,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: isSmall ? 14 : 18,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_holdCount > 0 && _holdCount < _holdRequired)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: LinearProgressIndicator(
                              value: _holdCount / _holdRequired,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                              minHeight: 4,
                            ),
                          ),
                        if (_currentAngle > 0 && _isCorrectPosition)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              "${_currentAngle.toStringAsFixed(0)}°",
                              style: const TextStyle(color: Colors.white54, fontSize: 14),
                            ),
                          ),
                        if (_isCorrectPosition)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _config['instruction'] as String,
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // ==================== EXERCISE COMPLETE ====================
          if (_exerciseComplete)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.6),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.green, width: 2),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.emoji_events, color: Colors.amber, size: 60),
                        const SizedBox(height: 16),
                        const Text(
                          "Exercise Complete! 🎉",
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "$_repCount reps of $_selectedExercise done",
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: _reset,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              child: const Text("Repeat", style: TextStyle(fontSize: 14)),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: _showExerciseSelectorDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              child: const Text("Change", style: TextStyle(fontSize: 14)),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              child: const Text("Done", style: TextStyle(fontSize: 14)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ==================== BOTTOM STATUS ====================
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Status indicator with dot
                  Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _statusColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _statusColor.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isCorrectPosition ? "Active" : "Positioning",
                        style: TextStyle(color: _statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  
                  // Camera indicator
                  Text(
                    _isFrontCamera ? "📷 Front" : "📷 Back",
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  
                  // Reset button
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
                    onPressed: _reset,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),

          // ==================== TUTORIAL TRIGGER BUTTON ====================
          Positioned(
            top: isSmall ? 80 : 90,
            right: 16,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showTutorial = true;
                  _tutorialStep = 0;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.help_outline,
                  color: Colors.white54,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExerciseSelectorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          "Choose Exercise",
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _exercises.map((exercise) {
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _changeExercise(exercise['name'] as String);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        exercise['emoji'] as String,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        exercise['name'] as String,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ==================== POSE SKELETON PAINTER - FIXED ====================
class PoseSkeletonPainter extends CustomPainter {
  final Pose pose;
  final bool isValid;
  final Color color;
  final bool isFrontCamera;

  const PoseSkeletonPainter({
    required this.pose,
    this.isValid = false,
    this.color = Colors.orange,
    this.isFrontCamera = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final mainColor = isValid ? Colors.green : color;
    
    // Create paints
    final connectionPaint = Paint()
      ..color = mainColor.withOpacity(0.8)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = mainColor
      ..style = PaintingStyle.fill;

    final innerDotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Map landmark to screen coordinates
    Offset mapLandmark(PoseLandmark landmark) {
      double x = landmark.x;
      // If using front camera, mirror horizontally for natural view
      if (isFrontCamera) {
        x = 1 - x;
      }
      return Offset(x * size.width, landmark.y * size.height);
    }

    // Helper to get landmark or return null
    PoseLandmark? getLandmark(PoseLandmarkType type) {
      return pose.landmarks[type];
    }

    // Define connections
    final connections = [
      // Upper body
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
      [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
      [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
      // Torso
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
      [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
      // Legs
      [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
      [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
      [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
      [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
    ];

    // Draw connections
    for (var connection in connections) {
      final start = getLandmark(connection[0]);
      final end = getLandmark(connection[1]);
      if (start != null && end != null) {
        // Check if landmarks are valid (not at default position)
        if (start.x > 0.01 && start.y > 0.01 && end.x > 0.01 && end.y > 0.01) {
          final startPoint = mapLandmark(start);
          final endPoint = mapLandmark(end);
          canvas.drawLine(startPoint, endPoint, connectionPaint);
        }
      }
    }

    // Draw landmarks (dots)
    for (var type in PoseLandmarkType.values) {
      final landmark = getLandmark(type);
      if (landmark != null) {
        // Check if landmark is valid
        if (landmark.x > 0.01 && landmark.y > 0.01) {
          final position = mapLandmark(landmark);
          
          // Outer glow
          final glowPaint = Paint()
            ..color = mainColor.withOpacity(0.3)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(position, 14, glowPaint);
          
          // Outer ring
          final ringPaint = Paint()
            ..color = mainColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2;
          canvas.drawCircle(position, 10, ringPaint);
          
          // Main dot
          canvas.drawCircle(position, 6, dotPaint);
          
          // Inner dot
          canvas.drawCircle(position, 3, innerDotPaint);
          
          // Small highlight
          final highlightPaint = Paint()
            ..color = Colors.white.withOpacity(0.4)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(position.dx - 2, position.dy - 2), 2, highlightPaint);
        }
      }
    }

    // Draw status indicator at top if valid
    if (isValid) {
      final statusText = "✅ Correct";
      final textSpan = TextSpan(
        text: statusText,
        style: TextStyle(
          color: Colors.green,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.8),
              blurRadius: 4,
              offset: const Offset(1, 1),
            ),
          ],
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas, 
        Offset((size.width - textPainter.width) / 2, 20),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is PoseSkeletonPainter) {
      return oldDelegate.pose != pose || 
             oldDelegate.isValid != isValid ||
             oldDelegate.color != color;
    }
    return true;
  }
}







// import 'dart:async';
// import 'dart:io';
// import 'dart:math' as math;
// import 'dart:ui' as ui;
// import 'package:flutter/material.dart';
// import 'package:camera/camera.dart';
// import 'dart:async';
// import 'dart:io';
// import 'dart:math' as math;
// import 'dart:ui' as ui;
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:camera/camera.dart';
// import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
// import 'package:flutter/foundation.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:image/image.dart' as img;
// import 'package:flutter_image_compress/flutter_image_compress.dart';

// class CameraScreen extends StatefulWidget {
//   final String selectedExercise;

//   const CameraScreen({super.key, this.selectedExercise = "Bicep Curls"});

//   @override
//   State<CameraScreen> createState() => _CameraScreenState();
// }

// class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
//   // Camera & ML variables
//   CameraController? _cameraController;
//   PoseDetector? _poseDetector;
//   bool _isInitializing = true;
//   bool _isProcessing = false;

//   // Local mutable copy of the exercise (widget.selectedExercise is final and can't be reassigned)
//   late String _selectedExercise;

//   // Performance optimization
//   Timer? _frameTimer;
//   CameraImage? _latestImage;
//   bool _isDisposed = false;
//   final int _frameCounter = 0;
//   static const int _processEveryNFrames = 2;
//   static const int _processIntervalMs = 100;
  
//   // Pose data
//   Pose? _currentPose;
//   double _currentScore = 0;
//   int _repCount = 0;
//   String _repState = "up";
//   String _feedback = "Get into position";
//   String _exerciseStatus = "Ready";
  
//   // Exercise thresholds
//   final Map<String, dynamic> _exerciseConfig = {
//     "Bicep Curls": {
//       "upAngle": 150,
//       "downAngle": 50,
//       "feedback": "Keep your shoulder stable! Don't swing.",
//       "threshold": 0.7
//     },
//     "Squats": {
//       "upAngle": 160,
//       "downAngle": 100,
//       "feedback": "Watch out! Push your hips further back.",
//       "threshold": 0.6
//     },
//     "Push-ups": {
//       "upAngle": 160,
//       "downAngle": 90,
//       "feedback": "Keep your back straight!",
//       "threshold": 0.6
//     }
//   };

//   // UI State
//   String _errorMessage = "";
//   List<CameraDescription>? _cameras;
//   CameraDescription? _frontCamera;
  
//   // Performance monitoring
//   final DateTime _lastProcessTime = DateTime.now();
//   final double _fps = 0;

//   @override
//   void initState() {
//     super.initState();
//     _selectedExercise = widget.selectedExercise;
//     WidgetsBinding.instance.addObserver(this);
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (mounted) {
//         _initialize();
//       }
//     });
//   }

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (state == AppLifecycleState.resumed) {
//       _restartCamera();
//     } else if (state == AppLifecycleState.paused) {
//       _pauseCamera();
//     }
//   }

//   Future<void> _initialize() async {
//     try {
//       // Request camera permission
//       final status = await Permission.camera.request();
//       if (status != PermissionStatus.granted) {
//         setState(() {
//           _errorMessage = "Camera permission is required";
//           _isInitializing = false;
//         });
//         return;
//       }

//       // Chhota delay taake app fully resumed ho jaye
//       await Future.delayed(const Duration(milliseconds: 200));
//       if (!mounted) return;

//       // Get available cameras
//       _cameras = await availableCameras();
//       if (_cameras == null || _cameras!.isEmpty) {
//         setState(() {
//           _errorMessage = "No camera found";
//           _isInitializing = false;
//         });
//         return;
//       }

//       // Select front camera
//       _frontCamera = _cameras!.firstWhere(
//         (cam) => cam.lensDirection == CameraLensDirection.front,
//         orElse: () => _cameras!.first,
//       );

//       // Initialize camera with optimal settings
//       _cameraController = CameraController(
//         _frontCamera!,
//         ResolutionPreset.medium,
//         enableAudio: false,
//         imageFormatGroup: Platform.isAndroid 
//             ? ImageFormatGroup.yuv420 
//             : ImageFormatGroup.bgra8888,
//       );

//       await _cameraController!.initialize();
      
//       // Initialize pose detector
//       _poseDetector = PoseDetector(
//         options: PoseDetectorOptions(
//           mode: PoseDetectionMode.stream,
//           model: PoseDetectionModel.accurate,
//         ),
//       );

//       // Start image stream
//       await _cameraController!.startImageStream(_processCameraImage);

//       // Start periodic processing timer
//       _frameTimer = Timer.periodic(
//         Duration(milliseconds: _processIntervalMs),
//         (timer) {
//           if (!mounted || _isDisposed) {
//             timer.cancel();
//             return;
//           }
//           if (_latestImage != null && !_isProcessing) {
//             _processImage(_latestImage!);
//           }
//         },
//       );

//       setState(() {
//         _isInitializing = false;
//         _exerciseStatus = "Camera ready";
//       });
      
//     } catch (e) {
//       debugPrint('Init Error: $e');
//       setState(() {
//         _errorMessage = "Failed to initialize: $e";
//         _isInitializing = false;
//       });
//     }
//   }

//   void _processCameraImage(CameraImage image) {
//     if (_isDisposed) return;
//     _latestImage = image;
//   }

//   Future<void> _processImage(CameraImage image) async {
//     if (_poseDetector == null || _cameraController == null || _isDisposed) return;
//     if (_isProcessing) return;
    
//     _isProcessing = true;
    
//     try {
//       // Convert and process image
//       final inputImage = await _convertCameraImage(image);
//       if (inputImage == null) return;

//       final poses = await _poseDetector!.processImage(inputImage);
      
//       if (poses.isNotEmpty && mounted && !_isDisposed) {
//         final pose = poses.first;
//         _currentPose = pose;
//         _evaluateExercise(pose);
        
//         setState(() {});
//       }
      
//     } catch (e) {
//       debugPrint('Processing Error: $e');
//     } finally {
//       _isProcessing = false;
//     }
//   }

//   Future<InputImage?> _convertCameraImage(CameraImage image) async {
//     if (_frontCamera == null) return null;

//     try {
//       final rotation = InputImageRotationValue.fromRawValue(
//         _frontCamera!.sensorOrientation
//       );
      
//       if (rotation == null || image.planes.isEmpty) return null;

//       // Convert image format
//       img.Image? convertedImage;
      
//       if (Platform.isAndroid) {
//         convertedImage = _convertYUV420ToImage(image);
//       } else {
//         convertedImage = _convertBGRAToImage(image);
//       }

//       if (convertedImage == null) return null;

//       // Compress image for better performance
//       final compressedBytes = await _compressImage(convertedImage);
//       if (compressedBytes == null) return null;

//       return InputImage.fromBytes(
//         bytes: compressedBytes,
//         metadata: InputImageMetadata(
//           size: Size(image.width.toDouble(), image.height.toDouble()),
//           rotation: rotation,
//           format: InputImageFormat.nv21,
//           bytesPerRow: image.planes.first.bytesPerRow,
//         ),
//       );
      
//     } catch (e) {
//       debugPrint('Conversion error: $e');
//       return null;
//     }
//   }

//   img.Image? _convertYUV420ToImage(CameraImage image) {
//     try {
//       final yPlane = image.planes[0];
//       final uvPlane = image.planes[1];
      
//       final yBytes = yPlane.bytes;
//       final uvBytes = uvPlane.bytes;
      
//       final width = image.width;
//       final height = image.height;
      
//       // Create RGBA image
//       final img.Image rgbaImage = img.Image(width: width, height: height);
      
//       for (int y = 0; y < height; y++) {
//         for (int x = 0; x < width; x++) {
//           final yIndex = y * yPlane.bytesPerRow + x;
//           final uvIndex = (y ~/ 2) * uvPlane.bytesPerRow + (x ~/ 2) * 2;
          
//           if (yIndex >= yBytes.length || uvIndex + 1 >= uvBytes.length) continue;
          
//           final yValue = yBytes[yIndex] & 0xFF;
//           final uValue = uvBytes[uvIndex] & 0xFF;
//           final vValue = uvBytes[uvIndex + 1] & 0xFF;
          
//           // YUV to RGB conversion
//           int r = (yValue + 1.402 * (vValue - 128)).toInt();
//           int g = (yValue - 0.344 * (uValue - 128) - 0.714 * (vValue - 128)).toInt();
//           int b = (yValue + 1.772 * (uValue - 128)).toInt();
          
//           r = r.clamp(0, 255);
//           g = g.clamp(0, 255);
//           b = b.clamp(0, 255);
          
//           rgbaImage.setPixelRgb(x, y, r, g, b);
//         }
//       }
      
//       return rgbaImage;
//     } catch (e) {
//       debugPrint('YUV conversion error: $e');
//       return null;
//     }
//   }

//   img.Image? _convertBGRAToImage(CameraImage image) {
//     try {
//       final bytes = image.planes[0].bytes;
//       final width = image.width;
//       final height = image.height;
      
//       final img.Image rgbaImage = img.Image(width: width, height: height);
      
//       for (int i = 0; i < bytes.length - 3; i += 4) {
//         final int b = bytes[i] & 0xFF;
//         final int g = bytes[i + 1] & 0xFF;
//         final int r = bytes[i + 2] & 0xFF;
//         final int a = bytes[i + 3] & 0xFF;
        
//         final int x = (i ~/ 4) % width;
//         final int y = (i ~/ 4) ~/ width;
        
//         if (x < width && y < height) {
//           rgbaImage.setPixelRgba(x, y, r, g, b, a);
//         }
//       }
      
//       return rgbaImage;
//     } catch (e) {
//       debugPrint('BGRA conversion error: $e');
//       return null;
//     }
//   }

//   Future<Uint8List?> _compressImage(img.Image image) async {
//     try {
//       // Resize image for better performance
//       final resized = img.copyResize(
//         image,
//         width: image.width ~/ 2,
//         height: image.height ~/ 2,
//       );
      
//       // Encode to JPEG
//       final jpgBytes = img.encodeJpg(resized, quality: 70);
      
//       // Further compress if needed
//       final compressed = await FlutterImageCompress.compressWithList(
//         jpgBytes,
//         minHeight: 300,
//         minWidth: 300,
//         quality: 70,
//       );
      
//       return compressed ?? jpgBytes;
//     } catch (e) {
//       debugPrint('Compression error: $e');
//       return null;
//     }
//   }

//   double _calculateAngle(
//     PoseLandmark first, 
//     PoseLandmark mid, 
//     PoseLandmark last
//   ) {
//     final radians = math.atan2(last.y - mid.y, last.x - mid.x) -
//                     math.atan2(first.y - mid.y, first.x - mid.x);
    
//     double angle = (radians * 180.0 / math.pi).abs();
    
//     if (angle > 180.0) {
//       angle = 360.0 - angle;
//     }
    
//     return angle;
//   }

//   void _evaluateExercise(Pose pose) {
//     final exercise = _exerciseConfig[_selectedExercise];
//     if (exercise == null) return;

//     if (_selectedExercise == "Bicep Curls") {
//       _evaluateBicepCurl(pose, exercise);
//     } else if (_selectedExercise == "Squats") {
//       _evaluateSquats(pose, exercise);
//     } else if (_selectedExercise == "Push-ups") {
//       _evaluatePushups(pose, exercise);
//     }
//   }

//   void _evaluateBicepCurl(Pose pose, Map<String, dynamic> config) {
//     final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
//     final elbow = pose.landmarks[PoseLandmarkType.leftElbow];
//     final wrist = pose.landmarks[PoseLandmarkType.leftWrist];

//     if (shoulder != null && elbow != null && wrist != null) {
//       final angle = _calculateAngle(shoulder, elbow, wrist);
//       final upAngle = config['upAngle'] as double;
//       final downAngle = config['downAngle'] as double;

//       setState(() {
//         _currentScore = ((180 - angle) / 140 * 100).clamp(0, 100);
//         _exerciseStatus = "Angle: ${angle.toStringAsFixed(1)}°";

//         // Rep counting logic
//         if (angle > upAngle && _repState != "down") {
//           _repState = "down";
//           _feedback = "Curl up your arm!";
//         }
//         if (angle < downAngle && _repState == "down") {
//           _repState = "up";
//           _repCount++;
//           _feedback = "Good rep! Lower down slowly.";
//         }
        
//         // Form feedback
//         if ((shoulder.y - elbow.y).abs() < 50) {
//           _feedback = config['feedback'] as String? ?? "Keep your shoulder stable!";
//         }
//       });
//     }
//   }

//   void _evaluateSquats(Pose pose, Map<String, dynamic> config) {
//     final hip = pose.landmarks[PoseLandmarkType.leftHip];
//     final knee = pose.landmarks[PoseLandmarkType.leftKnee];
//     final ankle = pose.landmarks[PoseLandmarkType.leftAnkle];

//     if (hip != null && knee != null && ankle != null) {
//       final angle = _calculateAngle(hip, knee, ankle);
//       final upAngle = config['upAngle'] as double;
//       final downAngle = config['downAngle'] as double;

//       setState(() {
//         _currentScore = ((180 - angle) / 90 * 100).clamp(0, 100);
//         _exerciseStatus = "Angle: ${angle.toStringAsFixed(1)}°";

//         if (angle > upAngle && _repState != "up") {
//           _repState = "up";
//           _feedback = "Squat down!";
//         }
//         if (angle < downAngle && _repState == "up") {
//           _repState = "down";
//           _repCount++;
//           _feedback = "Excellent depth! Stand up.";
//         }

//         // Form feedback
//         if (knee.x < ankle.x - 30) {
//           _feedback = config['feedback'] as String? ?? "Push your hips back!";
//         }
//       });
//     }
//   }

//   void _evaluatePushups(Pose pose, Map<String, dynamic> config) {
//     final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
//     final elbow = pose.landmarks[PoseLandmarkType.leftElbow];
//     final wrist = pose.landmarks[PoseLandmarkType.leftWrist];

//     if (shoulder != null && elbow != null && wrist != null) {
//       final angle = _calculateAngle(shoulder, elbow, wrist);
//       final upAngle = config['upAngle'] as double;
//       final downAngle = config['downAngle'] as double;

//       setState(() {
//         _currentScore = ((180 - angle) / 90 * 100).clamp(0, 100);
//         _exerciseStatus = "Angle: ${angle.toStringAsFixed(1)}°";

//         if (angle > upAngle && _repState != "up") {
//           _repState = "up";
//           _feedback = "Push up!";
//         }
//         if (angle < downAngle && _repState == "up") {
//           _repState = "down";
//           _repCount++;
//           _feedback = "Good form! Lower down.";
//         }

//         // Form feedback
//         final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
//         if (rightShoulder != null && (shoulder.y - rightShoulder.y).abs() > 30) {
//           _feedback = config['feedback'] as String? ?? "Keep your back straight!";
//         }
//       });
//     }
//   }

//   void _restartCamera() async {
//     if (_cameraController != null && !_cameraController!.value.isInitialized) {
//       try {
//         await _cameraController!.initialize();
//         await _cameraController!.startImageStream(_processCameraImage);
//       } catch (e) {
//         debugPrint('Restart camera error: $e');
//       }
//     }
//   }

//   void _pauseCamera() {
//     _cameraController?.stopImageStream();
//   }

//   @override
//   void dispose() {
//     _isDisposed = true;
//     WidgetsBinding.instance.removeObserver(this);
//     _frameTimer?.cancel();
//     _cameraController?.stopImageStream();
//     _cameraController?.dispose();
//     _poseDetector?.close();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_errorMessage.isNotEmpty) {
//       return _buildErrorScreen();
//     }

//     if (_isInitializing) {
//       return _buildLoadingScreen();
//     }

//     return _buildCameraScreen();
//   }

//   Widget _buildErrorScreen() {
//     return Scaffold(
//       backgroundColor: const Color(0xFF021721),
//       body: Center(
//         child: Padding(
//           padding: const EdgeInsets.all(20.0),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               const Icon(Icons.error_outline, color: Colors.red, size: 60),
//               const SizedBox(height: 20),
//               Text(
//                 _errorMessage,
//                 style: const TextStyle(color: Colors.white, fontSize: 16),
//                 textAlign: TextAlign.center,
//               ),
//               const SizedBox(height: 30),
//               ElevatedButton(
//                 onPressed: _resetAndRetry,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: const Color(0xFF00BFFF),
//                   padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
//                 ),
//                 child: const Text(
//                   "Retry",
//                   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildLoadingScreen() {
//     return const Scaffold(
//       backgroundColor: Color(0xFF021721),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             CircularProgressIndicator(
//               color: Color(0xFF00BFFF),
//               strokeWidth: 3,
//             ),
//             SizedBox(height: 20),
//             Text(
//               "Initializing Camera...",
//               style: TextStyle(color: Colors.white, fontSize: 16),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildCameraScreen() {
//     final mediaSize = MediaQuery.of(context).size;

//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         title: Text(
//           "PostureGuard - $_selectedExercise",
//           style: const TextStyle(fontSize: 16),
//         ),
//         backgroundColor: const Color(0xFF021721),
//         foregroundColor: Colors.white,
//         elevation: 0,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.settings),
//             onPressed: _showSettingsDialog,
//           ),
//         ],
//       ),
//       body: Stack(
//         children: [
//           // Camera Preview
//           if (_cameraController != null && _cameraController!.value.isInitialized)
//             Center(
//               child: AspectRatio(
//                 aspectRatio: _cameraController!.value.aspectRatio,
//                 child: CameraPreview(_cameraController!),
//               ),
//             ),

//           // Pose Skeleton Overlay
//           if (_currentPose != null && _cameraController != null)
//             CustomPaint(
//               size: mediaSize,
//               painter: PoseSkeletonPainter(
//                 pose: _currentPose!,
//                 imageSize: Size(
//                   mediaSize.width,
//                   mediaSize.height,
//                 ),
//               ),
//             ),

//           // Top Status Bar
//           Positioned(
//             top: 10,
//             left: 10,
//             right: 10,
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//               decoration: BoxDecoration(
//                 color: Colors.black.withOpacity(0.5),
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     _exerciseStatus,
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 12,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                   Text(
//                     "Reps: $_repCount",
//                     style: const TextStyle(
//                       color: Colors.greenAccent,
//                       fontSize: 14,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),

//           // Center guidance
//           if (_currentPose == null)
//             Positioned(
//               top: mediaSize.height * 0.3,
//               left: 20,
//               right: 20,
//               child: Container(
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: Colors.black.withOpacity(0.6),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: const Text(
//                   "Position yourself in the frame\nStand at a distance where your full body is visible",
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     color: Colors.white70,
//                     fontSize: 14,
//                     height: 1.5,
//                   ),
//                 ),
//               ),
//             ),

//           // Bottom HUD
//           Positioned(
//             bottom: 30,
//             left: 20,
//             right: 20,
//             child: Container(
//               padding: const EdgeInsets.all(20),
//               decoration: BoxDecoration(
//                 color: const Color(0xFF021721).withOpacity(0.9),
//                 borderRadius: BorderRadius.circular(20),
//                 border: Border.all(
//                   color: _getFeedbackColor(),
//                   width: 1.5,
//                 ),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.3),
//                     blurRadius: 10,
//                     offset: const Offset(0, 5),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Text(
//                     _feedback,
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       color: _getFeedbackColor(),
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const SizedBox(height: 15),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceAround,
//                     children: [
//                       _buildMetricColumn(
//                         "Accuracy",
//                         "${_currentScore.toStringAsFixed(0)}%",
//                         const Color(0xFF00BFFF),
//                       ),
//                       _buildMetricColumn(
//                         "Reps Done",
//                         "$_repCount",
//                         Colors.greenAccent,
//                       ),
//                     ],
//                   ),
//                   // Progress bar for accuracy
//                   const SizedBox(height: 10),
//                   ClipRRect(
//                     borderRadius: BorderRadius.circular(10),
//                     child: LinearProgressIndicator(
//                       value: _currentScore / 100,
//                       backgroundColor: Colors.grey.withOpacity(0.3),
//                       valueColor: const AlwaysStoppedAnimation<Color>(
//                         Color(0xFF00BFFF),
//                       ),
//                       minHeight: 4,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildMetricColumn(String label, String value, Color color) {
//     return Column(
//       children: [
//         Text(
//           label,
//           style: const TextStyle(color: Colors.white70, fontSize: 12),
//         ),
//         const SizedBox(height: 4),
//         Text(
//           value,
//           style: TextStyle(
//             color: color,
//             fontSize: 24,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ],
//     );
//   }

//   Color _getFeedbackColor() {
//     if (_feedback.contains("Good") || _feedback.contains("Excellent")) {
//       return Colors.greenAccent;
//     } else if (_feedback.contains("Watch") || _feedback.contains("Keep")) {
//       return Colors.orange;
//     } else if (_feedback.contains("Position")) {
//       return Colors.grey;
//     }
//     return Colors.white;
//   }

//   void _showSettingsDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text("Exercise Settings"),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             ListTile(
//               title: const Text("Bicep Curls"),
//               onTap: () {
//                 Navigator.pop(context);
//                 _changeExercise("Bicep Curls");
//               },
//             ),
//             ListTile(
//               title: const Text("Squats"),
//               onTap: () {
//                 Navigator.pop(context);
//                 _changeExercise("Squats");
//               },
//             ),
//             ListTile(
//               title: const Text("Push-ups"),
//               onTap: () {
//                 Navigator.pop(context);
//                 _changeExercise("Push-ups");
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _changeExercise(String exercise) {
//     setState(() {
//       _selectedExercise = exercise;
//       _repCount = 0;
//       _repState = "up";
//       _feedback = "Get into position";
//       _currentScore = 0;
//     });
//   }

//   void _resetAndRetry() {
//     setState(() {
//       _errorMessage = "";
//       _isInitializing = true;
//     });
//     _initialize();
//   }
// }

// // Improved Skeleton Painter
// class PoseSkeletonPainter extends CustomPainter {
//   final Pose pose;
//   final Size imageSize;
//   final bool showLabels;

//   PoseSkeletonPainter({
//     required this.pose,
//     required this.imageSize,
//     this.showLabels = true,
//   });

//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..color = const Color(0xFF00BFFF)
//       ..strokeWidth = 3.0
//       ..strokeCap = StrokeCap.round
//       ..style = PaintingStyle.stroke;

//     final dotPaint = Paint()
//       ..color = Colors.white
//       ..style = PaintingStyle.fill;

//     final textPaint = TextPainter(
//       textDirection: TextDirection.ltr,
//       textAlign: TextAlign.center,
//     );

//     // Scale points properly
//     Offset scalePoint(PoseLandmark landmark) {
//       // Flip horizontally for front camera and scale
//       return Offset(
//         (1 - landmark.x) * size.width,
//         landmark.y * size.height,
//       );
//     }

//     // Define connections
//     final connections = [
//       // Upper body
//       [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
//       [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
//       [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
//       [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
//       [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
      
//       // Torso
//       [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
//       [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
//       [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
      
//       // Lower body
//       [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
//       [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
//       [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
//       [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
//     ];

//     // Draw connections
//     for (var connection in connections) {
//       final start = pose.landmarks[connection[0]];
//       final end = pose.landmarks[connection[1]];
//       if (start != null && end != null) {
//         final startPoint = scalePoint(start);
//         final endPoint = scalePoint(end);
        
//         // Draw line with glow effect
//         for (int i = 0; i < 3; i++) {
//           paint
//             ..strokeWidth = 3.0 + i * 2
//             ..color = const Color(0xFF00BFFF).withOpacity(0.3 - i * 0.1);
//           canvas.drawLine(startPoint, endPoint, paint);
//         }
//       }
//     }

//     // Draw landmarks
//     for (var type in PoseLandmarkType.values) {
//       final landmark = pose.landmarks[type];
//       if (landmark != null) {
//         final position = scalePoint(landmark);
        
//         // Glow effect
//         final glowPaint = Paint()
//           ..color = const Color(0xFF00BFFF).withOpacity(0.3)
//           ..style = PaintingStyle.fill;
//         canvas.drawCircle(position, 12, glowPaint);
        
//         // Main dot
//         canvas.drawCircle(position, 5, dotPaint);
        
//         // Label
//         if (showLabels) {
//           final label = type.name.replaceAll('PoseLandmarkType.', '');
//           textPaint.text = TextSpan(
//             text: label,
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 10,
//               fontWeight: FontWeight.bold,
//             ),
//           );
//           textPaint.layout();
//           textPaint.paint(
//             canvas,
//             Offset(position.dx - 20, position.dy - 25),
//           );
//         }
//       }
//     }
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
// }