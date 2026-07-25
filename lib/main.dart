import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

// ═══════════════════════════════════════════════════════════
// CENTRAL CONFIG — all tunable thresholds live here, nowhere else
// ═══════════════════════════════════════════════════════════
class DetectionConfig {
  // YOLO-level thresholds
  static const double minDetectionConfidence = 0.40;
  static const double iouThreshold = 0.45;

  // Evidence-strength thresholds (used to judge DISEASE PRESENCE, not severity)
  static const double strongEvidenceConfidence = 0.70;
  static const double moderateEvidenceConfidence = 0.55;
  static const int strongEvidenceMinDetections = 3;
  static const int moderateEvidenceMinDetections = 2;

  // If the best and second-best disease scores are within this margin,
  // the result is treated as ambiguous instead of confidently picking one.
  static const double ambiguityMargin = 0.08;

  static const List<String> knownDiseases = [
    "Scabies",
    "ringworms",
    "Flee Allergy",
  ];

  // ── Clinical risk tier per disease — independent of AI confidence.
  //    This answers "how potentially dangerous IS this disease if present?",
  //    which confidence alone can never answer. Scabies (mite infestation)
  //    and ringworm (zoonotic fungal infection) can worsen quickly and are
  //    contagious to other animals/people; flea allergy is generally less
  //    systemically dangerous though still needs treatment.
  static const Map<String, DiseaseRiskLevel> diseaseRisk = {
    "Scabies": DiseaseRiskLevel.high,
    "ringworms": DiseaseRiskLevel.high,
    "Flee Allergy": DiseaseRiskLevel.moderate,
  };
}

// ═══════════════════════════════════════════════════════════
// ENUMS — structured status instead of raw strings
// ═══════════════════════════════════════════════════════════
enum DiseasePresenceStatus { detected, likelyDetected, uncertain, notDetected }

enum EvidenceStrength { strong, moderate, weak, insufficient }

enum UrgencyLevel { stable, moderate, high }

// How potentially dangerous the SUSPECTED disease itself is — a property
// of the disease, not of how confident the AI is. Independent input to
// urgency; must never be derived from confidence or detection count.
enum DiseaseRiskLevel { low, moderate, high }

// How sure the AI is about its top prediction — independent of whether
// that prediction, if correct, would be dangerous.
enum ConfidenceLevel { low, moderate, high }

extension DiseasePresenceStatusX on DiseasePresenceStatus {
  String get label => switch (this) {
    DiseasePresenceStatus.detected => "Detected",
    DiseasePresenceStatus.likelyDetected => "Likely Detected",
    DiseasePresenceStatus.uncertain => "Uncertain",
    DiseasePresenceStatus.notDetected => "Not Detected",
  };
}

extension EvidenceStrengthX on EvidenceStrength {
  String get label => switch (this) {
    EvidenceStrength.strong => "Strong Visual Evidence",
    EvidenceStrength.moderate => "Moderate Visual Evidence",
    EvidenceStrength.weak => "Weak Visual Evidence",
    EvidenceStrength.insufficient => "Insufficient Evidence",
  };
}

extension UrgencyLevelX on UrgencyLevel {
  String get label => switch (this) {
    UrgencyLevel.stable => "STABLE",
    UrgencyLevel.moderate => "MODERATE URGENCY",
    UrgencyLevel.high => "HIGH URGENCY",
  };

  String get icon => switch (this) {
    UrgencyLevel.stable => "✅",
    UrgencyLevel.moderate => "⚠️",
    UrgencyLevel.high => "🚨",
  };
}

extension DiseaseRiskLevelX on DiseaseRiskLevel {
  String get label => switch (this) {
    DiseaseRiskLevel.high => "High Clinical Risk",
    DiseaseRiskLevel.moderate => "Moderate Clinical Risk",
    DiseaseRiskLevel.low => "Low Clinical Risk",
  };
}

extension ConfidenceLevelX on ConfidenceLevel {
  String get label => switch (this) {
    ConfidenceLevel.high => "High Confidence",
    ConfidenceLevel.moderate => "Moderate Confidence",
    ConfidenceLevel.low => "Low Confidence",
  };
}

// ═══════════════════════════════════════════════════════════
// DATA MODELS (plain data holders — no service/OOP layering,
// everything still lives and runs in this one file)
// ═══════════════════════════════════════════════════════════

/// Aggregated evidence for a single disease class across all raw
/// YOLO detections in one image (built once per inference run).
class DiseaseEvidence {
  final String disease;
  final double bestConfidence;
  final double avgConfidence;
  final int detectionCount;

  const DiseaseEvidence({
    required this.disease,
    required this.bestConfidence,
    required this.avgConfidence,
    required this.detectionCount,
  });
}

/// The final, structured output of the expert system. The UI only
/// ever reads this object — it never re-derives medical conclusions.
class TriageResult {
  final DiseasePresenceStatus presenceStatus;
  final String? detectedDisease;
  final EvidenceStrength evidenceStrength;
  final UrgencyLevel urgency;
  final double? confidence;
  final ConfidenceLevel? confidenceLevel;
  final DiseaseRiskLevel? diseaseRisk;
  final int detectionCount;
  final int symptomCount;
  final bool isAmbiguous;
  final String reasoning;
  final String recommendation;
  final DateTime timestamp;
  final File? image;

  const TriageResult({
    required this.presenceStatus,
    required this.detectedDisease,
    required this.evidenceStrength,
    required this.urgency,
    required this.confidence,
    required this.confidenceLevel,
    required this.diseaseRisk,
    required this.detectionCount,
    required this.symptomCount,
    required this.isAmbiguous,
    required this.reasoning,
    required this.recommendation,
    required this.timestamp,
    required this.image,
  });

  // ── Serialization: lets history persist across app restarts ──
  Map<String, dynamic> toJson() => {
    'presenceStatus': presenceStatus.name,
    'detectedDisease': detectedDisease,
    'evidenceStrength': evidenceStrength.name,
    'urgency': urgency.name,
    'confidence': confidence,
    'confidenceLevel': confidenceLevel?.name,
    'diseaseRisk': diseaseRisk?.name,
    'detectionCount': detectionCount,
    'symptomCount': symptomCount,
    'isAmbiguous': isAmbiguous,
    'reasoning': reasoning,
    'recommendation': recommendation,
    'timestamp': timestamp.toIso8601String(),
    'imagePath': image?.path,
  };

  factory TriageResult.fromJson(Map<String, dynamic> json) {
    final imagePath = json['imagePath'] as String?;
    return TriageResult(
      presenceStatus: DiseasePresenceStatus.values.byName(
        json['presenceStatus'] as String,
      ),
      detectedDisease: json['detectedDisease'] as String?,
      evidenceStrength: EvidenceStrength.values.byName(
        json['evidenceStrength'] as String,
      ),
      urgency: UrgencyLevel.values.byName(json['urgency'] as String),
      confidence: (json['confidence'] as num?)?.toDouble(),
      confidenceLevel: json['confidenceLevel'] != null
          ? ConfidenceLevel.values.byName(json['confidenceLevel'] as String)
          : null,
      diseaseRisk: json['diseaseRisk'] != null
          ? DiseaseRiskLevel.values.byName(json['diseaseRisk'] as String)
          : null,
      detectionCount: json['detectionCount'] as int,
      symptomCount: json['symptomCount'] as int,
      isAmbiguous: json['isAmbiguous'] as bool,
      reasoning: json['reasoning'] as String,
      recommendation: json['recommendation'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      image: (imagePath != null && imagePath.isNotEmpty)
          ? File(imagePath)
          : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════
// HISTORY STORAGE — persists analysis history permanently on-device
// using SharedPreferences (JSON-encoded list). This is the single
// place that reads/writes history; screens never touch storage
// directly, they go through these static methods.
// ═══════════════════════════════════════════════════════════
class HistoryStorage {
  static const String _key = 'felivet_triage_history';

  static Future<List<TriageResult>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return [];
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => TriageResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Corrupted or unreadable history should never crash the app —
      // treat it as an empty history instead.
      return [];
    }
  }

  static Future<void> save(List<TriageResult> history) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(history.map((r) => r.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

// Buckets a raw confidence score into a ConfidenceLevel using the same
// thresholds as evidence strength — kept as ONE source of truth so
// "confidence" is described consistently everywhere in the app.
ConfidenceLevel _confidenceLevelFor(double conf) {
  if (conf >= DetectionConfig.strongEvidenceConfidence)
    return ConfidenceLevel.high;
  if (conf >= DetectionConfig.moderateEvidenceConfidence)
    return ConfidenceLevel.moderate;
  return ConfidenceLevel.low;
}

// ═══════════════════════════════════════════════════════════
// EXPERT SYSTEM — pure, deterministic function.
// Same inputs ALWAYS produce the same TriageResult.
//
// This is the single place that turns (evidence + symptoms) into
// a medical conclusion. The UI must never bypass this function.
// ═══════════════════════════════════════════════════════════
TriageResult runExpertSystem({
  required List<DiseaseEvidence> evidenceList,
  required int symptomCount,
  File? image,
}) {
  // ── Step 1: sort candidates by best confidence (deterministic tie-break
  //    on detection count, then alphabetically so ties never flip) ──
  final sorted = [...evidenceList]
    ..sort((a, b) {
      final c = b.bestConfidence.compareTo(a.bestConfidence);
      if (c != 0) return c;
      final d = b.detectionCount.compareTo(a.detectionCount);
      if (d != 0) return d;
      return a.disease.compareTo(b.disease);
    });

  // ── Step 2: no visual evidence at all ──
  if (sorted.isEmpty) {
    if (symptomCount >= 3) {
      return TriageResult(
        presenceStatus: DiseasePresenceStatus.notDetected,
        detectedDisease: null,
        evidenceStrength: EvidenceStrength.insufficient,
        urgency: UrgencyLevel.high,
        confidence: null,
        confidenceLevel: null,
        diseaseRisk: null,
        detectionCount: 0,
        symptomCount: symptomCount,
        isAmbiguous: false,
        reasoning:
            "No supported skin condition was visually detected. However, "
            "three or more systemic symptoms were reported. A negative visual "
            "result does not rule out internal illness, early-stage disease, "
            "or conditions outside this model's training classes.",
        recommendation:
            "NO VISUAL DISEASE DETECTED — SYMPTOMS REQUIRE ATTENTION. "
            "Seek veterinary care promptly to evaluate the reported symptoms.",
        timestamp: DateTime.now(),
        image: image,
      );
    } else if (symptomCount >= 1) {
      return TriageResult(
        presenceStatus: DiseasePresenceStatus.notDetected,
        detectedDisease: null,
        evidenceStrength: EvidenceStrength.insufficient,
        urgency: UrgencyLevel.moderate,
        confidence: null,
        confidenceLevel: null,
        diseaseRisk: null,
        detectionCount: 0,
        symptomCount: symptomCount,
        isAmbiguous: false,
        reasoning:
            "No supported skin condition was visually detected. ${symptomCount == 1 ? 'One systemic symptom was' : 'Two systemic symptoms were'} "
            "reported; ${symptomCount == 1 ? 'it' : 'they'} may be unrelated to a skin condition, "
            "but a reported symptom should still be addressed rather than "
            "left unchecked.",
        recommendation:
            "Consult a vet to evaluate the reported symptom(s) — please don't "
            "wait, even though no skin condition was visually detected.",
        timestamp: DateTime.now(),
        image: image,
      );
    } else {
      return TriageResult(
        presenceStatus: DiseasePresenceStatus.notDetected,
        detectedDisease: null,
        evidenceStrength: EvidenceStrength.insufficient,
        urgency: UrgencyLevel.stable,
        confidence: null,
        confidenceLevel: null,
        diseaseRisk: null,
        detectionCount: 0,
        symptomCount: 0,
        isAmbiguous: false,
        reasoning:
            "The model did not find sufficient visual evidence of any of "
            "the supported skin conditions, and no systemic symptoms were "
            "reported. This does not confirm the cat is completely healthy — "
            "it only reflects the absence of detectable evidence for this "
            "model's specific disease classes.",
        recommendation:
            "NO SUPPORTED SKIN DISEASE DETECTED. Continue routine monitoring "
            "and schedule regular vet check-ups.",
        timestamp: DateTime.now(),
        image: image,
      );
    }
  }

  final top = sorted.first;
  final second = sorted.length > 1 ? sorted[1] : null;

  // Independent inputs — neither is derived from the other.
  final DiseaseRiskLevel riskLevel =
      DetectionConfig.diseaseRisk[top.disease] ?? DiseaseRiskLevel.moderate;
  final ConfidenceLevel confLevel = _confidenceLevelFor(top.bestConfidence);

  // ── Step 3: ambiguity check — is the top disease clearly ahead? ──
  final bool isAmbiguous =
      second != null &&
      (top.bestConfidence - second.bestConfidence) <
          DetectionConfig.ambiguityMargin;

  // ── Step 4: evidence strength (answers "is a disease present?",
  //    deliberately NOT the same calculation as severity) ──
  EvidenceStrength strength;
  DiseasePresenceStatus presence;

  if (top.bestConfidence >= DetectionConfig.strongEvidenceConfidence &&
      top.detectionCount >= DetectionConfig.strongEvidenceMinDetections) {
    strength = EvidenceStrength.strong;
    presence = DiseasePresenceStatus.detected;
  } else if (top.bestConfidence >= DetectionConfig.moderateEvidenceConfidence &&
      top.detectionCount >= DetectionConfig.moderateEvidenceMinDetections) {
    strength = EvidenceStrength.moderate;
    presence = DiseasePresenceStatus.likelyDetected;
  } else if (top.bestConfidence >= DetectionConfig.minDetectionConfidence) {
    strength = EvidenceStrength.weak;
    presence = DiseasePresenceStatus.uncertain;
  } else {
    strength = EvidenceStrength.insufficient;
    presence = DiseasePresenceStatus.notDetected;
  }

  if (isAmbiguous && presence != DiseasePresenceStatus.notDetected) {
    presence = DiseasePresenceStatus.uncertain;
  }

  // ── Step 5: severity/urgency — evaluated SEPARATELY from confidence.
  //    Driven by evidence strength + detection count + symptom count,
  //    never by raw confidence alone. ──
  UrgencyLevel urgency;
  String reasoning;
  String recommendation;

  if (presence == DiseasePresenceStatus.notDetected) {
    // Weak/no usable evidence — fall back to symptom-only reasoning.
    if (symptomCount >= 3) {
      urgency = UrgencyLevel.high;
    } else if (symptomCount >= 1) {
      urgency = UrgencyLevel.moderate;
    } else {
      urgency = UrgencyLevel.stable;
    }
    reasoning =
        "Visual confidence (${(top.bestConfidence * 100).toStringAsFixed(0)}%) "
        "for ${top.disease} fell below the threshold needed to establish "
        "disease presence. This does not confirm the cat is healthy — the "
        "image may be unclear, poorly lit, or the condition may be very early-stage.";
    recommendation = symptomCount > 0
        ? "Visual evidence is insufficient to confidently classify a condition. "
              "Consider retaking the photo with better lighting and a clearer view, "
              "and have the reported symptom(s) evaluated — please don't wait."
        : "Visual evidence is insufficient to confidently classify a condition. "
              "Consider retaking the photo with better lighting and a clearer view.";
  } else if (presence == DiseasePresenceStatus.uncertain) {
    // Any real (even weak or ambiguous) visual evidence should be addressed.
    // Multiple reported symptoms alongside suspected skin disease is escalated
    // to high urgency, even when the visual evidence itself is only weak/ambiguous.
    urgency = symptomCount >= 2 ? UrgencyLevel.high : UrgencyLevel.moderate;
    if (isAmbiguous) {
      reasoning =
          "The model detected evidence that may correspond to more than one "
          "supported skin condition (${top.disease} vs ${second.disease}, "
          "scores within ${(DetectionConfig.ambiguityMargin * 100).toStringAsFixed(0)}% "
          "of each other). The visual result is inconclusive."
          "${symptomCount >= 2 ? ' Multiple systemic symptoms were also reported alongside this suspected skin condition, which escalates the case regardless of the inconclusive visual result.' : ''}";
      recommendation = symptomCount >= 2
          ? "CRITICAL: Uncertain Visual Classification with multiple systemic symptoms — "
                "seek veterinary care promptly. The visual result is inconclusive between "
                "candidate conditions, but the combination with multiple symptoms warrants urgency."
          : "Uncertain Visual Classification — the result is inconclusive between "
                "candidate conditions. A vet visit is recommended for a clear diagnosis.";
    } else {
      reasoning =
          "Weak visual evidence for ${top.disease} "
          "(${(top.bestConfidence * 100).toStringAsFixed(0)}% confidence, "
          "${top.detectionCount} detection(s)). Evidence is too limited to "
          "confidently establish disease presence. ${top.disease} is a "
          "${riskLevel.label.toLowerCase()} condition — low confidence does "
          "not mean the condition, if present, would be minor."
          "${symptomCount >= 2 ? ' Multiple systemic symptoms were also reported, which escalates this case even though visual confidence is low.' : ''}";
      recommendation = symptomCount >= 2
          ? "CRITICAL: Possible ${top.disease} with multiple systemic symptoms — "
                "seek veterinary care promptly. Confidence in the visual finding is low, "
                "but the combination with multiple symptoms warrants urgency."
          : "Possible ${top.disease} — Low Confidence. Consider retaking the "
                "photo with better lighting and a clearer view of the affected area, "
                "and don't assume the condition is mild just because confidence is low.";
    }
  } else {
    // detected or likelyDetected — a real disease-presence conclusion.
    final bool broadVisualSpread =
        top.detectionCount >= DetectionConfig.strongEvidenceMinDetections;

    // Risk-first escalation: a high-risk disease with strong evidence is
    // urgent on its own — lesion count/spread is not the deciding factor,
    // and we do not wait for symptoms to say so.
    if (strength == EvidenceStrength.strong &&
        riskLevel == DiseaseRiskLevel.high) {
      urgency = UrgencyLevel.high;
      reasoning =
          "${top.disease} is a high-clinical-risk condition, and visual "
          "evidence is ${strength.label.toLowerCase()} "
          "(${top.detectionCount} detection(s), "
          "${(top.bestConfidence * 100).toStringAsFixed(0)}% best confidence). "
          "Because the suspected disease itself carries significant risk, "
          "this is treated as urgent regardless of symptom count or "
          "affected-area size.";
      recommendation =
          "CRITICAL: ${top.disease} is a high-risk condition with strong "
          "visual evidence. Seek veterinary care promptly, even without "
          "other symptoms.";
    } else if (symptomCount >= 2) {
      urgency = UrgencyLevel.high;
      reasoning =
          "${top.disease} evidence is ${strength.label.toLowerCase()} "
          "(${top.detectionCount} detection(s), "
          "${(top.bestConfidence * 100).toStringAsFixed(0)}% best confidence, "
          "${riskLevel.label.toLowerCase()}), "
          "and multiple systemic symptoms were reported. The combination of "
          "visual and systemic evidence indicates the condition is actively "
          "affecting overall health.";
      recommendation =
          "CRITICAL: Seek veterinary care immediately — visual findings and "
          "systemic symptoms both point to an actively worsening condition.";
    } else if (symptomCount == 1) {
      urgency = UrgencyLevel.moderate;
      reasoning =
          "${top.disease} evidence is ${strength.label.toLowerCase()} "
          "(${top.detectionCount} detection(s), "
          "${(top.bestConfidence * 100).toStringAsFixed(0)}% best confidence, "
          "${riskLevel.label.toLowerCase()}). "
          "One systemic symptom was also reported; it may or may not be "
          "related to the skin condition and should be evaluated separately.";
      recommendation =
          "Consult a vet soon. ${top.disease} appears to be present and the "
          "reported symptom warrants a closer look, even if the two are unrelated.";
    } else if (broadVisualSpread && strength == EvidenceStrength.strong) {
      urgency = UrgencyLevel.moderate;
      reasoning =
          "${top.disease} shows ${strength.label.toLowerCase()} across "
          "${top.detectionCount} distinct detected area(s) "
          "(${(top.bestConfidence * 100).toStringAsFixed(0)}% best confidence, "
          "${riskLevel.label.toLowerCase()}), "
          "with no systemic symptoms reported. Wide visual spread alone "
          "warrants attention even without other symptoms.";
      recommendation =
          "The affected area appears widespread. Please consult a vet soon "
          "even though your cat isn't showing other symptoms.";
    } else {
      urgency = UrgencyLevel.moderate;
      reasoning =
          "${top.disease} evidence is ${strength.label.toLowerCase()} "
          "(${top.detectionCount} detection(s), "
          "${(top.bestConfidence * 100).toStringAsFixed(0)}% best confidence, "
          "${riskLevel.label.toLowerCase()}), "
          "with no systemic symptoms reported. A small affected area does "
          "not rule out a condition that still needs treatment.";
      recommendation =
          "AI detected a likely localized case of ${top.disease}. This skin "
          "condition is contagious and requires medical treatment. Please "
          "consult a vet soon.";
    }
  }

  return TriageResult(
    presenceStatus: presence,
    detectedDisease: presence == DiseasePresenceStatus.notDetected
        ? null
        : top.disease,
    evidenceStrength: strength,
    urgency: urgency,
    confidence: top.bestConfidence,
    confidenceLevel: confLevel,
    diseaseRisk: presence == DiseasePresenceStatus.notDetected
        ? null
        : riskLevel,
    detectionCount: top.detectionCount,
    symptomCount: symptomCount,
    isAmbiguous: isAmbiguous,
    reasoning: reasoning,
    recommendation: recommendation,
    timestamp: DateTime.now(),
    image: image,
  );
}

// ── Centralized, single-source confidence parser ──
// FlutterVision may expose confidence via box[4] or a 'confidence' key.
// box[4] is treated as authoritative; 'confidence' is only a fallback.
double? _extractConfidence(Map res) {
  try {
    final box = res['box'] as List?;
    if (box != null && box.length > 4) {
      final v = (box[4] as num).toDouble();
      if (v >= 0.0 && v <= 1.0) return v;
    }
  } catch (_) {}
  try {
    if (res['confidence'] != null) {
      final v = (res['confidence'] as num).toDouble();
      if (v >= 0.0 && v <= 1.0) return v;
    }
  } catch (_) {}
  return null; // malformed / out-of-range confidence is treated as absent
}

// ═══════════════════════════════════════════════════════════
// TRIAGE SCREEN — image + symptom input
// ═══════════════════════════════════════════════════════════
class TriageScreen extends StatefulWidget {
  const TriageScreen({super.key});

  @override
  State<TriageScreen> createState() => _TriageScreenState();
}

class _TriageScreenState extends State<TriageScreen> {
  File? _image;
  final ImagePicker _picker = ImagePicker();

  late FlutterVision _vision;
  bool _isModelLoaded = false;
  bool _isScanning = false;
  String? _loadError;

  bool _isVomiting = false;
  bool _isLethargic = false;
  bool _lostAppetite = false;

  List<TriageResult> _history = [];
  bool _isHistoryLoaded = false;

  @override
  void initState() {
    super.initState();
    _vision = FlutterVision();
    _loadModel();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final saved = await HistoryStorage.load();
    if (!mounted) return;
    setState(() {
      _history = saved;
      _isHistoryLoaded = true;
    });
  }

  Future<void> _persistHistory() async {
    await HistoryStorage.save(_history);
  }

  Future<void> _deleteHistoryEntry(TriageResult entry) async {
    setState(() => _history.remove(entry));
    await _persistHistory();
  }

  Future<void> _clearHistory() async {
    setState(() => _history = []);
    await HistoryStorage.clear();
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistoryScreen(
          history: _history,
          onDelete: _deleteHistoryEntry,
          onClearAll: _clearHistory,
        ),
      ),
    );
  }

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
      if (mounted) setState(() => _loadError = "Failed to load model: $e");
    }
  }

  @override
  void dispose() {
    _vision.closeYoloModel();
    super.dispose();
  }

  Future<void> _getImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  int get _symptomCount =>
      [_isVomiting, _isLethargic, _lostAppetite].where((s) => s).length;

  Future<void> _runInference() async {
    if (_image == null || !_isModelLoaded) return;
    setState(() => _isScanning = true);

    try {
      final Uint8List bytes = await _image!.readAsBytes();
      final imageInfo = await decodeImageFromList(bytes);

      final List<dynamic> rawResults = await _vision.yoloOnImage(
        bytesList: bytes,
        imageHeight: imageInfo.height,
        imageWidth: imageInfo.width,
        iouThreshold: DetectionConfig.iouThreshold,
        confThreshold: DetectionConfig.minDetectionConfidence,
      );

      // ── Aggregate raw detections into DiseaseEvidence per class ──
      final Map<String, List<double>> confidencesPerDisease = {
        for (final d in DetectionConfig.knownDiseases) d: [],
      };

      for (final res in rawResults) {
        if (res is! Map) continue;
        final String tag = (res['tag'] ?? '').toString();
        if (!DetectionConfig.knownDiseases.contains(tag)) continue;

        final conf = _extractConfidence(res);
        if (conf == null || conf < DetectionConfig.minDetectionConfidence) {
          continue;
        }
        confidencesPerDisease[tag]!.add(conf);
      }

      final evidenceList = <DiseaseEvidence>[];
      confidencesPerDisease.forEach((disease, confs) {
        if (confs.isEmpty) return;
        final best = confs.reduce((a, b) => a > b ? a : b);
        final avg = confs.reduce((a, b) => a + b) / confs.length;
        evidenceList.add(
          DiseaseEvidence(
            disease: disease,
            bestConfidence: best,
            avgConfidence: avg,
            detectionCount: confs.length,
          ),
        );
      });

      final result = runExpertSystem(
        evidenceList: evidenceList,
        symptomCount: _symptomCount,
        image: _image,
      );

      setState(() {
        _isScanning = false;
        _history.insert(0, result);
      });
      await _persistHistory();

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            result: result,
            history: _history,
            onDeleteHistoryEntry: _deleteHistoryEntry,
            onClearHistory: _clearHistory,
          ),
        ),
      );
    } catch (e) {
      setState(() => _isScanning = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error during scan: $e")));
    }
  }

  String _getSymptomInsight() {
    if (_symptomCount == 0) return "";
    if (_symptomCount >= 2) {
      return "Multiple symptoms suggest your cat is under stress. This could "
          "be related to a skin condition or to an unrelated internal issue — "
          "both should be evaluated by a vet.";
    } else if (_isVomiting) {
      return "Vomiting can have many causes, including but not limited to "
          "skin-condition-related over-grooming. It should be evaluated on "
          "its own merits rather than assumed to be caused by a skin issue.";
    } else if (_isLethargic) {
      return "Lethargy can stem from many causes. It should be evaluated "
          "independently rather than automatically attributed to a skin condition.";
    } else {
      return "Loss of appetite can have many causes. It should be evaluated "
          "independently rather than automatically attributed to a skin condition.";
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final bool hasSymptoms = _symptomCount > 0;

    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        return Scaffold(
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
                        ),
                        child: Icon(
                          isDark
                              ? Icons.dark_mode_rounded
                              : Icons.light_mode_rounded,
                          color: isDark
                              ? Colors.amber.shade300
                              : Colors.teal.shade800,
                          size: 26,
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
                    const SizedBox(height: 28),
                    GestureDetector(
                      onTap: !_isHistoryLoaded
                          ? null
                          : () {
                              Navigator.pop(context); // close drawer first
                              _openHistory();
                            },
                      child: Opacity(
                        opacity: _history.isEmpty ? 0.4 : 1.0,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.teal.shade900
                                    : Colors.teal.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.history_rounded,
                                color: isDark
                                    ? Colors.tealAccent
                                    : Colors.teal.shade800,
                                size: 26,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "History",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.teal.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_loadError != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Text(
                      "⚠️ $_loadError",
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontSize: 13,
                      ),
                    ),
                  )
                else if (!_isModelLoaded)
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
                if (hasSymptoms) ...[
                  const SizedBox(height: 10),
                  Container(
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
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// RESULT SCREEN — full-screen takeover after analysis
// ═══════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════
// RESULT SCREEN — full-screen takeover after analysis,
// styled as a colored status card + evidence breakdown.
// ═══════════════════════════════════════════════════════════
class ResultScreen extends StatelessWidget {
  final TriageResult result;
  final List<TriageResult> history;
  final Future<void> Function(TriageResult entry)? onDeleteHistoryEntry;
  final Future<void> Function()? onClearHistory;

  const ResultScreen({
    super.key,
    required this.result,
    required this.history,
    this.onDeleteHistoryEntry,
    this.onClearHistory,
  });

  // ── Pops the analyzed photo up full-screen, tap-to-dismiss ──
  void _showPhotoPopup(BuildContext context, File image) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.file(image, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 40,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _urgencyColor(UrgencyLevel u) {
    switch (u) {
      case UrgencyLevel.high:
        return const Color(0xFFE0402C);
      case UrgencyLevel.moderate:
        return const Color(0xFFF2A93B);
      case UrgencyLevel.stable:
        return const Color(0xFF3FA85C);
    }
  }

  IconData _urgencyIcon(UrgencyLevel u) {
    switch (u) {
      case UrgencyLevel.high:
        return Icons.warning_rounded;
      case UrgencyLevel.moderate:
        return Icons.assignment_late_rounded;
      case UrgencyLevel.stable:
        return Icons.verified_rounded;
    }
  }

  String _headerLabel() =>
      result.symptomCount > 0 ? "Triage Analyzation:" : "Analyzation:";

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        final color = _urgencyColor(result.urgency);
        final icon = _urgencyIcon(result.urgency);

        return Scaffold(
          extendBodyBehindAppBar: false,
          appBar: AppBar(
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              "Detection",
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            centerTitle: false,
            actions: [
              IconButton(
                tooltip: "Analyze again",
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [color.withValues(alpha: 0.28), const Color(0xFF121212)]
                    : [
                        color.withValues(alpha: 0.18),
                        color.withValues(alpha: 0.04),
                      ],
                stops: const [0.0, 0.45],
              ),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Top summary banner ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.35 : 0.06,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: color, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _headerLabel(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.grey.shade300
                                        : Colors.grey.shade700,
                                  ),
                                ),
                                Text(
                                  result.urgency.label,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  result.detectedDisease != null
                                      ? "AI Detection: ${result.detectedDisease}"
                                      : "AI Detection: No skin disease detected",
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: isDark
                                        ? Colors.grey.shade300
                                        : Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Analyzed photo — tap to pop up full-screen ──
                    if (result.image != null)
                      GestureDetector(
                        onTap: () => _showPhotoPopup(context, result.image!),
                        child: Container(
                          width: double.infinity,
                          height: 220,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.35 : 0.08,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.file(
                                  result.image!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Theme.of(context).cardColor,
                                    child: Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        size: 40,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 10,
                                bottom: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.zoom_in_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        "Tap to enlarge",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ── Main detail card ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isDark ? 0.16 : 0.10),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "Detection Result",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "RESULT",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.18),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(icon, color: color, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: "${_headerLabel()} ",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      TextSpan(
                                        text: result.urgency.label,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),
                          Text(
                            "Diagnosis summary",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            result.detectedDisease != null
                                ? "AI Detection: ${result.detectedDisease}"
                                : "AI Detection: No skin disease detected",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),

                          const SizedBox(height: 18),

                          // ── Evidence panel: confidence, detections, evidence strength ──
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.analytics_outlined,
                                      size: 15,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        "Evidence Analysis",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.grey.shade300
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        result.evidenceStrength.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                if (result.confidence != null) ...[
                                  Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 2,
                                    children: [
                                      Text(
                                        "Model Confidence",
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                      Text(
                                        "${(result.confidence! * 100).toStringAsFixed(0)}%"
                                        "${result.confidenceLevel != null ? ' · ${result.confidenceLevel!.label}' : ''}",
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: result.confidence,
                                      minHeight: 8,
                                      backgroundColor: isDark
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        color,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Confidence reflects how sure the AI is about this prediction — "
                                    "not how severe the condition is.",
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontStyle: FontStyle.italic,
                                      color: isDark
                                          ? Colors.grey.shade500
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                ],

                                Row(
                                  children: [
                                    Expanded(
                                      child: _statTile(
                                        context: context,
                                        isDark: isDark,
                                        label: "Detected Areas",
                                        value: "${result.detectionCount}",
                                        icon: Icons.grain_rounded,
                                        color: color,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _statTile(
                                        context: context,
                                        isDark: isDark,
                                        label: "Symptoms",
                                        value: "${result.symptomCount}",
                                        icon: Icons.checklist_rtl_rounded,
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _statTile(
                                        context: context,
                                        isDark: isDark,
                                        label: "Presence",
                                        value: result.presenceStatus.label,
                                        icon: Icons.fact_check_outlined,
                                        color: color,
                                        small: true,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _statTile(
                                        context: context,
                                        isDark: isDark,
                                        label: "Clinical Risk",
                                        value:
                                            result.diseaseRisk?.label ?? "N/A",
                                        icon: Icons.health_and_safety_outlined,
                                        color: color,
                                        small: true,
                                      ),
                                    ),
                                  ],
                                ),

                                if (result.isAmbiguous) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.help_outline_rounded,
                                        size: 14,
                                        color: color,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          "Classification is ambiguous between candidate conditions.",
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontStyle: FontStyle.italic,
                                            color: isDark
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // ── Reasoning + recommendation ──
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.psychology_outlined,
                                      size: 15,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Expert System Reasoning",
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.grey.shade300
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  result.reasoning,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    height: 1.5,
                                    color: isDark
                                        ? Colors.grey.shade200
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: color.withValues(
                                      alpha: isDark ? 0.15 : 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    result.recommendation,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      height: 1.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 13,
                                color: isDark
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "This is an AI-assisted triage tool. Always consult a licensed veterinarian for diagnosis.",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color: isDark
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // ── Bottom actions ──
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              side: BorderSide(color: color, width: 2),
                            ),
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.arrow_back,
                              color: color,
                              size: 18,
                            ),
                            label: Text(
                              "Back",
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 3,
                            ),
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text(
                              "Analyze again",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statTile({
    required BuildContext context,
    required bool isDark,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool small = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: small ? 11.5 : 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// HISTORY SCREEN — view previous results this session
// ═══════════════════════════════════════════════════════════
class HistoryScreen extends StatefulWidget {
  final List<TriageResult> history;
  final Future<void> Function(TriageResult entry) onDelete;
  final Future<void> Function() onClearAll;

  const HistoryScreen({
    super.key,
    required this.history,
    required this.onDelete,
    required this.onClearAll,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Local mutable copy so the list updates immediately on delete,
  // while the parent (source of truth) handles persisting to disk.
  late List<TriageResult> _items;

  @override
  void initState() {
    super.initState();
    _items = List<TriageResult>.from(widget.history);
  }

  Future<void> _confirmDelete(TriageResult entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete this analysis?"),
        content: const Text(
          "This will permanently remove this entry from your history.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _items.remove(entry));
      await widget.onDelete(entry);
    }
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Clear all history?"),
        content: const Text(
          "This will permanently remove every saved analysis. This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Clear All", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _items = []);
      await widget.onClearAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Analysis History"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: "Clear all",
              onPressed: _confirmClearAll,
            ),
        ],
      ),
      body: _items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "No saved analyses yet",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final r = _items[i];
                return Dismissible(
                  key: ValueKey(r.timestamp.toIso8601String() + i.toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    await _confirmDelete(r);
                    // We manage removal ourselves via setState above;
                    // tell Dismissible not to also remove the widget itself
                    // unless the item is actually gone from _items.
                    return !_items.contains(r);
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: r.image != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                r.image!,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Text(
                                  r.urgency.icon,
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                            )
                          : Text(
                              r.urgency.icon,
                              style: const TextStyle(fontSize: 22),
                            ),
                      title: Text(r.detectedDisease ?? "No disease detected"),
                      subtitle: Text(
                        "${r.urgency.label} · ${r.timestamp.hour.toString().padLeft(2, '0')}:${r.timestamp.minute.toString().padLeft(2, '0')}",
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.grey,
                        ),
                        tooltip: "Delete",
                        onPressed: () => _confirmDelete(r),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ResultScreen(
                            result: r,
                            history: _items,
                            onDeleteHistoryEntry: widget.onDelete,
                            onClearHistory: widget.onClearAll,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
