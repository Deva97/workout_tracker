# Domain Concept: Gym Workout Splits, Sets, Reps, and RIR Domain Model

## Metadata
| Field | Value |
|---|---|
| **ID** | `DOM-001` |
| **Concept / Term** | Gym Workout Splits, Sets, Reps, and RIR Domain Model |
| **Domain Area** | `Gym / Exercise Science / Training Splits` |
| **Status** | `Active` |
| **Last Updated** | 2026-10-02 |
| **Domain Authority** | Exercise Science & Standard Resistance Training Methodology |

---

## Formal Definition
This domain model formalizes resistance training methodologies into structured, measurable software entities:
- **Workout Splits**: The systemic division of muscular targets or kinetic movement planes across a weekly training microcycle to optimize myofibrillar stimulus and neuromuscular recovery.
- **Exercise**: A standardized physical movement pattern targeting specific anatomical musculature (e.g. Bench Press -> Chest, Squat -> Legs, Deadlift -> Back).
- **Set**: A contiguous, uninterrupted series of repetitions performed for an exercise before taking a rest interval.
- **Repetitions (Reps)**: The count of complete concentric and eccentric muscular actions executed during a single set.
- **Weight**: The external resistance load (quantified in kilograms) displaced during the set.
- **Reps In Reserve (RIR)**: A scientifically validated subjective rating of perceived exertion (inverse of RPE) measuring proximity to concentric muscular failure on a 0.0 to 10.0 scale. An RIR of 0.0 signifies technical or concentric failure (0 reps left), while 2.0 indicates the lifter could have completed 2 more reps before failure.

---

## Domain Rules & Standard Formulas
- **Volume Load Formula**:
  $$\text{Volume Load} = \text{weight} \times \text{reps}$$
- **Estimated 1-Repetition Maximum (Epley)**:
  $$\text{1RM} = \text{weight} \times \left(1.0 + \frac{\text{reps}}{30.0}\right)$$
- **RIR Validity Scale**: $0.0 \le \text{RIR} \le 10.0$ (modal increments of 0.5 or 1.0).
- **Repetition Boundary**: $\text{reps} \ge 1$ (sets with 0 reps are invalid and rejected during entry).
- **Weight Boundary**: $\text{weight} \ge 0.0$ kg (bodyweight movements default to $0.0$ kg).

---

## Gym Context & User Expectations
- **High Cognitive Fatigue Logging**: Trainees log sets immediately after intense physical exertion while fatigued. The interface must minimize text typing: numeric pickers, auto-incrementing set numbers, and pre-filling previous weight and rep values are essential.
- **Immediate Recovery Pacing**: Finishing a set triggers a rest countdown timer automatically, ensuring lifters recover adequately between work sets.
- **Gamified Performance Feedback**: Daily highest estimated 1RM sets receive an immediate `PR 🏆` gold badge, reinforcing training consistency and progressive overload.

---

## Entity Relationships
1. **WorkoutSplit** defines allowable schedule options (`getWorkoutOptions`) and maximum active weekly training days (`getMaximumWorkoutDays`).
2. An **Exercise** defines the movement identity (`guid`), display label (`name`), and anatomical classification (`bodyPart`).
3. A **DailyRecord** records an individual performance instance linking `workoutId` (foreign key to `Exercise.guid`), `date`, `set` index, `reps`, `weight`, and `rir`.
4. A **DailyWorkoutEntry** provides an in-memory aggregate joining a `DailyRecord` with its resolved `Exercise` definition for rich UI rendering and statistics.

---

## Code Model References
- **Domain Models**:
  - `lib/domain/models/workout_split.dart`
    - **Class**: `WorkoutSplit`
    - **Key Properties**: `broSplit`, `pullPushSplit`, `anteriorPosteriorSplit`, `fullBodySplit`, `weekdays`
  - `lib/domain/models/exercise.dart`
    - **Class**: `Exercise`
    - **Key Properties**: `guid`, `name`, `bodyPart`
  - `lib/domain/models/daily_record.dart`
    - **Class**: `DailyRecord`
    - **Key Properties**: `id`, `workoutId`, `workoutName`, `date`, `set`, `reps`, `rir`, `weight`
  - `lib/domain/models/daily_workout_entry.dart`
    - **Class**: `DailyWorkoutEntry`
    - **Key Properties**: `record`, `exercise`
- **Associated Tests**:
  - `test/widget_test.dart`: Validates split selection and schedule assignment.
  - `test/todays_workout_log_test.dart`: Validates set logging, modal validation, relational joins, and PR badges.
  - `test/excel_orm_test.dart`: Validates serialization of sets into Excel tables.
