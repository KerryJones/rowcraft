import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../widgets/content_constraint.dart';
import '../../services/audio_service.dart';
import '../../utils/pace_utils.dart';
import '../../widgets/discard_workout_dialog.dart';
import '../../widgets/save_discard_buttons.dart';
import 'save_auto_nav_mixin.dart';
import 'workout_provider.dart';
import 'workout_summary_screen.dart' show SaveProgressOverlay;

/// Full-screen FTP test result, shown inline in the workout screen
/// after an FTP test completes. Handles both FTP saving and workout
/// save/discard — the user never sees WorkoutSummaryContent for FTP tests.
class FtpResultScreen extends ConsumerStatefulWidget {
  final int calculatedFtp;
  final String calculationBasis;
  final int? previousFtpWatts;
  final bool isRamp;
  final int? rampStagesCompleted;
  final int? rampTotalStages;
  final int? rampPeakWatts;

  const FtpResultScreen({
    super.key,
    required this.calculatedFtp,
    required this.calculationBasis,
    this.previousFtpWatts,
    this.isRamp = false,
    this.rampStagesCompleted,
    this.rampTotalStages,
    this.rampPeakWatts,
  });

  @override
  ConsumerState<FtpResultScreen> createState() => _FtpResultScreenState();
}

class _FtpResultScreenState extends ConsumerState<FtpResultScreen>
    with TickerProviderStateMixin, SaveAutoNavMixin {
  late final AnimationController _trophyController;
  late final AnimationController _revealController;
  late final Animation<double> _trophyScale;
  late final Animation<double> _revealOpacity;
  late final Animation<double> _revealScale;
  bool _saveFtp = true;

  @override
  void initState() {
    super.initState();

    _trophyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _trophyScale = CurvedAnimation(
      parent: _trophyController,
      curve: Curves.elasticOut,
    );
    _revealOpacity = CurvedAnimation(
      parent: _revealController,
      curve: Curves.easeOut,
    );
    _revealScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _revealController, curve: Curves.easeOut),
    );

    // Start animations
    _trophyController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _revealController.forward();
    });

    // Play achievement sound (once only)
    AudioService.instance.playAchievement();
  }

  @override
  void dispose() {
    _trophyController.dispose();
    _revealController.dispose();
    cancelAutoNavTimer();
    super.dispose();
  }

  void _onSaveWorkout() {
    startSaveOverlay();
    ref
        .read(workoutSessionProvider.notifier)
        .saveResult(ftpWatts: _saveFtp ? widget.calculatedFtp : null);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(workoutSessionProvider);
    ref.listen(workoutSessionProvider, handleSaveProgressChange);

    final ftpPaceTenths = wattsToPaceTenths(widget.calculatedFtp);

    final hasPrevious =
        widget.previousFtpWatts != null &&
        widget.previousFtpWatts! > 0 &&
        widget.previousFtpWatts != kDefaultFtpWatts;

    final int? delta = hasPrevious
        ? widget.calculatedFtp - widget.previousFtpWatts!
        : null;
    final double? deltaPct = hasPrevious && widget.previousFtpWatts! > 0
        ? (delta! / widget.previousFtpWatts! * 100)
        : null;

    // Positive delta = more watts = faster = improved
    final deltaColor = delta != null
        ? (delta > 0
              ? RowCraftTheme.successGreen
              : delta < 0
              ? RowCraftTheme.errorRose
              : RowCraftTheme.warningAmber)
        : null;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ContentConstraint(
            maxWidth: 500,
            child: Column(
              children: [
                const SizedBox(height: 24),

                // Trophy icon with scale animation
                ScaleTransition(
                  scale: _trophyScale,
                  child: const Icon(
                    Icons.emoji_events,
                    size: 72,
                    color: RowCraftTheme.warningAmber,
                  ),
                ),
                const SizedBox(height: 16),

                // Test type header
                Text(
                  widget.isRamp
                      ? 'RAMP FTP TEST COMPLETE'
                      : '20-MIN FTP TEST COMPLETE',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: RowCraftTheme.metricWhite,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),

                // Ramp-specific: stages completed + peak watts
                if (widget.isRamp &&
                    widget.rampStagesCompleted != null &&
                    widget.rampTotalStages != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'You completed ${widget.rampStagesCompleted} of ${widget.rampTotalStages} stages',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: RowCraftTheme.subtleGrey,
                    ),
                  ),
                ],
                if (widget.isRamp && widget.rampPeakWatts != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Peak stage: ${widget.rampPeakWatts}W',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: RowCraftTheme.subtleGrey,
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                _divider(),
                const SizedBox(height: 32),

                // "YOUR NEW FTP" header
                Text(
                  'YOUR NEW FTP',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: RowCraftTheme.subtleGrey,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),

                // FTP pace with fade-in + scale reveal
                FadeTransition(
                  opacity: _revealOpacity,
                  child: ScaleTransition(
                    scale: _revealScale,
                    child: Text(
                      formatPace(ftpPaceTenths),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 56,
                        fontWeight: FontWeight.w700,
                        color: RowCraftTheme.successGreen,
                      ),
                    ),
                  ),
                ),
                Text(
                  '/500m  ·  ${widget.calculatedFtp}W',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: RowCraftTheme.subtleGrey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.calculationBasis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: RowCraftTheme.subtleGrey,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 28),
                _divider(),
                const SizedBox(height: 28),

                // Old vs new comparison
                if (hasPrevious && delta != null && deltaPct != null) ...[
                  Text(
                    'Previous: ${formatPace(wattsToPaceTenths(widget.previousFtpWatts!))} (${widget.previousFtpWatts}W)',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: RowCraftTheme.subtleGrey,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${delta > 0 ? '+' : ''}${delta}W (${delta > 0 ? '+' : ''}${deltaPct.toStringAsFixed(1)}%)',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: deltaColor,
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: RowCraftTheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'First FTP Test!',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: RowCraftTheme.warningAmber,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                _divider(),
                const SizedBox(height: 24),

                // "Save new FTP?" toggle
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: RowCraftTheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Save new FTP?',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: RowCraftTheme.metricWhite,
                        ),
                      ),
                      Switch(
                        value: _saveFtp,
                        onChanged: (v) => setState(() => _saveFtp = v),
                        activeTrackColor: RowCraftTheme.successGreen,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                SaveDiscardButtons(
                  onSave: _onSaveWorkout,
                  onDiscard: () => showDiscardWorkoutDialog(context, ref),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // Save progress overlay
        if (showSaveOverlay)
          Positioned.fill(
            child: SaveProgressOverlay(
              saveProgress: session.saveProgress,
              syncError: session.syncError,
              onRetry: () {
                ref
                    .read(workoutSessionProvider.notifier)
                    .saveResult(
                      ftpWatts: _saveFtp ? widget.calculatedFtp : null,
                    );
              },
            ),
          ),
      ],
    );
  }

  Widget _divider() {
    return Container(height: 1, color: RowCraftTheme.surfaceContainer);
  }
}
