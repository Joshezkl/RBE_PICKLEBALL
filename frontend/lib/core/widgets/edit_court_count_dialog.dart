import 'package:flutter/material.dart';

Future<int?> showEditCourtCountDialog(
  BuildContext context, {
  required int currentCount,
  int min = 1,
  int max = 12,
}) {
  return showDialog<int>(
    context: context,
    builder: (context) => _EditCourtCountDialog(
      currentCount: currentCount,
      min: min,
      max: max,
    ),
  );
}

class _EditCourtCountDialog extends StatefulWidget {
  const _EditCourtCountDialog({
    required this.currentCount,
    required this.min,
    required this.max,
  });

  final int currentCount;
  final int min;
  final int max;

  @override
  State<_EditCourtCountDialog> createState() => _EditCourtCountDialogState();
}

class _EditCourtCountDialogState extends State<_EditCourtCountDialog> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentCount.clamp(widget.min, widget.max);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit number of courts'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Active court assignments are cleared and matches are re-queued before the change.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _selected,
            decoration: const InputDecoration(
              labelText: 'Courts',
              prefixIcon: Icon(Icons.sports_tennis_rounded),
            ),
            items: [
              for (var i = widget.min; i <= widget.max; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text('$i'),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _selected = value);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selected == widget.currentCount
              ? null
              : () => Navigator.pop(context, _selected),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
