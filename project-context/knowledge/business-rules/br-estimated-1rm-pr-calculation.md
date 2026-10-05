# Business Rule: Estimated 1RM Formula & Personal Record (PR) Detection

## Metadata
| Field | Value |
|---|---|
| **ID** | `BR-003` |
| **Title** | Estimated 1RM Formula & Personal Record (PR) Detection |
| **Status** | `Active` |
| **Category** | Strength Progression / Personal Records |
| **Last Updated** | 2026-10-02 |
| **Author / Origin** | Engineering Team / Specification R5 |

---

## Rule Statement
Estimated 1-Repetition Maximum (1RM) is calculated using the validated Epley formula: $\text{1RM} = \text{weight} \times (1.0 + \text{reps} / 30.0)$ for weighted sets ($\text{weight} > 0$ and $\text{reps} > 0$). For bodyweight movements where $\text{weight} \le 0$, the score defaults to $\text{reps.toDouble()}$. If $\text{reps} \le 0$, the score is $0.0$. A set is flagged as a Personal Record (`isPersonalRecord == true`) and awarded the gold `PR 🏆` badge if its estimated 1RM is the strictly highest score among all logged sets for that specific exercise during today's workout.

---

## Domain Context & Business Rationale
Direct maximum load testing (1RM attempts) induces extreme central nervous system fatigue and elevates injury risk in unassisted gym environments. The Epley formula is the exercise science gold standard for estimating maximal strength from submaximal multi-rep efforts. By evaluating every completed set against this formula:
- Lifters can benchmark performance across different repetition schemes (e.g. comparing 100 kg × 5 reps vs 110 kg × 2 reps).
- The application automatically celebrates training breakthroughs by highlighting daily peak sets with a prominent `PR 🏆` badge.
- Historical trend analysis tracks strength progression over time.

---

## Formal Constraints & Boundaries
- **Constraint 1 (Epley 1RM Formula)**:
  $$\text{1RM} = \begin{cases} \text{weight} \times \left(1.0 + \frac{\text{reps}}{30.0}\right) & \text{if } \text{weight} > 0 \text{ and } \text{reps} > 0 \\ \text{reps} & \text{if } \text{weight} \le 0 \text{ and } \text{reps} > 0 \\ 0.0 & \text{if } \text{reps} \le 0 \end{cases}$$
- **Constraint 2 (Per-Exercise Daily Peak)**: PR evaluation groups entries by `exercise.guid`. For each exercise group, only the set yielding the highest `score` is added to `_prRecordIds`.
- **Constraint 3 (Reactive Recalculation)**: Any mutation to today's workout log (`saveSet`, `editSet`, `deleteSet`, `restoreSet`) immediately clears and recalculates PR badges across all active entries.

---

## Edge Cases & Error Handling
- **Edge Case 1 (Bodyweight Movements)**: For bodyweight exercises (e.g. pullups, dips, pushups) where weight is entered as 0 kg, the scoring algorithm falls back to `reps.toDouble()`, ensuring that calisthenics sets with higher rep counts correctly receive PR distinction.
- **Edge Case 2 (Zero or Negative Reps)**: Sets logged with `reps <= 0` are bypassed during PR calculation loop (`if (reps <= 0) continue;`) and yield a score of `0.0`.
- **Edge Case 3 (Tie Scores)**: If two sets achieve identical peak estimated 1RM scores, the first set encountered retains the PR flag (`score > peakScore` strictly required to usurp the peak).

---

## Source Code Citations
- **File**: [`get_exercise_statistics_use_case.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/lib/domain/use_cases/get_exercise_statistics_use_case.dart)
  - **Lines**: 78–81
  - **Function / Class**: `GetExerciseStatisticsUseCase._calculateEstimated1RM(double weight, int reps)`
  - **Role**: Core mathematical implementation of the Epley 1RM estimation formula.
- **File**: [`todays_workout_log_view_model.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/lib/ui/features/workout_log/view_models/todays_workout_log_view_model.dart)
  - **Lines**: 154–179
  - **Function / Class**: `TodaysWorkoutLogViewModel._recalculatePersonalRecords()`
  - **Role**: Groups today's sets by exercise, applies the Epley formula with bodyweight fallback, and populates `_prRecordIds`.
- **File**: [`todays_workout_log_screen.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/lib/ui/features/workout_log/views/todays_workout_log_screen.dart)
  - **Lines**: 316, 365–380
  - **Function / Class**: `TodaysWorkoutLogScreen` set tile builder
  - **Role**: Renders the gold `PR 🏆` badge next to the set tile when `_viewModel.isPersonalRecord(entry)` is true.

---

## Automated Test Citations
- **Test File**: [`todays_workout_log_test.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/test/todays_workout_log_test.dart)
  - **Lines**: 270–307
  - **Test Case Name**: `'renders PR 🏆 badge for the set with highest estimated 1RM'`
  - **Assertion**: Configures set 1 (40 kg × 10 reps, est. 53.33) and set 2 (50 kg × 8 reps, est. 63.33); asserts that `find.text('PR 🏆')` finds exactly one widget corresponding to set 2.
- **Test File**: [`todays_workout_log_test.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/test/todays_workout_log_test.dart)
  - **Lines**: 310–344
  - **Test Case Name**: `'identifies personal record set based on peak estimated 1RM'`
  - **Assertion**: Asserts that `viewModel.isPersonalRecord(entry1)` is false and `viewModel.isPersonalRecord(entry2)` is true for Bench Press.
- **Test File**: [`features_and_optimizations_test.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/test/features_and_optimizations_test.dart)
  - **Lines**: 250–299
  - **Test Case Name**: `'computes peakScore, totalSessions, totalSets and trendPercentage correctly in single pass'`
  - **Assertion**: Verifies single-pass statistical calculation of peak 1RM across sessions.
