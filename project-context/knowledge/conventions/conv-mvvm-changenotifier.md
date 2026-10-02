# Convention: MVVM Presentation with ChangeNotifier & Cache-First Rendering

## Metadata
| Field | Value |
|---|---|
| **ID** | `CONV-002` |
| **Title** | MVVM Presentation with ChangeNotifier & Cache-First Rendering |
| **Status** | `Active` |
| **Scope** | `UI / State` |
| **Last Updated** | 2026-10-02 |
| **Author / Origin** | Engineering Team / Specification R5 |

---

## Convention Statement
All feature screens in `lib/ui/features/` must bind to dedicated ViewModels that extend Flutter's `ChangeNotifier`. ViewModels must implement a strict **cache-first rendering strategy**: on initialization, they must immediately hydrate in-memory state from local `SharedPreferences` cache and notify listeners to achieve zero-latency (<16ms) instant UI presentation, followed by non-blocking asynchronous cloud synchronization.

---

## Rationale & Benefits
- **Zero-Latency App Launch**: Lifters opening the app in gym environments must see today's logged sets and exercise lists immediately without waiting for Google Drive network round-trips.
- **Offline Resilience**: Mobile network instability or lack of cellular reception in gym facilities does not freeze the UI or impede set logging.
- **Predictable State Flow**: Native `ChangeNotifier` state updates allow widgets to listen cleanly via `ListenableBuilder` or custom state binders without heavy external reactive frameworks.

---

## Code Examples

### Compliant Pattern (Do)
```dart
Future<void> loadTodaysWorkoutLog() async {
  // 1. Immediately render cached data if present for zero-latency screen load
  final cachedExercises = _exercisesUseCase.getCachedExercises();
  final cachedEntries = _getTodaysWorkoutUseCase.getCachedEntries();
  if (cachedExercises.isNotEmpty || cachedEntries.isNotEmpty) {
    _availableExercises = cachedExercises;
    _todaysEntries = cachedEntries;
    _isLoading = false;
    _recalculatePersonalRecords();
    notifyListeners();
  } else {
    _isLoading = true;
    notifyListeners();
  }

  // 2. Fetch fresh entries from Drive / background sync without blocking initial display
  try {
    final workoutData = await _getTodaysWorkoutUseCase.execute();
    _availableExercises = _exercisesUseCase.getCachedExercises();
    if (_availableExercises.isEmpty) {
      _availableExercises = await _exercisesUseCase.getExercises();
    }
    _todaysEntries = workoutData.entries;
    _recalculatePersonalRecords();
  } catch (_) {
    // Background sync errors don't crash display of cached data
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
```

### Anti-Pattern (Don't)
```dart
// ANTI-PATTERN: Forcing full-screen blocking loading indicator while awaiting network
Future<void> badLoadMethod() async {
  _isLoading = true;
  notifyListeners(); // Renders spinner, locking the user out
  
  // High-latency remote cloud call blocks screen interaction:
  final remoteSets = await _driveService.downloadSpreadsheetFromDrive(); 
  _todaysEntries = remoteSets;
  _isLoading = false;
  notifyListeners();
}
```

---

## Permitted Exceptions & Nuances
- **Cold First Run**: When the app is launched for the very first time on a new device and local caches are empty, `_isLoading = true` is legitimately retained while initial sheets are fetched or created.

---

## Enforcing Mechanisms & Linters
- **Architectural Standard**: Implemented across all feature ViewModels in `lib/ui/features/` (`TodaysWorkoutLogViewModel`, `ExerciseStatisticsViewModel`, `WeeklyActivityViewModel`, `HomeViewModel`, `AuthViewModel`, `WorkoutSplitViewModel`, `ExerciseInfoViewModel`).
- **Profile Reference**: `project-context/profiles/03-state.md` and `project-context/profiles/15-offline-architecture.md`.

---

## Source Code & Test Citations
- **Reference Code**:
  - `lib/ui/features/workout_log/view_models/todays_workout_log_view_model.dart` (Lines 76–116)
- **Verifying Test**:
  - `test/todays_workout_log_test.dart` (Lines 309–360): Unit tests asserting that `TodaysWorkoutLogViewModel` updates state, calculates PRs, and notifies listeners across save, edit, delete, and restore actions.
