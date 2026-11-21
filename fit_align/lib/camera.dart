import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

class _Exercise {
  final String name, cue, instruction;
  final IconData icon;
  final List<PoseLandmarkType> joints;
  final bool startsExtended;
  final double upAngle, downAngle;
  final int reps;

  const _Exercise(this.name, this.icon, this.joints, this.startsExtended, this.upAngle, this.downAngle, this.reps,
      this.cue, this.instruction);
}

const _arm = [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist];
const _leg = [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle];

const List<_Exercise> _exercises = [
  _Exercise('Bicep Curls', Icons.fitness_center, _arm, true, 150, 50, 10, 'Curl Up', 'Curl your arm up and down'),
  _Exercise('Squats', Icons.accessibility_new, _leg, true, 160, 100, 12, 'Squat Down', 'Squat down and stand up'),
  _Exercise('Push-ups', Icons.sports_gymnastics, _arm, true, 160, 90, 8, 'Lower Down', 'Push up and lower down'),
  _Exercise('Shoulder Press', Icons.arrow_upward, _arm, false, 170, 100, 10, 'Press Up', 'Press up and lower down'),
  _Exercise('Lunges', Icons.directions_walk, _leg, true, 170, 90, 10, 'Lunge Down', 'Lunge forward and back'),
  _Exercise('Tricep Extensions', Icons.arrow_downward, _arm, false, 170, 100, 10, 'Extend Up', 'Extend up and lower'),
  _Exercise('Calf Raises', Icons.vertical_align_top,
      [PoseLandmarkType.leftAnkle, PoseLandmarkType.leftKnee, PoseLandmarkType.leftHip], true, 160, 130, 15, 'Rise Up',
      'Rise up on toes and down'),
  _Exercise('Glute Bridges', Icons.vertical_align_center,
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee], true, 160, 110, 12,
      'Bridge Up', 'Bridge up and down'),
];

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  bool _isInitializing = true;
  bool _isProcessing = false;
  bool _isDisposed = false;
  bool _isFrontCamera = true;

  String _selectedExercise = "Bicep Curls";
  int _repCount = 0;
  int _targetReps = 10;
  String _repState = "idle";
  double _currentAngle = 0;
  bool _exerciseComplete = false;

  String _guidance = "Stand in front of camera";
  String _status = "Position yourself";
  bool _isGood = false;
  bool _isCorrectPosition = false;
  int _holdCount = 0;
  static const int _holdRequired = 20;

  bool _showTutorial = true;
  int _tutorialStep = 0;
  static const List<({IconData icon, String title, String description})> _tutorialSteps = [
    (
      icon: Icons.camera_alt,
      title: 'Welcome to FitAlign!',
      description: 'This app helps you exercise with proper form using AI pose detection.',
    ),
    (
      icon: Icons.person,
      title: 'Step 1: Stand in Front',
      description: 'Stand facing the camera with your full body visible in the frame.',
    ),
    (
      icon: Icons.center_focus_strong,
      title: 'Step 2: Center Yourself',
      description: 'Follow the on-screen guidance to position yourself correctly.',
    ),
    (
      icon: Icons.fitness_center,
      title: 'Step 3: Start Exercising',
      description: 'Once positioned, follow the exercise instructions and watch your reps count!',
    ),
  ];

  String _error = "";
  List<CameraDescription>? _cameras;
  CameraDescription? _frontCamera;
  CameraDescription? _backCamera;
  bool _showExerciseSelector = false;

  Timer? _frameTimer;
  CameraImage? _latestImage;
  static const int _processIntervalMs = 150;

  Pose? _currentPose;
  bool _poseVisible = false;
  Size _poseImageSize = const Size(1, 1);

  ColorScheme get cs => Theme.of(context).colorScheme;
  Color get _statusColor => _isGood ? cs.primary : cs.secondary;
  _Exercise get _config => _exercises.firstWhere((e) => e.name == _selectedExercise, orElse: () => _exercises[0]);

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
    if (state == AppLifecycleState.resumed) {
      _restartCamera();
    } else if (state == AppLifecycleState.paused) {
      _pauseCamera();
    }
  }

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
    await _cameraController?.dispose();

    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
    );

    await _cameraController!.initialize();

    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream, model: PoseDetectionModel.accurate),
    );

    await _cameraController!.startImageStream(_processCameraImage);

    _frameTimer?.cancel();
    _frameTimer = Timer.periodic(const Duration(milliseconds: _processIntervalMs), (timer) {
      if (!mounted || _isDisposed) {
        timer.cancel();
        return;
      }
      if (_latestImage != null && !_isProcessing) _processImage(_latestImage!);
    });

    setState(() {
      _isInitializing = false;
      _targetReps = _config.reps;
      _guidance = "Stand in front of camera";
      _status = "Position yourself";
      _isGood = false;
      _poseVisible = false;
    });
  }

  void _processCameraImage(CameraImage image) {
    if (_isDisposed) return;
    _latestImage = image;
  }

  Future<void> _processImage(CameraImage image) async {
    if (_poseDetector == null || _cameraController == null || _isDisposed || _isProcessing) return;
    if (_exerciseComplete) return;

    _isProcessing = true;

    try {
      final isRotated = _cameraController!.description.sensorOrientation % 180 == 90;
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final inputImage = await _convertCameraImage(image);
      if (inputImage == null) return;

      final poses = await _poseDetector!.processImage(inputImage);
      if (!mounted || _isDisposed) return;

      if (poses.isNotEmpty) {
        _poseImageSize = isRotated ? Size(imageSize.height, imageSize.width) : imageSize;
        _currentPose = poses.first;
        _poseVisible = true;
        _checkPositionAndExercise(_currentPose!);
        setState(() {});
      } else {
        _poseVisible = false;
        _setGuide("Move into frame", "No person detected");
      }
    } catch (e) {
      debugPrint('Processing Error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  void _setGuide(String guidance, String status) {
    setState(() {
      _guidance = guidance;
      _status = status;
      _isGood = false;
      _isCorrectPosition = false;
      _holdCount = 0;
    });
  }

  void _checkPositionAndExercise(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    if (leftShoulder == null || rightShoulder == null || leftHip == null || rightHip == null) {
      return _setGuide("Stand in front of camera", "Can't detect body");
    }

    final shoulderWidth = (rightShoulder.x - leftShoulder.x).abs() / _poseImageSize.width;
    final centerX = (leftShoulder.x + rightShoulder.x) / 2 / _poseImageSize.width;
    final shownX = _isFrontCamera ? 1 - centerX : centerX;
    final isUpright = (leftShoulder.y - leftHip.y).abs() / _poseImageSize.height > 0.1;

    if (!(shoulderWidth > 0.2 && shoulderWidth < 0.6)) {
      return _setGuide(shoulderWidth < 0.2 ? "Step Closer" : "Step Back", "Adjust distance");
    }
    if ((shownX - 0.5).abs() >= 0.15) {
      return _setGuide(shownX < 0.5 ? "Move Right" : "Move Left", "Center yourself");
    }
    if (!isUpright) return _setGuide("Stand Upright", "Straighten up");

    setState(() => _holdCount = math.min(_holdCount + 1, _holdRequired));

    if (_holdCount < _holdRequired) {
      setState(() {
        _guidance = "Hold Position";
        _status = "${(_holdCount / _holdRequired * 100).toInt()}%";
        _isGood = true;
        _isCorrectPosition = false;
      });
      return;
    }

    if (!_isCorrectPosition) {
      setState(() {
        _isCorrectPosition = true;
        _guidance = "Start!";
        _status = "Exercise";
        _isGood = true;
      });
    }

    _evaluateExercise(pose);
  }

  void _evaluateExercise(Pose pose) {
    final points = _config.joints.map((type) => pose.landmarks[type]).toList();
    if (points.contains(null)) return;

    _currentAngle = _calculateAngle(points[0]!, points[1]!, points[2]!);
    final isUp = _currentAngle > _config.upAngle;
    final isDown = _currentAngle < _config.downAngle;
    final atStart = _config.startsExtended ? isUp : isDown;
    final atEnd = _config.startsExtended ? isDown : isUp;

    setState(() {
      if (atStart && _repState != "ready") {
        _repState = "ready";
        _guidance = _config.cue;
        _isGood = false;
      }
      if (atEnd && _repState == "ready") {
        _repState = "idle";
        _repCount++;
        _guidance = "Rep $_repCount/$_targetReps";
        _isGood = true;
        HapticFeedback.lightImpact();
      }
      if (_repCount >= _targetReps) {
        _exerciseComplete = true;
        _guidance = "Complete!";
        _status = "Done";
        _isGood = true;
      }
    });
  }

  double _calculateAngle(PoseLandmark first, PoseLandmark mid, PoseLandmark last) {
    final radians = math.atan2(last.y - mid.y, last.x - mid.x) - math.atan2(first.y - mid.y, first.x - mid.x);
    double angle = (radians * 180.0 / math.pi).abs();
    if (angle > 180.0) angle = 360.0 - angle;
    return angle;
  }

  Future<InputImage?> _convertCameraImage(CameraImage image) async {
    if (_cameraController == null) return null;
    try {
      final rotation = InputImageRotationValue.fromRawValue(_cameraController!.description.sensorOrientation);
      if (rotation == null || image.planes.isEmpty) return null;

      final convertedImage = Platform.isAndroid ? _convertYUV420ToImage(image) : _convertBGRAToImage(image);
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
      final width = image.width;
      final height = image.height;
      final img.Image rgbaImage = img.Image(width: width, height: height);

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final yIndex = y * yPlane.bytesPerRow + x;
          final uvIndex = (y ~/ 2) * uvPlane.bytesPerRow + (x ~/ 2) * 2;
          if (yIndex >= yPlane.bytes.length || uvIndex + 1 >= uvPlane.bytes.length) continue;
          final yValue = yPlane.bytes[yIndex] & 0xFF;
          final uValue = uvPlane.bytes[uvIndex] & 0xFF;
          final vValue = uvPlane.bytes[uvIndex + 1] & 0xFF;
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
        final int x = (i ~/ 4) % width;
        final int y = (i ~/ 4) ~/ width;
        if (x < width && y < height) {
          rgbaImage.setPixelRgba(x, y, bytes[i + 2] & 0xFF, bytes[i + 1] & 0xFF, bytes[i] & 0xFF, bytes[i + 3] & 0xFF);
        }
      }
      return rgbaImage;
    } catch (e) {
      return null;
    }
  }

  Future<Uint8List?> _compressImage(img.Image image) async {
    try {
      final resized = img.copyResize(image, width: image.width ~/ 2, height: image.height ~/ 2);
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

  Future<void> _restartCamera() async {
    if (_cameraController != null && !_cameraController!.value.isInitialized) {
      try {
        await _cameraController!.initialize();
        await _cameraController!.startImageStream(_processCameraImage);
      } catch (e) {
        debugPrint('Restart camera error: $e');
      }
    }
  }

  void _pauseCamera() => _cameraController?.stopImageStream();

  Future<void> _switchCamera() async {
    if (_isDisposed) return;
    setState(() => _isInitializing = true);

    try {
      final camera = _isFrontCamera ? _backCamera : _frontCamera;
      if (camera != null) {
        _isFrontCamera = !_isFrontCamera;
        await _initCamera(camera);
      }
    } catch (e) {
      debugPrint('Camera switch error: $e');
      setState(() => _isInitializing = false);
    }
  }

  void _reset() {
    setState(() {
      _repCount = 0;
      _repState = "idle";
      _guidance = "Stand in front of camera";
      _status = "Position yourself";
      _isGood = false;
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
      _targetReps = _config.reps;
      _showExerciseSelector = false;
    });
    _reset();
  }

  @override
  Widget build(BuildContext context) {
    if (_error.isNotEmpty) return _buildErrorScreen();
    if (_isInitializing) return _buildLoadingScreen();
    return _buildMainScreen();
  }

  Widget _glass({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(12),
    double radius = 16,
    Color? borderColor,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: cs.surface.withAlpha(205),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? cs.outlineVariant),
      ),
      child: child,
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: _glass(
        padding: const EdgeInsets.all(8),
        radius: 20,
        child: Icon(icon, color: cs.onSurface, size: 20),
      ),
    );
  }

  Widget _exerciseChips(void Function(String) onPick) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _exercises.map((exercise) {
        final selected = exercise.name == _selectedExercise;
        return GestureDetector(
          onTap: () => onPick(exercise.name),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? cs.primary : cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? cs.primary : cs.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(exercise.icon, size: 16, color: selected ? cs.onPrimary : cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  exercise.name,
                  style: TextStyle(
                    color: selected ? cs.onPrimary : cs.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, color: cs.secondary, size: 56),
              const SizedBox(height: 20),
              Text(_error, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurface, fontSize: 16)),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _error = "";
                    _isInitializing = true;
                  });
                  _initialize();
                },
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: cs.primary),
            const SizedBox(height: 20),
            Text("Initializing Camera...", style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildMainScreen() {
    final size = MediaQuery.of(context).size;
    final isReady = _cameraController?.value.isInitialized ?? false;

    return Scaffold(
      body: Stack(
        children: [
          if (isReady) _buildPreview(),
          if (!_exerciseComplete && !_showTutorial) _buildGuidance(size),
          _buildBottomBar(),
          _buildTopBar(),
          if (_exerciseComplete) _buildCompleteOverlay(),
          if (_showTutorial) _buildTutorial(),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final preview = _cameraController!.value.previewSize!;
    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: preview.height,
            height: preview.width,
            child: Stack(
              children: [
                Positioned.fill(child: CameraPreview(_cameraController!)),
                if (_currentPose != null && _poseVisible)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: PoseSkeletonPainter(
                        pose: _currentPose!,
                        imageSize: _poseImageSize,
                        color: _statusColor,
                        isFrontCamera: _isFrontCamera,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => setState(() => _showExerciseSelector = !_showExerciseSelector),
                        child: _glass(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          radius: 20,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_config.icon, color: cs.primary, size: 18),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _selectedExercise,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: cs.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Icon(
                                _showExerciseSelector ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                                color: cs.onSurface,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _iconButton(Icons.help_outline_rounded, () => setState(() {
                        _showTutorial = true;
                        _tutorialStep = 0;
                      })),
                  const SizedBox(width: 8),
                  _iconButton(_isFrontCamera ? Icons.camera_front : Icons.camera_rear, _switchCamera),
                  const SizedBox(width: 8),
                  _glass(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    radius: 20,
                    borderColor: _statusColor,
                    child: Text(
                      "$_repCount/$_targetReps",
                      style: TextStyle(color: _statusColor, fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              if (_showExerciseSelector)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(width: double.infinity, child: _glass(child: _exerciseChips(_changeExercise))),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuidance(Size size) {
    final isSmall = size.width < 400;
    return Positioned(
      top: size.height * 0.28,
      left: 20,
      right: 20,
      child: _glass(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        radius: 20,
        borderColor: _statusColor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _guidance,
              textAlign: TextAlign.center,
              style: TextStyle(color: _statusColor, fontSize: isSmall ? 24 : 30, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: isSmall ? 14 : 17),
            ),
            if (_holdCount > 0 && _holdCount < _holdRequired)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(
                  value: _holdCount / _holdRequired,
                  backgroundColor: cs.outlineVariant,
                  color: cs.primary,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            if (_isCorrectPosition) ...[
              if (_currentAngle > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    "${_currentAngle.toStringAsFixed(0)}°",
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_config.instruction, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 20,
      right: 20,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _glass(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _statusColor,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: _statusColor.withAlpha(130), blurRadius: 8, spreadRadius: 2)],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isCorrectPosition ? "Active" : "Positioning",
                      style: TextStyle(color: _statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Text(
                  _isFrontCamera ? "Front camera" : "Back camera",
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
                IconButton(
                  icon: Icon(Icons.refresh_rounded, color: cs.onSurfaceVariant, size: 22),
                  onPressed: _reset,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompleteOverlay() {
    return Positioned.fill(
      child: Container(
        color: cs.surface.withAlpha(180),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cs.primary, width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events_rounded, color: cs.primary, size: 56),
                const SizedBox(height: 16),
                Text(
                  "Exercise Complete",
                  style: TextStyle(color: cs.onSurface, fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  "$_repCount reps of $_selectedExercise done",
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton(onPressed: _reset, child: const Text("Repeat")),
                    OutlinedButton(onPressed: _showExerciseSelectorDialog, child: const Text("Change")),
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Done")),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTutorial() {
    final step = _tutorialSteps[_tutorialStep];
    final isLast = _tutorialStep == _tutorialSteps.length - 1;

    return Positioned.fill(
      child: Container(
        color: cs.surface.withAlpha(235),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _tutorialSteps.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: index == _tutorialStep ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: index == _tutorialStep ? cs.primary : cs.outlineVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: cs.primary.withAlpha(30), shape: BoxShape.circle),
                  child: Icon(step.icon, color: cs.primary, size: 48),
                ),
                const SizedBox(height: 20),
                Text(
                  step.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurface, fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Text(
                  step.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15, height: 1.5),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _tutorialStep > 0
                        ? TextButton(onPressed: () => setState(() => _tutorialStep--), child: const Text("Back"))
                        : const SizedBox(width: 64),
                    FilledButton(
                      onPressed: () => setState(() => isLast ? _showTutorial = false : _tutorialStep++),
                      child: Text(isLast ? "Get Started" : "Next"),
                    ),
                    !isLast
                        ? TextButton(onPressed: () => setState(() => _showTutorial = false), child: const Text("Skip"))
                        : const SizedBox(width: 64),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showExerciseSelectorDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cs.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Choose Exercise", style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: double.maxFinite,
          child: _exerciseChips((name) {
            Navigator.pop(dialogContext);
            _changeExercise(name);
          }),
        ),
      ),
    );
  }
}

class PoseSkeletonPainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final Color color;
  final bool isFrontCamera;

  const PoseSkeletonPainter({
    required this.pose,
    required this.imageSize,
    required this.color,
    this.isFrontCamera = true,
  });

  static const List<List<PoseLandmarkType>> _connections = [
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
    [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
    [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
    [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
    [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
    [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
    [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
    [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    Offset map(PoseLandmark landmark) {
      final x = landmark.x / imageSize.width;
      return Offset((isFrontCamera ? 1 - x : x) * size.width, landmark.y / imageSize.height * size.height);
    }

    final linePaint = Paint()
      ..color = color.withAlpha(210)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final glowPaint = Paint()..color = color.withAlpha(70);
    final dotPaint = Paint()..color = color;
    final corePaint = Paint()..color = Colors.white;

    for (final connection in _connections) {
      final start = pose.landmarks[connection[0]];
      final end = pose.landmarks[connection[1]];
      if (start != null && end != null) canvas.drawLine(map(start), map(end), linePaint);
    }

    for (final landmark in pose.landmarks.values) {
      final position = map(landmark);
      canvas.drawCircle(position, 10, glowPaint);
      canvas.drawCircle(position, 5, dotPaint);
      canvas.drawCircle(position, 2, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant PoseSkeletonPainter oldDelegate) =>
      oldDelegate.pose != pose || oldDelegate.color != color;
}