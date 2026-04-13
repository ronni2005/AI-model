// services/feature_builder.dart
import 'dart:typed_data';
import '../models/patient_record.dart';

const List<String> kSymptomFeatures = [
  "fever", "high_fever", "cough", "dry_cough", "wet_cough",
  "breathlessness", "chest_pain", "fatigue", "weakness",
  "headache", "nausea", "vomiting", "diarrhea", "abdominal_pain",
  "rash", "skin_lesion", "swelling", "joint_pain", "muscle_pain",
  "sore_throat", "runny_nose", "loss_of_appetite", "weight_loss",
  "night_sweats", "chills", "confusion", "seizure",
  "bleeding", "yellow_eyes", "dark_urine", "swollen_lymph_nodes",
  "burning_urination", "frequent_urination", "back_pain",
  "blurred_vision", "excessive_thirst", "excessive_hunger",
  "palpitations", "dizziness", "fainting",
];

const Map<String, String> kSymptomLabels = {
  "fever":              "Fever",
  "high_fever":         "High Fever (>103°F)",
  "cough":              "Cough",
  "dry_cough":          "Dry Cough",
  "wet_cough":          "Wet / Productive Cough",
  "breathlessness":     "Breathlessness",
  "chest_pain":         "Chest Pain",
  "fatigue":            "Fatigue / Tiredness",
  "weakness":           "Weakness",
  "headache":           "Headache",
  "nausea":             "Nausea",
  "vomiting":           "Vomiting",
  "diarrhea":           "Diarrhea",
  "abdominal_pain":     "Abdominal Pain",
  "rash":               "Skin Rash",
  "skin_lesion":        "Skin Lesion / Wound",
  "swelling":           "Swelling",
  "joint_pain":         "Joint Pain",
  "muscle_pain":        "Muscle / Body Pain",
  "sore_throat":        "Sore Throat",
  "runny_nose":         "Runny Nose",
  "loss_of_appetite":   "Loss of Appetite",
  "weight_loss":        "Unexplained Weight Loss",
  "night_sweats":       "Night Sweats",
  "chills":             "Chills / Shivering",
  "confusion":          "Confusion / Disorientation",
  "seizure":            "Seizure / Fits",
  "bleeding":           "Unusual Bleeding",
  "yellow_eyes":        "Yellow Eyes / Skin",
  "dark_urine":         "Dark Urine",
  "swollen_lymph_nodes":"Swollen Lymph Nodes",
  "burning_urination":  "Burning Urination",
  "frequent_urination": "Frequent Urination",
  "back_pain":          "Back / Kidney Pain",
  "blurred_vision":     "Blurred Vision",
  "excessive_thirst":   "Excessive Thirst",
  "excessive_hunger":   "Excessive Hunger",
  "palpitations":       "Heart Palpitations",
  "dizziness":          "Dizziness",
  "fainting":           "Fainting",
};

const Map<String, List<String>> kSymptomGroups = {
  "Fever & Infection": [
    "fever","high_fever","chills","night_sweats","fatigue","weakness"
  ],
  "Respiratory": [
    "cough","dry_cough","wet_cough","breathlessness","chest_pain","sore_throat","runny_nose"
  ],
  "Digestive": [
    "nausea","vomiting","diarrhea","abdominal_pain","loss_of_appetite","dark_urine"
  ],
  "Pain & Swelling": [
    "headache","joint_pain","muscle_pain","back_pain","swelling","swollen_lymph_nodes"
  ],
  "Skin": [
    "rash","skin_lesion","yellow_eyes"
  ],
  "Neurological": [
    "confusion","seizure","dizziness","fainting","blurred_vision"
  ],
  "Urinary": [
    "burning_urination","frequent_urination"
  ],
  "Metabolic": [
    "weight_loss","excessive_thirst","excessive_hunger","palpitations","bleeding"
  ],
};

class FeatureBuilder {
  static Float32List build({
    required Set<String> selectedSymptoms,
    required PatientVitals vitals,
  }) {
    final buf = Float32List(kSymptomFeatures.length + 8);
    for (int i = 0; i < kSymptomFeatures.length; i++) {
      buf[i] = selectedSymptoms.contains(kSymptomFeatures[i]) ? 1.0 : 0.0;
    }
    final vl = vitals.toFeatureList();
    for (int j = 0; j < vl.length; j++) {
      buf[kSymptomFeatures.length + j] = vl[j];
    }
    return buf;
  }

  static Set<String> extractSymptomsFromText(String text) {
    final lower = text.toLowerCase();
    final found = <String>{};
    final keywordMap = <String, List<String>>{
      "fever":             ["fever","bukhar","बुखार"],
      "high_fever":        ["high fever","tej bukhar","tez bukhar"],
      "cough":             ["cough","khansi","खाँसी"],
      "wet_cough":         ["wet cough","balgam","phlegm","productive"],
      "dry_cough":         ["dry cough","sukhi khansi"],
      "breathlessness":    ["breathless","short of breath","saans","सांस"],
      "chest_pain":        ["chest pain","seene mein dard","छाती में दर्द"],
      "fatigue":           ["tired","fatigue","thakan","थकान"],
      "weakness":          ["weak","weakness","kamzori","कमज़ोरी"],
      "headache":          ["headache","sir dard","सिरदर्द"],
      "nausea":            ["nausea","nauseous","ji machlana"],
      "vomiting":          ["vomit","vomiting","ulti","उल्टी"],
      "diarrhea":          ["diarrhea","loose motion","daast","दस्त"],
      "abdominal_pain":    ["stomach pain","pet dard","पेट दर्द"],
      "rash":              ["rash","daane","दाने"],
      "skin_lesion":       ["wound","lesion","ghav","घाव"],
      "swelling":          ["swelling","sujan","सूजन"],
      "joint_pain":        ["joint pain","jodo mein dard","जोड़ों में दर्द"],
      "muscle_pain":       ["body ache","muscle pain","badan dard","बदन दर्द"],
      "sore_throat":       ["sore throat","gale mein dard","गले में दर्द"],
      "runny_nose":        ["runny nose","naak behna","नाक बहना","cold"],
      "loss_of_appetite":  ["no appetite","bhukh nahi","भूख नहीं"],
      "weight_loss":       ["weight loss","wajan kam","वजन कम"],
      "night_sweats":      ["night sweat","raat ko paseena"],
      "chills":            ["chills","kaanpna","कांपना","shivering"],
      "confusion":         ["confused","confusion","ghabrahat"],
      "seizure":           ["seizure","fit","mirgi","मिर्गी"],
      "bleeding":          ["bleeding","khoon","खून","blood"],
      "yellow_eyes":       ["yellow eye","peeli ankh","पीली आँखें","jaundice"],
      "dark_urine":        ["dark urine","kaale peshab"],
      "burning_urination": ["burning urination","peshab mein jalan","पेशाब में जलन"],
      "frequent_urination":["frequent urination","baar baar peshab"],
      "back_pain":         ["back pain","kamar dard","कमर दर्द"],
      "blurred_vision":    ["blurred vision","dhundhla","धुंधला"],
      "excessive_thirst":  ["excessive thirst","bahut pyaas","बहुत प्यास"],
      "excessive_hunger":  ["excessive hunger","bahut bhukh"],
      "palpitations":      ["palpitation","dil ki dhadkan"],
      "dizziness":         ["dizzy","dizziness","chakkar","चक्कर"],
      "fainting":          ["faint","behosh","बेहोश","unconscious"],
    };
    keywordMap.forEach((key, keywords) {
      for (final kw in keywords) {
        if (lower.contains(kw)) { found.add(key); break; }
      }
    });
    return found;
  }
}
