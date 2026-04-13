// screens/patient_summary_screen.dart
// Full detail view for a saved PatientRecord.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:share_plus/share_plus.dart';
import '../main.dart';
import '../models/patient_record.dart';
import '../services/report_service.dart';

class PatientSummaryScreen extends StatefulWidget {
  final PatientRecord record;
  const PatientSummaryScreen({super.key, required this.record});

  @override
  State<PatientSummaryScreen> createState() => _PatientSummaryScreenState();
}

class _PatientSummaryScreenState extends State<PatientSummaryScreen> {
  bool _generatingPdf = false;

  Future<void> _sharePdf() async {
    setState(() => _generatingPdf = true);
    try {
      final file = await ReportService.instance.generatePdf(widget.record);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Patient Report — ${widget.record.patientName}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('PDF failed: $e'),
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rec = widget.record;
    final r = rec.assessment;
    final riskColor = AppTheme.riskColor(r.riskLevel);
    final dateStr =
        DateFormat('dd MMM yyyy, hh:mm a').format(rec.createdAt);

    return Scaffold(
      appBar: AppBar(
        title: Text(rec.patientName),
        actions: [
          IconButton(
            icon: _generatingPdf
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.share_rounded),
            tooltip: 'Share PDF',
            onPressed: _generatingPdf ? null : _sharePdf,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Patient Info Card ─────────────────────────────────────
            _InfoCard(
              title: 'Patient Information',
              icon: Icons.person_rounded,
              children: [
                _InfoRow('Name', rec.patientName),
                _InfoRow('Age', '${rec.age} years'),
                _InfoRow('Gender', rec.gender),
                if (rec.village.isNotEmpty) _InfoRow('Village', rec.village),
                if (rec.workerName.isNotEmpty)
                  _InfoRow('Health Worker', rec.workerName),
                _InfoRow('Date', dateStr),
              ],
            ).animate().fadeIn(duration: 350.ms),

            const SizedBox(height: 14),

            // ── Risk badge ────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.riskBgColor(r.riskLevel),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: riskColor, width: 2),
              ),
              child: Row(children: [
                Icon(AppTheme.riskIcon(r.riskLevel), color: riskColor, size: 28),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RISK LEVEL',
                        style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            color: riskColor.withOpacity(0.8),
                            fontWeight: FontWeight.w500)),
                    Text(r.riskLevel.toUpperCase(),
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: riskColor)),
                  ],
                ),
              ]),
            ).animate().scale(
                begin: const Offset(0.9, 0.9),
                delay: 100.ms,
                duration: 400.ms,
                curve: Curves.easeOutBack),

            const SizedBox(height: 14),

            // ── Diseases ──────────────────────────────────────────────
            _InfoCard(
              title: 'AI Disease Assessment',
              icon: Icons.biotech_rounded,
              children: r.topDiseases.map((d) {
                final rankColors = [
                  AppTheme.emergency,
                  AppTheme.urgent,
                  AppTheme.accent,
                ];
                final color = rankColors[(d.rank - 1).clamp(0, 2)];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundColor: color,
                              child: Text('#${d.rank}',
                                  style: const TextStyle(
                                      fontSize: 9,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Text(d.diseaseName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                          ]),
                          Text(d.probabilityPercent,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                  fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearPercentIndicator(
                        percent: d.probability.clamp(0.0, 1.0),
                        lineHeight: 7,
                        backgroundColor: Colors.grey.shade200,
                        progressColor: color,
                        barRadius: const Radius.circular(4),
                        padding: EdgeInsets.zero,
                        animation: true,
                        animationDuration: 900,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 14),

            // ── Vitals ────────────────────────────────────────────────
            _InfoCard(
              title: 'Vital Signs',
              icon: Icons.monitor_heart_rounded,
              children: [
                _InfoRow('Temperature', r.vitals.tempString,
                    warn: r.vitals.temperatureF > 102.5),
                _InfoRow('Pulse', r.vitals.pulseString,
                    warn: r.vitals.pulseBpm > 100 || r.vitals.pulseBpm < 60),
                _InfoRow('Blood Pressure', r.vitals.bpString,
                    warn: r.vitals.systolicBp > 140),
                _InfoRow('SpO₂', r.vitals.spo2String,
                    warn: r.vitals.spo2Percent < 94),
                _InfoRow('Respiratory Rate', r.vitals.rrString,
                    warn: r.vitals.respiratoryRate > 20),
                _InfoRow('Weight', r.vitals.weightString),
              ],
            ).animate().fadeIn(delay: 260.ms),

            const SizedBox(height: 14),

            // ── Symptoms ──────────────────────────────────────────────
            if (r.selectedSymptoms.isNotEmpty)
              _InfoCard(
                title: 'Reported Symptoms',
                icon: Icons.sick_rounded,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: r.selectedSymptoms
                        .map((s) => Chip(
                              label: Text(s.replaceAll('_', ' '),
                                  style: const TextStyle(fontSize: 11)),
                              visualDensity: VisualDensity.compact,
                              backgroundColor:
                                  AppTheme.primary.withOpacity(0.07),
                            ))
                        .toList(),
                  ),
                ],
              ).animate().fadeIn(delay: 310.ms),

            if (r.selectedSymptoms.isNotEmpty) const SizedBox(height: 14),

            // ── Voice transcript ─────────────────────────────────────
            if (r.voiceTranscript != null &&
                r.voiceTranscript!.isNotEmpty) ...[
              _InfoCard(
                title: 'Voice Transcript',
                icon: Icons.mic_rounded,
                children: [
                  Text('"${r.voiceTranscript}"',
                      style: const TextStyle(
                          fontStyle: FontStyle.italic, fontSize: 13)),
                ],
              ).animate().fadeIn(delay: 340.ms),
              const SizedBox(height: 14),
            ],

            // ── Next steps ────────────────────────────────────────────
            _InfoCard(
              title: 'Recommended Next Steps',
              icon: Icons.checklist_rounded,
              children: r.nextSteps.asMap().entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: riskColor.withOpacity(0.15),
                        child: Text('${e.key + 1}',
                            style: TextStyle(
                                fontSize: 9,
                                color: riskColor,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(e.value,
                              style: const TextStyle(
                                  fontSize: 13, height: 1.4))),
                    ],
                  ),
                );
              }).toList(),
            ).animate().fadeIn(delay: 380.ms),

            const SizedBox(height: 20),

            // ── Share PDF button ──────────────────────────────────────
            ElevatedButton.icon(
              icon: _generatingPdf
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('Share PDF Report'),
              onPressed: _generatingPdf ? null : _sharePdf,
            ).animate().fadeIn(delay: 430.ms),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _InfoCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 16, color: AppTheme.primary),
              const SizedBox(width: 7),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
            ]),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool warn;

  const _InfoRow(this.label, this.value, {this.warn = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: warn ? FontWeight.bold : FontWeight.normal,
                color: warn ? AppTheme.urgent : AppTheme.textPrimary,
              ),
            ),
          ),
          if (warn)
            const Icon(Icons.warning_amber_rounded,
                size: 14, color: AppTheme.urgent),
        ],
      ),
    );
  }
}
