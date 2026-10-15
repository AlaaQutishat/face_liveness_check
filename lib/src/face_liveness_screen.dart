import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as image_lib;

import 'liveness_config.dart';

enum _LivenessState {
  verifyingSteps,
  awaitingStraightFace,
  capturing,
  completed,
}

/// A full-screen camera widget that guides the user through facial liveness checks
/// and captures a guaranteed straight, frontal reference photo upon completion.
class FaceLivenessScreen extends StatefulWidget {
  final LivenessConfig config;

  const FaceLivenessScreen({super.key, this.config = const LivenessConfig()});

  @override
  State<FaceLivenessScreen> createState() => _FaceLivenessScreenState();
}

class _FaceLivenessScreenState extends State<FaceLivenessScreen> {
  CameraController? _cameraController;
  CameraDescription? _selectedCamera;
  InputImageRotation? _imageRotation;
  bool _isProcessingImage = false;
  bool _isAdvancing = false;
  String? _cameraErrorMessage;
  late final FaceDetector _faceDetector;

  late List<LivenessStepItem> _remainingSteps;
  late String _instructionMessage;

  _LivenessState _state = _LivenessState.verifyingSteps;
  int _consecutiveStraightFrames = 0;
  Face? _currentFace;
  XFile? _capturedPhoto;

  @override
  void initState() {
    super.initState();
    _initSteps();

    // Initialize Face Detector with required settings for liveness
    final options = FaceDetectorOptions(
      enableClassification: true, // For smiles & blinks
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
    );
    _faceDetector = FaceDetector(options: options);

    _initializeCamera();
  }

  void _initSteps() {
    _state = _LivenessState.verifyingSteps;
    _consecutiveStraightFrames = 0;

    if (widget.config.steps.isEmpty) {
      _state = _LivenessState.awaitingStraightFace;
      _instructionMessage = widget.config.lookStraightInstruction;
      return;
    }

    _remainingSteps = List.from(widget.config.steps);
    _updateInstructionForCurrentStep();
  }

  void _updateInstructionForCurrentStep() {
    if (_remainingSteps.isEmpty) {
      _instructionMessage = widget.config.lookStraightInstruction;
      return;
    }

    final currentStep = _remainingSteps.first;
    switch (currentStep) {
      case LivenessStepItem.blink:
        _instructionMessage = widget.config.blinkInstruction;
        break;
      case LivenessStepItem.smile:
        _instructionMessage = widget.config.smileInstruction;
        break;
      case LivenessStepItem.turnHeadLeft:
        _instructionMessage = widget.config.turnLeftInstruction;
        break;
      case LivenessStepItem.turnHeadRight:
        _instructionMessage = widget.config.turnRightInstruction;
        break;
      case LivenessStepItem.lookStraight:
        _instructionMessage = widget.config.lookStraightInstruction;
        break;
    }
  }

  String _getStepSubtitle() {
    if (_state == _LivenessState.completed) {
      return widget.config.successInstruction;
    }
    if (_state == _LivenessState.capturing) {
      return widget.config.capturingInstruction;
    }
    if (_state == _LivenessState.awaitingStraightFace ||
        _remainingSteps.isEmpty) {
      return widget.config.awaitingStraightHint;
    }

    final total = widget.config.steps.length;
    final current = total - _remainingSteps.length + 1;
    final currentStep = _remainingSteps.first;

    final String hint;
    switch (currentStep) {
      case LivenessStepItem.blink:
        hint = widget.config.blinkHint;
        break;
      case LivenessStepItem.smile:
        hint = widget.config.smileHint;
        break;
      case LivenessStepItem.turnHeadLeft:
        hint = widget.config.turnLeftHint;
        break;
      case LivenessStepItem.turnHeadRight:
        hint = widget.config.turnRightHint;
        break;
      case LivenessStepItem.lookStraight:
        hint = widget.config.lookStraightHint;
        break;
    }

    if (widget.config.stepFormatBuilder != null) {
      return widget.config.stepFormatBuilder!(current, total, hint);
    }

    return "Step $current of $total • $hint";
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      for (final cam in cameras) {
        if (cam.lensDirection == CameraLensDirection.front) {
          _selectedCamera = cam;
          break;
        }
      }

      if (_selectedCamera == null && cameras.isNotEmpty) {
        _selectedCamera = cameras.first;
      }

      if (_selectedCamera == null) {
        _setCameraError(widget.config.noCameraFoundText);
        return;
      }

      _imageRotation = InputImageRotationValue.fromRawValue(
        _selectedCamera!.sensorOrientation,
      );

      await _startLiveFeed();
    } on CameraException catch (e) {
      _setCameraError(_cameraExceptionMessage(e));
    } catch (e) {
      _setCameraError(widget.config.cameraErrorText);
      if (kDebugMode) {
        print("Error starting camera: $e");
      }
    }
  }

  void _setCameraError(String message) {
    if (!mounted) return;
    setState(() {
      _cameraErrorMessage = message;
    });
  }

  String _cameraExceptionMessage(CameraException exception) {
    final code = exception.code.toLowerCase();
    if (code.contains('denied') || code.contains('permission')) {
      return widget.config.cameraPermissionRequiredText;
    }
    return exception.description ?? widget.config.cameraErrorText;
  }

  Future<void> _retryCamera() async {
    setState(() {
      _cameraErrorMessage = null;
    });
    await _cameraController?.dispose();
    _cameraController = null;
    await _initializeCamera();
  }

  Future<void> _startLiveFeed() async {
    if (_selectedCamera == null) return;

    _cameraController = CameraController(
      _selectedCamera!,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await _cameraController?.initialize();
    if (!mounted) return;

    await _cameraController?.startImageStream(_processCameraImage);
    setState(() {});
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessingImage ||
        _state == _LivenessState.capturing ||
        _state == _LivenessState.completed) {
      return;
    }
    _isProcessingImage = true;

    try {
      final Uint8List bytes;
      if (image.planes.length == 1) {
        bytes = image.planes[0].bytes;
      } else {
        final WriteBuffer allBytes = WriteBuffer();
        for (final Plane plane in image.planes) {
          allBytes.putUint8List(plane.bytes);
        }
        bytes = allBytes.done().buffer.asUint8List();
      }

      final Size imageSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );

      final imageRotation = _imageRotation ??
          InputImageRotationValue.fromRawValue(
            _selectedCamera?.sensorOrientation ?? 0,
          ) ??
          InputImageRotation.rotation0deg;

      final inputImageFormat =
          InputImageFormatValue.fromRawValue(image.format.raw);
      if (inputImageFormat == null) return;

      final inputImageData = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: inputImageData,
      );

      await _processImage(inputImage);
    } catch (e) {
      if (kDebugMode) {
        print("Error processing camera image: $e");
      }
    } finally {
      _isProcessingImage = false;
    }
  }

  Future<void> _processImage(InputImage inputImage) async {
    final faces = await _faceDetector.processImage(inputImage);

    if (faces.isEmpty) {
      if (_state == _LivenessState.awaitingStraightFace && mounted) {
        setState(() {
          _instructionMessage = widget.config.faceLostInstruction;
        });
      }
      return;
    }

    if (faces.length > 1) {
      if (mounted) {
        setState(() {
          _instructionMessage = widget.config.multipleFacesInstruction;
        });
      }
      return;
    }

    final face = faces.first;
    await _checkLiveness(face);
  }

  bool _isFaceStraight(Face face) {
    final yaw = (face.headEulerAngleY ?? 0.0).abs();
    final pitch = (face.headEulerAngleX ?? 0.0).abs();
    final roll = (face.headEulerAngleZ ?? 0.0).abs();
    final leftEye = face.leftEyeOpenProbability ?? 1.0;
    final rightEye = face.rightEyeOpenProbability ?? 1.0;

    return yaw <= widget.config.straightHeadYawThreshold &&
        pitch <= widget.config.straightHeadPitchThreshold &&
        roll <= widget.config.straightHeadRollThreshold &&
        leftEye >= widget.config.minEyeOpenProbability &&
        rightEye >= widget.config.minEyeOpenProbability;
  }

  Future<void> _checkLiveness(Face face) async {
    if (_isAdvancing ||
        _state == _LivenessState.capturing ||
        _state == _LivenessState.completed) {
      return;
    }

    if (mounted) {
      setState(() {
        _currentFace = face;
      });
    }

    if (_state == _LivenessState.verifyingSteps) {
      if (_remainingSteps.isEmpty) {
        _transitionToStraightCapture(face);
        return;
      }

      final currentStep = _remainingSteps.first;
      bool stepPassed = false;

      switch (currentStep) {
        case LivenessStepItem.blink:
          final leftEye = face.leftEyeOpenProbability ?? 1.0;
          final rightEye = face.rightEyeOpenProbability ?? 1.0;
          if (leftEye < widget.config.blinkProbabilityThreshold &&
              rightEye < widget.config.blinkProbabilityThreshold) {
            stepPassed = true;
          }
          break;

        case LivenessStepItem.smile:
          final smile = face.smilingProbability ?? 0.0;
          if (smile > widget.config.smileProbabilityThreshold) {
            stepPassed = true;
          }
          break;

        case LivenessStepItem.turnHeadLeft:
          final yaw = face.headEulerAngleY;
          if (yaw != null && yaw < -widget.config.headTurnAngleThreshold) {
            stepPassed = true;
          }
          break;

        case LivenessStepItem.turnHeadRight:
          final yaw = face.headEulerAngleY;
          if (yaw != null && yaw > widget.config.headTurnAngleThreshold) {
            stepPassed = true;
          }
          break;

        case LivenessStepItem.lookStraight:
          if (_isFaceStraight(face)) {
            stepPassed = true;
          }
          break;
      }

      if (stepPassed) {
        await _advanceStep(face);
      }
    } else if (_state == _LivenessState.awaitingStraightFace) {
      if (_isFaceStraight(face)) {
        _consecutiveStraightFrames++;
        if (_consecutiveStraightFrames >= widget.config.straightHoldFrames) {
          await _captureFinalPhotoAndComplete();
        }
      } else {
        _consecutiveStraightFrames = 0;
        if (mounted &&
            _instructionMessage != widget.config.lookStraightInstruction) {
          setState(() {
            _instructionMessage = widget.config.lookStraightInstruction;
          });
        }
      }
    }
  }

  Future<void> _advanceStep(Face currentFace) async {
    if (_isAdvancing) return;
    _isAdvancing = true;

    _remainingSteps.removeAt(0);

    if (_remainingSteps.isEmpty) {
      _transitionToStraightCapture(currentFace);
    } else {
      if (mounted) {
        setState(() {
          _updateInstructionForCurrentStep();
        });
      }
    }

    // Debounce to allow user to transition naturally to the next action
    await Future.delayed(const Duration(milliseconds: 300));
    _isAdvancing = false;
  }

  void _transitionToStraightCapture(Face currentFace) {
    _state = _LivenessState.awaitingStraightFace;
    _consecutiveStraightFrames = 0;

    if (_isFaceStraight(currentFace)) {
      _consecutiveStraightFrames = 1;
    }

    if (mounted) {
      setState(() {
        _instructionMessage = widget.config.lookStraightInstruction;
      });
    }

    if (_consecutiveStraightFrames >= widget.config.straightHoldFrames) {
      _captureFinalPhotoAndComplete();
    }
  }

  Future<void> _captureSilentPhoto() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        if (_cameraController!.value.isStreamingImages) {
          await _cameraController!.stopImageStream();
          // Short pause so camera pipeline cleanly transitions from stream to still photo
          await Future.delayed(const Duration(milliseconds: 200));
        }
        final photo = await _cameraController!.takePicture();

        // Bake orientation so the image is physically upright with correct dimensions
        try {
          final photoFile = File(photo.path);
          final bytes = await photoFile.readAsBytes();
          final decoded = image_lib.decodeImage(bytes);
          if (decoded != null) {
            final upright = image_lib.bakeOrientation(decoded);
            await photoFile.writeAsBytes(
              image_lib.encodeJpg(upright, quality: 95),
            );
          }
        } catch (e) {
          if (kDebugMode) {
            print("Error baking photo orientation: $e");
          }
        }

        if (mounted) {
          setState(() {
            _capturedPhoto = photo;
          });
        }
      } catch (e) {
        if (kDebugMode) {
          print("Error taking photo: $e");
        }
      }
    }
  }

  Future<void> _captureFinalPhotoAndComplete() async {
    if (_state == _LivenessState.capturing ||
        _state == _LivenessState.completed) {
      return;
    }
    _state = _LivenessState.capturing;

    if (mounted) {
      setState(() {
        _instructionMessage = widget.config.capturingInstruction;
      });
    }

    // Capture the verified frontal photo while the head is straight
    await _captureSilentPhoto();

    _state = _LivenessState.completed;
    if (mounted) {
      setState(() {
        _instructionMessage = widget.config.successInstruction;
      });
    }

    await _cameraController?.dispose();
    _cameraController = null;

    // Show the success state and thumbnail briefly, then pop the result
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      Navigator.pop(
        context,
        LivenessResult(
          isProven: true,
          imagePath: _capturedPhoto?.path,
        ),
      );
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = _state == _LivenessState.completed;
    final totalSteps = widget.config.steps.length + 1; // +1 for straight face capture
    final completedChallenges = widget.config.steps.length - _remainingSteps.length;
    final straightCapturedValue = (_state == _LivenessState.awaitingStraightFace &&
            _consecutiveStraightFrames > 0) ||
        _state == _LivenessState.capturing ||
        _state == _LivenessState.completed
        ? 1
        : 0;
    final progressValue =
        ((completedChallenges + straightCapturedValue) / totalSteps).clamp(0.0, 1.0);

    final isFaceStraight = _currentFace != null && _isFaceStraight(_currentFace!);
    final effectiveBorderColor = isFaceStraight
        ? (widget.config.guideStraightBorderColor ?? widget.config.successColor)
        : widget.config.guideBorderColor;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, const LivenessResult(isProven: false));
      },
      child: Scaffold(
        backgroundColor: widget.config.backgroundColor,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Camera Feed (Background)
            if (isSuccess)
              Container(color: widget.config.backgroundColor)
            else if (_cameraController != null &&
                _cameraController!.value.isInitialized)
              CameraPreview(_cameraController!)
            else if (_cameraErrorMessage != null)
              Container(color: widget.config.backgroundColor)
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // 2. Face Guide Overlay (The Cutout)
            if (!isSuccess &&
                _cameraController != null &&
                _cameraController!.value.isInitialized)
              CustomPaint(
                painter: FaceGuidePainter(
                  overlayColor: widget.config.overlayColor,
                  borderColor: effectiveBorderColor,
                  widthFactor: widget.config.ovalWidthFactor,
                  heightFactor: widget.config.ovalHeightFactor,
                  verticalOffset: widget.config.ovalVerticalOffset,
                ),
                child: Container(),
              ),

            // 3. Top Bar
            Positioned(
              top: 50,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(
                      context,
                      const LivenessResult(isProven: false),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.config.closeButtonBackgroundColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        color: widget.config.closeButtonColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: widget.config.titleBackgroundColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.config.titleText,
                      style: TextStyle(
                        color: widget.config.titleTextColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            if (_cameraErrorMessage != null && !isSuccess)
              _CameraErrorView(
                message: _cameraErrorMessage!,
                buttonText: widget.config.tryAgainButtonText,
                onRetry: _retryCamera,
              ),

            // 4. Success Overlay
            if (isSuccess)
              Container(
                color: widget.config.overlayColor,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_capturedPhoto != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          width: 150,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: widget.config.successColor,
                              width: 3,
                            ),
                            image: DecorationImage(
                              image: FileImage(File(_capturedPhoto!.path)),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      TweenAnimationBuilder(
                        tween: Tween<double>(begin: 0.5, end: 1.0),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.elasticOut,
                        builder: (context, scale, child) {
                          return Transform.scale(
                            scale: scale,
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: widget.config.successColor,
                              size: 100,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

            // 5. Bottom Instructions Panel
            if (_cameraErrorMessage == null)
              Positioned(
                bottom: 40,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: widget.config.cardBackgroundColor,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                    border: Border.all(
                      color: widget.config.cardBorderColor,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _instructionMessage,
                        style: TextStyle(
                          color: widget.config.instructionTextColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (!isSuccess) ...[
                        const SizedBox(height: 8),
                        Text(
                          _getStepSubtitle(),
                          style: TextStyle(
                            fontSize: 14,
                            color: widget.config.subInstructionTextColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          child: LinearProgressIndicator(
                            value: progressValue,
                            minHeight: 8,
                            backgroundColor:
                                widget.config.progressBarBackgroundColor,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.config.successColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CameraErrorView extends StatelessWidget {
  final String message;
  final String buttonText;
  final VoidCallback onRetry;

  const _CameraErrorView({
    required this.message,
    required this.buttonText,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.redAccent,
                size: 48,
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(buttonText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FaceGuidePainter extends CustomPainter {
  final Color overlayColor;
  final Color borderColor;
  final double widthFactor;
  final double heightFactor;
  final double verticalOffset;

  FaceGuidePainter({
    required this.overlayColor,
    required this.borderColor,
    this.widthFactor = 0.65,
    this.heightFactor = 1.35,
    this.verticalOffset = -40.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double ovalWidth = size.width * widthFactor;
    final double ovalHeight = ovalWidth * heightFactor;

    final Rect centralOval = Rect.fromCenter(
      center: Offset(size.width / 2, (size.height / 2) + verticalOffset),
      width: ovalWidth,
      height: ovalHeight,
    );

    final bgPaint = Paint()..color = overlayColor;
    final bgPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final ovalPath = Path()..addOval(centralOval);

    final resultPath = Path.combine(PathOperation.difference, bgPath, ovalPath);
    canvas.drawPath(resultPath, bgPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawOval(centralOval, borderPaint);
    _drawCorners(canvas, centralOval, borderPaint);
  }

  void _drawCorners(Canvas canvas, Rect rect, Paint paint) {
    const length = 20.0;
    // Top Left
    canvas.drawLine(
      rect.topLeft,
      rect.topLeft + const Offset(length, 0),
      paint,
    );
    canvas.drawLine(
      rect.topLeft,
      rect.topLeft + const Offset(0, length),
      paint,
    );
    // Top Right
    canvas.drawLine(
      rect.topRight,
      rect.topRight + const Offset(-length, 0),
      paint,
    );
    canvas.drawLine(
      rect.topRight,
      rect.topRight + const Offset(0, length),
      paint,
    );
    // Bottom Left
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft + const Offset(length, 0),
      paint,
    );
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft + const Offset(0, -length),
      paint,
    );
    // Bottom Right
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight + const Offset(-length, 0),
      paint,
    );
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight + const Offset(0, -length),
      paint,
    );
  }

  @override
  bool shouldRepaint(FaceGuidePainter oldDelegate) =>
      overlayColor != oldDelegate.overlayColor ||
      borderColor != oldDelegate.borderColor ||
      widthFactor != oldDelegate.widthFactor ||
      heightFactor != oldDelegate.heightFactor ||
      verticalOffset != oldDelegate.verticalOffset;
}
