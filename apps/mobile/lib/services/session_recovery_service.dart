import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/workout_result.dart';
import '../utils/app_log.dart';

/// Persists an in-progress workout snapshot to disk so a session that dies
/// unexpectedly (process kill, crash, battery pull) can be recovered on the
/// next launch instead of losing the entire row.
///
/// The workout provider writes a partial [WorkoutResult] every few seconds
/// while rowing and clears it once the result is safely queued or the user
/// discards it. On startup, [loadSnapshot] returns the orphaned result (if
/// any) so the UI can offer to save it.
class SessionRecoveryService {
  SessionRecoveryService({Future<Directory> Function()? getDirectory})
      : _getDirectory = getDirectory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _getDirectory;

  static const _fileName = 'in_progress_session.json';

  /// Snapshots older than this are stale — silently discarded.
  static const maxAge = Duration(hours: 12);

  Future<File> _file() async =>
      File(p.join((await _getDirectory()).path, _fileName));

  /// Write the current partial result. Called repeatedly during a workout,
  /// so failures are logged and swallowed — a failed snapshot must never
  /// interrupt the session.
  Future<void> saveSnapshot(WorkoutResult result) async {
    try {
      final file = await _file();
      final payload = jsonEncode({
        'saved_at': DateTime.now().toIso8601String(),
        'result': result.toJson(),
      });
      // Write-then-rename so a crash mid-write can't truncate the live
      // snapshot — rename on the same filesystem is atomic, so a reader
      // always sees either the previous snapshot or the complete new one.
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(payload, flush: true);
      await tmp.rename(file.path);
    } catch (e) {
      AppLog.warn('recovery', 'saveSnapshot failed', e);
    }
  }

  /// Load an orphaned snapshot, or null when there is none, it is stale,
  /// or it cannot be parsed (corrupt snapshots are deleted).
  Future<WorkoutResult?> loadSnapshot() async {
    File? file;
    try {
      file = await _file();
      if (!await file.exists()) return null;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final savedAt = DateTime.parse(json['saved_at'] as String);
      if (DateTime.now().difference(savedAt) > maxAge) {
        await clear();
        return null;
      }
      return WorkoutResult.fromJson(json['result'] as Map<String, dynamic>);
    } catch (e) {
      AppLog.warn('recovery', 'loadSnapshot failed', e);
      try {
        await file?.delete();
      } catch (_) {
        // Best effort — leave the corrupt file for the next attempt.
      }
      return null;
    }
  }

  /// Delete the snapshot (after a successful save or explicit discard).
  Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (e) {
      AppLog.warn('recovery', 'clear failed', e);
    }
  }
}

/// Global session recovery service instance.
final sessionRecoveryServiceProvider = Provider<SessionRecoveryService>((ref) {
  return SessionRecoveryService();
});
