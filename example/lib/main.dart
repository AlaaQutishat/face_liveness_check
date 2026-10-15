import 'dart:io';
import 'package:face_liveness_check/face_liveness_check.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const LivenessExampleApp());
}

class LivenessExampleApp extends StatelessWidget {
  const LivenessExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Liveness Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const LivenessHomeScreen(),
    );
  }
}

class LivenessHomeScreen extends StatefulWidget {
  const LivenessHomeScreen({super.key});

  @override
  State<LivenessHomeScreen> createState() => _LivenessHomeScreenState();
}

class _LivenessHomeScreenState extends State<LivenessHomeScreen> {
  LivenessResult? _lastResult;
  bool _useArabic = false;
  Color _themeColor = const Color(0xFF14B8A6);

  // Toggled steps
  bool _includeBlink = true;
  bool _includeSmile = true;
  bool _includeTurnLeft = true;
  bool _includeTurnRight = true;
  bool _includeLookStraight = false;

  List<LivenessStepItem> get _selectedSteps {
    final list = <LivenessStepItem>[];
    if (_includeBlink) list.add(LivenessStepItem.blink);
    if (_includeSmile) list.add(LivenessStepItem.smile);
    if (_includeTurnLeft) list.add(LivenessStepItem.turnHeadLeft);
    if (_includeTurnRight) list.add(LivenessStepItem.turnHeadRight);
    if (_includeLookStraight) list.add(LivenessStepItem.lookStraight);
    return list.isEmpty
        ? const [LivenessStepItem.blink, LivenessStepItem.smile]
        : list;
  }

  Future<void> _startLiveness() async {
    final config = _useArabic
        ? LivenessConfig.arabic(
            steps: _selectedSteps,
            successColor: _themeColor,
          )
        : LivenessConfig(
            steps: _selectedSteps,
            titleText: 'KYC Face Verification',
            successColor: _themeColor,
            instructionTextColor: Colors.white,
            backgroundColor: Colors.black,
            overlayColor: const Color(0xCC000000),
          );

    final result = await FaceLivenessCheck.start(
      context,
      config: config,
    );

    if (!mounted || result == null) return;

    setState(() {
      _lastResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Liveness Check'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      _lastResult == null
                          ? Icons.camera_front_outlined
                          : _lastResult!.isProven
                              ? Icons.verified_user_rounded
                              : Icons.cancel_outlined,
                      size: 54,
                      color: _lastResult == null
                          ? Colors.grey
                          : _lastResult!.isProven
                              ? Colors.green
                              : Colors.redAccent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _lastResult == null
                          ? 'No Verification Performed'
                          : _lastResult!.isProven
                              ? 'Liveness Successfully Verified!'
                              : 'Verification Failed or Cancelled',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_lastResult?.imagePath != null) ...[
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_lastResult!.imagePath!),
                          height: 180,
                          width: 140,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Frontal photo captured:\n${_lastResult!.imagePath}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Customization Options
            const Text(
              'Customize Configuration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Language Switch
            SwitchListTile(
              title: const Text('Arabic Localization Preset'),
              subtitle: Text(
                _useArabic
                    ? 'Using LivenessConfig.arabic()'
                    : 'Using English defaults',
              ),
              value: _useArabic,
              onChanged: (val) => setState(() => _useArabic = val),
            ),

            // Color Selector
            ListTile(
              title: const Text('Success Highlight Color'),
              trailing: CircleAvatar(
                backgroundColor: _themeColor,
                radius: 14,
              ),
              onTap: () {
                setState(() {
                  if (_themeColor == const Color(0xFF14B8A6)) {
                    _themeColor = const Color(0xFF6366F1); // Indigo
                  } else if (_themeColor == const Color(0xFF6366F1)) {
                    _themeColor = const Color(0xFFF59E0B); // Amber
                  } else {
                    _themeColor = const Color(0xFF14B8A6); // Teal
                  }
                });
              },
            ),

            const Divider(height: 32),

            // Challenge Steps Toggle
            const Text(
              'Challenge Steps',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            CheckboxListTile(
              title: const Text('Blink Eyes'),
              value: _includeBlink,
              onChanged: (v) => setState(() => _includeBlink = v ?? false),
            ),
            CheckboxListTile(
              title: const Text('Smile'),
              value: _includeSmile,
              onChanged: (v) => setState(() => _includeSmile = v ?? false),
            ),
            CheckboxListTile(
              title: const Text('Turn Head Left'),
              value: _includeTurnLeft,
              onChanged: (v) => setState(() => _includeTurnLeft = v ?? false),
            ),
            CheckboxListTile(
              title: const Text('Turn Head Right'),
              value: _includeTurnRight,
              onChanged: (v) => setState(() => _includeTurnRight = v ?? false),
            ),
            CheckboxListTile(
              title: const Text('Look Straight (Explicit Step)'),
              value: _includeLookStraight,
              onChanged: (v) => setState(() => _includeLookStraight = v ?? false),
            ),

            const SizedBox(height: 24),

            // Start Button
            FilledButton.icon(
              onPressed: _startLiveness,
              style: FilledButton.styleFrom(
                backgroundColor: _themeColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 26),
              label: const Text(
                'Start Liveness Check',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
