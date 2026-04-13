// services/report_service.dart
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/patient_record.dart';

class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  Future<File> generatePdf(PatientRecord record) async {
    final pdf     = pw.Document();
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(record.createdAt);
    final r       = record.assessment;
    final rc      = _riskColor(r.riskLevel);

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin:     const pw.EdgeInsets.all(32),
      header:     (_) => _header(record, dateStr),
      footer:     (_) => _footer(),
      build: (ctx) => [
        pw.SizedBox(height: 12),
        _section('Patient Information'),
        pw.SizedBox(height: 6),
        _table([
          ['Full Name',      record.patientName],
          ['Age',            '${record.age} years'],
          ['Gender',         record.gender],
          ['Village / Area', record.village.isNotEmpty ? record.village : '—'],
          ['Health Worker',  record.workerName.isNotEmpty ? record.workerName : '—'],
          ['Date',           dateStr],
        ]),
        pw.SizedBox(height: 14),
        _riskBanner(r.riskLevel, rc),
        pw.SizedBox(height: 14),
        _section('Vital Signs'),
        pw.SizedBox(height: 6),
        _table([
          ['Temperature',     r.vitals.tempString],
          ['Pulse',           r.vitals.pulseString],
          ['Blood Pressure',  r.vitals.bpString],
          ['SpO₂',           r.vitals.spo2String],
          ['Respiratory Rate',r.vitals.rrString],
          ['Weight',          r.vitals.weightString],
        ]),
        pw.SizedBox(height: 14),
        if (r.selectedSymptoms.isNotEmpty) ...[
          _section('Reported Symptoms'),
          pw.SizedBox(height: 6),
          pw.Wrap(
            spacing: 6, runSpacing: 6,
            children: r.selectedSymptoms.map(_chip).toList(),
          ),
          pw.SizedBox(height: 14),
        ],
        if (r.voiceTranscript != null && r.voiceTranscript!.isNotEmpty) ...[
          _section('Voice Transcript'),
          pw.SizedBox(height: 4),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text('"${r.voiceTranscript}"',
                style: pw.TextStyle(
                    fontSize: 10, fontStyle: pw.FontStyle.italic)),
          ),
          pw.SizedBox(height: 14),
        ],
        _section('AI Assessment — Possible Conditions'),
        pw.SizedBox(height: 8),
        pw.Column(children: r.topDiseases.map(_diseaseRow).toList()),
        pw.SizedBox(height: 14),
        _section('Recommended Next Steps'),
        pw.SizedBox(height: 6),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: r.nextSteps.map((s) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('• ', style: const pw.TextStyle(fontSize: 10)),
                pw.Expanded(child: pw.Text(s, style: const pw.TextStyle(fontSize: 10))),
              ],
            ),
          )).toList(),
        ),
        pw.SizedBox(height: 20),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.amber50,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Text(
            'DISCLAIMER: This AI assessment supports, not replaces, clinical judgment. '
            'Consult a qualified healthcare provider for all treatment decisions.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
      ],
    ));

    final dir  = await getApplicationDocumentsDirectory();
    final name = 'patient_${record.patientName.replaceAll(' ', '_')}'
                 '_${DateFormat('yyyyMMdd_HHmm').format(record.createdAt)}.pdf';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  pw.Widget _header(PatientRecord r, String date) => pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 10),
    decoration: const pw.BoxDecoration(
        border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.green700, width: 2))),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('RuralHealth AI',
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800)),
          pw.Text('Offline Multimodal Health Assistant — CureBay',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ]),
        pw.Text('Patient Assessment Report\n$date',
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
      ],
    ),
  );

  pw.Widget _footer() => pw.Container(
    padding: const pw.EdgeInsets.only(top: 6),
    decoration: const pw.BoxDecoration(
        border:
            pw.Border(top: pw.BorderSide(color: PdfColors.grey300))),
    child: pw.Text(
      'Generated by RuralHealth AI • Offline Mode • Not a substitute for medical advice',
      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
      textAlign: pw.TextAlign.center,
    ),
  );

  pw.Widget _section(String title) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    decoration: const pw.BoxDecoration(
      color: PdfColors.green50,
      border: pw.Border(
          left: pw.BorderSide(color: PdfColors.green700, width: 3)),
    ),
    child: pw.Text(title,
        style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.green800)),
  );

  pw.Widget _table(List<List<String>> rows) => pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey300),
    columnWidths: {
      0: const pw.FlexColumnWidth(1.8),
      1: const pw.FlexColumnWidth(3),
    },
    children: rows.map((r) => pw.TableRow(children: [
      pw.Padding(padding: const pw.EdgeInsets.all(6),
          child: pw.Text(r[0],
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
      pw.Padding(padding: const pw.EdgeInsets.all(6),
          child: pw.Text(r[1], style: const pw.TextStyle(fontSize: 10))),
    ])).toList(),
  );

 pw.Widget _riskBanner(String level, PdfColor color) {
    // We create a very light version of the risk color for the background
    // by manually blending it with white.
    final bgColor = PdfColor.fromInt((color.toInt() & 0x00FFFFFF) | 0x22000000); 

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: color, width: 2),
      ),
      child: pw.Center(
        child: pw.Text('RISK LEVEL:  ${level.toUpperCase()}',
            style: pw.TextStyle(
                fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
      ),
    );
  }
  pw.Widget _chip(String s) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: pw.BoxDecoration(
      color: PdfColors.teal50,
      borderRadius: pw.BorderRadius.circular(12),
      border: pw.Border.all(color: PdfColors.teal200),
    ),
    child: pw.Text(s.replaceAll('_', ' '),
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.teal800)),
  );

  pw.Widget _diseaseRow(DiseasePrediction d) {
    final colors = [PdfColors.red700, PdfColors.orange700, PdfColors.blue700];
    final color  = colors[(d.rank - 1).clamp(0, 2)];
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('#${d.rank}  ${d.diseaseName}',
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold, color: color)),
              pw.Text(d.probabilityPercent,
                  style: pw.TextStyle(fontSize: 11, color: color)),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Stack(children: [
            pw.Container(
                height: 7, width: 200,
                decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(4))),
            pw.Container(
                height: 7,
                width: (200 * d.probability).clamp(0, 200),
                decoration: pw.BoxDecoration(
                    color: color,
                    borderRadius: pw.BorderRadius.circular(4))),
          ]),
        ],
      ),
    );
  }

  PdfColor _riskColor(String r) {
    switch (r) {
      case 'Emergency': return PdfColors.red700;
      case 'Urgent':    return PdfColors.orange700;
      default:          return PdfColors.green700;
    }
  }
}
