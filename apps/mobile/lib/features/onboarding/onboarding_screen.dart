import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/router.dart' show markOnboardingCompleted;
import '../../app/theme.dart';
import '../../services/c2_logbook_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/hr_zones.dart';
import '../../widgets/content_constraint.dart';
import '../profile/profile_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Page 2: About You
  final _weightController = TextEditingController();
  bool _weightInLbs = true;

  // Page 3: Heart Rate Setup
  final _maxHrController = TextEditingController();
  final _restingHrController = TextEditingController();

  // Page 4: Zone System
  ZoneSystem _selectedZoneSystem = ZoneSystem.rowing;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Rebuild when HR inputs change so page 4 zone preview stays current
    _maxHrController.addListener(_onHrChanged);
    _restingHrController.addListener(_onHrChanged);
  }

  void _onHrChanged() => setState(() {});

  @override
  void dispose() {
    _maxHrController.removeListener(_onHrChanged);
    _restingHrController.removeListener(_onHrChanged);
    _pageController.dispose();
    _weightController.dispose();
    _maxHrController.dispose();
    _restingHrController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    setState(() => _saving = true);
    try {
      final service = ref.read(supabaseServiceProvider);

      // Parse weight
      double? weightKg;
      final weightVal = double.tryParse(_weightController.text);
      if (weightVal != null && weightVal > 0) {
        weightKg = _weightInLbs ? weightVal * 0.453592 : weightVal;
      }

      // Parse max HR
      final maxHr = int.tryParse(_maxHrController.text);
      final validMaxHr =
          maxHr != null && maxHr >= 100 && maxHr <= 250 ? maxHr : null;

      // Parse resting HR
      final restingHr = int.tryParse(_restingHrController.text);
      final validRestingHr =
          restingHr != null && restingHr >= 30 && restingHr <= 120
              ? restingHr
              : null;

      await service.saveOnboardingProfile(
        weightKg: weightKg,
        maxHeartRate: validMaxHr,
        restingHeartRate: validRestingHr,
        zoneSystem: _selectedZoneSystem,
      );

      markOnboardingCompleted();
      ref.invalidate(profileProvider);
      if (mounted) context.go('/connect');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Dot indicators
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final isActive = i == _currentPage;
                  return Container(
                    width: isActive ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? RowCraftTheme.primaryBlue
                          : RowCraftTheme.subtleGrey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _WelcomePage(onNext: _nextPage),
                  _AboutYouPage(
                    weightController: _weightController,
                    weightInLbs: _weightInLbs,
                    onWeightUnitChanged: (lbs) =>
                        setState(() => _weightInLbs = lbs),
                  ),
                  _HeartRateSetupPage(
                    maxHrController: _maxHrController,
                    restingHrController: _restingHrController,
                  ),
                  _ZoneSystemPage(
                    selectedSystem: _selectedZoneSystem,
                    onSystemChanged: (s) =>
                        setState(() => _selectedZoneSystem = s),
                    maxHr: int.tryParse(_maxHrController.text),
                    restingHr: int.tryParse(_restingHrController.text),
                  ),
                ],
              ),
            ),
            // Navigation buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: _previousPage,
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox(width: 80),
                  const Spacer(),
                  if (_currentPage < 3)
                    ElevatedButton(
                      onPressed: _nextPage,
                      child: const Text('Next'),
                    )
                  else
                    ElevatedButton(
                      onPressed: _saving ? null : _completeOnboarding,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Get Started'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 1: Welcome + C2 Logbook
// ---------------------------------------------------------------------------

class _WelcomePage extends ConsumerWidget {
  final VoidCallback onNext;

  const _WelcomePage({required this.onNext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c2LinkedAsync = ref.watch(c2LinkedProvider);

    return ContentConstraint(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.rowing,
              size: 80,
              color: RowCraftTheme.primaryBlue,
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to RowCraft',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Structured rowing workouts for your Concept2 erg. '
              'Connect your PM5 via Bluetooth, follow guided workouts, '
              'and track your progress.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: RowCraftTheme.subtleGrey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            // C2 Logbook connection
            c2LinkedAsync.when(
              data: (isLinked) => isLinked
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color:
                            RowCraftTheme.successGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: RowCraftTheme.successGreen
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: RowCraftTheme.successGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Concept2 Logbook Connected',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: RowCraftTheme.successGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: () async {
                        final service = ref.read(c2LogbookServiceProvider);
                        await service.authenticate();
                      },
                      icon: const Icon(Icons.link),
                      label: const Text('Connect Concept2 Logbook'),
                    ),
              loading: () => const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),
            Text(
              'Optional — you can do this later',
              style: theme.textTheme.bodySmall?.copyWith(
                color: RowCraftTheme.subtleGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 2: About You
// ---------------------------------------------------------------------------

class _AboutYouPage extends StatelessWidget {
  final TextEditingController weightController;
  final bool weightInLbs;
  final ValueChanged<bool> onWeightUnitChanged;

  const _AboutYouPage({
    required this.weightController,
    required this.weightInLbs,
    required this.onWeightUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ContentConstraint(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        children: [
          const SizedBox(height: 40),
          Text(
            'About You',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Used for calorie calculations. Optional.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: RowCraftTheme.subtleGrey,
            ),
          ),
          const SizedBox(height: 32),

          // Weight
          Text('Weight', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: weightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'Enter weight',
                    suffixText: weightInLbs ? 'lbs' : 'kg',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('lbs')),
                  ButtonSegment(value: false, label: Text('kg')),
                ],
                selected: {weightInLbs},
                onSelectionChanged: (s) => onWeightUnitChanged(s.first),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 3: Heart Rate Setup
// ---------------------------------------------------------------------------

class _HeartRateSetupPage extends StatelessWidget {
  final TextEditingController maxHrController;
  final TextEditingController restingHrController;

  const _HeartRateSetupPage({
    required this.maxHrController,
    required this.restingHrController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ContentConstraint(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        children: [
          const SizedBox(height: 40),
          Text(
            'Heart Rate Zones',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Used to calculate your personal training zones. '
            'More accurate zones help you train at the right intensity.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: RowCraftTheme.subtleGrey,
            ),
          ),
          const SizedBox(height: 32),

          // Max HR
          Text('Max Heart Rate', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: maxHrController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '190',
              suffixText: 'bpm',
              helperText: 'From a max effort test, or use 220 - age as a starting point',
            ),
          ),
          const SizedBox(height: 32),

          // Resting HR
          Text('Resting Heart Rate', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: restingHrController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '60',
              suffixText: 'bpm',
              helperText:
                  'Measure first thing in the morning, lying still for 2 min',
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: RowCraftTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 16,
                    color: RowCraftTheme.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Adding resting HR enables heart rate reserve (HRR) '
                    'calculation, which gives more accurate zone boundaries '
                    'for trained athletes.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: RowCraftTheme.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 4: Zone System Selection
// ---------------------------------------------------------------------------

class _ZoneSystemPage extends StatelessWidget {
  final ZoneSystem selectedSystem;
  final ValueChanged<ZoneSystem> onSystemChanged;
  final int? maxHr;
  final int? restingHr;

  const _ZoneSystemPage({
    required this.selectedSystem,
    required this.onSystemChanged,
    this.maxHr,
    this.restingHr,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveMaxHr = maxHr ?? 190;
    final effectiveRestingHr =
        restingHr != null && restingHr! >= 30 && restingHr! <= 120
            ? restingHr
            : null;

    return ContentConstraint(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        children: [
          const SizedBox(height: 40),
          Text(
            'Zone Labels',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose how zones are labeled. Same training zones, different terminology.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: RowCraftTheme.subtleGrey,
            ),
          ),
          const SizedBox(height: 24),

          // Standard card
          _ZoneSystemCard(
            title: 'Standard',
            subtitle: 'Z1 / Z2 / Z3 / Z4 / Z5',
            description: 'Familiar from fitness apps and watches',
            isSelected: selectedSystem == ZoneSystem.standard,
            onTap: () => onSystemChanged(ZoneSystem.standard),
          ),
          const SizedBox(height: 12),

          // Rowing card
          _ZoneSystemCard(
            title: 'Rowing',
            subtitle: 'UT2 / UT1 / AT / TR / AN',
            description: 'Used by rowing coaches and training plans',
            isSelected: selectedSystem == ZoneSystem.rowing,
            onTap: () => onSystemChanged(ZoneSystem.rowing),
          ),
          const SizedBox(height: 24),

          // Zone preview
          Text('Your Zones', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          ...List.generate(5, (i) {
            final zone = i + 1;
            final info = zoneDisplayInfo(zone, selectedSystem);
            final range = zoneBpmRange(
              zone,
              effectiveMaxHr,
              restingHr: effectiveRestingHr,
              system: selectedSystem,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: info.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: info.color.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: info.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      info.name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: info.color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      info.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: RowCraftTheme.subtleGrey,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${range.min}-${range.max} bpm',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        color: RowCraftTheme.metricWhite,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ZoneSystemCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _ZoneSystemCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? RowCraftTheme.primaryBlue.withValues(alpha: 0.1)
              : RowCraftTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? RowCraftTheme.primaryBlue
                : RowCraftTheme.surfaceContainerHigh,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      color: RowCraftTheme.subtleGrey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: RowCraftTheme.subtleGrey,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: RowCraftTheme.primaryBlue,
              ),
          ],
        ),
      ),
    );
  }
}
