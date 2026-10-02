# Convention: 3-Layer Clean Architecture & Dependency Direction

## Metadata
| Field | Value |
|---|---|
| **ID** | `CONV-001` |
| **Title** | 3-Layer Clean Architecture & Dependency Direction |
| **Status** | `Active` |
| **Scope** | `Architecture` |
| **Last Updated** | 2026-10-02 |
| **Author / Origin** | Engineering Team / Specification R5 |

---

## Convention Statement
The codebase strictly adheres to 3 concentric architectural layers with inward-facing dependency directions. The innermost **Domain Layer** (`lib/domain/`) encapsulates pure business entities and contracts with zero dependencies on Flutter UI, Google APIs, or storage engines. The **Data Layer** (`lib/data/`) implements repository interfaces and encapsulates persistence engines (ExcelORM, Google Drive, SharedPreferences). The **UI Layer** (`lib/ui/`) manages presentation via feature-scoped MVVM patterns. Direct imports or dependencies from the UI Layer into concrete Data Layer services or ORM classes are strictly prohibited.

---

## Rationale & Benefits
- **Hermetic Testability**: Decoupling domain logic and presentation from Google Drive networking enables 100% offline, lightning-fast unit and widget tests without spinning up network mocks or emulators.
- **Persistence Agnosticism**: Changes to Excel table layouts or Drive API serialization do not pollute domain rules or break UI presentation logic.
- **Maintainability**: Enforces clear mental models for both human developers and autonomous AI coding agents navigating the codebase.

---

## Code Examples

### Compliant Pattern (Do)
```dart
// ViewModel depends exclusively on domain Use Cases or Repository interfaces:
class TodaysWorkoutLogViewModel extends ChangeNotifier {
  final ManageWorkoutSetUseCase _manageSetUseCase;
  final GetTodaysWorkoutUseCase _getTodaysWorkoutUseCase;

  TodaysWorkoutLogViewModel({
    ManageWorkoutSetUseCase? manageSetUseCase,
    GetTodaysWorkoutUseCase? getTodaysWorkoutUseCase,
  }) : _manageSetUseCase = manageSetUseCase ?? ManageWorkoutSetUseCase(),
       _getTodaysWorkoutUseCase = getTodaysWorkoutUseCase ?? GetTodaysWorkoutUseCase();

  Future<void> saveSet(DailyRecord record) async {
    await _manageSetUseCase.addSet(record);
  }
}
```

### Anti-Pattern (Don't)
```dart
// ANTI-PATTERN: UI Screen or ViewModel directly invoking raw Data services or Drive APIs
class BadWorkoutLogWidget extends StatelessWidget {
  void _onSave(DailyRecord record) {
    // VIOLATION: Directly calling GoogleDriveService or ExcelContext from UI
    GoogleDriveService().syncDailyRecordsToDrive([record]);
  }
}
```

---

## Permitted Exceptions & Nuances
- **Default Parameter Injection**: To balance dependency injection testability with Flutter widget ergonomics, ViewModels provide default fallback instantiations in constructor initializers (e.g. `manageSetUseCase ?? ManageWorkoutSetUseCase()`), avoiding heavy dependency injection service locators.

---

## Enforcing Mechanisms & Linters
- **Foundational Standard**: Root `AGENTS.md` (lines 7–13): "Follow the 3-Layer Clean Architecture: UI Layer (`lib/ui/`), Domain Layer (`lib/domain/`), Data Layer (`lib/data/`)."
- **Architectural Boundary**: Verified via architectural survey in `project-context/architecture/overview.md`.

---

## Source Code & Test Citations
- **Reference Code**:
  - `lib/domain/repositories/workout_repository.dart` (Lines 1–20)
  - `lib/data/repositories/workout_repository_impl.dart` (Lines 1–80)
  - `lib/ui/features/workout_log/view_models/todays_workout_log_view_model.dart` (Lines 14–45)
- **Verifying Test**:
  - `test/todays_workout_log_test.dart` (Lines 14–25): Demonstrates hermetic testing where repository and context are cleanly configured in `setUp()` without external Drive API connections.
