// screens/records_screen.dart
// Searchable, filterable list of all saved patient records.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/patient_record.dart';
import '../services/database_service.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});
  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  final _searchCtrl = TextEditingController();
  String _riskFilter = 'All';
  List<PatientRecord> _records = [];
  bool _loading = true;

  static const _filters = ['All', 'Emergency', 'Urgent', 'Normal'];

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() => _load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final records = await DatabaseService.instance.fetchAll(
      searchQuery: _searchCtrl.text.trim(),
      riskFilter: _riskFilter == 'All' ? null : _riskFilter,
    );
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  Future<void> _deleteRecord(PatientRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record?'),
        content: Text('Delete record for ${record.patientName}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true && record.id != null) {
      await DatabaseService.instance.delete(record.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patient Records')),
      body: Column(
        children: [
          // ── Search bar ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name or village…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          _load();
                        },
                      )
                    : null,
              ),
            ),
          ),

          // ── Risk filter chips ──────────────────────────────────────
          SizedBox(
            height: 52,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              children: _filters.map((f) {
                final selected = _riskFilter == f;
                final color = f == 'All'
                    ? AppTheme.accent
                    : AppTheme.riskColor(f);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _riskFilter = f);
                      _load();
                    },
                    selectedColor: color.withOpacity(0.2),
                    checkmarkColor: color,
                    labelStyle: TextStyle(
                      color: selected ? color : AppTheme.textSecondary,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(
                        color: selected ? color : Colors.grey.shade300),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Record count ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              Text(
                '${_records.length} record(s) found',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ]),
          ),

          // ── List ───────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                    ? _EmptyState()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                          itemCount: _records.length,
                          itemBuilder: (ctx, i) => _RecordTile(
                            record: _records[i],
                            onDelete: () => _deleteRecord(_records[i]),
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/summary',
                              arguments: _records[i],
                            ).then((_) => _load()),
                          ).animate().fadeIn(
                              delay: Duration(milliseconds: i * 40),
                              duration: 300.ms),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _RecordTile extends StatelessWidget {
  final PatientRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RecordTile({
    required this.record,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final r = record.assessment;
    final riskColor = AppTheme.riskColor(r.riskLevel);
    final dateStr = DateFormat('dd MMM yyyy  hh:mm a').format(record.createdAt);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Risk dot
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(AppTheme.riskIcon(r.riskLevel),
                    color: riskColor, size: 22),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.patientName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      '${record.age}y · ${record.gender}'
                      '${record.village.isNotEmpty ? " · ${record.village}" : ""}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      _RiskBadge(level: r.riskLevel),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          r.primaryDisease,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    Text(dateStr,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),

              // Delete
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent, size: 20),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),

              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  final String level;
  const _RiskBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.riskColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        level.toUpperCase(),
        style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 0.5),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded,
              size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No records found',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text('Complete an assessment to save a record.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}
