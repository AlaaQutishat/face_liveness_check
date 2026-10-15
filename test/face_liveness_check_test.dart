import 'package:face_liveness_check/face_liveness_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LivenessConfig', () {
    test('default configuration sets expected steps and thresholds', () {
      const config = LivenessConfig();

      expect(config.steps, [
        LivenessStepItem.blink,
        LivenessStepItem.smile,
        LivenessStepItem.turnHeadLeft,
        LivenessStepItem.turnHeadRight,
      ]);
      expect(config.straightHeadYawThreshold, 10.0);
      expect(config.minEyeOpenProbability, 0.5);
      expect(config.straightHoldFrames, 3);
      expect(config.lookStraightInstruction, isNotEmpty);
      expect(config.backgroundColor, Colors.black);
      expect(config.successColor, Colors.greenAccent);
    });

    test('custom configuration overrides defaults properly', () {
      const customColor = Color(0xFF6366F1);
      final config = LivenessConfig(
        steps: const [LivenessStepItem.lookStraight],
        titleText: 'Custom Title',
        successColor: customColor,
        straightHeadYawThreshold: 8.0,
        minEyeOpenProbability: 0.6,
        straightHoldFrames: 5,
        stepFormatBuilder: (current, total, hint) => '[$current/$total] $hint',
      );

      expect(config.steps.length, 1);
      expect(config.steps.first, LivenessStepItem.lookStraight);
      expect(config.titleText, 'Custom Title');
      expect(config.successColor, customColor);
      expect(config.straightHeadYawThreshold, 8.0);
      expect(config.minEyeOpenProbability, 0.6);
      expect(config.straightHoldFrames, 5);
      expect(config.stepFormatBuilder!(1, 3, 'Smile'), '[1/3] Smile');
    });

    test('arabic preset sets localized strings and RTL text', () {
      final config = LivenessConfig.arabic();

      expect(config.titleText, 'التحقق من حيوية الوجه');
      expect(config.blinkInstruction, 'يرجى أن ترمش بعينيك');
      expect(config.smileInstruction, 'يرجى أن تبتسم');
      expect(config.lookStraightInstruction, 'يرجى النظر مباشرة إلى الكاميرا');
      expect(config.successInstruction, 'تم التحقق بنجاح!');
      expect(config.stepFormatBuilder, isNotNull);
      expect(
        config.stepFormatBuilder!(1, 4, 'ارمش'),
        'الخطوة 1 من 4 • ارمش',
      );
    });
  });

  group('LivenessResult', () {
    test('result holds success status and image path', () {
      const result = LivenessResult(isProven: true, imagePath: '/path/to/img.jpg');
      expect(result.isProven, isTrue);
      expect(result.imagePath, '/path/to/img.jpg');
    });

    test('failed result defaults imagePath to null', () {
      const result = LivenessResult(isProven: false);
      expect(result.isProven, isFalse);
      expect(result.imagePath, isNull);
    });
  });
}
