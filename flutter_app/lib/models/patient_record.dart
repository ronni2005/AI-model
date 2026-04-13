// models/patient_record.dart
import 'dart:convert';

// ════════════════════════════════════════════
// VITALS
// ════════════════════════════════════════════

class PatientVitals {
  final double temperatureF;
  final double pulseBpm;
  final double systolicBp;
  final double diastolicBp;
  final double spo2Percent;
  final double respiratoryRate;
  final double age;
  final double weightKg;

  const PatientVitals({
    required this.temperatureF,
    required this.pulseBpm,
    required this.systolicBp,
    required this.diastolicBp,
    required this.spo2Percent,
    required this.respiratoryRate,
    required this.age,
    required this.weightKg,
  });

  factory PatientVitals.defaults() => const PatientVitals(
        temperatureF: 98.6,
        pulseBpm: 72,
        systolicBp: 120,
        diastolicBp: 80,
        spo2Percent: 98,
        respiratoryRate: 16,
        age: 30,
        weightKg: 55,
      );

  static double _d(dynamic v, double def) =>
      v == null ? def : (v as num).toDouble();

  Map<String, dynamic> toMap() => {
        'temperature_f': temperatureF,
        'pulse_bpm': pulseBpm,
        'systolic_bp': systolicBp,
        'diastolic_bp': diastolicBp,
        'spo2_percent': spo2Percent,
        'respiratory_rate': respiratoryRate,
        'age': age,
        'weight_kg': weightKg,
      };

  factory PatientVitals.fromMap(Map<String, dynamic> m) => PatientVitals(
        temperatureF: _d(m['temperature_f'], 98.6),
        pulseBpm: _d(m['pulse_bpm'], 72),
        systolicBp: _d(m['systolic_bp'], 120),
        diastolicBp: _d(m['diastolic_bp'], 80),
        spo2Percent: _d(m['spo2_percent'], 98),
        respiratoryRate: _d(m['respiratory_rate'], 16),
        age: _d(m['age'], 30),
        weightKg: _d(m['weight_kg'], 55),
      );

  List<double> toFeatureList() => [
        temperatureF, pulseBpm, systolicBp, diastolicBp,
        spo2Percent, respiratoryRate, age, weightKg,
      ];

  String get bpString => '${systolicBp.toInt()}/${diastolicBp.toInt()} mmHg';
  String get tempString => '${temperatureF.toStringAsFixed(1)} °F';
  String get spo2String => '${spo2Percent.toInt()} %';
  String get pulseString => '${pulseBpm.toInt()} bpm';
  String get rrString => '${respiratoryRate.toInt()} /min';
  String get ageString => '${age.toInt()} yrs';
  String get weightString => '${weightKg.toStringAsFixed(1)} kg';
}

// ════════════════════════════════════════════
// DISEASE PREDICTION
// ════════════════════════════════════════════

class DiseasePrediction {
  final String diseaseName;
  final double probability;
  final int rank;

  const DiseasePrediction({
    required this.diseaseName,
    required this.probability,
    required this.rank,
  });

  String get probabilityPercent =>
      '${(probability * 100).toStringAsFixed(1)} %';

  Map<String, dynamic> toMap() => {
        'disease_name': diseaseName,
        'probability': probability,
        'rank': rank,
      };

  factory DiseasePrediction.fromMap(Map<String, dynamic> m) =>
      DiseasePrediction(
        diseaseName: m['disease_name'] as String,
        probability: (m['probability'] as num).toDouble(),
        rank: m['rank'] as int,
      );
}

// ════════════════════════════════════════════
// ASSESSMENT RESULT
// ════════════════════════════════════════════

class AssessmentResult {
  final List<DiseasePrediction> topDiseases;
  final String riskLevel; // "Emergency" | "Urgent" | "Normal"
  final List<String> nextSteps;
  final PatientVitals vitals;
  final List<String> selectedSymptoms;
  final String? voiceTranscript;
  final String? imagePath;
  final DateTime assessedAt;

  AssessmentResult({
    required this.topDiseases,
    required this.riskLevel,
    required this.nextSteps,
    required this.vitals,
    required this.selectedSymptoms,
    this.voiceTranscript,
    this.imagePath,
    DateTime? assessedAt,
  }) : assessedAt = assessedAt ?? DateTime.now();

  String get primaryDisease =>
      topDiseases.isNotEmpty ? topDiseases.first.diseaseName : 'Unknown';

  Map<String, dynamic> toMap() => {
        'top_diseases': topDiseases.map((d) => d.toMap()).toList(),
        'risk_level': riskLevel,
        'next_steps': nextSteps,
        'vitals': vitals.toMap(),
        'selected_symptoms': selectedSymptoms,
        'voice_transcript': voiceTranscript,
        'image_path': imagePath,
        'assessed_at': assessedAt.toIso8601String(),
      };

  String toJson() => jsonEncode(toMap());

  factory AssessmentResult.fromMap(Map<String, dynamic> m) =>
      AssessmentResult(
        topDiseases: (m['top_diseases'] as List)
            .map((d) => DiseasePrediction.fromMap(d as Map<String, dynamic>))
            .toList(),
        riskLevel: m['risk_level'] as String,
        nextSteps: List<String>.from(m['next_steps'] as List),
        vitals:
            PatientVitals.fromMap(m['vitals'] as Map<String, dynamic>),
        selectedSymptoms:
            List<String>.from(m['selected_symptoms'] as List),
        voiceTranscript: m['voice_transcript'] as String?,
        imagePath: m['image_path'] as String?,
        assessedAt: DateTime.parse(m['assessed_at'] as String),
      );
}

// ════════════════════════════════════════════
// PATIENT RECORD  (SQLite row)
// ════════════════════════════════════════════

class PatientRecord {
  final String? id;
  final String patientName;
  final int age;
  final String gender;
  final String village;
  final String workerName;
  final AssessmentResult assessment;
  final DateTime createdAt;

  PatientRecord({
    this.id,
    required this.patientName,
    required this.age,
    required this.gender,
    required this.village,
    required this.workerName,
    required this.assessment,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'patient_name': patientName,
        'age': age,
        'gender': gender,
        'village': village,
        'worker_name': workerName,
        'assessment_json': assessment.toJson(),
        'risk_level': assessment.riskLevel,
        'primary_disease': assessment.primaryDisease,
        'created_at': createdAt.toIso8601String(),
      };

  factory PatientRecord.fromMap(Map<String, dynamic> m) => PatientRecord(
        id: m['id']?.toString(),
        patientName: m['patient_name'] as String,
        age: m['age'] as int,
        gender: m['gender'] as String,
        village: m['village'] as String? ?? '',
        workerName: m['worker_name'] as String? ?? '',
        assessment: AssessmentResult.fromMap(
          jsonDecode(m['assessment_json'] as String)
              as Map<String, dynamic>,
        ),
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
