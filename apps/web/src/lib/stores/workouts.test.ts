import { describe, it, expect, beforeEach } from 'vitest';
import { get } from 'svelte/store';
import { workoutStore, filteredWorkouts, allTags } from './workouts';
import type { Workout } from '$lib/types';

function makeWorkout(overrides: Partial<Workout> = {}): Workout {
	return {
		id: '1',
		author_id: null,
		title: 'Test Workout',
		description: 'A test workout',
		workout_type: 'intervals',
		segments: [],
		tags: [],
		is_public: true,
		fork_count: 0,
		forked_from: null,
		created_at: '2024-01-01T00:00:00Z',
		updated_at: '2024-01-01T00:00:00Z',
		...overrides
	};
}

describe('workoutStore', () => {
	beforeEach(() => {
		workoutStore.clearFilters();
		workoutStore.setWorkouts([]);
	});

	it('setWorkouts stores workouts', () => {
		const workouts = [makeWorkout({ id: '1' }), makeWorkout({ id: '2' })];
		workoutStore.setWorkouts(workouts);

		const state = get(workoutStore);
		expect(state.workouts).toHaveLength(2);
		expect(state.workouts[0].id).toBe('1');
		expect(state.workouts[1].id).toBe('2');
		expect(state.loading).toBe(false);
	});

	it('toggleTag adds a tag', () => {
		workoutStore.toggleTag('endurance');
		expect(get(workoutStore).activeTags).toEqual(['endurance']);
	});

	it('toggleTag removes a tag when toggled again', () => {
		workoutStore.toggleTag('endurance');
		workoutStore.toggleTag('endurance');
		expect(get(workoutStore).activeTags).toEqual([]);
	});

	it('clearFilters resets state', () => {
		workoutStore.setSearchQuery('test');
		workoutStore.toggleTag('sprint');
		workoutStore.setActiveTab('mine');

		workoutStore.clearFilters();

		const state = get(workoutStore);
		expect(state.searchQuery).toBe('');
		expect(state.activeTags).toEqual([]);
		expect(state.activeTab).toBe('all');
	});
});

describe('filteredWorkouts', () => {
	beforeEach(() => {
		workoutStore.clearFilters();
		workoutStore.setWorkouts([
			makeWorkout({ id: '1', title: 'Morning Row', description: 'Easy pace', tags: ['endurance'] }),
			makeWorkout({ id: '2', title: 'Sprint Intervals', description: 'Hard effort', tags: ['sprint', 'hiit'] }),
			makeWorkout({ id: '3', title: 'Steady State', description: 'Moderate row', tags: ['endurance', 'technique'] })
		]);
	});

	it('returns all workouts when no filters active', () => {
		expect(get(filteredWorkouts)).toHaveLength(3);
	});

	it('filters by searchQuery on title', () => {
		workoutStore.setSearchQuery('sprint');
		expect(get(filteredWorkouts)).toHaveLength(1);
		expect(get(filteredWorkouts)[0].id).toBe('2');
	});

	it('filters by searchQuery on description', () => {
		workoutStore.setSearchQuery('easy');
		expect(get(filteredWorkouts)).toHaveLength(1);
		expect(get(filteredWorkouts)[0].id).toBe('1');
	});

	it('filters by activeTags', () => {
		workoutStore.toggleTag('endurance');
		const results = get(filteredWorkouts);
		expect(results).toHaveLength(2);
		expect(results.map((w) => w.id).sort()).toEqual(['1', '3']);
	});

	it('filters by both searchQuery and activeTags', () => {
		workoutStore.setSearchQuery('steady');
		workoutStore.toggleTag('endurance');
		const results = get(filteredWorkouts);
		expect(results).toHaveLength(1);
		expect(results[0].id).toBe('3');
	});
});

describe('allTags', () => {
	beforeEach(() => {
		workoutStore.clearFilters();
	});

	it('extracts unique tags sorted alphabetically', () => {
		workoutStore.setWorkouts([
			makeWorkout({ tags: ['sprint', 'endurance'] }),
			makeWorkout({ tags: ['endurance', 'technique'] })
		]);
		expect(get(allTags)).toEqual(['endurance', 'sprint', 'technique']);
	});

	it('returns empty array when no workouts', () => {
		workoutStore.setWorkouts([]);
		expect(get(allTags)).toEqual([]);
	});
});
