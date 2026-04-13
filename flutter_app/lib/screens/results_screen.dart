// screens/results_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:share_plus/share_plus.dart';
import '../main.dart';
import '../models/patient_record.dart';
import '../services/database_service.dart';
import '../services/report_service.dart';
import '../services/speech_service.dart';

class ResultsScreen extends StatefulWidget {
  final PatientRecord record; // full record including patient name/info
  const ResultsScreen({super.key, required this.record});
  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _saving = false;
  bool _generatingPdf = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 600), () {
      SpeechService.instance.speakResult(
        riskLevel: widget.record.assessment.riskLevel,
        primaryDisease: widget.record.assessment.primaryDisease,
        locale: 'en_IN',
      );
    });
  }

  Future<void> _saveRecord() async {
    if (_saved) { _snack('Already saved'); return; }
    setState(() => _saving = true);
    try {
      await DatabaseService.instance.insert(widget.record);
      setState(() { _saved = true; _saving = false; });
      _snack('Record saved successfully');
    } catch (e) {
      setState(() => _saving = false);
      _snack('Save failed: $e');
    }
  }

  Future<void> _generatePdf() async {
    setState(() => _generatingPdf = true);
    try {
      final file = await ReportService.instance.generatePdf(widget.record);
      await Share.shareXFiles([XFile(file.path)],
          subject: 'Patient Report — ${widget.record.patientName}');
    } catch (e) {
      _snack('PDF failed: $e');
    } finally {
      setState(() => _generatingPdf = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    final rec = widget.record;
    final r = rec.assessment;
    final riskColor = AppTheme.riskColor(r.riskLevel);

    return Scaffold(
      appBar: AppBar(
        title: Text('Results — ${rec.patientName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up_rounded),
            onPressed: () => SpeechService.instance.speakResult(
              riskLevel: r.riskLevel,
              primaryDisease: r.primaryDisease,
              locale: 'en_IN',
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Risk banner
          _RiskBanner(riskLevel: r.riskLevel)
              .animate().scale(begin: const Offset(0.85,0.85), duration: 450.ms,
                  curve: Curves.easeOutBack).fadeIn(),

          const SizedBox(height: 20),

          // Patient summary row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200)),
            child: Row(children: [
              const Icon(Icons.person_rounded, size: 18, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text('${rec.patientName}  •  ${rec.age}y  •  ${rec.gender}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              if (rec.village.isNotEmpty) ...[
                const Text('  •  ', style: TextStyle(color: AppTheme.textSecondary)),
                Text(rec.village, style: const TextStyle(fontSize: 13)),
              ],
            ]),
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 20),

          // Possible conditions
          const _SecHeader(title: 'Possible Conditions', icon: Icons.biotech_rounded),
          const SizedBox(height: 10),
          ...r.topDiseases.asMap().entries.map((e) =>
            _DiseaseTile(p: e.value, delay: Duration(milliseconds: 100 * e.key))),

          const SizedBox(height: 20),

          // Vitals
          const _SecHeader(title: 'Vital Signs', icon: Icons.monitor_heart_rounded),
          const SizedBox(height: 10),
          _VitalsSummary(vitals: r.vitals).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 20),

          // Symptoms
          if (r.selectedSymptoms.isNotEmpty) ...[
            const _SecHeader(title: 'Reported Symptoms', icon: Icons.sick_rounded),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: r.selectedSymptoms.map((s) => Chip(
                label: Text(s.replaceAll('_', ' '),
                    style: const TextStyle(fontSize: 11)),
                backgroundColor: riskColor.withOpacity(0.07),
                side: BorderSide(color: riskColor.withOpacity(0.25)),
                visualDensity: VisualDensity.compact,
              )).toList(),
            ).animate().fadeIn(delay: 350.ms),
            const SizedBox(height: 20),
          ],

          // Voice transcript
          if (r.voiceTranscript != null && r.voiceTranscript!.isNotEmpty) ...[
            const _SecHeader(title: 'Voice Input', icon: Icons.mic_rounded),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300)),
              child: Text('"${r.voiceTranscript}"',
                  style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
            ).animate().fadeIn(delay: 380.ms),
            const SizedBox(height: 20),
          ],

          // Image if provided
          if (r.imagePath != null && r.imagePath!.isNotEmpty) ...[
            const _SecHeader(title: 'Uploaded Image', icon: Icons.image_rounded),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(r.imagePath!),
                  height: 160, width: double.infinity, fit: BoxFit.cover),
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 20),
          ],

          // Next steps
          const _SecHeader(title: 'Recommended Next Steps', icon: Icons.checklist_rounded),
          const SizedBox(height: 10),
          _NextSteps(steps: r.nextSteps, color: riskColor)
              .animate().slideY(begin: 0.2, delay: 420.ms).fadeIn(delay: 420.ms),

          const SizedBox(height: 24),

          // Save
          ElevatedButton.icon(
            icon: _saving
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(_saved ? Icons.check_circle_rounded : Icons.save_rounded),
            label: Text(_saved ? 'Record Saved' : 'Save Patient Record'),
            onPressed: _saving || _saved ? null : _saveRecord,
            style: ElevatedButton.styleFrom(
                backgroundColor: _saved ? AppTheme.normal : AppTheme.primary),
          ).animate().fadeIn(delay: 460.ms),

          const SizedBox(height: 10),

          OutlinedButton.icon(
            icon: _generatingPdf
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('Generate & Share PDF'),
            onPressed: _generatingPdf ? null : _generatePdf,
          ).animate().fadeIn(delay: 500.ms),

          const SizedBox(height: 10),

          TextButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Assessment'),
            onPressed: () {
              Navigator.popUntil(context, ModalRoute.withName('/'));
              Navigator.pushNamed(context, '/assessment');
            },
          ).animate().fadeIn(delay: 540.ms),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade200)),
            child: Text(
              'ℹ️ This AI assessment supports — but does not replace — clinical judgment. '
              'Always consult a qualified healthcare provider.',
              style: TextStyle(fontSize: 11, color: Colors.amber.shade900)),
          ).animate().fadeIn(delay: 580.ms),

          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _RiskBanner extends StatelessWidget {
  final String riskLevel;
  const _RiskBanner({required this.riskLevel});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.riskColor(riskLevel);
    final bg = AppTheme.riskBgColor(riskLevel);
    final messages = {
      'Emergency': 'Refer to hospital IMMEDIATELY',
      'Urgent':    'Medical consultation needed soon',
      'Normal':    'Basic care & monitoring advised',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color, width: 2)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(AppTheme.riskIcon(riskLevel), color: color, size: 32)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('RISK LEVEL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
              color: color.withOpacity(0.8), letterSpacing: 1.2)),
          Text(riskLevel.toUpperCase(),
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
          Text(messages[riskLevel] ?? '',
              style: TextStyle(fontSize: 13, color: color.withOpacity(0.85))),
        ])),
      ]),
    );
  }
}

class _SecHeader extends StatelessWidget {
  final String title; final IconData icon;
  const _SecHeader({required this.title, required this.icon});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 17, color: AppTheme.primary), const SizedBox(width: 7),
    Text(title, style: Theme.of(context).textTheme.titleMedium),
  ]);
}

class _DiseaseTile extends StatelessWidget {
  final DiseasePrediction p; final Duration delay;
  const _DiseaseTile({required this.p, required this.delay});
  @override
  Widget build(BuildContext context) {
    final colors = [AppTheme.emergency, AppTheme.urgent, AppTheme.accent];
    final color = colors[(p.rank - 1).clamp(0, 2)];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 26, height: 26,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Center(child: Text('#${p.rank}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))),
            const SizedBox(width: 10),
            Expanded(child: Text(p.diseaseName,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
            Text(p.probabilityPercent,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ]),
          const SizedBox(height: 8),
          LinearPercentIndicator(
            percent: p.probability.clamp(0.0, 1.0), lineHeight: 8,
            backgroundColor: Colors.grey.shade200, progressColor: color,
            barRadius: const Radius.circular(4), padding: EdgeInsets.zero,
            animation: true, animationDuration: 800),
        ],
      )),
    ).animate().slideX(begin: 0.3, delay: delay, duration: 400.ms).fadeIn(delay: delay);
  }
}

class _VitalsSummary extends StatelessWidget {
  final PatientVitals vitals;
  const _VitalsSummary({required this.vitals});
  @override
  Widget build(BuildContext context) {
    final items = [
      ['🌡️', 'Temp', vitals.tempString, vitals.temperatureF > 102.5],
      ['💓', 'Pulse', vitals.pulseString, vitals.pulseBpm > 100 || vitals.pulseBpm < 60],
      ['🫀', 'BP', vitals.bpString, vitals.systolicBp > 140],
      ['🫁', 'SpO₂', vitals.spo2String, vitals.spo2Percent < 94],
      ['🌬️', 'RR', vitals.rrString, vitals.respiratoryRate > 20],
      ['⚖️', 'Wt', vitals.weightString, false],
    ];
    return Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.count(
        shrinkWrap: true, crossAxisCount: 3, childAspectRatio: 2.1,
        crossAxisSpacing: 6, mainAxisSpacing: 6,
        physics: const NeverScrollableScrollPhysics(),
        children: items.map((i) {
          final warn = i[3] as bool;
          return Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: warn ? const Color(0xFFFFF3E0) : const Color(0xFFF5F9F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: warn ? AppTheme.urgent.withOpacity(0.4) : Colors.grey.shade200)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(i[0] as String, style: const TextStyle(fontSize: 14)),
              Text(i[2] as String, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                  color: warn ? AppTheme.urgent : AppTheme.textPrimary)),
              Text(i[1] as String, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
            ]),
          );
        }).toList(),
      ),
    ));
  }
}

class _NextSteps extends StatelessWidget {
  final List<String> steps; final Color color;
  const _NextSteps({required this.steps, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2))),
      child: Column(children: steps.asMap().entries.map((e) => Column(children: [
        if (e.key > 0) Divider(height: 1, color: color.withOpacity(0.12)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(radius: 10, backgroundColor: color.withOpacity(0.15),
              child: Text('${e.key+1}', style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold))),
            const SizedBox(width: 10),
            Expanded(child: Text(e.value, style: const TextStyle(fontSize: 13, height: 1.4))),
          ]),
        ),
      ])).toList()),
    );
  }
}
