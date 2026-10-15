library;

import 'package:flutter/material.dart';

import 'src/face_liveness_screen.dart';
import 'src/liveness_config.dart';

export 'src/face_liveness_screen.dart';
export 'src/liveness_config.dart';

/// Convenient entrypoint class to launch the facial liveness flow.
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
}
