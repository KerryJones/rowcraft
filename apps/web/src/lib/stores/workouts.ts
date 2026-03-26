import { writable, derived } from 'svelte/store';
import type { Workout } from '$lib/types';

type FilterTab = 'all' | 'mine' | 'community';

interface WorkoutState {
	workouts: Workout[];
	loading: boolean;
	searchQuery: string;
	activeTab: FilterTab;
	activeTags: string[];
}

function createWorkoutStore() {
	const { subscribe, set, update } = writable<WorkoutState>({
		workouts: [],
		loading: false,
		searchQuery: '',
		activeTab: 'all',
		activeTags: []
	});

	return {
		subscribe,
		setWorkouts(workouts: Workout[]) {
			update((state) => ({ ...state, workouts, loading: false }));
		},
		setLoading(loading: boolean) {
			update((state) => ({ ...state, loading }));
		},
		setSearchQuery(searchQuery: string) {
			update((state) => ({ ...state, searchQuery }));
		},
		setActiveTab(activeTab: FilterTab) {
			update((state) => ({ ...state, activeTab }));
		},
		toggleTag(tag: string) {
			update((state) => {
				const activeTags = state.activeTags.includes(tag)
					? state.activeTags.filter((t) => t !== tag)
					: [...state.activeTags, tag];
				return { ...state, activeTags };
			});
		},
		clearFilters() {
			update((state) => ({
				...state,
				searchQuery: '',
				activeTab: 'all',
				activeTags: []
			}));
		}
	};
}

export const workoutStore = createWorkoutStore();

export const filteredWorkouts = derived(workoutStore, ($store) => {
	let result = $store.workouts;

	// Filter by search query
	if ($store.searchQuery) {
		const query = $store.searchQuery.toLowerCase();
		result = result.filter(
			(w) =>
				w.title.toLowerCase().includes(query) ||
				w.description.toLowerCase().includes(query) ||
				w.tags.some((t) => t.toLowerCase().includes(query))
		);
	}

	// Filter by active tags
	if ($store.activeTags.length > 0) {
		result = result.filter((w) => $store.activeTags.some((tag) => w.tags.includes(tag)));
	}

	return result;
});

export const allTags = derived(workoutStore, ($store) => {
	const tagSet = new Set<string>();
	$store.workouts.forEach((w) => w.tags.forEach((t) => tagSet.add(t)));
	return Array.from(tagSet).sort();
});
