import 'package:flutter/material.dart';

/// A small "amount + unit" dialog (e.g. 2 hours) that returns the value in the
/// base unit (minutes). It owns its TextEditingController and disposes it with
/// the dialog, avoiding "controller used after disposed" during the dismiss
/// animation. [units] is a list of (multiplier, label) pairs.
Future<int?> showAmountUnitDialog(
  BuildContext context, {
  required String title,
  required List<(int, String)> units,
  int? defaultUnit,
  String addLabel = 'Add',
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _AmountUnitDialog(
      title: title,
      units: units,
      defaultUnit: defaultUnit ?? units.first.$1,
      addLabel: addLabel,
    ),
  );
}

class _AmountUnitDialog extends StatefulWidget {
  const _AmountUnitDialog({
    required this.title,
    required this.units,
    required this.defaultUnit,
    required this.addLabel,
  });

  final String title;
  final List<(int, String)> units;
  final int defaultUnit;
  final String addLabel;

  @override
  State<_AmountUnitDialog> createState() => _AmountUnitDialogState();
}

class _AmountUnitDialogState extends State<_AmountUnitDialog> {
  final _value = TextEditingController();
  late int _unit = widget.defaultUnit;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _value,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<int>(
            value: _unit,
            items: [
              for (final (mult, label) in widget.units)
                DropdownMenuItem(value: mult, child: Text(label)),
            ],
            onChanged: (v) => setState(() => _unit = v ?? widget.defaultUnit),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final n = int.tryParse(_value.text.trim());
            if (n != null && n > 0) Navigator.pop(context, n * _unit);
          },
          child: Text(widget.addLabel),
        ),
      ],
    );
  }
}
