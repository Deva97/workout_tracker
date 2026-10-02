# Architecture Decision Record: Two-Tier Cache-First Local Storage Architecture

## Metadata
| Field | Value |
|---|---|
| **ID** | `ADR-002` |
| **Title** | Two-Tier Cache-First Local Storage Architecture |
| **Status** | `Accepted` |
| **Date** | 2026-10-02 |
| **Deciders** | Architecture Council / Engineering Team |
| **Consulted** | Core Contributors / Specification Survey |

---

## Context & Problem Statement
Mobile networks in gym facilities (particularly basement weight rooms or concrete-shielded facilities) frequently suffer from severe latency, intermittent dropouts, or total lack of cellular reception. Direct Google Drive API network calls require between 500 ms and 3000 ms per round-trip. If workout logging actions, set edits, or screen loads directly awaited remote cloud responses, the application would feel sluggish and unworkable for trainees needing to rapidly log sets and start rest timers between efforts.

---

## Decision Drivers
- **Driver 1 (Instantaneous UI Latency)**: Zero-latency (<16ms) interactive responsiveness for adding sets, editing weights, and navigating screens.
- **Driver 2 (Offline Autonomy)**: Full operational capability during complete network dropouts during workouts.
- **Driver 3 (Eventual Consistency)**: Reliable, non-blocking synchronization with the user's remote Google Drive Excel spreadsheets.

---

## Considered Options

### Option 1: Two-Tier Cache-First Architecture (Chosen)
- **Description**: Two distinct storage tiers:
  - **Tier 1 (Local Cache)**: `SharedPreferences` key-value storage (`exercise_cache`, `daily_record_cache`, `weekly_activity_cache`, `workout_schedule`, `split_choice`). Reads and writes occur synchronously in-memory / locally.
  - **Tier 2 (Remote Persistence)**: Google Drive Excel files (`Exercise_DB.xlsx`, `Daily_record.xlsx`). Asynchronous background syncing pushes local state changes to Drive without blocking the UI.
- **Pros**:
  - Immediate optimistic screen rendering and state mutations.
  - Complete immunity to cellular dead zones during workouts.
  - Low complexity without requiring native SQL engine drivers.
- **Cons**:
  - Requires explicit cache reconciliation and eviction lifecycle management.

### Option 2: Cloud-First Architecture
- **Description**: All user actions await Google Drive API round-trips before rendering or persisting state.
- **Pros**: Trivial consistency model without separate cache storage.
- **Cons**: Completely unusable in poor network conditions; unacceptably sluggish UI latency.

---

## Decision Outcome
**Chosen Option**: **Option 1: Two-Tier Cache-First Architecture**

### Justification
Gym workout tracking demands immediate tactile responsiveness. A trainee logging a heavy set while fatigued cannot wait for a network wheel to spin. The two-tier architecture guarantees immediate local state commits, allowing rest timers to activate instantly while background workers reconcile cloud spreadsheets.

---

## Consequences

### Positive Consequences
- Set logging and screen transitions execute with 0 ms perceptible latency.
- Full offline capability: trainees can complete entire workouts with zero internet access, with data syncing upon reconnection.
- Decouples UI widget rendering from network connection states.

### Negative Consequences / Trade-offs & Mitigations
- **Cache Eviction Nuances**: Standard daily caching purges historical records older than today, which would break the weekly activity tracker.
  - **Mitigation**: Implemented independent cache key `weekly_activity_cache` in `GoogleDriveService` to retain the current Monday–Sunday window independently from the daily purge.

---

## Source Code & Test Traceability
- **Implementation Core**: `lib/data/services/local_storage_service.dart` (Lines 4–60)
- **ViewModel Integration**: `lib/ui/features/workout_log/view_models/todays_workout_log_view_model.dart` (Lines 76–88)
- **Automated Regression Test**:
  - `test/widget_test.dart` (Lines 123–136, test name: `'restores saved weekly assignments'`)
  - `test/todays_workout_log_test.dart` (Lines 293–299): Verifies cache hydration in widget test harness.
