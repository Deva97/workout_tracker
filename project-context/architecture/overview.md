# Workout Tracker — Architecture Overview

## 1. Architectural Paradigms

The **Workout Tracker** application is engineered around three core design principles that prioritize domain purity, instant user interaction, and transparent data ownership:

1. **3-Layer Clean Architecture**: Strict concentric layer separation ensures business logic remains independent of external frameworks, databases, and UI widgets. Dependencies point exclusively inward toward the Domain layer.
2. **Decoupled MVVM Presentation**: Views bind reactively to `ChangeNotifier` ViewModels. ViewModels depend exclusively on Domain Use Cases and Repository interfaces, accepting constructor injection for hermetic unit testing.
3. **Two-Tier Cache-First Persistence**: A local cache-first architecture provides instantaneous (0ms) UI rendering and offline operability, while a debounced, serialized background queue handles synchronization with the user's Google Drive.

```
┌───────────────────────────────────────────────────────────┐
│                         UI Layer                          │
│  lib/ui/core/ (Theme, Modular Widgets)                    │
│  lib/ui/features/ (Screens, ChangeNotifier ViewModels)     │
└─────────────────────────────┬─────────────────────────────┘
                              │ Calls Use Cases & Repositories
                              ▼
┌───────────────────────────────────────────────────────────┐
│                       Domain Layer                        │
│  lib/domain/models/ (WorkoutSplit, Exercise, DailyRecord) │
│  lib/domain/repositories/ (WorkoutRepository Interface)   │
│  lib/domain/use_cases/ (GetExerciseStatistics, LogSet)    │
└─────────────────────────────▲─────────────────────────────┘
                              │ Implements Interfaces
                              │
┌───────────────────────────────────────────────────────────┐
│                        Data Layer                         │
│  lib/data/orm/ (ExcelContext, ExcelTable, EntityMapper)   │
│  lib/data/context/ (WorkoutDbContext)                     │
│  lib/data/services/ (GoogleDriveService, LocalStorage)    │
│  lib/data/repositories/ (WorkoutRepositoryImpl)           │
└───────────────────────────────────────────────────────────┘
```

---

## 2. Layered Architecture Breakdown

### 2.1 Domain Layer (`lib/domain/`)
The Domain layer represents the core business logic and rules of the application. It has zero external dependencies on Flutter UI components, Google APIs, or local device storage.
- **Entities & Value Objects (`lib/domain/models/`)**:
  - `WorkoutSplit`: Encapsulates training split classifications (`Bro Split`, `Pull-Push Split`, `Anterior-Posterior Split`, `Full Body Split`), max workout day boundaries, and weekday sequences.
  - `Exercise`: Represents unique exercises with body part targets and database identifiers.
  - `DailyRecord`: Models individual workout set entries (reps, weight, RIR, timestamp, exercise metadata).
- **Repository Contracts (`lib/domain/repositories/`)**:
  - `WorkoutRepository`: Defines pure abstract contracts for retrieving schedules, querying exercises, logging sets, and syncing workout history.
- **Use Cases / Interactors (`lib/domain/use_cases/`)**:
  - `GetExerciseStatisticsUseCase`: Orchestrates 1RM calculations, historical trends, volume metrics, and personal records.
  - `GetTodaysWorkoutLogUseCase`: Coordinates loading of the active workout day log and cache state.

### 2.2 Data Layer (`lib/data/`)
The Data layer implements domain repository contracts, manages external device caches, and orchestrates cloud persistence.
- **Custom ExcelORM Engine (`lib/data/orm/`)**:
  - `ExcelContext`: Reflection-free spreadsheet context managing workbook byte buffers and table schemas.
  - `ExcelTable<T>`: Generic strongly-typed table providing insert, update, query, and pagination operations.
  - `ExcelQuery<T>`: Fluent query builder executing filters, sorting, and row limits on spreadsheet records.
  - `EntityMapper<T>`: Bi-directional serializer mapping between raw spreadsheet cells and strongly-typed Dart domain entities.
- **Database Context (`lib/data/context/`)**:
  - `WorkoutDbContext`: Concrete database context managing the `Exercise_DB` and `Daily_record` tables.
- **Infrastructure Services (`lib/data/services/`)**:
  - `GoogleDriveService`: Singleton communicating with Google Drive v3 REST API, handling OAuth2 authentication, file ID resolution, and byte uploads/downloads.
  - `LocalStorageService`: Low-latency key-value wrapper around `SharedPreferences` managing offline caches and user configuration.
- **Repository Implementations (`lib/data/repositories/`)**:
  - `WorkoutRepositoryImpl`: Bridges domain use cases with `WorkoutDbContext`, `GoogleDriveService`, and `LocalStorageService`.

### 2.3 UI Layer (`lib/ui/`)
The UI layer delivers the user interface using Google Material Design 3 and atomic component patterns.
- **Design System & Core Widgets (`lib/ui/core/`)**:
  - `theme/`: Defines global color palettes (`AppColors`), typography hierarchies (`AppTypography`), and Material 3 theme configurations (`AppTheme`).
  - `widgets/`: Reusable atomic and composite components including `ModularCard`, `StatusBadge`, `SyncStatusCard`, `EmptyStateWidget`, and `SearchBarInput`.
- **Feature Modules (`lib/ui/features/`)**:
  - `workout_log/`: Active workout screen (`TodaysWorkoutLogScreen`), set entry modal (`AddWorkoutSetModal`), rest timer overlay, and `TodaysWorkoutLogViewModel`.
  - `weekly_activity/`: 7-day Monday–Sunday visual calendar grid, streak counter, and `WeeklyActivityViewModel`.
  - `workout_split/`: Split configuration and weekday selection (`WorkoutSplitScreen`, `WorkoutSplitViewModel`).
  - `exercise_info/`: Historical performance analytics, trend charts, and `ExerciseStatisticsViewModel`.
  - `auth/`: Google OAuth2 sign-in screen and authentication state flow.

---

## 3. Google Drive Excel Persistence Engine

Rather than relying on proprietary backend databases or cloud lock-in, the application employs a **Bring-Your-Own-Storage (BYOS)** architecture storing data directly inside the user's private Google Drive:

1. **Spreadsheet Files**:
   - `Exercise_DB.xlsx`: Master exercise encyclopedia containing columns `Id`, `exercise_name`, and `body_part_target`.
   - `Daily_record.xlsx`: Tabular ledger of all logged workout sets containing columns `ID`, `workout_ID`, `workout_name`, `Date`, `set`, `reps`, `RIR`, and `weight`.
2. **ExcelORM Streaming**:
   - The custom ORM reads and writes standard OpenXML `.xlsx` byte streams directly in memory.
   - Zero reflection is used, ensuring high performance and compatibility with Dart ahead-of-time (AOT) compilation.
   - Backward row streaming enables fast reverse-chronological queries without parsing the entire file into memory.

---

## 4. Two-Tier Caching & Synchronization Architecture

To eliminate network latency during intense gym workouts, the application decouples immediate UI interaction from cloud synchronization:

```
User Action (Log Set)
      │
      ▼
┌──────────────────────────────────────────────┐
│  Tier 1: Local Cache (SharedPreferences)     │
│  - Instant 0ms update                        │
│  - Optimistic UI state re-render             │
│  - Offline resilient                         │
└──────────────────────┬───────────────────────┘
                       │
                       │ 1500ms Debounce Window
                       ▼
┌──────────────────────────────────────────────┐
│  Tier 2: Remote Drive Sync Queue             │
│  - Serialized queue (in-flight lock)         │
│  - Coalesces rapid sequential set entries    │
│  - Uploads compiled Daily_record.xlsx        │
│  - Emits SyncState (idle, syncing, success,  │
│    or error with non-blocking fallback)      │
└──────────────────────────────────────────────┘
```

### 4.1 Debounced Serialized Sync Queue
- **Debounce Timer**: Rapid set insertions (such as using "Add & Next Set") reset a 1500ms debounce timer in `GoogleDriveService.syncDailyRecordsToDriveInBackground()`.
- **In-Flight Serialization**: A boolean lock `_inFlightDailyRecordSync` ensures only one upload runs at a time. If subsequent writes occur during an upload, `_pendingDailyRecordSyncRequested` queues a follow-up sync automatically.
- **Rate Limit & Collision Protection**: This architecture prevents HTTP 429 Google Drive API throttling and eliminates file corruption from concurrent byte uploads.

### 4.2 Cache Purge Isolation
- **Active-Day Purge**: Standard daily fetches (`getDailyRecords()`) isolate the active workout date to conserve memory.
- **Weekly History Protection**: Multi-day history queries (`getWeeklyDailyRecords()`) explicitly bypass destructive cache purges, guaranteeing that full 7-day Monday–Sunday activity maps remain consistent across sessions.

---

## 5. Architectural Entry Points Map

| Component | File Path | Responsibilities |
|---|---|---|
| **App Bootstrap** | [`main.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/lib/main.dart) | Initializes services, binds global themes, and sets root route. |
| **Domain Repository** | [`workout_repository.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/lib/domain/repositories/workout_repository.dart) | Defines the domain data contracts. |
| **Split Model** | [`workout_split.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/lib/domain/models/workout_split.dart) | Encapsulates split rules and weekday calculations. |
| **1RM Statistics Use Case** | [`get_exercise_statistics_use_case.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/lib/domain/use_cases/get_exercise_statistics_use_case.dart) | Calculates Epley 1RM, volume trends, and PR status. |
| **Database Context** | [`workout_db_context.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/lib/data/context/workout_db_context.dart) | Provides strongly-typed Excel tables for exercises and records. |
| **Excel ORM Core** | [`excel_context.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/lib/data/orm/excel_context.dart) | Manages raw spreadsheet byte streams and table definitions. |
| **Drive Service** | [`google_drive_service.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/lib/data/services/google_drive_service.dart) | Handles Drive OAuth2, REST API calls, and debounced sync queue. |
| **Local Storage Service** | [`local_storage_service.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/lib/data/services/local_storage_service.dart) | Manages `SharedPreferences` keys for cache and preferences. |
| **Daily Log ViewModel** | [`todays_workout_log_view_model.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/lib/ui/features/workout_log/view_models/todays_workout_log_view_model.dart) | Manages active workout session state, set adding, and PR badges. |
| **Weekly Activity ViewModel** | [`weekly_activity_view_model.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/lib/ui/features/weekly_activity/view_models/weekly_activity_view_model.dart) | Computes Monday–Sunday calendar compliance and streaks. |

---

## 6. Verification & Automated Test Coverage

The architectural boundaries defined above are covered by 55 automated regression tests in `test/`:
- **ORM & Serialization**: [`excel_orm_test.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/test/excel_orm_test.dart) validates bidirectional Excel encoding/decoding and reverse queries.
- **Drive Debouncing & Isolation**: [`features_and_optimizations_test.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/test/features_and_optimizations_test.dart) verifies debouncing coalescing and historical cache isolation.
- **ViewModel Decoupling**: [`todays_workout_log_test.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/test/todays_workout_log_test.dart) demonstrates hermetic ViewModel testing using mock repositories without network calls.
- **Calendar Boundaries**: [`weekly_activity_test.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/test/weekly_activity_test.dart) verifies strict Monday-to-Sunday calculation boundaries.
- **Domain Split Constraints**: [`widget_test.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/test/widget_test.dart) confirms user-facing UI enforcement of split day limits.
