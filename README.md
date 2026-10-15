# Face Liveness Check

A high-performance, fully customizable Flutter package for on-device real-time facial liveness detection powered by Google ML Kit.

Guarantees active human presence through customizable challenges (blink, smile, turn head) and **always captures a razor-sharp, frontal, upright reference photo** for biometric verification and KYC.

<p align="center">
  <img src="https://raw.githubusercontent.com/alaaqutishat/face_liveness_check/main/doc/images/showcase_banner.jpg" alt="Face Liveness Check Showcase" width="100%" />
</p>

---

## ✨ Features

- **⚡ 100% On-Device & Offline:** Powered by Google ML Kit Face Detection. Zero cloud latency, zero external API costs, and total user privacy.
- **🎯 Guaranteed Frontal Photo:** Regardless of the challenge order (even if the user turns their head on the final step), the engine automatically requires the user to face forward before snapping the photo.
- **🔄 Auto-Bake EXIF Orientation:** The captured JPEG is physically normalized to 0° upright orientation, preventing sideways-face bugs in downstream recognition algorithms.
- **🎨 Complete UI Customization:** Customize every color, overlay opacity, guide oval size, card border, button style, and progress bar.
- **🌍 Full Localization & Translation:** Customize every single instruction, hint, button, and error state. Includes a pre-built `LivenessConfig.arabic()` preset out of the box.
- **🚀 One-Line Launch:** Launch effortlessly using `FaceLivenessCheck.start(context)` or embed `FaceLivenessScreen` into your custom routes.
- **🛡️ Battle-Tested Architecture:** Camera stream pipeline optimized with cached sensor orientation, single-plane memory buffers, and motion-blur stabilization frames.

---

## 📐 Architecture & Pipeline

<p align="center">
  <img src="https://raw.githubusercontent.com/alaaqutishat/face_liveness_check/main/doc/images/architecture_workflow.jpg" alt="Face Liveness Check & 1:1 Biometric Matching Pipeline" width="100%" />
</p>

---

## 📱 Platform Setup

### iOS

1. Open `ios/Runner/Info.plist` and add the camera usage description:
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for facial liveness verification.</string>
```

2. Open `ios/Podfile` and ensure the minimum deployment target is set to **iOS 15.5** (required by Google ML Kit):
```ruby
platform :ios, '15.5'
```

---

### Android

1. Open `android/app/build.gradle` (or `build.gradle.kts`) and set `minSdkVersion` to at least **21**:
```kotlin
android {
    defaultConfig {
        minSdkVersion = 21
    }
}
```

2. Open `android/app/src/main/AndroidManifest.xml` and ensure camera permissions are declared:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" />
<uses-feature android:name="android.hardware.camera.front" />
```

---

## 🚀 Getting Started

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  face_liveness_check: ^1.0.0
```

Run:
```bash
flutter pub get
```

---

## 💡 Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:face_liveness_check/face_liveness_check.dart';

Future<void> verifyUser(BuildContext context) async {
  // Launch the verification screen
  final LivenessResult? result = await FaceLivenessCheck.start(
    context,
    config: const LivenessConfig(
      titleText: 'Identity Verification',
      successColor: Color(0xFF14B8A6),
    ),
  );

  if (result == null) {
    // User cancelled
    return;
  }

  if (result.isProven) {
    print('Liveness Passed!');
    print('Guaranteed frontal photo path: ${result.imagePath}');
  } else {
    print('Liveness verification failed or was cancelled.');
  }
}
```

---

## ⚙️ Advanced Customization

### 1. Selecting Specific Challenge Steps

You can choose which challenges the user must perform and in what order:

```dart
final config = LivenessConfig(
  steps: const [
    LivenessStepItem.blink,
    LivenessStepItem.smile,
    LivenessStepItem.turnHeadLeft,
    LivenessStepItem.turnHeadRight,
    LivenessStepItem.lookStraight, // Optional explicit step
  ],
);
```

> **Note:** Even if `LivenessStepItem.lookStraight` is omitted, the final photo capture step **always** requires the user to face forward with open eyes before snapping the photo.

---

### 2. Localization & Translations

Every string shown to the user can be localized.

#### Pre-built Arabic Preset:
```dart
final arabicConfig = LivenessConfig.arabic(
  steps: [
    LivenessStepItem.blink,
    LivenessStepItem.smile,
    LivenessStepItem.turnHeadRight,
  ],
  successColor: const Color(0xFF10B981),
);
```

#### Custom Translations (e.g. Spanish, French, German, or custom wording):
```dart
final customConfig = LivenessConfig(
  titleText: 'Verificación Facial',
  blinkInstruction: 'Por favor, parpadee',
  smileInstruction: 'Por favor, sonría',
  turnLeftInstruction: 'Gire la cabeza a la izquierda',
  turnRightInstruction: 'Gire la cabeza a la derecha',
  lookStraightInstruction: 'Mire directamente a la cámara',
  capturingInstruction: 'Manténgase quieto...',
  successInstruction: '¡Completado con éxito!',
  faceLostInstruction: 'Rostro no detectado.\nCentre su rostro en el óvalo.',
  multipleFacesInstruction: 'Asegúrese de que solo haya una persona en el encuadre.',
  blinkHint: 'Parpadee con naturalidad',
  smileHint: 'Muestre una sonrisa natural',
  turnLeftHint: 'Gire suavemente hacia la izquierda',
  turnRightHint: 'Gire suavemente hacia la derecha',
  awaitingStraightHint: 'Mire al frente y manténgase quieto',
  cameraPermissionRequiredText: 'Se requiere permiso de cámara para verificar su identidad.',
  noCameraFoundText: 'No se encontró ninguna cámara en este dispositivo.',
  cameraErrorText: 'No se pudo iniciar la cámara. Inténtelo de nuevo.',
  tryAgainButtonText: 'Reintentar',
  stepFormatBuilder: (current, total, hint) => 'Paso $current de $total • $hint',
);
```

---

### 3. Customizing Colors & Styling

```dart
final styledConfig = LivenessConfig(
  backgroundColor: Colors.black,
  overlayColor: const Color(0xDD000000),         // Darkened cutout overlay
  successColor: const Color(0xFF14B8A6),         // Progress bar & checkmark
  guideBorderColor: Colors.white54,              // Oval border in normal state
  guideStraightBorderColor: Color(0xFF14B8A6),   // Oval border when straight
  instructionTextColor: Colors.white,
  subInstructionTextColor: Colors.white70,
  titleTextColor: Colors.white,
  titleBackgroundColor: Colors.black45,
  progressBarBackgroundColor: Colors.white24,
  cardBackgroundColor: const Color(0x22FFFFFF),  // Bottom glassmorphic card
  cardBorderColor: const Color(0x33FFFFFF),
  closeButtonColor: Colors.white,
  closeButtonBackgroundColor: Colors.black45,
);
```

---

### 4. Customizing Detection Sensitivity & Geometry

```dart
final sensitiveConfig = LivenessConfig(
  // Geometry
  ovalWidthFactor: 0.68,              // Width of the face cutout oval (fraction of screen width)
  ovalHeightFactor: 1.35,             // Height multiplier of the oval
  ovalVerticalOffset: -30.0,          // Vertical offset from center
  
  // Detection Thresholds
  straightHeadYawThreshold: 8.0,      // Max yaw angle (in degrees) to consider face straight
  straightHeadPitchThreshold: 10.0,   // Max pitch angle (in degrees) to consider face straight
  straightHeadRollThreshold: 10.0,    // Max roll angle (in degrees) to consider face straight
  minEyeOpenProbability: 0.6,         // Eye open probability threshold for photo capture
  smileProbabilityThreshold: 0.4,     // Smile probability threshold
  blinkProbabilityThreshold: 0.15,    // Eye closed probability threshold
  headTurnAngleThreshold: 28.0,       // Turn angle threshold (in degrees)
  straightHoldFrames: 3,              // Number of stable frames required before snap
);
```

---

## 📋 Configuration Reference Table

| Property | Type | Default | Description |
|---|---|---|---|
| `steps` | `List<LivenessStepItem>` | `[blink, smile, turnLeft, turnRight]` | Sequence of challenges required to pass. |
| `titleText` | `String` | `'Face Verification'` | Title displayed in the top bar. |
| `blinkInstruction` | `String` | `'Please Blink Your Eyes'` | Instruction during blink challenge. |
| `smileInstruction` | `String` | `'Please Smile'` | Instruction during smile challenge. |
| `turnLeftInstruction` | `String` | `'Turn Head Left'` | Instruction during turn left challenge. |
| `turnRightInstruction` | `String` | `'Turn Head Right'` | Instruction during turn right challenge. |
| `lookStraightInstruction` | `String` | `'Please Look Straight at the Camera'` | Instruction during straight face alignment. |
| `capturingInstruction` | `String` | `'Hold Still...'` | Instruction during final photo snap. |
| `successInstruction` | `String` | `'Completed!'` | Instruction when verification succeeds. |
| `faceLostInstruction` | `String` | `'Face lost! Please center your face...'` | Shown when face leaves the camera frame. |
| `multipleFacesInstruction` | `String` | `'Please ensure only one face...'` | Shown when more than one face is detected. |
| `stepFormatBuilder` | `StepFormatBuilder?` | `null` | Custom formatter: `(current, total, hint) => '...'`. |
| `backgroundColor` | `Color` | `Colors.black` | Base background color of the screen. |
| `overlayColor` | `Color` | `Colors.black87` | Color of the mask outside the oval. |
| `successColor` | `Color` | `Colors.greenAccent` | Color of checkmark and completed progress. |
| `guideBorderColor` | `Color` | `Colors.white54` | Oval border color when awaiting alignment. |
| `guideStraightBorderColor` | `Color?` | `null (defaults to successColor)` | Oval border color when head is aligned straight. |
| `ovalWidthFactor` | `double` | `0.65` | Oval width ratio relative to screen width. |
| `ovalHeightFactor` | `double` | `1.35` | Oval height multiplier relative to width. |
| `ovalVerticalOffset` | `double` | `-40.0` | Vertical offset of oval from screen center. |
| `straightHeadYawThreshold` | `double` | `10.0` | Max yaw in degrees for straight face. |
| `straightHeadPitchThreshold` | `double` | `12.0` | Max pitch in degrees for straight face. |
| `minEyeOpenProbability` | `double` | `0.5` | Minimum eye openness required for photo capture. |
| `straightHoldFrames` | `int` | `3` | Consecutive frames required before taking photo. |

---

## 📦 Result Object (`LivenessResult`)

The method `FaceLivenessCheck.start(context)` returns a `LivenessResult?`:

- `isProven` (`bool`): `true` if the user completed all challenges and the frontal photo was captured. `false` if cancelled or failed.
- `imagePath` (`String?`): Absolute file path to the verified, upright, high-resolution frontal reference photo. `null` if verification failed.

---

## 🔍 On-Device 1:1 Face Matching (`FaceMatchService`)

The plugin includes a complete on-device 1:1 facial matching engine powered by MobileFaceNet (TFLite) and Google ML Kit Face Detection. It lets you compare the verified liveness photo against an ID document or selfie photo directly, with zero external dependencies!

### Quick Comparison:
```dart
import 'package:face_liveness_check/face_liveness_check.dart';

// Compare two face images
final result = await FaceLivenessCheck.compareFaces(
  livenessImagePath: livenessResult.imagePath!,
  comparisonImagePath: idCardOrSelfiePath,
);

print('Match Level: ${result.matchLevel}%'); // e.g. 92%
print('Is Match: ${result.isMatch}');         // true (if >= 65%)
print('Message: ${result.message}');
```

### Comparing Two Photos:
```dart
final matchService = FaceMatchService();

try {
  // Compare the liveness reference photo against an ID photo or selfie
  final result = await matchService.compare(
    livenessImagePath: livenessResult.imagePath!,
    comparisonImagePath: idPhotoPath,
  );

  print('Match Level: ${result.matchLevel}%'); // e.g. 92%
  print('Is Match: ${result.isMatch}');         // true (>= 65%)
  print('Message: ${result.message}');
} finally {
  await matchService.dispose();
}
```

---

## 🛠️ Example App

Check out the fully functional example application in the [`example/`](example/) directory showcasing custom colors, dynamic step toggling, Arabic localization presets, and previewing the captured reference photo.

To run the example:
```bash
cd example
flutter run
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
