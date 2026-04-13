import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../services/audio_service.dart';
import '../../utils/pace_utils.dart';

/// Full-screen FTP test result, shown inline in the workout screen
/// after an FTP test completes (replaces the summary until save/skip).
class FtpResultScreen extends StatefulWidget {
  final int calculatedFtp;
  final String calculationBasis;
  final int? previousFtpWatts;
  final bool isRamp;
  final int? rampStagesCompleted;
  final int? rampTotalStages;
  final int? rampPeakWatts;
  final void Function(int watts) onSave;
  final VoidCallback onSkip;

  const FtpResultScreen({
    super.key,
    required this.calculatedFtp,
    required this.calculationBasis,
    required this.onSave,
    required this.onSkip,
    this.previousFtpWatts,
    this.isRamp = false,
    this.rampStagesCompleted,
    this.rampTotalStages,
    this.rampPeakWatts,
  });

  @override
  State<FtpResultScreen> createState() => _FtpResultScreenState();
}

class _FtpResultScreenState extends State<FtpResultScreen>
    with TickerProviderStateMixin {
  late final AnimationController _trophyController;
  late final AnimationController _revealController;
  late final TextEditingController _overrideController;
  bool _showOverride = false;
  bool _userEdited = false;

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

    _overrideController = TextEditingController(
      text: formatPaceNoTenths(wattsToPaceTenths(widget.calculatedFtp)),
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
    _overrideController.dispose();
    super.dispose();
  }

  int _resolveWatts() {
    if (_userEdited) {
      final tenths = parsePace(_overrideController.text);
      return tenths != null ? paceTenthsToWatts(tenths) : widget.calculatedFtp;
    }
    return widget.calculatedFtp;
  }

  @override
  Widget build(BuildContext context) {
    final ftpPaceTenths = wattsToPaceTenths(widget.calculatedFtp);

    final hasPrevious = widget.previousFtpWatts != null &&
        widget.previousFtpWatts! > 0 &&
        widget.previousFtpWatts != kDefaultFtpWatts;

    final int? delta =
        hasPrevious ? widget.calculatedFtp - widget.previousFtpWatts! : null;
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

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          const SizedBox(height: 24),

              // Trophy icon with scale animation
              ScaleTransition(
                scale: CurvedAnimation(
                  parent: _trophyController,
                  curve: Curves.elasticOut,
                ),
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
                opacity: CurvedAnimation(
                  parent: _revealController,
                  curve: Curves.easeOut,
                ),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _revealController,
                      curve: Curves.easeOut,
                    ),
                  ),
                  child: Text(
                    formatPaceNoTenths(ftpPaceTenths),
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
                  'Previous: ${formatPaceNoTenths(wattsToPaceTenths(widget.previousFtpWatts!))} (${widget.previousFtpWatts}W)',
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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

              // Override field (expandable)
              GestureDetector(
                onTap: () => setState(() => _showOverride = !_showOverride),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _showOverride
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 18,
                      color: RowCraftTheme.subtleGrey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Override FTP',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: RowCraftTheme.subtleGrey,
                      ),
                    ),
                  ],
                ),
              ),
              if (_showOverride) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _overrideController,
                    keyboardType: TextInputType.text,
                    textAlign: TextAlign.center,
                    onChanged: (_) => setState(() => _userEdited = true),
                    decoration: const InputDecoration(
                      labelText: 'FTP pace (m:ss)',
                      suffixText: '/500m',
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 36),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    final watts = _resolveWatts();
                    if (watts > 0) widget.onSave(watts);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RowCraftTheme.successGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Save FTP',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Skip button
              TextButton(
                onPressed: widget.onSkip,
                child: Text(
                  'Skip',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: RowCraftTheme.subtleGrey,
                  ),
                ),
              ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 1,
      color: RowCraftTheme.surfaceContainer,
    );
  }
}
