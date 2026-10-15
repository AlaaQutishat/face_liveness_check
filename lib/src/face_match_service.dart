import 'dart:io';
import 'dart:math' as math;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as image_lib;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Service providing on-device 1:1 facial matching using MobileFaceNet TFLite
/// and Google ML Kit Face Detection.
class FaceMatchService {
  static const String defaultModelAsset =
      'packages/face_liveness_check/assets/mobilefacenet.tflite';
  static const double _minimumFaceAreaRatio = 0.025;
  static const double _minimumReadableBrightness = 25.0;
  static const double _maximumReadableBrightness = 235.0;
  static const double _lowLightWarningBrightness = 50.0;
  static const double _highLightWarningBrightness = 215.0;

  final String modelAsset;
  final int matchThreshold;

  final FaceDetector _faceDetector;
  Interpreter? _interpreter;

  FaceMatchService({
    this.modelAsset = defaultModelAsset,
    this.matchThreshold = 65,
    FaceDetector? customFaceDetector,
  }) : _faceDetector =
           customFaceDetector ??
           FaceDetector(
             options: FaceDetectorOptions(
               enableClassification: true,
               enableLandmarks: true,
               performanceMode: FaceDetectorMode.accurate,
             ),
           );

  /// Compares a liveness reference photo against a comparison photo (e.g. ID card or selfie).
  Future<FaceMatchResult> compare({
    required String livenessImagePath,
    required String comparisonImagePath,
  }) async {
    final interpreter = await _ensureInterpreter();
    final livenessSample = await _extractFaceSample(
      livenessImagePath,
      label: 'liveness photo',
    );
    final comparisonSample = await _extractFaceSample(
      comparisonImagePath,
      label: 'comparison photo',
    );

    final livenessEmbedding = _runModel(interpreter, livenessSample.faceImage);
    final comparisonEmbedding = _runModel(
      interpreter,
      comparisonSample.faceImage,
    );

    final similarity = _cosineSimilarity(
      livenessEmbedding,
      comparisonEmbedding,
    );
    final matchLevel = (similarity.clamp(0.0, 1.0) * 100).round();
    final isMatch = matchLevel >= matchThreshold;
    final qualityNotes = [
      livenessSample.qualityNote,
      comparisonSample.qualityNote,
    ].nonNulls.join(' ');

    return FaceMatchResult(
      matchLevel: matchLevel,
      isMatch: isMatch,
      message: isMatch ? 'Images are similar.' : 'Images do not match.',
      qualityNote: qualityNotes.isEmpty ? null : qualityNotes,
    );
  }

  /// Releases resources (interpreter and face detector).
  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
    await _faceDetector.close();
  }

  Future<Interpreter> _ensureInterpreter() async {
    final existingInterpreter = _interpreter;
    if (existingInterpreter != null) {
      return existingInterpreter;
    }

    final options = InterpreterOptions()..threads = 2;
    try {
      try {
        final interpreter = await Interpreter.fromAsset(
          modelAsset,
          options: options,
        );
        _interpreter = interpreter;
        return interpreter;
      } catch (_) {
        // Fallback for root asset path vs package asset path
        final fallbackAsset =
            modelAsset.startsWith('packages/face_liveness_check/')
                ? modelAsset.replaceFirst('packages/face_liveness_check/', '')
                : 'packages/face_liveness_check/$modelAsset';
        final interpreter = await Interpreter.fromAsset(
          fallbackAsset,
          options: options,
        );
        _interpreter = interpreter;
        return interpreter;
      }
    } finally {
      options.delete();
    }
  }

  Future<_FaceSample> _extractFaceSample(
    String imagePath, {
    required String label,
  }) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw FaceMatchException(
        'The $label could not be found. Please try again.',
      );
    }

    final bytes = await file.readAsBytes();
    final decoded = image_lib.decodeImage(bytes);
    if (decoded == null) {
      throw FaceMatchException(
        'The $label could not be read. Please use a clear JPG or PNG image.',
      );
    }

    // 1. Bake orientation first so pixel data is physically upright (0° rotation)
    final orientedImage = image_lib.bakeOrientation(decoded);

    // 2. Run face detection on the normalized upright image
    final tempDir = Directory.systemTemp;
    final tempFile = File(
      '${tempDir.path}/norm_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await tempFile.writeAsBytes(
      image_lib.encodeJpg(orientedImage, quality: 95),
    );

    List<Face> faces;
    try {
      faces = await _faceDetector.processImage(
        InputImage.fromFilePath(tempFile.path),
      );
    } finally {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }

    // Fallback: try original file if normalized temp detection was empty
    if (faces.isEmpty) {
      faces = await _faceDetector.processImage(
        InputImage.fromFilePath(imagePath),
      );
    }

    if (faces.isEmpty) {
      throw FaceMatchException(
        'No clear face was found in the $label. Center one face in good light and try again.',
      );
    }
    if (faces.length > 1) {
      throw FaceMatchException(
        'More than one face was found in the $label. Please use an image with only one person.',
      );
    }

    final face = faces.first;
    final crop = _cropFace(orientedImage, face);
    final qualityNote = _validateQuality(
      face: face,
      crop: crop,
      sourceImage: orientedImage,
      label: label,
    );

    return _FaceSample(faceImage: crop, qualityNote: qualityNote);
  }

  image_lib.Image _cropFace(image_lib.Image sourceImage, Face face) {
    final box = face.boundingBox;
    final horizontalPadding = box.width * 0.25;
    final topPadding = box.height * 0.35;
    final bottomPadding = box.height * 0.20;

    final left = _clampInt(
      box.left - horizontalPadding,
      0,
      sourceImage.width - 1,
    );
    final top = _clampInt(box.top - topPadding, 0, sourceImage.height - 1);
    final right = _clampInt(
      box.right + horizontalPadding,
      left + 1,
      sourceImage.width,
    );
    final bottom = _clampInt(
      box.bottom + bottomPadding,
      top + 1,
      sourceImage.height,
    );

    return image_lib.copyCrop(
      sourceImage,
      x: left,
      y: top,
      width: right - left,
      height: bottom - top,
    );
  }

  String? _validateQuality({
    required Face face,
    required image_lib.Image crop,
    required image_lib.Image sourceImage,
    required String label,
  }) {
    final faceArea = face.boundingBox.width * face.boundingBox.height;
    final imageArea = sourceImage.width * sourceImage.height;
    if (faceArea / imageArea < _minimumFaceAreaRatio) {
      throw FaceMatchException(
        'The face in the $label is too small. Move closer and try again.',
      );
    }

    final brightness = _averageBrightness(crop);
    if (brightness < _minimumReadableBrightness) {
      throw FaceMatchException(
        'The $label is too dark to compare reliably. Try again in better lighting.',
      );
    }
    if (brightness > _maximumReadableBrightness) {
      throw FaceMatchException(
        'The $label is overexposed. Reduce glare and try again.',
      );
    }

    final yaw = face.headEulerAngleY?.abs() ?? 0.0;
    final roll = face.headEulerAngleZ?.abs() ?? 0.0;
    if (yaw > 35 || roll > 28) {
      throw FaceMatchException(
        'The face in the $label is not facing the camera clearly. Retake it straight on.',
      );
    }

    if (brightness < _lowLightWarningBrightness) {
      return 'Lighting is low, so the score may be less reliable.';
    }
    if (brightness > _highLightWarningBrightness) {
      return 'Bright glare may reduce matching accuracy.';
    }
    return null;
  }

  double _averageBrightness(image_lib.Image image) {
    final sample = image_lib.copyResize(image, width: 32, height: 32);
    var total = 0.0;
    var count = 0;

    for (final pixel in sample) {
      total += (0.2126 * pixel.r) + (0.7152 * pixel.g) + (0.0722 * pixel.b);
      count++;
    }

    return count == 0 ? 0.0 : total / count;
  }

  List<double> _runModel(Interpreter interpreter, image_lib.Image faceImage) {
    final inputShape = interpreter.getInputTensor(0).shape;
    final outputShape = interpreter.getOutputTensor(0).shape;
    final input = _imageToInput(faceImage, inputShape);
    final output = List<double>.filled(
      _elementCount(outputShape),
      0.0,
    ).reshape(outputShape);

    interpreter.run(input, output);
    return _flattenNumbers(output).toList(growable: false);
  }

  Object _imageToInput(image_lib.Image faceImage, List<int> shape) {
    if (shape.length != 4 || shape.first != 1) {
      throw FaceMatchException(
        'The face matching model has an unsupported input shape.',
      );
    }

    final isChannelFirst = shape[1] == 3;
    final height = isChannelFirst ? shape[2] : shape[1];
    final width = isChannelFirst ? shape[3] : shape[2];
    final channels = isChannelFirst ? shape[1] : shape[3];

    if (channels != 3) {
      throw FaceMatchException(
        'The face matching model expects a three-channel image.',
      );
    }

    final resized = image_lib.copyResize(
      faceImage,
      width: width,
      height: height,
      interpolation: image_lib.Interpolation.linear,
    );

    double normalize(num value) => (value - 127.5) / 128.0;

    if (isChannelFirst) {
      return [
        List.generate(
          channels,
          (channel) => List.generate(
            height,
            (y) => List.generate(width, (x) {
              final pixel = resized.getPixel(x, y);
              return switch (channel) {
                0 => normalize(pixel.r),
                1 => normalize(pixel.g),
                _ => normalize(pixel.b),
              };
            }),
          ),
        ),
      ];
    }

    return [
      List.generate(
        height,
        (y) => List.generate(width, (x) {
          final pixel = resized.getPixel(x, y);
          return [normalize(pixel.r), normalize(pixel.g), normalize(pixel.b)];
        }),
      ),
    ];
  }

  Iterable<double> _flattenNumbers(Object value) sync* {
    if (value is List) {
      for (final item in value) {
        yield* _flattenNumbers(item as Object);
      }
    } else if (value is num) {
      yield value.toDouble();
    }
  }

  double _cosineSimilarity(List<double> first, List<double> second) {
    if (first.length != second.length || first.isEmpty) {
      throw FaceMatchException('The face embeddings could not be compared.');
    }

    var dot = 0.0;
    var firstMagnitude = 0.0;
    var secondMagnitude = 0.0;
    for (var index = 0; index < first.length; index++) {
      dot += first[index] * second[index];
      firstMagnitude += first[index] * first[index];
      secondMagnitude += second[index] * second[index];
    }

    if (firstMagnitude == 0 || secondMagnitude == 0) {
      throw FaceMatchException('The face embeddings were empty.');
    }

    return dot / (math.sqrt(firstMagnitude) * math.sqrt(secondMagnitude));
  }

  int _elementCount(List<int> shape) {
    return shape.fold(1, (total, value) => total * value);
  }

  int _clampInt(num value, int min, int max) {
    return value.round().clamp(min, max).toInt();
  }
}

/// The result returned by [FaceMatchService.compare].
class FaceMatchResult {
  final int matchLevel;
  final bool isMatch;
  final String message;
  final String? qualityNote;

  const FaceMatchResult({
    required this.matchLevel,
    required this.isMatch,
    required this.message,
    this.qualityNote,
  });
}

/// Exception thrown when face matching fails or detects quality issues.
class FaceMatchException implements Exception {
  final String message;

  const FaceMatchException(this.message);

  @override
  String toString() => message;
}

class _FaceSample {
  final image_lib.Image faceImage;
  final String? qualityNote;

  const _FaceSample({required this.faceImage, required this.qualityNote});
}
