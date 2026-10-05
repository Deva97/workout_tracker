# Business Rule: Workout Split Weekly Day Limits

## Metadata
| Field | Value |
|---|---|
| **ID** | `BR-001` |
| **Title** | Workout Split Weekly Day Limits |
| **Status** | `Active` |
| **Category** | Workout Splits / Scheduling Limits |
| **Last Updated** | 2026-10-02 |
| **Author / Origin** | Engineering Team / Specification R5 |

---

## Rule Statement
Each workout split defines an immutable upper bound on the number of active workout days permitted within a 7-day calendar week. Pull-Push Split allows a maximum of 4 workout days; Anterior-Posterior Split allows a maximum of 4 workout days; Full Body Split allows a maximum of 3 workout days; and Bro Split permits unlimited workout days (returns `null`).

---

## Domain Context & Business Rationale
Resistance training programs require structured rest periods to allow neuromuscular recovery and myofibrillar protein synthesis. 
- **Full Body Split**: Because every training session stresses major kinetic chains across the entire body, systemic central nervous system (CNS) and muscular fatigue require at least 48 hours between workouts, capping weekly frequency at 3 days.
- **Pull-Push Split & Anterior-Posterior Split**: These 2-way splits distribute volume between agonist/antagonist or movement plane pairings, accommodating 4 weekly sessions without excessive local overlap.
- **Bro Split**: Because individual sessions isolate single muscle groups (e.g. Chest, Back, Shoulders, Legs), consecutive training days target different muscular systems, allowing up to 7 training sessions per week.

---

## Formal Constraints & Boundaries
- **Constraint 1 (Split Limits Table)**:
  - `WorkoutSplit.pullPushSplit` (`'Pull-Push Split'`): Max 4 days per week.
  - `WorkoutSplit.anteriorPosteriorSplit` (`'Anterior-Posterior Split'`): Max 4 days per week.
  - `WorkoutSplit.fullBodySplit` (`'Full Body Split'`): Max 3 days per week.
  - `WorkoutSplit.broSplit` (`'Bro Split'`): Unlimited (returns `null`).
- **Constraint 2 (Active Day Definition)**: An active workout day is any weekday where the assigned workout value is non-empty and not equal to `'Rest'`.
- **Constraint 3 (Validation Evaluation)**: Candidate schedule assignment is valid if and only if:
  $$\text{activeDaysCount} \le \text{maxDays} \quad \text{or} \quad \text{maxDays is null}$$

---

## Edge Cases & Error Handling
- **Edge Case 1 (Limit Reached on Unassigned Day)**: If the user attempts to assign a workout to a rest day when the split limit is already reached, workout options in the selection dialog are disabled (`onTap: null`) and a warning message is rendered: `'Maximum of X workout days reached for <Split>.'`.
- **Edge Case 2 (Editing an Existing Day)**: Selecting an already active workout day allows switching workout options without increasing total active day count (`enabled: !limitReached || workout == currentWorkout`).
- **Edge Case 3 (Split Switching Reset)**: Switching from one split to another presents a confirmation dialog warning that the weekly schedule will be reset, clearing `workout_schedule` from local storage.

---

## Source Code Citations
- **File**: [`workout_split.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/lib/domain/models/workout_split.dart)
  - **Lines**: 56–67
  - **Function / Class**: `WorkoutSplit.getMaximumWorkoutDays(String split)`
  - **Role**: Returns the maximum allowed workout days for each split string (`4`, `4`, `3`, or `null`).
- **File**: [`manage_workout_split_use_case.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/lib/domain/use_cases/manage_workout_split_use_case.dart)
  - **Lines**: 27–44
  - **Function / Class**: `ManageWorkoutSplitUseCase.canAssignWorkoutDay(...)`
  - **Role**: Validates whether assigning a target value to a weekday violates the split day limit.
- **File**: [`workout_schedule_page.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/lib/ui/features/workout_split/views/workout_schedule_page.dart)
  - **Lines**: 60–83, 112–149
  - **Function / Class**: `WorkoutSchedulePage._maximumWorkoutDays` and dialog builder
  - **Role**: Enforces interactive day limits in UI and displays warning banner when limit is reached.

---

## Automated Test Citations
- **Test File**: [`widget_test.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/test/widget_test.dart)
  - **Lines**: 102–121
  - **Test Case Name**: `'Full Body Split prevents a fourth workout day'`
  - **Assertion**: Populates 3 days with 'Full Body' and asserts that tapping a fourth day ('Thursday') displays `'Maximum of 3 workout days reached for Full Body Split.'` (`findsOneWidget`).
