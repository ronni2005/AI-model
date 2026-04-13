// screens/assessment_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart';
import '../models/patient_record.dart';
import '../services/feature_builder.dart';
import '../services/inference_service.dart';
import '../services/locale_service.dart';
import '../services/speech_service.dart';
import '../widgets/vital_input.dart';
import '../widgets/symptom_grid.dart';

class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({super.key});
  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  // Page 0
  final _nameCtrl    = TextEditingController();
  final _ageCtrl     = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _workerCtrl  = TextEditingController();
  String _gender     = 'Male';
  final _formKey     = GlobalKey<FormState>();

  // Page 1
  final Set<String> _selectedSymptoms = {};

  // Page 2
  final _tempCtrl  = TextEditingController(text: '98.6');
  final _pulseCtrl = TextEditingController(text: '72');
  final _sbpCtrl   = TextEditingController(text: '120');
  final _dbpCtrl   = TextEditingController(text: '80');
  final _spo2Ctrl  = TextEditingController(text: '98');
  final _rrCtrl    = TextEditingController(text: '16');
  final _wtCtrl    = TextEditingController(text: '55');

  // Page 3
  String? _voiceTranscript;
  String? _imagePath;
  bool _isListening = false;
  bool _isAnalysing = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final c in [_nameCtrl, _ageCtrl, _villageCtrl, _workerCtrl,
      _tempCtrl, _pulseCtrl, _sbpCtrl, _dbpCtrl, _spo2Ctrl, _rrCtrl, _wtCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _next() {
    if (_page == 0 && !_formKey.currentState!.validate()) return;
    if (_page < 3) {
      setState(() => _page++);
      _pageCtrl.animateToPage(_page,
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      _runAnalysis();
    }
  }

  void _prev() {
    if (_page > 0) {
      setState(() => _page--);
      _pageCtrl.animateToPage(_page,
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      Navigator.pop(context);
    }
  }

  // ── Voice ────────────────────────────────────────────────────────────
  Future<void> _toggleVoice() async {
    final speech = SpeechService.instance;
    if (!speech.isAvailable) {
      _showSnack('Voice input not available on this platform — use a mobile device');
      return;
    }
    if (_isListening) {
      await speech.stopListening();
      setState(() => _isListening = false);
      return;
    }
    setState(() { _isListening = true; _voiceTranscript = ''; });
    await speech.startListening(
      onResult: (w) => setState(() => _voiceTranscript = w),
      onDone: () {
        setState(() => _isListening = false);
        if (_voiceTranscript != null && _voiceTranscript!.isNotEmpty) {
          final ex = FeatureBuilder.extractSymptomsFromText(_voiceTranscript!);
          if (ex.isNotEmpty) {
            setState(() => _selectedSymptoms.addAll(ex));
            _showSnack('${ex.length} symptom(s) detected from voice');
          }
        }
      },
    );
  }

  // ── Image pick (file_picker — works on desktop) ─────────────────────
  Future<void> _pickImage() async {
  final picker = ImagePicker();
  final xFile = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 800,
    imageQuality: 80,
  );
  if (xFile != null) setState(() => _imagePath = xFile.path);
}

  // ── Analysis ─────────────────────────────────────────────────────────
  Future<void> _runAnalysis() async {
    setState(() => _isAnalysing = true);
    PatientVitals vitals;
    try {
      vitals = PatientVitals(
        temperatureF:    double.parse(_tempCtrl.text),
        pulseBpm:        double.parse(_pulseCtrl.text),
        systolicBp:      double.parse(_sbpCtrl.text),
        diastolicBp:     double.parse(_dbpCtrl.text),
        spo2Percent:     double.parse(_spo2Ctrl.text),
        respiratoryRate: double.parse(_rrCtrl.text),
        age:             double.parse(_ageCtrl.text.isEmpty ? '30' : _ageCtrl.text),
        weightKg:        double.parse(_wtCtrl.text),
      );
    } catch (_) {
      _showSnack('Please enter valid numbers for all vital signs');
      setState(() => _isAnalysing = false);
      return;
    }

    try {
      final result = await InferenceService.instance.predict(
        selectedSymptoms: _selectedSymptoms,
        vitals:           vitals,
        voiceTranscript:  _voiceTranscript,
        imagePath:        _imagePath,
      );

      if (!mounted) return;

      final record = PatientRecord(
        patientName: _nameCtrl.text.trim().isEmpty ? 'Patient' : _nameCtrl.text.trim(),
        age:         int.tryParse(_ageCtrl.text) ?? 0,
        gender:      _gender,
        village:     _villageCtrl.text.trim(),
        workerName:  _workerCtrl.text.trim(),
        assessment:  result,
      );

      Navigator.pushNamed(context, '/results', arguments: record)
          .then((_) => Navigator.pop(context, record));
    } catch (e) {
      _showSnack('Analysis error: $e');
    } finally {
      if (mounted) setState(() => _isAnalysing = false);
    }
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _page == 0,
      onPopInvoked: (didPop) { if (!didPop) _prev(); },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_titles[_page]),
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded), onPressed: _prev),
        ),
        body: Column(children: [
          _StepBar(current: _page),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _page0(),
                _page1(),
                _page2(),
                _page3(),
              ],
            ),
          ),
          _BottomBar(page: _page, analysing: _isAnalysing,
              onNext: _next, onPrev: _prev),
        ]),
      ),
    );
  }

  static const _titles = [
    'Patient Information', 'Select Symptoms',
    'Vital Signs',         'Voice & Image',
  ];

  // ── Page 0 ────────────────────────────────────────────────────────────
  Widget _page0() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Form(
      key: _formKey,
      child: Column(children: [
        TextFormField(
          controller: _nameCtrl,
          decoration: InputDecoration(
              labelText: tr('patient_name'),
              prefixIcon: const Icon(Icons.person_rounded)),
          textCapitalization: TextCapitalization.words,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? tr('error_name') : null,
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: TextFormField(
            controller: _ageCtrl,
            decoration: InputDecoration(
                labelText: tr('age'),
                prefixIcon: const Icon(Icons.cake_rounded)),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          )),
          const SizedBox(width: 12),
          Expanded(child: DropdownButtonFormField<String>(
            initialValue: _gender,
            decoration: InputDecoration(labelText: tr('gender')),
            items: ['Male', 'Female', 'Other']
                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                .toList(),
            onChanged: (v) => setState(() => _gender = v!),
          )),
        ]),
        const SizedBox(height: 14),
        TextFormField(
          controller: _villageCtrl,
          decoration: InputDecoration(
              labelText: tr('village'),
              prefixIcon: const Icon(Icons.location_on_rounded)),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _workerCtrl,
          decoration: InputDecoration(
              labelText: tr('worker_name'),
              prefixIcon: const Icon(Icons.badge_rounded)),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFA5D6A7))),
          child: Row(children: [
            const Icon(Icons.info_outline, color: AppTheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'All data is stored locally on this device only.',
              style: TextStyle(fontSize: 12, color: Colors.green.shade800),
            )),
          ]),
        ),
      ]),
    ),
  );

  // ── Page 1 ────────────────────────────────────────────────────────────
  Widget _page1() => Column(children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(children: [
        Expanded(child: Text(
          '${_selectedSymptoms.length} symptom(s) selected',
          style: const TextStyle(
              fontWeight: FontWeight.w600, color: AppTheme.primary),
        )),
        if (_selectedSymptoms.isNotEmpty)
          TextButton(
              onPressed: () => setState(() => _selectedSymptoms.clear()),
              child: const Text('Clear all')),
      ]),
    ),
    Expanded(child: SymptomGrid(
      selectedSymptoms: _selectedSymptoms,
      onToggle: (k) => setState(() {
        _selectedSymptoms.contains(k)
            ? _selectedSymptoms.remove(k)
            : _selectedSymptoms.add(k);
      }),
    )),
  ]);

  // ── Page 2 ────────────────────────────────────────────────────────────
  Widget _page2() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      Row(children: [
        Expanded(child: VitalInput(ctrl: _tempCtrl,  label: 'Temperature (°F)', icon: Icons.thermostat_rounded,    hint: '98.6', min: 90,  max: 110)),
        const SizedBox(width: 12),
        Expanded(child: VitalInput(ctrl: _pulseCtrl, label: 'Pulse (bpm)',       icon: Icons.favorite_rounded,      hint: '72',   min: 30,  max: 200)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: VitalInput(ctrl: _sbpCtrl, label: 'Systolic BP',   icon: Icons.monitor_heart_rounded,   hint: '120', min: 60,  max: 250)),
        const SizedBox(width: 12),
        Expanded(child: VitalInput(ctrl: _dbpCtrl, label: 'Diastolic BP',  icon: Icons.monitor_heart_outlined,  hint: '80',  min: 40,  max: 140)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: VitalInput(ctrl: _spo2Ctrl, label: 'SpO₂ (%)',     icon: Icons.air_rounded,             hint: '98',  min: 50,  max: 100, warningBelow: 94, dangerBelow: 90)),
        const SizedBox(width: 12),
        Expanded(child: VitalInput(ctrl: _rrCtrl,   label: 'Resp. Rate',   icon: Icons.wind_power_rounded,      hint: '16',  min: 5,   max: 60)),
      ]),
      const SizedBox(height: 12),
      VitalInput(ctrl: _wtCtrl, label: 'Weight (kg)', icon: Icons.monitor_weight_rounded, hint: '55', min: 2, max: 200),
      const SizedBox(height: 16),
      _NormalRangesCard(),
    ]),
  );

  // ── Page 3 ────────────────────────────────────────────────────────────
  Widget _page3() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      Text('Voice Description', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 6),
      Text(
        SpeechService.instance.isAvailable
            ? 'Tap the mic and describe symptoms in any language.'
            : 'Voice input is available on Android only. On desktop, type symptoms manually or use the symptom picker.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 12),

      GestureDetector(
        onTap: _toggleVoice,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _isListening
                ? const Color(0xFFFFEBEB)
                : SpeechService.instance.isAvailable
                    ? const Color(0xFFE8F5E9)
                    : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isListening
                  ? AppTheme.emergency
                  : SpeechService.instance.isAvailable
                      ? AppTheme.primary
                      : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Column(children: [
            Icon(
              _isListening ? Icons.stop_circle_rounded : Icons.mic_rounded,
              size: 40,
              color: _isListening
                  ? AppTheme.emergency
                  : SpeechService.instance.isAvailable
                      ? AppTheme.primary
                      : Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              _isListening
                  ? 'Listening…'
                  : SpeechService.instance.isAvailable
                      ? 'Tap to speak'
                      : 'Voice unavailable on desktop',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _isListening ? AppTheme.emergency : AppTheme.primary,
              ),
            ),
          ]),
        ),
      ),

      if (_voiceTranscript != null && _voiceTranscript!.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300)),
          child: Text('"$_voiceTranscript"',
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 14)),
        ),
      ],

      const SizedBox(height: 24),

      Text('Upload Image (Optional)',
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 6),
      Text('Upload a photo of skin conditions, wounds, or medical reports.',
          style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 12),

      if (_imagePath != null) ...[
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(File(_imagePath!), height: 180,
              width: double.infinity, fit: BoxFit.cover),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          icon: const Icon(Icons.close_rounded, size: 16),
          label: const Text('Remove image'),
          onPressed: () => setState(() => _imagePath = null),
        ),
      ] else
        OutlinedButton.icon(
          icon: const Icon(Icons.upload_rounded),
          label: const Text('Choose Image File'),
          onPressed: _pickImage,
        ),

      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFE082))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.tips_and_updates_rounded,
              color: Color(0xFFF9A825), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(
            'Voice and image are optional. Tap "Analyse Patient" to run the AI assessment.',
            style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
          )),
        ]),
      ),
    ]),
  );
}

// ── Step indicator ────────────────────────────────────────────────────────────

class _StepBar extends StatelessWidget {
  final int current;
  const _StepBar({required this.current});

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
      children: List.generate(4, (i) => Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 5,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: i < current
                ? AppTheme.primary
                : i == current
                    ? AppTheme.primaryLight
                    : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      )),
    ),
  );
}

// ── Bottom nav bar ────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final int page;
  final bool analysing;
  final VoidCallback onNext, onPrev;
  const _BottomBar({required this.page, required this.analysing,
      required this.onNext, required this.onPrev});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.06),
            blurRadius: 8, offset: const Offset(0, -2))
      ],
    ),
    child: Row(children: [
      if (page > 0) ...[
        SizedBox(
          width: 52, height: 52,
          child: OutlinedButton(
            onPressed: onPrev,
            style: OutlinedButton.styleFrom(
                minimumSize: Size.zero, padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            child: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        const SizedBox(width: 12),
      ],
      Expanded(child: ElevatedButton.icon(
        onPressed: analysing ? null : onNext,
        icon: analysing
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Icon(page == 3
                ? Icons.analytics_rounded
                : Icons.arrow_forward_rounded),
        label: Text(analysing
            ? 'Analysing…'
            : page == 3 ? tr('analyze') : 'Next'),
      )),
    ]),
  );
}

// ── Normal ranges reference ───────────────────────────────────────────────────

class _NormalRangesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: const Color(0xFFF3F9F4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBDFC4))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Normal Ranges (Adult)',
          style: TextStyle(fontWeight: FontWeight.bold,
              fontSize: 12, color: AppTheme.primary)),
      const SizedBox(height: 6),
      for (final row in [
        ['Temperature:', '97–99 °F'],
        ['Pulse:',       '60–100 bpm'],
        ['BP:',          '90/60 – 120/80 mmHg'],
        ['SpO₂:',        '95–100 %'],
        ['Resp. Rate:',  '12–20 /min'],
      ])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(children: [
            SizedBox(width: 90,
                child: Text(row[0], style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600))),
            Text(row[1], style: const TextStyle(fontSize: 11)),
          ]),
        ),
    ]),
  );
}
