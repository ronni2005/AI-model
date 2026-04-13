// services/inference_service.dart
// Pure-Dart rule-based inference engine.
// No tflite_flutter — runs on every platform (Windows, Mac, Linux, Android).
// When you add .tflite files later, swap _ruleBasedDiseases/_ruleBasedRisk
// with the TFLite interpreter calls shown in the comments below.

import '../models/patient_record.dart';

class InferenceService {
  InferenceService._();
  static final InferenceService instance = InferenceService._();

  bool get isModelLoaded => false; // set true when .tflite is wired in

  // ── Main entry point ────────────────────────────────────────────────
  Future<AssessmentResult> predict({
    required Set<String> selectedSymptoms,
    required PatientVitals vitals,
    String? voiceTranscript,
    String? imagePath,
  }) async {
    // Small artificial delay so the UI spinner shows (simulates inference)
    await Future.delayed(const Duration(milliseconds: 900));

    final topDiseases = _ruleBasedDiseases(selectedSymptoms, vitals);
    final riskLevel   = _ruleBasedRisk(vitals, selectedSymptoms);
    final nextSteps   = _buildNextSteps(riskLevel, topDiseases.first.diseaseName);

    return AssessmentResult(
      topDiseases:       topDiseases,
      riskLevel:         riskLevel,
      nextSteps:         nextSteps,
      vitals:            vitals,
      selectedSymptoms:  selectedSymptoms.toList(),
      voiceTranscript:   voiceTranscript,
      imagePath:         imagePath,
    );
  }

  // ── Disease scoring ─────────────────────────────────────────────────
  List<DiseasePrediction> _ruleBasedDiseases(
      Set<String> sym, PatientVitals v) {
    final scores = <String, double>{};

    void vote(String disease, double w) =>
        scores[disease] = (scores[disease] ?? 0) + w;

    // ---- Fever cluster ----
    if (sym.contains('fever') || sym.contains('high_fever')) {
      if (sym.contains('chills') && sym.contains('muscle_pain')) {
        vote("Malaria", 3.5);
      }
      if (sym.contains('headache') && sym.contains('abdominal_pain')) {
        vote("Typhoid", 3.0);
      }
      if (sym.contains('rash') && sym.contains('joint_pain')) {
        vote("Dengue", 3.5);
      }
      if (sym.contains('rash'))   vote("Dengue", 1.0);
      if (sym.contains('dry_cough') && sym.contains('fatigue')) {
        vote("COVID-19", 2.5);
      }
      vote("Common Cold / Flu", 1.0);
    }

    // ---- Respiratory ----
    if (sym.contains('wet_cough') && sym.contains('night_sweats') &&
        sym.contains('weight_loss')) {
      vote("Tuberculosis", 4.5);
    }
    if (sym.contains('wet_cough') && sym.contains('breathlessness')) {
      vote("Pneumonia", 3.5);
    }
    if (sym.contains('dry_cough') && sym.contains('fatigue')) {
      vote("COVID-19", 1.5);
    }
    if (sym.contains('cough') && sym.contains('runny_nose') &&
        sym.contains('sore_throat')) {
      vote("Common Cold / Flu", 3.0);
    }

    // ---- SpO2-based ----
    if (v.spo2Percent < 93) vote("Pneumonia", 2.0);
    if (v.respiratoryRate > 24) vote("Pneumonia", 1.5);

    // ---- Digestive ----
    if (sym.contains('diarrhea') && sym.contains('vomiting')) {
      vote("Diarrheal Disease", 3.5);
    }
    if (sym.contains('yellow_eyes') || sym.contains('dark_urine')) {
      vote("Jaundice", 4.5);
    }

    // ---- Metabolic / Chronic ----
    if (sym.contains('excessive_thirst') && sym.contains('frequent_urination')) {
      vote("Diabetes", 4.5);
    }
    if (sym.contains('burning_urination') && sym.contains('back_pain')) {
      vote("UTI", 4.5);
    }
    if (v.systolicBp > 145) vote("Hypertension", 3.0);
    if (v.systolicBp > 160) vote("Hypertension", 1.5);
    if (sym.contains('weight_loss') && sym.contains('swelling')) {
      vote("Malnutrition", 3.0);
    }
    if (sym.contains('fatigue') && sym.contains('palpitations') &&
        sym.contains('dizziness')) {
      vote("Anemia", 3.5);
    }
    if (sym.contains('headache') && sym.contains('dizziness') &&
        v.systolicBp > 140) {
      vote("Hypertension", 2.0);
    }

    // ---- Skin ----
    if (sym.contains('skin_lesion') || sym.contains('rash')) {
      vote("Skin Infection", 2.0);
    }

    // Default fallback
    if (scores.isEmpty) vote("Common Cold / Flu", 1.0);

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = sorted.take(3).toList();
    final total = top3.fold(0.0, (s, e) => s + e.value);

    return top3.asMap().entries.map((e) => DiseasePrediction(
      diseaseName: e.value.key,
      probability: total > 0
          ? (e.value.value / total).clamp(0.0, 1.0)
          : 0.33,
      rank: e.key + 1,
    )).toList();
  }

  // ── Risk classification ─────────────────────────────────────────────
  String _ruleBasedRisk(PatientVitals v, Set<String> sym) {
    // Emergency
    if (v.spo2Percent < 90 ||
        v.systolicBp > 180 ||
        v.temperatureF > 104.5 ||
        v.respiratoryRate > 30 ||
        sym.contains('seizure') ||
        sym.contains('confusion') ||
        sym.contains('fainting')) {
      return "Emergency";
    }

    // Urgent
    if (v.spo2Percent < 94 ||
        v.systolicBp > 155 ||
        v.temperatureF > 102.5 ||
        v.respiratoryRate > 24 ||
        sym.contains('breathlessness') ||
        sym.contains('chest_pain') ||
        sym.contains('bleeding')) {
      return "Urgent";
    }

    return "Normal";
  }

  // ── Next steps ──────────────────────────────────────────────────────
  List<String> _buildNextSteps(String risk, String disease) {
    final steps = <String>[];

    switch (risk) {
      case "Emergency":
        steps.addAll([
          "⚠️ Refer patient to nearest hospital IMMEDIATELY",
          "Do NOT delay — arrange transport / ambulance now",
          "Monitor vitals continuously during transfer",
          "Inform receiving facility about patient condition",
        ]);
        break;
      case "Urgent":
        steps.addAll([
          "📋 Schedule doctor consultation within 24 hours",
          "Start supportive care: hydration, rest, fever management",
          "Monitor vitals every 4–6 hours",
          "Return immediately if condition worsens",
        ]);
        break;
      default:
        steps.addAll([
          "🏠 Home care and rest advised",
          "Ensure adequate hydration and nutrition",
          "Monitor for 48 hours; revisit if no improvement",
        ]);
    }

    const diseaseSteps = <String, List<String>>{
      "Malaria": [
        "Collect blood sample for RDT / slide test",
        "Start anti-malarial per local protocol if confirmed",
        "Use mosquito net; prevent further bites",
      ],
      "Tuberculosis": [
        "Refer for sputum AFB / CBNAAT test",
        "Isolate patient; ensure mask use",
        "Notify RNTCP / district TB officer",
      ],
      "Pneumonia": [
        "Administer oxygen if SpO₂ < 94%",
        "Amoxicillin 500 mg TDS per protocol",
        "Urgent referral if SpO₂ drops further",
      ],
      "Dengue": [
        "NO aspirin or ibuprofen — paracetamol only",
        "Encourage frequent oral fluid intake",
        "Watch for bleeding — immediate referral if present",
      ],
      "Typhoid": [
        "Send blood/stool culture if available",
        "Azithromycin or Ceftriaxone per protocol",
        "Avoid raw food and contaminated water",
      ],
      "COVID-19": [
        "Isolate patient for 5–7 days",
        "Monitor SpO₂ every 4 hours",
        "Refer to hospital if SpO₂ drops below 94%",
      ],
      "Diarrheal Disease": [
        "Start ORS immediately — 200 ml after each loose stool",
        "Zinc 20 mg daily for 14 days (children)",
        "Encourage frequent small feeds",
      ],
      "Hypertension": [
        "Advise low-salt diet and rest",
        "Refer for BP monitoring and medication review",
        "Avoid stress and heavy physical exertion",
      ],
      "Diabetes": [
        "Check blood glucose with glucometer if available",
        "Advise immediate dietary modification",
        "Refer for HbA1c and medication review",
      ],
      "Malnutrition": [
        "Enrol in ICDS / NRC programme if child",
        "Provide therapeutic food (RUTF) per protocol",
        "Check for vitamin A, iron deficiency",
      ],
      "UTI": [
        "Cotrimoxazole or Nitrofurantoin per local protocol",
        "Encourage increased fluid intake",
        "Refer if symptoms persist after 3 days",
      ],
      "Anemia": [
        "Start iron + folic acid supplementation",
        "Advise iron-rich foods (leafy vegetables, jaggery)",
        "Refer if breathlessness is severe",
      ],
      "Jaundice": [
        "Check for hepatitis A/B/E via rapid test",
        "Strict bed rest, high-carb low-fat diet",
        "Refer urgently if confusion or deep jaundice",
      ],
    };

    steps.addAll(
      diseaseSteps[disease] ??
          ["Follow standard care protocols", "Record vitals daily"],
    );
    return steps;
  }
}
