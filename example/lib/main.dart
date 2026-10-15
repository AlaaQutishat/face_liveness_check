import 'dart:async';
import 'dart:io';

import 'package:face_liveness_check/face_liveness_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const FaceLivenessExampleApp());
}

class FaceLivenessExampleApp extends StatelessWidget {
  const FaceLivenessExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0F766E);

    return MaterialApp(
      title: 'Face Liveness & Match',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        useMaterial3: true,
      ),
      home: const LivenessHomeScreen(),
    );
  }
}

/// Home Screen containing:
/// 1. Top Card: Captured Liveness Photo
/// 2. Button 1: Config (redirects to separated ConfigPage)
/// 3. Button 2: Take Liveness Check
/// 4. Button 3: Match (Camera / Gallery picker -> Match Level)
class LivenessHomeScreen extends StatefulWidget {
  const LivenessHomeScreen({super.key});

  @override
  State<LivenessHomeScreen> createState() => _LivenessHomeScreenState();
}

class _LivenessHomeScreenState extends State<LivenessHomeScreen> {
  final FaceMatchService _matchService = FaceMatchService();
  final ImagePicker _imagePicker = ImagePicker();

  // Active configuration
  LivenessConfig _config = const LivenessConfig(
    titleText: 'Face Verification',
    successColor: Color(0xFF14B8A6),
  );
  bool _useArabic = false;

  // State
  LivenessResult? _lastResult;
  String? _comparisonImagePath;
  FaceMatchResult? _matchResult;
  String? _feedbackMessage;
  bool _isMatching = false;

  bool get _hasLiveReference =>
      _lastResult?.isProven == true && _lastResult?.imagePath != null;

  @override
  void dispose() {
    unawaited(_matchService.dispose());
    super.dispose();
  }

  // --- 1. Navigate to Separated Config Page ---
  Future<void> _openConfigPage() async {
    final updatedConfig = await Navigator.push<LivenessConfig>(
      context,
      MaterialPageRoute(
        builder: (context) => ConfigPage(
          currentConfig: _config,
          initialUseArabic: _useArabic,
        ),
      ),
    );

    if (updatedConfig != null) {
      setState(() {
        _config = updatedConfig;
        _useArabic = updatedConfig.languageCode == 'ar';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration updated successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // --- 2. Take Liveness Check ---
  Future<void> _startLiveness() async {
    setState(() {
      _feedbackMessage = null;
      _matchResult = null;
      _comparisonImagePath = null;
    });

    try {
      final result = await FaceLivenessCheck.start(
        context,
        config: _config,
      );

      if (!mounted || result == null) return;

      setState(() {
        _lastResult = result;
        if (!result.isProven) {
          _feedbackMessage =
              'Liveness check was not completed. Please try again.';
        } else if (result.imagePath == null) {
          _feedbackMessage =
              'Liveness completed, but no frontal photo was captured.';
        } else {
          _feedbackMessage =
              'Liveness verified! You can now match against an ID or selfie.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lastResult = const LivenessResult(isProven: false);
        _feedbackMessage =
            'Camera access is required for liveness verification. Please grant permission.';
      });
    }
  }

  // --- 3. Match: Show Camera / Gallery options then compare ---
  Future<void> _handleMatchPressed() async {
    if (!_hasLiveReference) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete the Liveness Check first to capture a reference photo.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Comparison Photo',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a photo to compare against your verified liveness image',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_camera, color: Colors.teal),
                ),
                title: const Text('Take with Camera',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Snap an ID card photo or selfie'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndMatch(ImageSource.camera);
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library, color: Colors.indigo),
                ),
                title: const Text('Choose from Gallery',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Select an existing photo from library'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndMatch(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndMatch(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 92,
      );
      if (pickedFile == null || !mounted) return;

      setState(() {
        _comparisonImagePath = pickedFile.path;
        _matchResult = null;
        _feedbackMessage = 'Extracting face & analyzing similarity...';
        _isMatching = true;
      });

      final result = await _matchService.compare(
        livenessImagePath: _lastResult!.imagePath!,
        comparisonImagePath: pickedFile.path,
      );

      if (!mounted) return;

      setState(() {
        _matchResult = result;
        _feedbackMessage = result.message;
        _isMatching = false;
      });
    } on FaceMatchException catch (error) {
      _showError(error.message);
    } on PlatformException catch (error) {
      _showError(
        error.code.toLowerCase().contains('denied')
            ? 'Permission denied. Please enable permission in device settings.'
            : (error.message ?? 'Image selection failed.'),
      );
    } catch (_) {
      _showError('The images could not be compared. Please try a clearer photo.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _feedbackMessage = message;
      _matchResult = null;
      _isMatching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Face Liveness & Match',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Configure Liveness',
            onPressed: _openConfigPage,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // -----------------------------------------------------------
            // TOP PHOTO CARD: Shows the captured liveness photo when done
            // -----------------------------------------------------------
            _TopLivenessPhotoCard(
              imagePath: _lastResult?.imagePath,
              isProven: _lastResult?.isProven ?? false,
              onRetake: _startLiveness,
            ),
            const SizedBox(height: 20),

            // -----------------------------------------------------------
            // 3 MAIN ACTION BUTTONS
            // 1. Config (Redirect)
            // 2. Take Liveness Check
            // 3. Match (Camera / Gallery -> Match Level)
            // -----------------------------------------------------------
            _ActionButtonsSection(
              hasLiveReference: _hasLiveReference,
              isMatching: _isMatching,
              onOpenConfig: _openConfigPage,
              onStartLiveness: _startLiveness,
              onMatchPressed: _handleMatchPressed,
            ),
            const SizedBox(height: 20),

            // Comparison Image preview (if picked)
            if (_comparisonImagePath != null) ...[
              _ComparisonPreviewRow(
                livenessPath: _lastResult?.imagePath,
                comparisonPath: _comparisonImagePath,
              ),
              const SizedBox(height: 16),
            ],

            // Feedback Message Banner
            if (_feedbackMessage != null) ...[
              _FeedbackBanner(
                message: _feedbackMessage!,
                isError: _matchResult?.isMatch == false ||
                    _feedbackMessage!.toLowerCase().contains('denied') ||
                    _feedbackMessage!.toLowerCase().contains('could not') ||
                    _feedbackMessage!.toLowerCase().contains('not completed'),
              ),
              const SizedBox(height: 16),
            ],

            // Progress bar while matching
            if (_isMatching) ...[
              const LinearProgressIndicator(minHeight: 6),
              const SizedBox(height: 16),
            ],

            // -----------------------------------------------------------
            // MATCH LEVEL RESULT PANEL
            // -----------------------------------------------------------
            if (_matchResult != null) ...[
              _MatchResultPanel(result: _matchResult!),
            ],
          ],
        ),
      ),
    );
  }
}

// =======================================================================
// TOP CARD: Captured Liveness Photo
// =======================================================================
class _TopLivenessPhotoCard extends StatelessWidget {
  final String? imagePath;
  final bool isProven;
  final VoidCallback onRetake;

  const _TopLivenessPhotoCard({
    required this.imagePath,
    required this.isProven,
    required this.onRetake,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = isProven && imagePath != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: hasPhoto ? const Color(0xFF14B8A6) : Colors.grey.shade200,
          width: hasPhoto ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: hasPhoto
                  ? const Color(0xFF14B8A6).withValues(alpha: 0.08)
                  : Colors.grey.shade50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(
                  hasPhoto
                      ? Icons.verified_rounded
                      : Icons.account_circle_outlined,
                  color: hasPhoto
                      ? const Color(0xFF0F766E)
                      : Colors.grey.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasPhoto
                      ? 'Verified Frontal Reference Photo'
                      : 'Frontal Reference Photo',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: hasPhoto
                          ? const Color(0xFF0F766E)
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
                if (hasPhoto)
                  GestureDetector(
                    onTap: onRetake,
                    child: const Text(
                      'Retake',
                      style: TextStyle(
                        color: Color(0xFF0F766E),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 200,
              child: hasPhoto
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(imagePath!),
                        fit: BoxFit.contain,
                        width: double.infinity,
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.face_retouching_natural_rounded,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No Liveness Photo Captured Yet',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap "Take Liveness Check" below to verify and capture.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// =======================================================================
// ACTION BUTTONS SECTION (The 3 Buttons)
// =======================================================================
class _ActionButtonsSection extends StatelessWidget {
  final bool hasLiveReference;
  final bool isMatching;
  final VoidCallback onOpenConfig;
  final VoidCallback onStartLiveness;
  final VoidCallback onMatchPressed;

  const _ActionButtonsSection({
    required this.hasLiveReference,
    required this.isMatching,
    required this.onOpenConfig,
    required this.onStartLiveness,
    required this.onMatchPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Button 1: Config (redirects to separated page)
        OutlinedButton.icon(
          onPressed: onOpenConfig,
          icon: const Icon(Icons.tune_rounded),
          label: const Text('1. Liveness Configuration Page'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 2. Button 2: Take Liveness Check
        FilledButton.icon(
          onPressed: isMatching ? null : onStartLiveness,
          icon: const Icon(Icons.camera_alt_outlined),
          label: Text(
            hasLiveReference
                ? '2. Run Liveness Check Again'
                : '2. Take Liveness Check',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0F766E),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 3. Button 3: Match (Camera / Gallery -> Match Level)
        FilledButton.tonalIcon(
          onPressed: hasLiveReference && !isMatching ? onMatchPressed : null,
          icon: const Icon(Icons.compare_arrows_rounded),
          label: const Text('3. Match Face (Camera or Gallery)'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}

// =======================================================================
// COMPARISON PREVIEW
// =======================================================================
class _ComparisonPreviewRow extends StatelessWidget {
  final String? livenessPath;
  final String? comparisonPath;

  const _ComparisonPreviewRow({
    required this.livenessPath,
    required this.comparisonPath,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ImageThumbnailCard(
            title: 'Liveness',
            filePath: livenessPath,
            accentColor: const Color(0xFF0F766E),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ImageThumbnailCard(
            title: 'Comparison Photo',
            filePath: comparisonPath,
            accentColor: Colors.indigo,
          ),
        ),
      ],
    );
  }
}

class _ImageThumbnailCard extends StatelessWidget {
  final String title;
  final String? filePath;
  final Color accentColor;

  const _ImageThumbnailCard({
    required this.title,
    required this.filePath,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (filePath != null)
              Image.file(File(filePath!), fit: BoxFit.cover)
            else
              const Center(child: Icon(Icons.image, color: Colors.grey)),
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================================
// MATCH RESULT PANEL (Shows percentage & match level)
// =======================================================================
class _MatchResultPanel extends StatelessWidget {
  final FaceMatchResult result;

  const _MatchResultPanel({required this.result});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resultColor = result.isMatch
        ? const Color(0xFF15803D)
        : result.matchLevel >= 50
            ? const Color(0xFFB45309)
            : colorScheme.error;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: resultColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result.isMatch
                      ? Icons.verified_rounded
                      : Icons.warning_amber_rounded,
                  color: resultColor,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Match Level: ${result.matchLevel}%',
                    style: TextStyle(
                      color: resultColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: resultColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    result.isMatch ? 'PASSED' : 'NOT MATCHED',
                    style: TextStyle(
                      color: resultColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 12,
                value: result.matchLevel / 100,
                color: resultColor,
                backgroundColor: Colors.grey.shade200,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              result.message,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (result.qualityNote != null) ...[
              const SizedBox(height: 8),
              Text(
                result.qualityNote!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  final String message;
  final bool isError;

  const _FeedbackBanner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? Colors.red.shade700 : const Color(0xFF0F766E);

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =======================================================================
// PAGE 1: DEDICATED CONFIGURATION PAGE (Separated Page)
// =======================================================================
class ConfigPage extends StatefulWidget {
  final LivenessConfig currentConfig;
  final bool initialUseArabic;

  const ConfigPage({
    super.key,
    required this.currentConfig,
    required this.initialUseArabic,
  });

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  late bool _useArabic;
  late bool _includeBlink;
  late bool _includeSmile;
  late bool _includeTurnLeft;
  late bool _includeTurnRight;
  late bool _includeLookStraight;
  late Color _themeColor;

  final List<Color> _availableColors = const [
    Color(0xFF14B8A6), // Teal
    Color(0xFF2563EB), // Blue
    Color(0xFF7C3AED), // Purple
    Color(0xFFEA580C), // Orange
    Color(0xFF16A34A), // Green
  ];

  @override
  void initState() {
    super.initState();
    _useArabic = widget.initialUseArabic;
    _themeColor = widget.currentConfig.successColor;

    final steps = widget.currentConfig.steps;
    _includeBlink = steps.contains(LivenessStepItem.blink);
    _includeSmile = steps.contains(LivenessStepItem.smile);
    _includeTurnLeft = steps.contains(LivenessStepItem.turnHeadLeft);
    _includeTurnRight = steps.contains(LivenessStepItem.turnHeadRight);
    _includeLookStraight = steps.contains(LivenessStepItem.lookStraight);
  }

  void _save() {
    final activeSteps = <LivenessStepItem>[];
    if (_includeBlink) activeSteps.add(LivenessStepItem.blink);
    if (_includeSmile) activeSteps.add(LivenessStepItem.smile);
    if (_includeTurnLeft) activeSteps.add(LivenessStepItem.turnHeadLeft);
    if (_includeTurnRight) activeSteps.add(LivenessStepItem.turnHeadRight);
    if (_includeLookStraight) activeSteps.add(LivenessStepItem.lookStraight);

    if (activeSteps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one step!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final newConfig = _useArabic
        ? LivenessConfig.arabic(
            steps: activeSteps,
            successColor: _themeColor,
          )
        : LivenessConfig(
            steps: activeSteps,
            titleText: 'Face Verification',
            successColor: _themeColor,
          );

    Navigator.pop(context, newConfig);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liveness Configuration'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Language Card
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Language & Localization',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Arabic Mode (العربية)'),
                    subtitle: const Text('Localizes all instructions and hints to Arabic'),
                    value: _useArabic,
                    onChanged: (val) => setState(() => _useArabic = val),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Steps Card
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Challenge Steps',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select which liveness challenges to enforce during verification:',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text('Blink Eyes'),
                    value: _includeBlink,
                    onChanged: (val) => setState(() => _includeBlink = val ?? true),
                  ),
                  CheckboxListTile(
                    title: const Text('Smile'),
                    value: _includeSmile,
                    onChanged: (val) => setState(() => _includeSmile = val ?? true),
                  ),
                  CheckboxListTile(
                    title: const Text('Turn Head Left'),
                    value: _includeTurnLeft,
                    onChanged: (val) => setState(() => _includeTurnLeft = val ?? true),
                  ),
                  CheckboxListTile(
                    title: const Text('Turn Head Right'),
                    value: _includeTurnRight,
                    onChanged: (val) => setState(() => _includeTurnRight = val ?? true),
                  ),
                  CheckboxListTile(
                    title: const Text('Look Straight'),
                    value: _includeLookStraight,
                    onChanged: (val) => setState(() => _includeLookStraight = val ?? false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Primary Theme Color Card
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Success Accent Color',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _availableColors.map((color) {
                      final isSelected =
                          _themeColor.toARGB32() == color.toARGB32();
                      return GestureDetector(
                        onTap: () => setState(() => _themeColor = color),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.black : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Save Button
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Save & Apply Configuration'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
