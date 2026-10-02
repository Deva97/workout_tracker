# Business Rules Knowledge Catalog

## 1. Overview & Purpose
The **Business Rules** category captures immutable business logic, domain boundaries, calculation formulas, and algorithmic rules that govern the workout tracker application. Business rules are independent of UI framework or persistence implementation; they define the invariant operational logic of the product.

Every business rule persisted in this directory must pass the **Business Rule Litmus Test**:
> *"Does this define a core calculation formula, validation constraint, domain boundary, or operational rule governing user data?"*

---

## 2. Naming & Identification Standards
- **File Naming Pattern**: `br-<topic-slug>.md` (e.g. `br-workout-split-limits.md`)
- **Identifier Prefix**: `BR-XXX` (sequential 3-digit zero-padded number, e.g. `BR-001`)
- **Document Template**: Standardized schema defined in [Business Rule Template](../../../.agents/skills/project-context-memory/templates/business-rule.md)

---

## 3. Active Business Rules Catalog

| ID | File | Rule Title | Enforcing Code | Regressing Test | Status |
|:---:|:---|:---|:---|:---|:---:|
| **BR-001** | [`br-workout-split-limits.md`](br-workout-split-limits.md) | Workout Split Weekly Day Limits | `lib/domain/models/workout_split.dart:56-67` | `test/widget_test.dart:102-121` | Active |
| **BR-002** | [`br-calendar-week-boundaries.md`](br-calendar-week-boundaries.md) | Monday-to-Sunday Weekly Calendar Boundaries | `lib/domain/models/workout_split.dart:15-23`, `lib/ui/features/weekly_activity/view_models/weekly_activity_view_model.dart` | `test/weekly_activity_test.dart:31-73`, `test/weekly_activity_test.dart:75-100` | Active |
| **BR-003** | [`br-estimated-1rm-pr-calculation.md`](br-estimated-1rm-pr-calculation.md) | Estimated 1RM Formula & Personal Record (PR) Detection | `lib/domain/use_cases/get_exercise_statistics_use_case.dart:78-81`, `lib/ui/features/workout_log/view_models/todays_workout_log_view_model.dart:169-170` | `test/todays_workout_log_test.dart:270-307`, `test/todays_workout_log_test.dart:310-344` | Active |

---

## 4. Contributing & Modifying Business Rules
1. **Discover**: Identify candidate rules during requirement analysis, bug fixing, or code review.
2. **Verify Against Code & Tests**: Check existing source files in `lib/` and tests in `test/`. Never record a rule based on assumption.
3. **Check for Duplicates**: Search this catalog to confirm the rule is not already documented.
4. **Scaffold**: Copy `.agents/skills/project-context-memory/templates/business-rule.md` to `project-context/knowledge/business-rules/br-<slug>.md`.
5. **Populate**: Include exact file paths, line numbers, and regression test descriptions.
6. **Register**: Add the new rule entry to the catalog table above and update `project-context/index.md`.
7. **Deprecation**: If a rule changes due to product requirements, mark the old record as `Superseded by BR-XXX` with rationale. Never delete silently.
