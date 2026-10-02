# Business Rule: Monday-to-Sunday Weekly Calendar Boundaries

## Metadata
| Field | Value |
|---|---|
| **ID** | `BR-002` |
| **Title** | Monday-to-Sunday Weekly Calendar Boundaries |
| **Status** | `Active` |
| **Category** | Calendar / Activity Tracking |
| **Last Updated** | 2026-10-02 |
| **Author / Origin** | Engineering Team / Specification R5 |

---

## Rule Statement
Weekly workout schedules, consistency streak counts, and weekly activity heatmap indicators operate strictly on a 7-day Monday through Sunday calendar cycle. Monday is defined as day 1 (`DateTime.monday = 1`), and Sunday is defined as day 7 (`DateTime.sunday = 7`). Records occurring outside the active Monday 00:00:00 to Sunday 23:59:59 window belong to distinct training microcycles.

---

## Domain Context & Business Rationale
In athletic resistance training and gym culture, training programs are structured around weekly microcycles starting on Monday. Lifters plan their splits (e.g. Push on Monday, Pull on Tuesday) with intentional recovery distribution through the weekend. Establishing a deterministic Monday-to-Sunday boundary guarantees that:
- Training frequency adheres to weekly split volume prescriptions.
- Consistency streaks accurately reflect adherence during the current training week.
- Past missed sessions and future scheduled rest days are clearly distinguished in the UI.

---

## Formal Constraints & Boundaries
- **Constraint 1 (Ordered Weekdays)**: The week schedule adheres to the 7-day list:
  `['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']`.
- **Constraint 2 (Monday Boundary Formula)**: Given the current date `now`:
  $$\text{today} = \text{DateTime}(\text{now.year}, \text{now.month}, \text{now.day})$$
  $$\text{monday} = \text{today} - \text{Duration}(\text{days: } \text{now.weekday} - 1)$$
  Because Dart defines Monday as weekday `1`, subtracting $\text{weekday} - 1$ days reliably anchors the microcycle to Monday at 00:00:00.
- **Constraint 3 (7-Day Activity Map)**: `WeeklyActivityViewModel.weekActivity` produces an unmodifiable map with exactly 7 entries: `['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']`.
- **Constraint 4 (Streak Calculation)**:
  $$\text{streakCount} = \sum_{\text{day} \in \text{weekActivity}} [\text{isActive}(\text{day}) == \text{true}]$$

---

## Edge Cases & Error Handling
- **Edge Case 1 (Daily Cache Eviction Isolation)**: The daily record cache (`daily_record_cache`) purges records older than today. To prevent this purge from erasing weekly completion indicators, `GoogleDriveService.getWeeklyDailyRecords([referenceDate])` maintains a separate cache key (`weekly_activity_cache`) that retains all completed records across the current Monday-to-Sunday window.
- **Edge Case 2 (Missed Past Days vs Future Days)**: In `WeeklyActivitySection`:
  - Days prior to today without logged workouts render in red (`AppColors.error`) with `Icons.close`.
  - Completed days render in green (`AppColors.success`) with `Icons.check`.
  - The current day renders with an accent border.
  - Future days in the week render neutrally awaiting completion.

---

## Source Code Citations
- **File**: `lib/domain/models/workout_split.dart`
  - **Lines**: 15–23
  - **Function / Class**: `WorkoutSplit.weekdays`
  - **Role**: Defines the canonical Monday-through-Sunday weekday string list.
- **File**: `lib/ui/features/weekly_activity/view_models/weekly_activity_view_model.dart`
  - **Lines**: 40–63
  - **Function / Class**: `WeeklyActivityViewModel.loadWeeklyActivity()`
  - **Role**: Computes Monday start using `now.weekday - 1`, evaluates 7 days of activity, and calculates weekly streak count.
- **File**: `lib/data/services/google_drive_service.dart`
  - **Lines**: 567–628
  - **Function / Class**: `GoogleDriveService.getWeeklyDailyRecords([DateTime? referenceDate])`
  - **Role**: Retrieves and merges weekly records between `monday` and `nextMonday`, protecting weekly historical cache.

---

## Automated Test Citations
- **Test File**: `test/weekly_activity_test.dart`
  - **Lines**: 31–73
  - **Test Case Name**: `'marks logged days in the current Monday-to-Sunday week'`
  - **Assertion**: Verifies that `viewModel.weekActivity` has length 7, marks Mon and Wed as true, Sun as false, and calculates streak count of 2.
- **Test File**: `test/weekly_activity_test.dart`
  - **Lines**: 75–104
  - **Test Case Name**: `'retains completed dates after the daily cache purges history'`
  - **Assertion**: Verifies that records from earlier in the week remain accessible via `getWeeklyDailyRecords` even when `getDailyRecords()` returns empty due to daily purging.
