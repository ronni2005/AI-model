# RuralHealth AI

A mobile and desktop app for healthcare workers in rural areas. Built with Flutter + Python/XGBoost. Works offline. Basically, you feed it patient symptoms and vitals, it gives you an AI assessment, and you can save everything to a PDF.

---

## Tech Stack

- **Dart/Flutter** - The whole app is built with Flutter, which is why it works on Windows, Mac, Linux, and Android
- **Python + XGBoost** - The ML model that does the actual diagnosis. Trained separately and packaged as TensorFlow Lite (.tflite)
- **SQLite** - Stores patient records locally on the device
- **tflite_flutter** - Used to run the ML model on mobile
- **PDF generation** - Built-in,to generate reports
- **Google Fonts** - For the typography

Basically: Dart for the UI, Python for the brains, SQLite for the data.

---

## Folder Layout

```
AI-model/
├── flutter_app/              # The actual app
│   ├── lib/                 # Dart code 
│   ├── assets/models/       # .tflite model files
│   ├── pubspec.yaml         # Dependencies
│   ├── windows/             # Windows stuff
│   ├── macos/               # Mac stuff
│   └── linux/               # Linux stuff
│
├── model_training/          # for model training
│   ├── train_and_export.py
│   └── requirements.txt
│
└── README.md             
```

---

## What It Does

**Core functionality:**
- Collect patient info (demographics, medical history)
- Pick symptoms from a list
- Enter vital signs (blood pressure, temperature, heart rate, etc)
- Run it through the AI to get a diagnosis
- Save the patient record to the local database
- Generate and export a PDF report

**Works offline:** Everything happens on the device. No internet required. Perfect for remote clinics.

**Multiple platforms:** Desktop (Windows/Mac/Linux) and Android mobile.

**Platform differences:** Mobile with featues like camera and voice input.

---

## Desktop vs Mobile - What Works Where

| Feature | Desktop | Mobile (Android) |
|---------|---------|------------------|
| Add patient info | ✅ | ✅ |
| Pick symptoms | ✅ | ✅ |
| Enter vitals | ✅ | ✅ |
| Get diagnosis | ✅ | ✅ |
| Save patient record | ✅ | ✅ |
| Export to PDF | ✅ | ✅ |
| Camera | ❌ (use file picker) | ✅ |
| Voice input | ❌ | ✅ |
| Gallery access | ❌ (file picker) | ✅ |

**TL;DR:** Everything core works on both. Mobile has extras like voice and camera. Desktop is more stripped down.

---

## Getting It Running

### Basic Requirements

- Flutter SDK (3.1.0 or newer)
- Dart (comes with Flutter)
- VS Code with Flutter & Dart extensions
- Python 3.7+

### Install Flutter

**Windows:**
1. Download: https://docs.flutter.dev/get-started/install/windows/desktop
2. Extract to `C:\flutter`
3. Add `C:\flutter\bin` to your PATH:
   - Search "Environment Variables" in Start Menu
   - Click "Edit the system environment variables"
   - Edit PATH, add `C:\flutter\bin`
   - Restart terminal
4. Run: `flutter doctor`



If `flutter doctor` complains about anything, usually just install what it asks for (typically VS Code extension).

### Turn on Desktop Support

```bash
flutter config --enable-windows-desktop    # Windows
```

### Get the VS Code Extensions

Open VS Code, go to Extensions (Ctrl+Shift+X), search for and install:
- **Flutter** (by Dart Code)
- **Dart** (by Dart Code)

### Run the App

```bash
cd flutter_app
flutter pub get
```

Then run it:

```bash
flutter run -d windows    # Windows
```

Or just press F5 in VS Code and pick your device from the dropdown at the bottom.

App should open in a window.

### Build for Android

```bash
flutter build apk --release --split-per-abi
```

APK will be: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`

---

## Training Your Own ML Model (Optional)

The app comes with a basic rule-based engine. If you want to train your own XGBoost model:

```bash
cd model_training
pip install -r requirements.txt
python train_and_export.py
```

This creates `.tflite` files and puts them in `flutter_app/assets/models/`.

Then you need to:
1. Open `inference_service.dart`
2. Turn on the tflite_flutter code
3. Point it to load the new models

Models are loaded from the assets folder.

---

## Code Organization

**Flutter side (`flutter_app/lib/`):**
- `main.dart` - Starts the app
- `screens/` - All the UI screens
- `services/inference_service.dart` - Runs the ML model
- `services/database_service.dart` - Handles the patient database
- `models/` - Data structures (Patient, Assessment, etc)
- `pubspec.yaml` - Dependencies (SQLite, PDF stuff, fonts, etc)

**Python side (`model_training/`):**
- `train_and_export.py` - Takes patient data, trains XGBoost, exports to TensorFlow Lite
- `requirements.txt` - Python packages you need

---

## Troubleshooting

| Error | Solution |
|-------|----------|
| `flutter: command not found` | Add Flutter bin to system PATH, restart terminal |
| `Unable to find suitable target device` | Run `flutter config --enable-[windows/macos/linux]-desktop` |
| `pub get failed` | Check internet, run `flutter clean && flutter pub get` |
| `sqflite_common_ffi error` | Update Flutter SDK to ≥ 3.1.0 |
| `Google Fonts timeout` | Fonts download on first run, requires internet once |
| Black screen on launch | Run `flutter clean && flutter pub get && flutter run` |


---

## What This is Good For

- **Rural clinics** - Works offline, no internet needed
- **Training health workers** - Shows how symptoms map to diseases
- **Telemedicine** - Quick patient assessment before talking to a real doctor
- **Healthcare data collection** - Gather diagnostic info from hard-to-reach areas
- **Patient self-check** - People can assess themselves before visiting a clinic

---

## Security & Privacy

Everything stays on the device. No internet, no cloud, no servers. Patient data lives in a local SQLite database. This is important for privacy in healthcare settings.


---

## What The App Looks Like

- Patient intake screen - fill in basic info
- Symptom picker - check off what the patient reports
- Vitals input - enter BP, temp, heart rate, etc
- Analysis results - see what the AI thinks
- Patient history - view past assessments
- PDF export - save or print the report


---

## Ideas for the Future

- Connect to actual EHR systems
- Multiple languages (for different regions)
- Voice-based input (for people who can't read)
- Admin dashboard with stats and analytics
- Work with telemedicine platforms
- Optional cloud backup
- IoT integration (like automated blood pressure monitors)
- Custom PDF templates with your clinic's branding
