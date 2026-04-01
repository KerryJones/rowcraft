import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../utils/pace_utils.dart';

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
  bool _userEdited = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: formatPaceNoTenths(wattsToPaceTenths(widget.calculatedFtp)),
    );
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
          // Big FTP pace
          Text(
            wattsToPaceStringNoTenths(widget.calculatedFtp),
            style: theme.textTheme.displayMedium?.copyWith(
              color: RowCraftTheme.successGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Estimated FTP',
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 2),
          Text(
            '${widget.calculatedFtp}W',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: RowCraftTheme.subtleGrey,
            ),
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
            keyboardType: TextInputType.text,
            onChanged: (_) => setState(() => _userEdited = true),
            decoration: const InputDecoration(
              labelText: 'Override FTP pace (m:ss)',
              suffixText: '/500m',
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
            int watts;
            if (_userEdited) {
              final tenths = parsePace(_controller.text);
              watts = tenths != null
                  ? paceTenthsToWatts(tenths)
                  : widget.calculatedFtp;
            } else {
              watts = widget.calculatedFtp;
            }
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
