// widgets/vital_input.dart
// A labelled numeric TextFormField with inline abnormal-value colour coding.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';

class VitalInput extends StatefulWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final String hint;
  final double min;
  final double max;
  final double? warningBelow;
  final double? dangerBelow;

  const VitalInput({
    super.key,
    required this.ctrl,
    required this.label,
    required this.icon,
    required this.hint,
    required this.min,
    required this.max,
    this.warningBelow,
    this.dangerBelow,
  });

  @override
  State<VitalInput> createState() => _VitalInputState();
}

class _VitalInputState extends State<VitalInput> {
  Color _borderColor = Colors.grey.shade300;
  String? _warningText;

  void _onChanged(String val) {
    final parsed = double.tryParse(val);
    if (parsed == null) {
      setState(() {
        _borderColor = Colors.grey.shade300;
        _warningText = null;
      });
      return;
    }

    if (widget.dangerBelow != null && parsed < widget.dangerBelow!) {
      setState(() {
        _borderColor = AppTheme.emergency;
        _warningText = 'Critical low!';
      });
    } else if (widget.warningBelow != null && parsed < widget.warningBelow!) {
      setState(() {
        _borderColor = AppTheme.urgent;
        _warningText = 'Below normal';
      });
    } else if (parsed < widget.min || parsed > widget.max) {
      setState(() {
        _borderColor = AppTheme.urgent;
        _warningText = 'Outside expected range (${widget.min}–${widget.max})';
      });
    } else {
      setState(() {
        _borderColor = Colors.grey.shade300;
        _warningText = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.ctrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true, signed: false),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          onChanged: _onChanged,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: Icon(widget.icon,
                color: _borderColor == Colors.grey.shade300
                    ? AppTheme.textSecondary
                    : _borderColor,
                size: 18),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Required';
            final n = double.tryParse(v);
            if (n == null) return 'Invalid number';
            return null;
          },
        ),
        if (_warningText != null)
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 4),
            child: Text(
              _warningText!,
              style: TextStyle(
                  fontSize: 10,
                  color: _borderColor,
                  fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }
}
