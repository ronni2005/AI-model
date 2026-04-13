# RuralHealth AI — Setup & Run Guide
### Run on Windows / Mac / Linux in VS Code

---

## STEP 1 — Install Flutter SDK

**Windows:**
1. Download from https://docs.flutter.dev/get-started/install/windows/desktop
2. Extract the zip to `C:\flutter`
3. Add `C:\flutter\bin` to your system PATH:
   - Search "Environment Variables" in Start Menu
   - Edit PATH → Add `C:\flutter\bin`
4. Open a new terminal and run: `flutter doctor`

**Mac:**
```bash
brew install flutter
flutter doctor
```

**Linux:**
```bash
sudo snap install flutter --classic
flutter doctor
```

After running `flutter doctor`, fix any issues it shows (usually just Android Studio or VS Code extension).

---

## STEP 2 — Enable Desktop Support

Run this once in your terminal:
```bash
flutter config --enable-windows-desktop   # Windows
flutter config --enable-macos-desktop     # Mac
flutter config --enable-linux-desktop     # Linux
```

---

## STEP 3 — Install VS Code Extensions

Open VS Code → Extensions (Ctrl+Shift+X) → search and install:
- **Flutter** (by Dart Code) — ID: `Dart-Code.flutter`
- **Dart** (by Dart Code) — ID: `Dart-Code.dart-code`

---

## STEP 4 — Open the Project

```bash
cd rural_health_ai_desktop/flutter_app
code .
```

Or: File → Open Folder → select `rural_health_ai_desktop/flutter_app`

---

## STEP 5 — Install Dependencies

In the VS Code terminal (Ctrl+`):
```bash
flutter pub get
```

Expected output: `Got dependencies!`

---

## STEP 6 — Run on Desktop

```bash
flutter run -d windows    # Windows
flutter run -d macos      # Mac
flutter run -d linux      # Linux
```

Or press **F5** in VS Code after selecting a device from the bottom status bar.

The app window will open. You can now:
- Click "Start Assessment"
- Fill patient info, select symptoms, enter vitals
- Hit "Analyse Patient" — results appear instantly
- Save the record, generate PDF

---

## STEP 7 (Optional) — Train the ML Model

The app already runs with a rule-based engine. To use the real XGBoost model:

```bash
cd rural_health_ai_desktop/model_training
pip install -r requirements.txt
python train_and_export.py
```

This saves `.tflite` files to `flutter_app/assets/models/`.
To wire them in, update `inference_service.dart` to use `tflite_flutter`.

---

## Common Errors & Fixes

| Error | Fix |
|---|---|
| `flutter: command not found` | Add Flutter bin to PATH, restart terminal |
| `Unable to find suitable target device` | Run `flutter config --enable-windows-desktop` |
| `pub get failed` | Check internet connection, run `flutter clean` then `flutter pub get` |
| `sqflite_common_ffi error` | Ensure Flutter SDK is ≥ 3.1.0 (`flutter --version`) |
| `Google Fonts timeout` | Fonts download on first run — needs internet once |
| Black screen on launch | Run `flutter clean && flutter pub get && flutter run` |

---

## What Works on Desktop vs Mobile

| Feature | Desktop (VS Code) | Android Phone |
|---|---|---|
| Symptom picker | ✅ Full | ✅ Full |
| Vitals input | ✅ Full | ✅ Full |
| AI assessment | ✅ Full (rule-based) | ✅ Full |
| PDF generation | ✅ Saves to Documents | ✅ Share sheet |
| Patient records | ✅ SQLite | ✅ SQLite |
| Voice input | ❌ Not available | ✅ Works |
| Camera | ❌ File picker instead | ✅ Camera |
| Image upload | ✅ File picker | ✅ Gallery |

---

## Build Android APK (after reviewing on desktop)

```bash
flutter build apk --release --split-per-abi
```

Output: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
