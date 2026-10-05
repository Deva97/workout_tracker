# Business Rule: Workout Split Weekly Target Days & Dynamic Day Limits

## Metadata
| Field | Value |
|---|---|
| **ID** | `BR-001` |
| **Title** | Workout Split Weekly Target Days & Dynamic Day Limits |
| **Status** | `Active` |
| **Category** | Workout Splits / Scheduling Limits |
| **Last Updated** | 2026-10-05 |
| **Author / Origin** | Engineering Team / Dynamic Target Days Specification |

---

## Rule Statement
Users configure their weekly training frequency (1 to 7 days per week) whenever choosing or modifying any workout split. The selected target days $X$ is persisted under `split_target_days` and acts as the authoritative dynamic limiter for weekly scheduling. No workout split enforces an immutable hardcoded day cap; any split (Bro Split, Pull-Push Split, Anterior-Posterior Split, Full Body Split) can be scheduled for as many active workout days as the user chooses ($1 \le X \le 7$).

---

## Domain Context & Business Rationale
While conventional athletic guidelines offer baseline frequency suggestions (e.g. 3 days for Full Body, 4 days for 2-way splits like Anterior-Posterior or Pull-Push, 5 days for Bro Split), real-world athletes tailor their schedules to individual recovery capacity, life schedules, and volume periodization.
- By prompting the user: **"How many days are you working out?"** upon selecting any split, the app establishes user intent upfront.
- The schedule limiter is dynamically parameterized by the user's choice $X$, preventing accidental scheduling beyond the designated target while allowing complete freedom of frequency across all split types.

---

## Formal Constraints & Boundaries
- **Constraint 1 (Dynamic Target Range)**: Weekly target days $X$ must satisfy $1 \le X \le 7$. Default suggested fallbacks (`getDefaultTargetDays`) are:
  - Pull-Push Split: 4 days
  - Anterior-Posterior Split: 4 days
  - Full Body Split: 3 days
  - Bro Split: 5 days
- **Constraint 2 (Active Day Definition)**: An active workout day is any weekday where the assigned workout value is non-empty and not equal to `'Rest'`.
- **Constraint 3 (Validation Evaluation)**: Candidate schedule assignment is valid if and only if:
  $$\text{activeDaysCount} \le \text{targetDays}$$
  Unassigning a day or marking it `'Rest'` is unconditionally permitted.
- **Constraint 4 (In-Place Target Adjustment)**: Users can adjust their weekly target $X$ at any time via the header card in `WorkoutSchedulePage` without resetting their split or existing schedule.

---

## Edge Cases & Error Handling
- **Edge Case 1 (Limit Reached on Unassigned Day)**: If active scheduled days reach the user's target $X$ and the user selects an unassigned (Rest) day, non-rest workout options in the selection dialog are disabled (`onTap: null`) and a warning message is rendered: `'Maximum of X workout days reached for <Split>.'`.
- **Edge Case 2 (Editing an Existing Active Day)**: Selecting an already active workout day allows switching workout options without increasing total active day count (`enabled: !limitReached || workout == currentWorkout`).
- **Edge Case 3 (Split Switching Reset)**: Switching from one split to a different split presents a confirmation dialog warning that the weekly schedule will be reset, clearing `workout_schedule` from local storage.
- **Edge Case 4 (Persistence Backward Compatibility)**: If no target days are stored in `SharedPreferences`, `WorkoutSchedulePage` gracefully falls back to `initialTargetDays` or `WorkoutSplit.getDefaultTargetDays(split)`.

---

## Source Code Citations
- **File**: [`workout_split.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/lib/domain/models/workout_split.dart)
  - **Function / Class**: `WorkoutSplit.getDefaultTargetDays(String split)`
  - **Role**: Provides suggested default target frequencies.
- **File**: [`manage_workout_split_use_case.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/lib/domain/use_cases/manage_workout_split_use_case.dart)
  - **Function / Class**: `ManageWorkoutSplitUseCase.canAssignWorkoutDay(...)`
  - **Role**: Validates schedule mutations against dynamic `maxDays`.
- **File**: [`workout_split_page.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/lib/ui/features/workout_split/views/workout_split_page.dart)
  - **Function / Class**: `WorkoutSplitPage._promptWorkoutDays`
  - **Role**: Prompts user for weekly workout target (1-7 days) when selecting any split.
- **File**: [`workout_schedule_page.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/lib/ui/features/workout_split/views/workout_schedule_page.dart)
  - **Function / Class**: `WorkoutSchedulePage._chooseWorkout` and `_showEditTargetDaysDialog`
  - **Role**: Displays weekly target progress card, enforces dynamic limiter $X$, and enables live target adjustments.

---

## Automated Test Citations
- **Test File**: [`widget_test.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/test/widget_test.dart)
  - `'selecting a split opens the seven-day schedule'`: Verifies selecting a split triggers the day prompt and navigates with chosen target days.
  - `'Full Body Split prevents a fourth workout day'`: Verifies 3-day limit enforcement.
  - `'Anterior-Posterior Split allows up to 5 days when user targets 5 days'`: Verifies Anterior-Posterior is no longer capped at 4 and respects user target of 5 days.
  - `'User can edit target days in WorkoutSchedulePage dynamically'`: Verifies live adjustment of target days on the schedule page.
- **Test File**: [`features_and_optimizations_test.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/test/features_and_optimizations_test.dart)
  - `'LocalStorageService persists and retrieves split_target_days'`
  - `'ManageWorkoutSplitUseCase validates against dynamic maxDays'`
  - `'WorkoutSplitViewModel loads, saves, and evaluates target days'`
  - `'WorkoutSplitPage prompts for days and navigates with chosen target'`
