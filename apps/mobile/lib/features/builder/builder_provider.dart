import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/workout.dart';
import '../../models/workout_segment.dart';
import '../../services/supabase_service.dart';

/// State for the workout builder.
class BuilderState {
  final String? id;
  final String title;
  final String description;
  final WorkoutType workoutType;
  final List<WorkoutSegment> segments;
  final List<String> tags;
  final bool isPublic;
  final bool isSaving;
  final String? error;

  const BuilderState({
    this.id,
    this.title = '',
    this.description = '',
    this.workoutType = WorkoutType.singleDistance,
    this.segments = const [],
    this.tags = const [],
    this.isPublic = false,
    this.isSaving = false,
    this.error,
  });

  BuilderState copyWith({
    String? id,
    String? title,
    String? description,
    WorkoutType? workoutType,
    List<WorkoutSegment>? segments,
    List<String>? tags,
    bool? isPublic,
    bool? isSaving,
    String? error,
  }) {
    return BuilderState(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      workoutType: workoutType ?? this.workoutType,
      segments: segments ?? this.segments,
      tags: tags ?? this.tags,
      isPublic: isPublic ?? this.isPublic,
      isSaving: isSaving ?? this.isSaving,
      error: error,
    );
  }
}

class BuilderNotifier extends StateNotifier<BuilderState> {
  final SupabaseService _supabaseService;

  BuilderNotifier(this._supabaseService) : super(const BuilderState());

  void setTitle(String title) {
    state = state.copyWith(title: title);
  }

  void setDescription(String description) {
    state = state.copyWith(description: description);
  }

  void setType(WorkoutType type) {
    state = state.copyWith(workoutType: type);
  }

  void setPublic(bool isPublic) {
    state = state.copyWith(isPublic: isPublic);
  }

  void addTag(String tag) {
    if (!state.tags.contains(tag)) {
      state = state.copyWith(tags: [...state.tags, tag]);
    }
  }

  void removeTag(String tag) {
    state = state.copyWith(tags: state.tags.where((t) => t != tag).toList());
  }

  void addSegment(WorkoutSegment segment) {
    state = state.copyWith(segments: [...state.segments, segment]);
  }

  void removeSegment(int index) {
    final segments = [...state.segments];
    segments.removeAt(index);
    state = state.copyWith(segments: segments);
  }

  void updateSegment(int index, WorkoutSegment segment) {
    final segments = [...state.segments];
    segments[index] = segment;
    state = state.copyWith(segments: segments);
  }

  void reorderSegment(int oldIndex, int newIndex) {
    final segments = [...state.segments];
    if (newIndex > oldIndex) newIndex--;
    final item = segments.removeAt(oldIndex);
    segments.insert(newIndex, item);
    state = state.copyWith(segments: segments);
  }

  /// Load an existing workout for editing.
  Future<void> loadWorkout(String id) async {
    try {
      final workout = await _supabaseService.getWorkout(id);
      state = BuilderState(
        id: workout.id,
        title: workout.title,
        description: workout.description,
        workoutType: workout.workoutType,
        segments: workout.segments,
        tags: workout.tags,
        isPublic: workout.isPublic,
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to load workout: $e');
    }
  }

  /// Save the workout to Supabase. Returns the saved workout, or null on error.
  Future<Workout?> save() async {
    if (state.title.trim().isEmpty) {
      state = state.copyWith(error: 'Title is required');
      return null;
    }

    if (state.segments.isEmpty) {
      state = state.copyWith(error: 'Add at least one segment');
      return null;
    }

    state = state.copyWith(isSaving: true, error: null);

    try {
      final userId = _supabaseService.currentUserId;
      if (userId == null) throw StateError('Not authenticated');

      final now = DateTime.now();
      final workout = Workout(
        id: state.id ?? '',
        authorId: userId,
        title: state.title.trim(),
        description: state.description.trim(),
        workoutType: state.workoutType,
        segments: state.segments,
        tags: state.tags,
        isPublic: state.isPublic,
        createdAt: now,
        updatedAt: now,
      );

      final saved = await _supabaseService.saveWorkout(workout);
      state = state.copyWith(isSaving: false, id: saved.id);
      return saved;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to save: $e',
      );
      return null;
    }
  }

  /// Reset the builder to a blank state.
  void reset() {
    state = const BuilderState();
  }
}

final builderProvider =
    StateNotifierProvider<BuilderNotifier, BuilderState>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return BuilderNotifier(supabaseService);
});
