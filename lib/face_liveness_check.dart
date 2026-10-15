library;

import 'package:flutter/material.dart';

import 'src/face_liveness_screen.dart';
import 'src/face_match_service.dart';
import 'src/liveness_config.dart';

export 'package:image_picker/image_picker.dart' show ImageSource, CameraDevice;
export 'src/face_liveness_screen.dart';
export 'src/face_match_service.dart';
export 'src/liveness_config.dart';

/// Convenient entrypoint class to launch the facial liveness flow and matching services.
class FaceLivenessCheck {
  const FaceLivenessCheck._();

  /// Launches the liveness verification screen with optional [config]
  /// and returns the resulting [LivenessResult].
  ///
  /// Example:
  /// ```dart
  /// final result = await FaceLivenessCheck.start(
  ///   context,
  ///   config: const LivenessConfig(
  ///     titleText: 'Identity Verification',
  ///     successColor: Color(0xFF14B8A6),
  ///   ),
  /// );
  ///
  /// if (result?.isProven == true) {
  ///   final photoPath = result!.imagePath;
  /// }
  /// ```
  static Future<LivenessResult?> start(
    BuildContext context, {
    LivenessConfig config = const LivenessConfig(),
    RouteSettings? routeSettings,
  }) {
    return Navigator.push<LivenessResult>(
      context,
      MaterialPageRoute<LivenessResult>(
        builder: (_) => FaceLivenessScreen(config: config),
        settings: routeSettings,
      ),
    );
  }

  /// Compares a liveness reference photo against a comparison photo (e.g. ID card or selfie)
  /// using the on-device MobileFaceNet model.
  static Future<FaceMatchResult> compareFaces({
    required String livenessImagePath,
    required String comparisonImagePath,
    int matchThreshold = 65,
    String modelAsset = FaceMatchService.defaultModelAsset,
  }) async {
    final service = FaceMatchService(
      modelAsset: modelAsset,
      matchThreshold: matchThreshold,
    );
    try {
      return await service.compare(
        livenessImagePath: livenessImagePath,
        comparisonImagePath: comparisonImagePath,
      );
    } finally {
      await service.dispose();
    }
  }
}
