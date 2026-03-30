import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Modal dialog shown after an FTP test workout completes.
class FtpResultDialog extends StatefulWidget {
  final int calculatedFtp;
  final String calculationBasis;
  final void Function(int watts) onSave;
  final VoidCallback onSkip;

  const FtpResultDialog({
    super.key,
    required this.calculatedFtp,
    required this.calculationBasis,
    required this.onSave,
    required this.onSkip,
  });

  @override
  State<FtpResultDialog> createState() => _FtpResultDialogState();
}

class _FtpResultDialogState extends State<FtpResultDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.calculatedFtp.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: RowCraftTheme.surfaceContainer,
      title: Text(
        'FTP Test Result',
        style: theme.textTheme.headlineSmall,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Big FTP number
          Text(
            '${widget.calculatedFtp}W',
            style: theme.textTheme.displayMedium?.copyWith(
              color: RowCraftTheme.successGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Estimated FTP',
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Text(
            widget.calculationBasis,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Editable override
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Override FTP (watts)',
              suffixText: 'W',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onSkip,
          child: const Text(
            'Skip',
            style: TextStyle(color: RowCraftTheme.subtleGrey),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            final watts =
                int.tryParse(_controller.text) ?? widget.calculatedFtp;
            if (watts > 0) {
              widget.onSave(watts);
            }
          },
          child: const Text('Save FTP'),
        ),
      ],
    );
  }
}
