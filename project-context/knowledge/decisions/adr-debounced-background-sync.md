# Architecture Decision Record: Debounced Serialized Background Drive Synchronization Queue

## Metadata
| Field | Value |
|---|---|
| **ID** | `ADR-003` |
| **Title** | Debounced Serialized Background Drive Synchronization Queue |
| **Status** | `Accepted` |
| **Date** | 2026-10-02 |
| **Deciders** | Architecture Council / Engineering Team |
| **Consulted** | Core Contributors / Specification Survey |

---

## Context & Problem Statement
During intensive workout sessions, lifters frequently log sets in rapid succession (e.g. entering warm-up sets back-to-back, or quickly adjusting reps and weight). Because persistence is backed by full `.xlsx` spreadsheet byte streams uploaded to Google Drive, triggering an immediate cloud upload on every individual set operation would fire multiple concurrent network calls. Uncoordinated concurrent uploads create catastrophic race conditions where slower requests overwrite newer state, trigger HTTP 429 (Rate Limit Exceeded) errors, and consume unnecessary cellular battery and bandwidth.

---

## Decision Drivers
- **Driver 1 (Concurrency Protection & Zero Write Collisions)**: Ensure strictly serialized upload execution against `Daily_record.xlsx` in Google Drive.
- **Driver 2 (API Quota & Rate Limit Conservation)**: Collapse bursty set-logging operations into single batched Drive updates.
- **Driver 3 (Guaranteed Eventual Freshness)**: Ensure that modifications occurring while an upload is actively in-flight are never lost and trigger a follow-up sync with the latest snapshot.

---

## Considered Options

### Option 1: Debounced (1500ms) Serialized Sync Queue with In-Flight Lock & Pending Flag (Chosen)
- **Description**: `GoogleDriveService.syncDailyRecordsToDriveInBackground()` debounces calls with a default 1500 ms timer. When fired, it checks an in-flight lock (`_inFlightDailyRecordSync`). If active, it flags `_pendingDailyRecordSyncRequested = true`. Upon completion, the `finally` block executes a follow-up sync if pending changes were recorded.
- **Pros**:
  - Automatically collapses rapid-fire set edits into a single Drive upload.
  - Strict serialization prevents any concurrent write collisions or sheet byte corruption.
  - Transparent state tracking via `syncStateNotifier` (`SyncState.syncing`, `SyncState.synced`, `SyncState.error`).
- **Cons**:
  - Introduces a 1.5-second buffer before changes hit Google Drive.

### Option 2: Unthrottled Immediate Uploads
- **Description**: Trigger a separate HTTP multipart upload to Google Drive on every set mutation.
- **Pros**: Immediate cloud initiation.
- **Cons**: High likelihood of race conditions, overwritten records, HTTP 429 throttling, and excessive battery usage.

### Option 3: Manual Sync Only
- **Description**: Only sync when user explicitly taps a "Sync to Drive" button.
- **Pros**: Complete determinism.
- **Cons**: High risk of user forgetting to sync before closing the app.

---

## Decision Outcome
**Chosen Option**: **Option 1: Debounced (1500ms) Serialized Sync Queue**

### Justification
Option 1 offers the ideal balance: the UI saves to local cache instantly, the 1500 ms debounce collapses rapid inputs into a single upload, and the serialization lock (`_inFlightDailyRecordSync` + `_pendingDailyRecordSyncRequested`) guarantees that all data reaches Google Drive in valid sequence without conflicts.

---

## Consequences

### Positive Consequences
- Multiple rapid set additions (e.g. 3 sets logged in 10 seconds) execute as a single clean Drive upload.
- Concurrency race conditions against Google Drive spreadsheets are eliminated.
- Clear UI observability: users see a compact sync indicator reflecting syncing, synced, or error states.

### Negative Consequences / Trade-offs & Mitigations
- **Debounce Latency in Automated Tests**: 1500 ms debounce would slow down unit tests.
  - **Mitigation**: `syncDailyRecordsToDriveInBackground` accepts an optional `debounce` parameter (e.g. `Duration(milliseconds: 50)` in tests or `Duration.zero` for immediate execution), and provides `cancelPendingSync()`.

---

## Source Code & Test Traceability
- **Implementation Core**: [`google_drive_service.dart:L666–715: `syncDailyRecordsToDriveInBackground`-`_executeSerializedDailyRecordSync`-`_performDailyRecordSync``](file:///Users/devashishraut/StudioProjects/workout_tracker/lib/data/services/google_drive_service.dart#L666-L715)
- **State Notifier**: [`google_drive_service.dart`](file:///Users/devashishraut/StudioProjects/workout_tracker/lib/data/services/google_drive_service.dart)
- **Automated Regression Test**:
  - [`features_and_optimizations_test.dart:L233–247-test name: `'syncDailyRecordsToDriveInBackground debounces rapid invocations into single execution'``](file:///Users/devashishraut/StudioProjects/workout_tracker/test/features_and_optimizations_test.dart#L233-L247)
