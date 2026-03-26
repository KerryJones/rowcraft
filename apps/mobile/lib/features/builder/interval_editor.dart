import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../models/workout_segment.dart';

/// Widget for editing a single workout segment.
class IntervalEditor extends StatelessWidget {
  final WorkoutSegment segment;
  final int index;
  final ValueChanged<WorkoutSegment> onChanged;

  const IntervalEditor({
    super.key,
    required this.segment,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final segmentColor = switch (segment.type) {
      SegmentType.work => RowCraftTheme.segmentWork,
      SegmentType.rest => RowCraftTheme.segmentRest,
      SegmentType.warmup => RowCraftTheme.segmentWarmup,
      SegmentType.cooldown => RowCraftTheme.segmentCooldown,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: segmentColor, width: 4),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: index + type dropdown + repeat
            Row(
              children: [
                // Drag handle
                const Icon(Icons.drag_handle, size: 20, color: RowCraftTheme.subtleGrey),
                const SizedBox(width: 8),
                Text(
                  '#${index + 1}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: segmentColor,
                  ),
                ),
                const SizedBox(width: 12),

                // Segment type dropdown
                Expanded(
                  child: DropdownButtonFormField<SegmentType>(
                    value: segment.type,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: SegmentType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(
                          type.name[0].toUpperCase() + type.name.substring(1),
                        ),
                      );
                    }).toList(),
                    onChanged: (type) {
                      if (type != null) {
                        onChanged(segment.copyWith(type: type));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Repeat count
                SizedBox(
                  width: 72,
                  child: TextFormField(
                    initialValue: segment.repeat.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Repeat',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      final repeat = int.tryParse(value);
                      if (repeat != null && repeat > 0) {
                        onChanged(segment.copyWith(repeat: repeat));
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Duration: type selector + value
            Row(
              children: [
                // Duration type
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<DurationType>(
                    value: segment.durationType,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: DurationType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(
                          type.name[0].toUpperCase() + type.name.substring(1),
                        ),
                      );
                    }).toList(),
                    onChanged: (type) {
                      if (type != null) {
                        onChanged(segment.copyWith(durationType: type));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Duration value
                Expanded(
                  child: TextFormField(
                    initialValue: _formatDurationValue(),
                    decoration: InputDecoration(
                      labelText: _durationLabel,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      suffixText: _durationSuffix,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      final parsed = _parseDurationValue(value);
                      if (parsed != null) {
                        onChanged(segment.copyWith(durationValue: parsed));
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Target split range
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: segment.targetSplit?.min.toStringAsFixed(1),
                    decoration: const InputDecoration(
                      labelText: 'Target Split Min',
                      hintText: '1:45.0',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (value) {
                      final parsed = _parseSplitValue(value);
                      if (parsed != null) {
                        final current = segment.targetSplit ??
                            const SplitTarget(min: 0, max: 0);
                        onChanged(segment.copyWith(
                          targetSplit: current.copyWith(min: parsed),
                        ));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: segment.targetSplit?.max.toStringAsFixed(1),
                    decoration: const InputDecoration(
                      labelText: 'Target Split Max',
                      hintText: '1:50.0',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (value) {
                      final parsed = _parseSplitValue(value);
                      if (parsed != null) {
                        final current = segment.targetSplit ??
                            const SplitTarget(min: 0, max: 0);
                        onChanged(segment.copyWith(
                          targetSplit: current.copyWith(max: parsed),
                        ));
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Target stroke rate range
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: segment.targetStrokeRate?.min.toString(),
                    decoration: const InputDecoration(
                      labelText: 'SR Min',
                      hintText: '24',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      suffixText: 'spm',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed != null) {
                        final current = segment.targetStrokeRate ??
                            const StrokeRateTarget(min: 0, max: 0);
                        onChanged(segment.copyWith(
                          targetStrokeRate: current.copyWith(min: parsed),
                        ));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: segment.targetStrokeRate?.max.toString(),
                    decoration: const InputDecoration(
                      labelText: 'SR Max',
                      hintText: '28',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      suffixText: 'spm',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed != null) {
                        final current = segment.targetStrokeRate ??
                            const StrokeRateTarget(min: 0, max: 0);
                        onChanged(segment.copyWith(
                          targetStrokeRate: current.copyWith(max: parsed),
                        ));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // HR Zone
                SizedBox(
                  width: 72,
                  child: TextFormField(
                    initialValue: segment.targetHrZone?.toString(),
                    decoration: const InputDecoration(
                      labelText: 'HR Zone',
                      hintText: '3',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      onChanged(segment.copyWith(targetHrZone: parsed));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDurationValue() {
    switch (segment.durationType) {
      case DurationType.time:
        final totalSeconds = segment.durationValue.toInt();
        final minutes = totalSeconds ~/ 60;
        final seconds = totalSeconds % 60;
        return '$minutes:${seconds.toString().padLeft(2, '0')}';
      case DurationType.distance:
        return segment.durationValue.toInt().toString();
      case DurationType.calories:
        return segment.durationValue.toInt().toString();
    }
  }

  String get _durationLabel {
    return switch (segment.durationType) {
      DurationType.time => 'Duration',
      DurationType.distance => 'Distance',
      DurationType.calories => 'Calories',
    };
  }

  String get _durationSuffix {
    return switch (segment.durationType) {
      DurationType.time => '',
      DurationType.distance => 'm',
      DurationType.calories => 'cal',
    };
  }

  double? _parseDurationValue(String value) {
    switch (segment.durationType) {
      case DurationType.time:
        // Parse M:SS or just seconds
        final parts = value.split(':');
        if (parts.length == 2) {
          final minutes = int.tryParse(parts[0]);
          final seconds = int.tryParse(parts[1]);
          if (minutes != null && seconds != null) {
            return (minutes * 60 + seconds).toDouble();
          }
        }
        return double.tryParse(value);
      case DurationType.distance:
      case DurationType.calories:
        return double.tryParse(value);
    }
  }

  /// Parse a split value like "1:45.0" to tenths of seconds per 500m.
  double? _parseSplitValue(String value) {
    final parts = value.split(':');
    if (parts.length == 2) {
      final minutes = int.tryParse(parts[0]);
      final secondsParts = parts[1].split('.');
      final seconds = int.tryParse(secondsParts[0]);
      final tenths =
          secondsParts.length > 1 ? int.tryParse(secondsParts[1]) ?? 0 : 0;
      if (minutes != null && seconds != null) {
        return (minutes * 600 + seconds * 10 + tenths).toDouble();
      }
    }
    return double.tryParse(value);
  }
}
