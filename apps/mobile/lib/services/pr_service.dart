import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/personal_record.dart';
import '../models/workout_result.dart';
import 'supabase_service.dart';

final prServiceProvider = Provider<PrService>((ref) {
  return PrService(ref.watch(supabaseServiceProvider));
});

/// Distance ranges for pace-based PRs: (minMeters, maxMeters).
/// fastest_500m has no upper bound — any workout >= 500m qualifies.
const _distanceRanges = <PrType, (int, int?)>{
  PrType.fastest500m: (500, null),
  PrType.fastest2k: (2000, 2500),
  PrType.fastest5k: (5000, 5500),
  PrType.fastest6k: (6000, 6500),
  PrType.fastest10k: (10000, 10500),
  PrType.fastestHalfMarathon: (21097, 21597),
  PrType.fastestMarathon: (42195, 42695),
};

class PrService {
  final SupabaseService _supabaseService;

  /// In-memory cache of current PRs, keyed by PrType.
  final Map<PrType, PersonalRecord> _cache = {};
  bool _loaded = false;

  PrService(this._supabaseService);

  bool get isLoaded => _loaded;
  Map<PrType, PersonalRecord> get cachedPRs => Map.unmodifiable(_cache);

  /// Load PRs from Supabase into cache.
  Future<void> load() async {
    try {
      final records = await _supabaseService.getPersonalRecords();
      _cache.clear();
      for (final r in records) {
        _cache[r.prType] = r;
      }
      _loaded = true;
    } catch (e) {
      dev.log('PrService.load failed: $e', name: 'rowcraft');
    }
  }

  PersonalRecord _buildCandidate({
    required PrType prType,
    required int value,
    required String userId,
    required String? resultId,
    required DateTime achievedAt,
    PersonalRecord? existing,
  }) {
    return PersonalRecord(
      id: existing?.id ?? '',
      userId: userId,
      prType: prType,
      value: value,
      resultId: resultId,
      achievedAt: achievedAt,
      previousValue: existing?.value,
      createdAt: existing?.createdAt ?? achievedAt,
      updatedAt: achievedAt,
    );
  }

  /// Check a workout result against all pace-based PRs and longest distance.
  /// Returns list of newly set/broken PRs.
  Future<List<PersonalRecord>> checkAndUpdatePRs(
    WorkoutResult result,
    String resultId,
  ) async {
    final userId = result.userId;
    final distance = result.totalDistance.toInt();
    final pace = result.avgSplit;
    final now = DateTime.now();

    // Collect candidates
    final candidates = <PersonalRecord>[];

    if (pace > 0) {
      for (final entry in _distanceRanges.entries) {
        final prType = entry.key;
        final (minDist, maxDist) = entry.value;

        if (distance < minDist) continue;
        if (maxDist != null && distance >= maxDist) continue;

        final existing = _cache[prType];
        if (existing != null && pace >= existing.value) continue;

        candidates.add(_buildCandidate(
          prType: prType,
          value: pace,
          userId: userId,
          resultId: resultId,
          achievedAt: now,
          existing: existing,
        ));
      }
    }

    // Longest distance
    final existingDist = _cache[PrType.longestDistance];
    if (existingDist == null || distance > existingDist.value) {
      candidates.add(_buildCandidate(
        prType: PrType.longestDistance,
        value: distance,
        userId: userId,
        resultId: resultId,
        achievedAt: now,
        existing: existingDist,
      ));
    }

    if (candidates.isEmpty) return [];

    // Upsert all candidates in parallel
    final results = await Future.wait(
      candidates.map((r) async {
        try {
          return await _supabaseService.upsertPersonalRecord(r);
        } catch (e) {
          dev.log('PrService.checkAndUpdatePRs(${r.prType}) failed: $e',
              name: 'rowcraft');
          return null;
        }
      }),
    );

    final newPRs = <PersonalRecord>[];
    for (final saved in results) {
      if (saved != null) {
        _cache[saved.prType] = saved;
        newPRs.add(saved);
      }
    }
    return newPRs;
  }

  /// Check FTP against highest_ftp PR. Returns the new PR if broken.
  Future<PersonalRecord?> checkFtpPR(
    int ftpWatts,
    String userId,
    String? resultId,
  ) async {
    final existing = _cache[PrType.highestFtp];
    if (existing != null && ftpWatts <= existing.value) return null;

    final record = _buildCandidate(
      prType: PrType.highestFtp,
      value: ftpWatts,
      userId: userId,
      resultId: resultId,
      achievedAt: DateTime.now(),
      existing: existing,
    );

    try {
      final saved = await _supabaseService.upsertPersonalRecord(record);
      _cache[PrType.highestFtp] = saved;
      return saved;
    } catch (e) {
      dev.log('PrService.checkFtpPR failed: $e', name: 'rowcraft');
      return null;
    }
  }

  /// Backfill PRs from all existing workout results and FTP history.
  /// Only runs when cache is empty (first load after feature ships).
  Future<void> backfill(
    List<WorkoutResult> results,
    String userId, {
    List<FtpRecord> ftpHistory = const [],
  }) async {
    if (_cache.isNotEmpty) return;

    // Find best values per PR type
    final bestPace = <PrType, (int, WorkoutResult)>{};
    int? longestDist;
    WorkoutResult? longestResult;

    for (final r in results) {
      final distance = r.totalDistance.toInt();
      final pace = r.avgSplit;

      // Pace PRs
      if (pace > 0) {
        for (final entry in _distanceRanges.entries) {
          final prType = entry.key;
          final (minDist, maxDist) = entry.value;

          if (distance < minDist) continue;
          if (maxDist != null && distance >= maxDist) continue;

          final current = bestPace[prType];
          if (current == null || pace < current.$1) {
            bestPace[prType] = (pace, r);
          }
        }
      }

      // Longest distance
      if (longestDist == null || distance > longestDist) {
        longestDist = distance;
        longestResult = r;
      }
    }

    // Build all candidate records
    final candidates = <PersonalRecord>[];
    for (final entry in bestPace.entries) {
      final (pace, r) = entry.value;
      candidates.add(_buildCandidate(
        prType: entry.key,
        value: pace,
        userId: userId,
        resultId: r.id.isNotEmpty ? r.id : null,
        achievedAt: r.startedAt,
      ));
    }

    if (longestDist != null && longestResult != null) {
      candidates.add(_buildCandidate(
        prType: PrType.longestDistance,
        value: longestDist,
        userId: userId,
        resultId: longestResult.id.isNotEmpty ? longestResult.id : null,
        achievedAt: longestResult.startedAt,
      ));
    }

    // Highest FTP from history
    if (ftpHistory.isNotEmpty) {
      final best = ftpHistory.reduce(
        (a, b) => a.ftpWatts >= b.ftpWatts ? a : b,
      );
      candidates.add(_buildCandidate(
        prType: PrType.highestFtp,
        value: best.ftpWatts,
        userId: userId,
        resultId: best.sourceResultId,
        achievedAt: best.testedAt,
      ));
    }

    // Write all PRs in parallel
    final saved = await Future.wait(
      candidates.map((r) async {
        try {
          return await _supabaseService.upsertPersonalRecord(r);
        } catch (e) {
          dev.log('PrService.backfill(${r.prType}) failed: $e',
              name: 'rowcraft');
          return null;
        }
      }),
    );

    for (final s in saved) {
      if (s != null) _cache[s.prType] = s;
    }
  }
}
