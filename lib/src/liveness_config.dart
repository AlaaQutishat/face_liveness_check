import 'package:flutter/material.dart';

/// Supported challenge steps in the face liveness verification flow.
enum LivenessStepItem {
  blink,
  smile,
  turnHeadLeft,
  turnHeadRight,
  lookStraight,
}

/// Signature for custom formatting of step indicator and hint subtitle.
typedef StepFormatBuilder = String Function(
  int currentStep,
  int totalSteps,
  String stepHint,
);

/// Comprehensive configuration for customizing UI colors, localized strings,
/// detection sensitivity, and layout in [FaceLivenessScreen].
class LivenessConfig {
  /// The specific steps the user must perform to pass liveness.
  /// If not provided, defaults to: [blink, smile, turnHeadLeft, turnHeadRight].
  ///
  /// Regardless of the configured steps, the final verified photo is ALWAYS
  /// captured when the user's head is straight, centered, and eyes are open.
  final List<LivenessStepItem> steps;

  /// Language code identifier (e.g. 'en', 'ar').
  final String languageCode;

  // ---------------------------------------------------------------------------
  // Translations & Instructions (Fully Localizable)
  // ---------------------------------------------------------------------------
  final String titleText;
  final String blinkInstruction;
  final String smileInstruction;
  final String turnLeftInstruction;
  final String turnRightInstruction;
  final String lookStraightInstruction;
  final String capturingInstruction;
  final String successInstruction;
  final String faceLostInstruction;
  final String multipleFacesInstruction;

  // Subtitle hints for each action
  final String blinkHint;
  final String smileHint;
  final String turnLeftHint;
  final String turnRightHint;
  final String lookStraightHint;
  final String awaitingStraightHint;

  // Error view strings
  final String cameraPermissionRequiredText;
  final String noCameraFoundText;
  final String cameraErrorText;
  final String tryAgainButtonText;

  /// Custom builder for formatting the subtitle below the instruction.
  /// If null, defaults to: `"Step $currentStep of $totalSteps • $stepHint"`.
  final StepFormatBuilder? stepFormatBuilder;

  // ---------------------------------------------------------------------------
  // UI Colors & Styling
  // ---------------------------------------------------------------------------
  final Color backgroundColor;
  final Color overlayColor;
  final Color successColor;
  final Color guideBorderColor;
  final Color? guideStraightBorderColor;
  final Color instructionTextColor;
  final Color subInstructionTextColor;
  final Color titleTextColor;
  final Color titleBackgroundColor;
  final Color progressBarBackgroundColor;
  final Color closeButtonColor;
  final Color closeButtonBackgroundColor;
  final Color cardBackgroundColor;
  final Color cardBorderColor;

  // ---------------------------------------------------------------------------
  // Oval Layout Geometry
  // ---------------------------------------------------------------------------
  /// Fraction of screen width for the cutout oval. Default is 0.65.
  final double ovalWidthFactor;

  /// Multiplier of oval width to determine oval height. Default is 1.35.
  final double ovalHeightFactor;

  /// Vertical offset of the cutout oval from screen center. Default is -40.0.
  final double ovalVerticalOffset;

  // ---------------------------------------------------------------------------
  // ML Detection Thresholds
  // ---------------------------------------------------------------------------
  /// Maximum head yaw angle (in degrees) to be considered straight. Default is 10.0°.
  final double straightHeadYawThreshold;

  /// Maximum head pitch angle (in degrees) to be considered straight. Default is 12.0°.
  final double straightHeadPitchThreshold;

  /// Maximum head roll angle (in degrees) to be considered straight. Default is 12.0°.
  final double straightHeadRollThreshold;

  /// Minimum probability required for an eye to be considered open when capturing straight face. Default is 0.5.
  final double minEyeOpenProbability;

  /// Probability threshold above which a smile is detected. Default is 0.35.
  final double smileProbabilityThreshold;

  /// Probability threshold below which an eye is considered closed (blink). Default is 0.2.
  final double blinkProbabilityThreshold;

  /// Minimum angle (in degrees) required for turning head left or right. Default is 30.0°.
  final double headTurnAngleThreshold;

  /// Number of consecutive straight frames required before taking the photo to prevent motion blur. Default is 3.
  final int straightHoldFrames;

  const LivenessConfig({
    this.steps = const [
      LivenessStepItem.blink,
      LivenessStepItem.smile,
      LivenessStepItem.turnHeadLeft,
      LivenessStepItem.turnHeadRight,
    ],
    this.languageCode = 'en',
    // Texts
    this.titleText = "Face Verification",
    this.blinkInstruction = "Please Blink Your Eyes",
    this.smileInstruction = "Please Smile",
    this.turnLeftInstruction = "Turn Head Left",
    this.turnRightInstruction = "Turn Head Right",
    this.lookStraightInstruction = "Please Look Straight at the Camera",
    this.capturingInstruction = "Hold Still...",
    this.successInstruction = "Completed!",
    this.faceLostInstruction = "Face lost!\nPlease center your face in the oval",
    this.multipleFacesInstruction =
        "Please ensure only one face is in the frame.",
    // Subtitle hints
    this.blinkHint = "Blink your eyes naturally",
    this.smileHint = "Show a natural smile",
    this.turnLeftHint = "Turn your head slightly to the left",
    this.turnRightHint = "Turn your head slightly to the right",
    this.lookStraightHint = "Look directly at the camera",
    this.awaitingStraightHint = "Align your face in the center and hold steady",
    // Error texts
    this.cameraPermissionRequiredText =
        "Camera permission is required for liveness verification.",
    this.noCameraFoundText = "No camera was found on this device.",
    this.cameraErrorText = "Camera could not be started. Please try again.",
    this.tryAgainButtonText = "Try Again",
    this.stepFormatBuilder,
    // Colors
    this.backgroundColor = Colors.black,
    this.overlayColor = Colors.black87,
    this.successColor = Colors.greenAccent,
    this.guideBorderColor = Colors.white54,
    this.guideStraightBorderColor,
    this.instructionTextColor = Colors.white,
    this.subInstructionTextColor = Colors.white70,
    this.titleTextColor = Colors.white,
    this.titleBackgroundColor = Colors.black54,
    this.progressBarBackgroundColor = Colors.white24,
    this.closeButtonColor = Colors.white,
    this.closeButtonBackgroundColor = Colors.black54,
    this.cardBackgroundColor = const Color(0x22FFFFFF),
    this.cardBorderColor = const Color(0x33FFFFFF),
    // Geometry
    this.ovalWidthFactor = 0.65,
    this.ovalHeightFactor = 1.35,
    this.ovalVerticalOffset = -40.0,
    // Thresholds
    this.straightHeadYawThreshold = 10.0,
    this.straightHeadPitchThreshold = 12.0,
    this.straightHeadRollThreshold = 12.0,
    this.minEyeOpenProbability = 0.5,
    this.smileProbabilityThreshold = 0.35,
    this.blinkProbabilityThreshold = 0.2,
    this.headTurnAngleThreshold = 30.0,
    this.straightHoldFrames = 3,
  });

  /// Factory preset for Arabic localization.
  factory LivenessConfig.arabic({
    List<LivenessStepItem>? steps,
    Color? successColor,
  }) {
    return LivenessConfig(
      steps: steps ??
          const [
            LivenessStepItem.blink,
            LivenessStepItem.smile,
            LivenessStepItem.turnHeadLeft,
            LivenessStepItem.turnHeadRight,
          ],
      languageCode: 'ar',
      titleText: "التحقق من حيوية الوجه",
      blinkInstruction: "يرجى أن ترمش بعينيك",
      smileInstruction: "يرجى أن تبتسم",
      turnLeftInstruction: "أدر رأسك لليسار",
      turnRightInstruction: "أدر رأسك لليمين",
      lookStraightInstruction: "يرجى النظر مباشرة إلى الكاميرا",
      capturingInstruction: "اثبت لالتقاط الصورة...",
      successInstruction: "تم التحقق بنجاح!",
      faceLostInstruction: "لم يتم التعرف على الوجه!\nيرجى التوسيط داخل الإطار",
      multipleFacesInstruction: "يرجى التأكد من وجود شخص واحد فقط أمام الكاميرا.",
      blinkHint: "ارمش بعينيك بشكل طبيعي",
      smileHint: "ابتسم بلطف أمام الكاميرا",
      turnLeftHint: "أدر وجهك قليلاً إلى جهة اليسار",
      turnRightHint: "أدر وجهك قليلاً إلى جهة اليمين",
      lookStraightHint: "انظر إلى الكاميرا مباشرة",
      awaitingStraightHint: "اضبط وجهك في المنتصف واثبت",
      cameraPermissionRequiredText: "إذن الكاميرا مطلوب للتحقق من الهوية.",
      noCameraFoundText: "لم يتم العثور على كاميرا في هذا الجهاز.",
      cameraErrorText: "تعذر تشغيل الكاميرا. يرجى المحاولة مرة أخرى.",
      tryAgainButtonText: "إعادة المحاولة",
      stepFormatBuilder: (current, total, hint) =>
          "الخطوة $current من $total • $hint",
      successColor: successColor ?? const Color(0xFF14B8A6),
    );
  }
}

/// The result returned by [FaceLivenessScreen] or [FaceLivenessCheck.start].
class LivenessResult {
  /// True if the user successfully completed all configured liveness steps.
  /// False if the user cancelled the flow or failed.
  final bool isProven;

  /// Absolute path to the captured frontal reference photo.
  /// Null if `isProven` is false or if photo capture failed.
  final String? imagePath;

  const LivenessResult({required this.isProven, this.imagePath});
}
