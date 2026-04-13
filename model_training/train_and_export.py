"""
Rural Health AI — Model Training & TFLite Export
=================================================
Pipeline:
  1. Generate synthetic clinical dataset (replace with real data in prod)
  2. Train XGBoost classifiers (disease + risk)
  3. Wrap in TensorFlow SavedModel → convert to .tflite
  4. Save label metadata JSON for Flutter to consume

Run:
  pip install -r requirements.txt
  python train_and_export.py
Outputs:
  exported/disease_model.tflite
  exported/risk_model.tflite
  exported/model_metadata.json   ← copy all three to flutter_app/assets/models/
"""

import json
import os
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import classification_report, accuracy_score
import xgboost as xgb
import tensorflow as tf

# ──────────────────────────────────────────────
# FEATURE SCHEMA  (must mirror lib/services/feature_builder.dart)
# ──────────────────────────────────────────────

SYMPTOM_FEATURES = [
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
]

VITAL_FEATURES = [
    "temperature_f",    # 95–106
    "pulse_bpm",        # 40–180
    "systolic_bp",      # 60–200
    "diastolic_bp",     # 40–130
    "spo2_percent",     # 70–100
    "respiratory_rate", # 8–40
    "age",              # 0–100
    "weight_kg",        # 3–150
]

ALL_FEATURES = SYMPTOM_FEATURES + VITAL_FEATURES  # 48 total

DISEASES = [
    "Malaria", "Typhoid", "Tuberculosis", "Pneumonia",
    "Dengue", "COVID-19", "Diarrheal Disease", "Anemia",
    "Hypertension", "Diabetes", "UTI", "Jaundice",
    "Malnutrition", "Common Cold / Flu", "Skin Infection",
]

RISK_LEVELS = ["Normal", "Urgent", "Emergency"]

# ──────────────────────────────────────────────
# SYNTHETIC DATASET
# ──────────────────────────────────────────────

DISEASE_PROFILES = {
    "Malaria": {
        "core": ["fever", "high_fever", "chills", "headache", "muscle_pain", "fatigue", "nausea", "vomiting"],
        "vitals": {"temperature_f": (102, 105), "pulse_bpm": (90, 120)},
        "risk": ["Urgent", "Emergency"],
    },
    "Typhoid": {
        "core": ["fever", "headache", "abdominal_pain", "loss_of_appetite", "fatigue", "diarrhea", "weakness"],
        "vitals": {"temperature_f": (101, 104), "pulse_bpm": (80, 100)},
        "risk": ["Urgent", "Emergency"],
    },
    "Tuberculosis": {
        "core": ["wet_cough", "cough", "night_sweats", "weight_loss", "fatigue", "breathlessness", "chest_pain"],
        "vitals": {"temperature_f": (99, 102), "spo2_percent": (86, 95), "respiratory_rate": (18, 28)},
        "risk": ["Urgent", "Emergency"],
    },
    "Pneumonia": {
        "core": ["fever", "wet_cough", "breathlessness", "chest_pain", "fatigue"],
        "vitals": {"temperature_f": (101, 104), "spo2_percent": (80, 93), "respiratory_rate": (24, 38)},
        "risk": ["Urgent", "Emergency"],
    },
    "Dengue": {
        "core": ["fever", "high_fever", "rash", "joint_pain", "muscle_pain", "headache", "bleeding", "fatigue"],
        "vitals": {"temperature_f": (102, 105), "pulse_bpm": (85, 115)},
        "risk": ["Urgent", "Emergency"],
    },
    "COVID-19": {
        "core": ["fever", "dry_cough", "fatigue", "breathlessness", "loss_of_appetite", "headache"],
        "vitals": {"temperature_f": (99, 103), "spo2_percent": (85, 97), "respiratory_rate": (18, 32)},
        "risk": ["Normal", "Urgent", "Emergency"],
    },
    "Diarrheal Disease": {
        "core": ["diarrhea", "abdominal_pain", "nausea", "vomiting", "weakness", "fever"],
        "vitals": {"temperature_f": (99, 102), "pulse_bpm": (88, 115)},
        "risk": ["Normal", "Urgent"],
    },
    "Anemia": {
        "core": ["fatigue", "weakness", "dizziness", "palpitations", "breathlessness"],
        "vitals": {"pulse_bpm": (90, 120), "temperature_f": (97, 99)},
        "risk": ["Normal", "Urgent"],
    },
    "Hypertension": {
        "core": ["headache", "dizziness", "palpitations", "chest_pain", "blurred_vision"],
        "vitals": {"systolic_bp": (150, 200), "diastolic_bp": (95, 130)},
        "risk": ["Normal", "Urgent", "Emergency"],
    },
    "Diabetes": {
        "core": ["excessive_thirst", "excessive_hunger", "frequent_urination", "fatigue", "blurred_vision", "weight_loss"],
        "vitals": {"temperature_f": (97, 99)},
        "risk": ["Normal", "Urgent"],
    },
    "UTI": {
        "core": ["burning_urination", "frequent_urination", "abdominal_pain", "fever", "back_pain"],
        "vitals": {"temperature_f": (99, 102)},
        "risk": ["Normal", "Urgent"],
    },
    "Jaundice": {
        "core": ["yellow_eyes", "dark_urine", "fatigue", "loss_of_appetite", "nausea", "abdominal_pain"],
        "vitals": {"temperature_f": (99, 102)},
        "risk": ["Urgent", "Emergency"],
    },
    "Malnutrition": {
        "core": ["weight_loss", "weakness", "fatigue", "swelling", "loss_of_appetite"],
        "vitals": {"temperature_f": (96, 98), "pulse_bpm": (60, 90), "weight_kg": (25, 45)},
        "risk": ["Normal", "Urgent"],
    },
    "Common Cold / Flu": {
        "core": ["cough", "runny_nose", "sore_throat", "fever", "headache", "muscle_pain", "fatigue"],
        "vitals": {"temperature_f": (99, 101)},
        "risk": ["Normal"],
    },
    "Skin Infection": {
        "core": ["rash", "skin_lesion", "swelling", "fever", "fatigue"],
        "vitals": {"temperature_f": (99, 101)},
        "risk": ["Normal", "Urgent"],
    },
}

BASE_VITAL_RANGES = {
    "temperature_f":    (97.5, 99.5),
    "pulse_bpm":        (60,   90),
    "systolic_bp":      (110,  130),
    "diastolic_bp":     (70,   85),
    "spo2_percent":     (96,   100),
    "respiratory_rate": (14,   20),
    "age":              (5,    70),
    "weight_kg":        (20,   80),
}


def generate_dataset(n: int = 8000, seed: int = 42) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    rows = []

    for _ in range(n):
        disease = rng.choice(DISEASES)
        profile = DISEASE_PROFILES[disease]
        row: dict = {}

        # Symptoms
        for sf in SYMPTOM_FEATURES:
            if sf in profile["core"]:
                row[sf] = float(rng.random() > 0.20)   # 80 % present
            else:
                row[sf] = float(rng.random() > 0.88)   # 12 % noise

        # Vitals
        vr = {**BASE_VITAL_RANGES, **profile.get("vitals", {})}
        for vf in VITAL_FEATURES:
            lo, hi = vr[vf]
            row[vf] = round(float(rng.uniform(lo, hi)), 1)

        # Risk label
        risk = str(rng.choice(profile["risk"]))
        # Hard-rule overrides
        spo2 = row["spo2_percent"]
        sbp  = row["systolic_bp"]
        temp = row["temperature_f"]
        rr   = row["respiratory_rate"]
        if spo2 < 90 or sbp > 180 or temp > 104.5 or row.get("seizure", 0) or row.get("confusion", 0):
            risk = "Emergency"
        elif spo2 < 94 or sbp > 155 or temp > 102.5 or rr > 28:
            if risk == "Normal":
                risk = "Urgent"

        row["disease"]    = disease
        row["risk_level"] = risk
        rows.append(row)

    return pd.DataFrame(rows)


# ──────────────────────────────────────────────
# TRAINING
# ──────────────────────────────────────────────

def train_xgboost(X_train, y_train, X_test, y_test, n_classes, label=""):
    model = xgb.XGBClassifier(
        n_estimators=300,
        max_depth=6,
        learning_rate=0.08,
        subsample=0.85,
        colsample_bytree=0.85,
        eval_metric="mlogloss",
        use_label_encoder=False,
        random_state=42,
        n_jobs=-1,
    )
    model.fit(X_train, y_train,
              eval_set=[(X_test, y_test)],
              verbose=False)
    preds = model.predict(X_test)
    acc = accuracy_score(y_test, preds)
    print(f"\n  [{label}] Accuracy: {acc:.4f}")
    return model, acc


# ──────────────────────────────────────────────
# TFLITE EXPORT
# ──────────────────────────────────────────────

def xgboost_to_tflite(xgb_model, n_features: int, out_path: str, n_classes: int):
    """
    Wraps XGBoost booster in a thin TF SavedModel, then converts to TFLite.
    The model takes float32 [1, n_features] → returns float32 [1, n_classes] probabilities.
    """
    # Extract raw leaf predictions from XGBoost as a numpy lookup approach:
    # We create a TF function that runs inference via tf.py_function embedding.
    # For production use tensorflow_decision_forests or re-train in Keras.

    booster = xgb_model.get_booster()

    # Build a small Keras model that delegates to XGBoost via a numpy lambda
    class XGBWrapper(tf.Module):
        def __init__(self, bst, n_cls):
            super().__init__()
            self._bst = bst
            self._n_cls = n_cls

        @tf.function(input_signature=[tf.TensorSpec(shape=[1, n_features], dtype=tf.float32)])
        def predict(self, x):
            # Use tf.numpy_function for inference
            def _infer(arr):
                dm = xgb.DMatrix(arr)
                proba = self._bst.predict(dm)  # shape (1, n_cls) or (1,) for binary
                if proba.ndim == 1:
                    proba = proba.reshape(1, -1)
                return proba.astype(np.float32)

            result = tf.numpy_function(_infer, [x], tf.float32)
            result.set_shape([1, self._n_cls])
            return result

    saved_dir = out_path.replace(".tflite", "_saved")
    wrapper = XGBWrapper(booster, n_classes)
    tf.saved_model.save(wrapper, saved_dir, signatures={"serving_default": wrapper.predict})

    # Convert to TFLite
    converter = tf.lite.TFLiteConverter.from_saved_model(
        saved_dir,
        signature_keys=["serving_default"],
    )
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]
    tflite_model = converter.convert()

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "wb") as f:
        f.write(tflite_model)
    size_kb = len(tflite_model) / 1024
    print(f"  Saved {out_path}  ({size_kb:.1f} KB)")
    return tflite_model


# ──────────────────────────────────────────────
# MAIN
# ──────────────────────────────────────────────

def main():
    OUT_DIR = "exported"
    FLUTTER_ASSETS = "../flutter_app/assets/models"
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(FLUTTER_ASSETS, exist_ok=True)

    print("═" * 55)
    print("  Rural Health AI — Training Pipeline")
    print("═" * 55)

    # 1. Dataset
    print("\n📊  Generating dataset …")
    df = generate_dataset(8000)
    print(f"     Shape: {df.shape}")
    print(f"     Disease distribution:\n{df['disease'].value_counts().to_string()}")
    print(f"     Risk distribution:\n{df['risk_level'].value_counts().to_string()}")

    X = df[ALL_FEATURES].values.astype(np.float32)

    disease_enc = LabelEncoder().fit(DISEASES)
    risk_enc    = LabelEncoder().fit(RISK_LEVELS)

    y_disease = disease_enc.transform(df["disease"])
    y_risk    = risk_enc.transform(df["risk_level"])

    X_tr, X_te, yd_tr, yd_te, yr_tr, yr_te = train_test_split(
        X, y_disease, y_risk, test_size=0.2, random_state=42, stratify=y_disease
    )

    # 2. Train
    print("\n🔬  Training disease classifier …")
    disease_model, d_acc = train_xgboost(X_tr, yd_tr, X_te, yd_te,
                                          len(DISEASES), "Disease")
    print(classification_report(yd_te, disease_model.predict(X_te),
                                 target_names=list(disease_enc.classes_)))

    print("\n⚠️   Training risk classifier …")
    risk_model, r_acc = train_xgboost(X_tr, yr_tr, X_te, yr_te,
                                       len(RISK_LEVELS), "Risk")
    print(classification_report(yr_te, risk_model.predict(X_te),
                                 target_names=list(risk_enc.classes_)))

    # 3. Export TFLite
    print("\n📦  Exporting to TFLite …")
    disease_tflite_path = f"{OUT_DIR}/disease_model.tflite"
    risk_tflite_path    = f"{OUT_DIR}/risk_model.tflite"

    xgboost_to_tflite(disease_model, len(ALL_FEATURES), disease_tflite_path, len(DISEASES))
    xgboost_to_tflite(risk_model,    len(ALL_FEATURES), risk_tflite_path,    len(RISK_LEVELS))

    # Copy to flutter assets
    import shutil
    for fname in ["disease_model.tflite", "risk_model.tflite"]:
        shutil.copy(f"{OUT_DIR}/{fname}", f"{FLUTTER_ASSETS}/{fname}")
        print(f"  Copied → {FLUTTER_ASSETS}/{fname}")

    # 4. Metadata JSON
    metadata = {
        "model_version": "1.0.0",
        "feature_names": ALL_FEATURES,
        "symptom_features": SYMPTOM_FEATURES,
        "vital_features": VITAL_FEATURES,
        "disease_classes": list(disease_enc.classes_),
        "risk_classes": list(risk_enc.classes_),
        "n_features": len(ALL_FEATURES),
        "disease_model_accuracy": round(d_acc, 4),
        "risk_model_accuracy": round(r_acc, 4),
    }
    meta_json = json.dumps(metadata, indent=2)
    for path in [f"{OUT_DIR}/model_metadata.json", f"{FLUTTER_ASSETS}/model_metadata.json"]:
        with open(path, "w") as f:
            f.write(meta_json)
    print(f"  Saved model_metadata.json")

    print("\n✅  All done! Copy flutter_app/assets/models/* into your Flutter project.")
    print("═" * 55)


if __name__ == "__main__":
    main()
