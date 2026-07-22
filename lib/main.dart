import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_vision/flutter_vision.dart';

final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier(false);

void main() {
  runApp(const FeliVetApp());
}

// ─────────────────────────────────────────────
// APP ROOT
// ─────────────────────────────────────────────
class FeliVetApp extends StatelessWidget {
  const FeliVetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'FeliVet Insight',
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            primarySwatch: Colors.teal,
            useMaterial3: true,
            fontFamily: 'Roboto',
            brightness: Brightness.light,
            scaffoldBackgroundColor: Colors.grey[50],
            cardColor: Colors.white,
          ),
          darkTheme: ThemeData(
            primarySwatch: Colors.teal,
            useMaterial3: true,
            fontFamily: 'Roboto',
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardColor: const Color(0xFF1E1E1E),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// SPLASH SCREEN
// ─────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _pawOpacity = 0.0;
  double _textOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    _startAnimationSequence();
  }

  void _startAnimationSequence() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _pawOpacity = 1.0);

    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _textOpacity = 1.0);

    await Future.delayed(const Duration(milliseconds: 2500));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TriageScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 800),
              opacity: _pawOpacity,
              child: const Icon(Icons.pets, size: 90, color: Colors.white),
            ),
            const SizedBox(height: 20),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 800),
              opacity: _textOpacity,
              child: Column(
                children: [
                  const Text(
                    "FeliVet Insights",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "We care about your fur babies.",
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: Colors.teal.shade100,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DETECTION RESULT MODEL
// ─────────────────────────────────────────────
class DetectionResult {
  final String disease;
  final double confidence;
  final int spotCount;

  const DetectionResult({
    required this.disease,
    required this.confidence,
    required this.spotCount,
  });
}

// ─────────────────────────────────────────────
// TRIAGE SCREEN
// ─────────────────────────────────────────────
class TriageScreen extends StatefulWidget {
  const TriageScreen({super.key});

  @override
  State<TriageScreen> createState() => _TriageScreenState();
}

class _TriageScreenState extends State<TriageScreen> {
  // ── Image ──
  File? _image;
  final ImagePicker _picker = ImagePicker();

  // ── Model ──
  late FlutterVision _vision;
  bool _isModelLoaded = false;
  bool _isScanning = false;

  // ── Symptoms ──
  bool _isVomiting = false;
  bool _isLethargic = false;
  bool _lostAppetite = false;

  // ── Result ──
  String _triageResult = "";

  // ── Known disease labels (must match labels.txt exactly) ──
  static const List<String> _knownDiseases = [
    "Scabies",
    "ringworms",
    "Flee Allergy",
  ];

  // ── Detection thresholds ──
  static const double _confThreshold = 0.40; // raised from 0.15
  static const double _iouThreshold = 0.45; // slightly stricter overlap
  static const double _severeConfidence = 0.70; // aligned to new range
  static const int _severeSpotCount = 3; // raised from 2

  @override
  void initState() {
    super.initState();
    _vision = FlutterVision();
    _loadModel();
  }

  // ── Model loading ──────────────────────────
  Future<void> _loadModel() async {
    try {
      await _vision.loadYoloModel(
        labels: 'assets/labels.txt',
        modelPath: 'assets/CatDisease.tflite',
        modelVersion: "yolov8",
        numThreads: 2,
        useGpu: false,
      );
      if (mounted) setState(() => _isModelLoaded = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _triageResult = "⚠️ Failed to load model: $e";
        });
      }
    }
  }

  @override
  void dispose() {
    _vision.closeYoloModel();
    super.dispose();
  }

  // ── Image picking ──────────────────────────
  Future<void> _getImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _triageResult = "";
      });
    }
  }

  // ── Core inference ─────────────────────────
  Future<void> _runInference() async {
    if (_image == null || !_isModelLoaded) return;

    setState(() {
      _isScanning = true;
      _triageResult = "Scanning image… Please wait.";
    });

    try {
      final Uint8List bytes = await _image!.readAsBytes();
      final imageInfo = await decodeImageFromList(bytes);

      final List<dynamic> rawResults = await _vision.yoloOnImage(
        bytesList: bytes,
        imageHeight: imageInfo.height,
        imageWidth: imageInfo.width,
        iouThreshold: _iouThreshold,
        confThreshold: _confThreshold,
      );

      // ── Parse detections ───────────────────
      // Track best confidence + total spots per disease for balance
      final Map<String, double> bestConfPerDisease = {
        for (final d in _knownDiseases) d: 0.0,
      };
      final Map<String, int> spotCountPerDisease = {
        for (final d in _knownDiseases) d: 0,
      };

      for (final res in rawResults) {
        final String tag = (res['tag'] ?? '').toString();
        if (!_knownDiseases.contains(tag)) continue;

        // Consistent confidence extraction: box[4] is the primary source
        double conf = 0.0;
        try {
          final box = res['box'] as List?;
          if (box != null && box.length > 4) {
            conf = (box[4] as num).toDouble();
          } else if (res['confidence'] != null) {
            conf = (res['confidence'] as num).toDouble();
          }
        } catch (_) {}

        // Only count detections that pass the threshold
        if (conf < _confThreshold) continue;

        spotCountPerDisease[tag] = (spotCountPerDisease[tag] ?? 0) + 1;

        // Keep the highest confidence per disease (not last-wins)
        if (conf > (bestConfPerDisease[tag] ?? 0.0)) {
          bestConfPerDisease[tag] = conf;
        }
      }

      // ── Pick the dominant disease ──────────
      // Scoring = confidence × 0.7 + normalized spot weight × 0.3
      // This balances both detection count and confidence fairly.
      DetectionResult? best;
      double bestScore = 0.0;

      for (final disease in _knownDiseases) {
        final double conf = bestConfPerDisease[disease]!;
        final int spots = spotCountPerDisease[disease]!;
        if (spots == 0) continue;

        // Normalize spot count (cap at 5 for scoring)
        final double spotWeight = (spots.clamp(1, 5)) / 5.0;
        final double score = (conf * 0.7) + (spotWeight * 0.3);

        if (score > bestScore) {
          bestScore = score;
          best = DetectionResult(
            disease: disease,
            confidence: conf,
            spotCount: spots,
          );
        }
      }

      // ── Build triage output ────────────────
      final int symptomCount = [
        _isVomiting,
        _isLethargic,
        _lostAppetite,
      ].where((s) => s).length;

      final String result = _buildTriageText(
        detection: best,
        symptomCount: symptomCount,
      );

      setState(() {
        _triageResult = result;
        _isScanning = false;
      });
    } catch (e) {
      setState(() {
        _triageResult = "⚠️ Error during scan: $e";
        _isScanning = false;
      });
    }
  }

  // ── Triage logic ───────────────────────────
  String _buildTriageText({
    required DetectionResult? detection,
    required int symptomCount,
  }) {
    final bool diseaseFound = detection != null;
    final bool isSevereVisual =
        diseaseFound &&
        (detection.spotCount >= _severeSpotCount ||
            detection.confidence >= _severeConfidence);

    String urgency;
    String advice;

    if (diseaseFound && (symptomCount >= 1 || isSevereVisual)) {
      urgency = "🚨 HIGH URGENCY";
      if (isSevereVisual && symptomCount == 0) {
        advice =
            "CRITICAL: The visual severity of ${detection.disease} is alarming (${(detection.confidence * 100).toStringAsFixed(0)}% confidence, ${detection.spotCount} area(s) detected). Even without other symptoms, seek veterinary care immediately to prevent further spreading or suffering.";
      } else {
        advice =
            "CRITICAL: ${detection.disease} detected (${(detection.confidence * 100).toStringAsFixed(0)}% confidence) along with systemic symptoms. This indicates the condition is actively affecting your cat's overall health. Seek veterinary care immediately.";
      }
    } else if (diseaseFound) {
      urgency = "⚠️ MODERATE URGENCY";
      advice =
          "AI detected a localized or early case of ${detection.disease} (${(detection.confidence * 100).toStringAsFixed(0)}% confidence, ${detection.spotCount} area(s)). This skin condition is contagious and requires medical treatment. Please consult a vet soon.";
    } else if (symptomCount >= 2) {
      urgency = "🚨 HIGH URGENCY";
      advice =
          "Multiple systemic symptoms detected. Even without visible skin issues, your cat needs an immediate medical check-up. Internal conditions can cause these signs.";
    } else if (symptomCount == 1) {
      urgency = "⚠️ MODERATE URGENCY";
      advice =
          "One systemic symptom detected. Monitor closely and consult a vet if the condition persists or worsens over 24–48 hours.";
    } else {
      urgency = "✅ STABLE";
      advice =
          "No skin diseases or systemic symptoms detected. Your cat appears healthy. Continue monitoring for any future changes and schedule routine vet check-ups.";
    }

    final String detectionLine = diseaseFound
        ? "AI Detection: ${detection.disease}"
        : "AI Detection: No skin disease detected";

    final String header = symptomCount > 0
        ? "Triage Analyzation: "
        : "Analyzation: ";

    return "$detectionLine\n\n$header$urgency\n\n$advice";
  }

  // ── Symptom insight text ───────────────────
  String _getSymptomInsight() {
    final int count = [
      _isVomiting,
      _isLethargic,
      _lostAppetite,
    ].where((s) => s).length;

    if (count == 0) return "";

    String insight;
    if (count >= 2) {
      insight =
          "Multiple symptoms suggest your cat is under severe stress. Skin issues like extreme Scabies or infected Flea bites can cause this, but internal illness may also be a factor.";
    } else if (_isVomiting) {
      insight =
          "Cats with itchy skin diseases often over-groom, swallowing hair, scabs, or fleas — leading to upset stomachs and vomiting.";
    } else if (_isLethargic) {
      insight =
          "Lethargy means your cat's energy is drained. Constant itching from mites or fighting off a fungal infection can exhaust them significantly.";
    } else {
      insight =
          "Cats often stop eating when stressed or uncomfortable. Severe skin irritation or pain can easily cause them to skip meals.";
    }

    return "Live Insight: $insight\n\nMention any other symptoms you've noticed to your vet.";
  }

  // ── Result color helpers ───────────────────
  Color _getResultBgColor(String resultText, bool isDark) {
    if (resultText.contains("HIGH URGENCY")) {
      return isDark
          ? Colors.red.shade900.withValues(alpha: 0.3)
          : Colors.red.shade50;
    }
    if (resultText.contains("MODERATE URGENCY")) {
      return isDark
          ? Colors.orange.shade900.withValues(alpha: 0.3)
          : Colors.orange.shade50;
    }
    if (resultText.contains("STABLE")) {
      return isDark
          ? Colors.green.shade900.withValues(alpha: 0.3)
          : Colors.green.shade50;
    }
    return isDark
        ? Colors.teal.shade900.withValues(alpha: 0.2)
        : Colors.teal.shade50;
  }

  Color _getResultBorderColor(String resultText) {
    if (resultText.contains("HIGH URGENCY")) return Colors.red.shade400;
    if (resultText.contains("MODERATE URGENCY")) return Colors.orange.shade400;
    if (resultText.contains("STABLE")) return Colors.green.shade400;
    return Colors.teal.shade300;
  }

  Color _getResultTextColor(String resultText, bool isDark) {
    if (isDark) return Colors.white;
    if (resultText.contains("HIGH URGENCY")) return Colors.red.shade900;
    if (resultText.contains("MODERATE URGENCY")) return Colors.orange.shade900;
    if (resultText.contains("STABLE")) return Colors.green.shade900;
    return Colors.teal.shade900;
  }

  // ── Symptom checkbox widget ────────────────
  Widget _buildSymptomOption({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required bool isDark,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: value
            ? (isDark
                  ? Colors.teal.shade900.withValues(alpha: 0.5)
                  : Colors.teal.shade50)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: value
              ? Colors.teal
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
          width: value ? 2.5 : 1.0,
        ),
        boxShadow: value
            ? [
                BoxShadow(
                  color: Colors.teal.withValues(alpha: 0.15),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: CheckboxListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: value ? FontWeight.bold : FontWeight.w500,
            color: value
                ? (isDark ? Colors.tealAccent : Colors.teal.shade900)
                : (isDark ? Colors.white : Colors.black87),
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            fontSize: 13,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: Colors.teal,
        checkColor: Colors.white,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  // ── Confidence badge widget ────────────────
  Widget _buildConfidenceBadge(String resultText, bool isDark) {
    // Extract confidence value from result text to display a progress bar
    final RegExp confRegex = RegExp(r'(\d+)%\s+confidence');
    final match = confRegex.firstMatch(resultText);
    if (match == null) return const SizedBox.shrink();

    final int confPercent = int.tryParse(match.group(1) ?? '0') ?? 0;
    final Color barColor = _getResultBorderColor(resultText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 14,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              "Model Confidence",
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const Spacer(),
            Text(
              "$confPercent%",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: confPercent / 100,
            minHeight: 6,
            backgroundColor: isDark
                ? Colors.grey.shade800
                : Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }

  // ── BUILD ──────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bool hasSymptoms = _isVomiting || _isLethargic || _lostAppetite;

    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        return Scaffold(
          // ── AppBar ───────────────────────
          appBar: AppBar(
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.pets, size: 26),
                SizedBox(width: 10),
                Text(
                  "FeliVet Insight",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),

          // ── Drawer ───────────────────────
          drawer: SizedBox(
            width: MediaQuery.of(context).size.width * 0.20,
            child: Drawer(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 30),
                    GestureDetector(
                      onTap: () =>
                          isDarkModeNotifier.value = !isDarkModeNotifier.value,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.teal.shade700
                              : Colors.teal.shade50,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.3)
                                  : Colors.teal.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) =>
                              RotationTransition(
                                turns: child.key == const ValueKey('icon1')
                                    ? Tween<double>(
                                        begin: 1,
                                        end: 0.5,
                                      ).animate(animation)
                                    : Tween<double>(
                                        begin: 0.5,
                                        end: 1,
                                      ).animate(animation),
                                child: ScaleTransition(
                                  scale: animation,
                                  child: child,
                                ),
                              ),
                          child: Icon(
                            isDark
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            key: ValueKey(isDark ? 'icon1' : 'icon2'),
                            color: isDark
                                ? Colors.amber.shade300
                                : Colors.teal.shade800,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isDark ? "Dark" : "Light",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.teal.shade800,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.settings,
                      color: isDark
                          ? Colors.grey.shade600
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),

          // ── Body ─────────────────────────
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Model status banner ───
                if (!_isModelLoaded)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.amber,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Loading detection model…",
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Image preview ─────────
                Container(
                  width: double.infinity,
                  height: 260,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.3 : 0.05,
                        ),
                        blurRadius: 10,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _image == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.pets,
                                size: 60,
                                color: Colors.teal[200],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Upload a photo to begin",
                                style: TextStyle(
                                  color: Colors.teal[300],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          )
                        : Image.file(_image!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Image source buttons ──
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: Colors.teal.shade400,
                            width: 2.5,
                          ),
                        ),
                        onPressed: () => _getImage(ImageSource.camera),
                        icon: Icon(
                          Icons.camera_alt,
                          color: Colors.teal.shade700,
                        ),
                        label: Text(
                          "Camera",
                          style: TextStyle(
                            color: Colors.teal.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: Colors.teal.shade400,
                            width: 2.5,
                          ),
                        ),
                        onPressed: () => _getImage(ImageSource.gallery),
                        icon: Icon(
                          Icons.photo_library,
                          color: Colors.teal.shade700,
                        ),
                        label: Text(
                          "Gallery",
                          style: TextStyle(
                            color: Colors.teal.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // ── Symptoms section ──────
                Text(
                  "Systemic Symptoms",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Check any symptoms your cat is currently showing.",
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 15),

                _buildSymptomOption(
                  title: "Vomiting",
                  subtitle: "Frequent throwing up or dry heaving",
                  value: _isVomiting,
                  onChanged: (v) => setState(() => _isVomiting = v!),
                  isDark: isDark,
                ),
                _buildSymptomOption(
                  title: "Lethargy",
                  subtitle: "Unusually tired, sleepy, or unresponsive",
                  value: _isLethargic,
                  onChanged: (v) => setState(() => _isLethargic = v!),
                  isDark: isDark,
                ),
                _buildSymptomOption(
                  title: "Loss of Appetite",
                  subtitle: "Ignoring food or eating very little",
                  value: _lostAppetite,
                  onChanged: (v) => setState(() => _lostAppetite = v!),
                  isDark: isDark,
                ),

                // ── Symptom insight box ───
                if (hasSymptoms) ...[
                  const SizedBox(height: 10),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F2D40)
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: isDark
                            ? Colors.blue.shade800
                            : Colors.blue.shade200,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: isDark
                              ? Colors.blue.shade300
                              : Colors.blue.shade700,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _getSymptomInsight(),
                            style: TextStyle(
                              color: isDark
                                  ? Colors.blue.shade100
                                  : Colors.blue.shade900,
                              height: 1.4,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 25),

                // ── Analyze button ────────
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed:
                        (_image == null || !_isModelLoaded || _isScanning)
                        ? null
                        : _runInference,
                    child: _isScanning
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : const Text(
                            "ANALYZE HEALTH",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                  ),
                ),

                // ── Result card ───────────
                if (_triageResult.isNotEmpty) ...[
                  const SizedBox(height: 25),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _getResultBgColor(_triageResult, isDark),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: _getResultBorderColor(_triageResult),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.3)
                              : _getResultBorderColor(
                                  _triageResult,
                                ).withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _triageResult,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            color: _getResultTextColor(_triageResult, isDark),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        // Confidence progress bar (shown when disease found)
                        _buildConfidenceBadge(_triageResult, isDark),
                        // Disclaimer
                        const SizedBox(height: 14),
                        Divider(
                          color: isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 13,
                              color: isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade500,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "This is an AI-assisted triage tool. Always consult a licensed veterinarian for diagnosis.",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade500,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }
}
