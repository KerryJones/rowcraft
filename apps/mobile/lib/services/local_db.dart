import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'local_db.g.dart';

/// Pending workout results waiting to be synced to Supabase/C2.
class PendingResults extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The full workout result serialized as JSON.
  TextColumn get resultJson => text()();

  /// When this result was queued.
  DateTimeColumn get queuedAt => dateTime().withDefault(currentDateAndTime)();

  /// Number of failed sync attempts.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Whether this result has been synced to Supabase.
  BoolColumn get syncedToSupabase =>
      boolean().withDefault(const Constant(false))();

  /// Whether this result has been synced to C2 Logbook.
  BoolColumn get syncedToC2 =>
      boolean().withDefault(const Constant(false))();
}

/// Locally cached workouts for offline access.
class CachedWorkouts extends Table {
  TextColumn get workoutId => text()();
  TextColumn get workoutJson => text()();
  DateTimeColumn get cachedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {workoutId};
}

@DriftDatabase(tables: [PendingResults, CachedWorkouts])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // ── Pending Results ─────────────────────────────────────────────────

  /// Queue a workout result for syncing.
  Future<int> queueResult(String resultJson) {
    return into(pendingResults).insert(
      PendingResultsCompanion.insert(resultJson: resultJson),
    );
  }

  /// Get all pending results that haven't been fully synced.
  Future<List<PendingResult>> getPendingResults() {
    return (select(pendingResults)
          ..where((r) =>
              r.syncedToSupabase.equals(false) |
              r.syncedToC2.equals(false))
          ..orderBy([(r) => OrderingTerm.asc(r.queuedAt)]))
        .get();
  }

  /// Get count of pending results.
  Future<int> getPendingCount() async {
    final count = countAll();
    final query = selectOnly(pendingResults)
      ..where(pendingResults.syncedToSupabase.equals(false))
      ..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Mark a pending result as synced to Supabase.
  Future<void> markSyncedToSupabase(int id) {
    return (update(pendingResults)..where((r) => r.id.equals(id)))
        .write(const PendingResultsCompanion(
      syncedToSupabase: Value(true),
    ));
  }

  /// Mark a pending result as synced to C2 Logbook.
  Future<void> markSyncedToC2(int id) {
    return (update(pendingResults)..where((r) => r.id.equals(id)))
        .write(const PendingResultsCompanion(
      syncedToC2: Value(true),
    ));
  }

  /// Increment the attempt counter for a failed sync.
  Future<void> incrementAttempts(int id) async {
    final row = await (select(pendingResults)
          ..where((r) => r.id.equals(id)))
        .getSingle();
    await (update(pendingResults)..where((r) => r.id.equals(id)))
        .write(PendingResultsCompanion(
      attempts: Value(row.attempts + 1),
    ));
  }

  /// Remove fully synced results (both Supabase and C2).
  Future<int> cleanupSynced() {
    return (delete(pendingResults)
          ..where((r) =>
              r.syncedToSupabase.equals(true) &
              r.syncedToC2.equals(true)))
        .go();
  }

  // ── Cached Workouts ─────────────────────────────────────────────────

  /// Cache a workout for offline access.
  Future<void> cacheWorkout(String workoutId, String workoutJson) {
    return into(cachedWorkouts).insertOnConflictUpdate(
      CachedWorkoutsCompanion.insert(
        workoutId: workoutId,
        workoutJson: workoutJson,
      ),
    );
  }

  /// Get a cached workout by ID.
  Future<CachedWorkout?> getCachedWorkout(String workoutId) {
    return (select(cachedWorkouts)
          ..where((w) => w.workoutId.equals(workoutId)))
        .getSingleOrNull();
  }

  /// Clear all cached workouts older than the given duration.
  Future<int> clearOldCache(Duration maxAge) {
    final cutoff = DateTime.now().subtract(maxAge);
    return (delete(cachedWorkouts)
          ..where((w) => w.cachedAt.isSmallerThanValue(cutoff)))
        .go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'rowcraft.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

/// Global database provider.
final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  final db = LocalDatabase();
  ref.onDispose(() => db.close());
  return db;
});
