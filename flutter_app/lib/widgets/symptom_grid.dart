// widgets/symptom_grid.dart
// Grouped, searchable symptom selector used on AssessmentScreen page 1.

import 'package:flutter/material.dart';
import '../main.dart';
import '../services/feature_builder.dart';

class SymptomGrid extends StatefulWidget {
  final Set<String> selectedSymptoms;
  final void Function(String key) onToggle;

  const SymptomGrid({
    super.key,
    required this.selectedSymptoms,
    required this.onToggle,
  });

  @override
  State<SymptomGrid> createState() => _SymptomGridState();
}

class _SymptomGridState extends State<SymptomGrid> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Map<String, List<String>> get _filtered {
    if (_query.isEmpty) return kSymptomGroups;

    final result = <String, List<String>>{};
    kSymptomGroups.forEach((group, keys) {
      final matches = keys.where((k) {
        final label = (kSymptomLabels[k] ?? k).toLowerCase();
        return label.contains(_query) || k.contains(_query);
      }).toList();
      if (matches.isNotEmpty) result[group] = matches;
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _filtered;

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search symptoms…',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => _searchCtrl.clear(),
                    )
                  : null,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ),

        // Groups
        Expanded(
          child: groups.isEmpty
              ? const Center(
                  child: Text('No matching symptoms found.',
                      style: TextStyle(color: AppTheme.textSecondary)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  children: groups.entries.map((entry) {
                    return _SymptomGroup(
                      groupName: entry.key,
                      symptomKeys: entry.value,
                      selectedSymptoms: widget.selectedSymptoms,
                      onToggle: widget.onToggle,
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _SymptomGroup extends StatelessWidget {
  final String groupName;
  final List<String> symptomKeys;
  final Set<String> selectedSymptoms;
  final void Function(String) onToggle;

  const _SymptomGroup({
    required this.groupName,
    required this.symptomKeys,
    required this.selectedSymptoms,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            groupName,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: symptomKeys.map((key) {
            final label = kSymptomLabels[key] ?? key.replaceAll('_', ' ');
            final selected = selectedSymptoms.contains(key);

            return GestureDetector(
              onTap: () => onToggle(key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.primary
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? AppTheme.primary
                        : Colors.grey.shade300,
                    width: selected ? 1.5 : 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected) ...[
                      const Icon(Icons.check_rounded,
                          size: 13, color: Colors.white),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: selected ? Colors.white : AppTheme.textPrimary,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        Divider(color: Colors.grey.shade100, height: 16),
      ],
    );
  }
}
