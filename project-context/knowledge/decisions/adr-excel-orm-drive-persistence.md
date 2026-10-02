# Architecture Decision Record: Custom ExcelORM for Google Drive Tabular Persistence

## Metadata
| Field | Value |
|---|---|
| **ID** | `ADR-001` |
| **Title** | Custom ExcelORM for Google Drive Tabular Persistence |
| **Status** | `Accepted` |
| **Date** | 2026-10-02 |
| **Deciders** | Architecture Council / Engineering Team |
| **Consulted** | Core Contributors / Specification Survey |

---

## Context & Problem Statement
Gym trainees accumulating years of workout history require permanent data ownership without risk of proprietary cloud vendor lock-in. Traditional backend architectures (e.g. Firebase Firestore, AWS DynamoDB, Supabase) silo fitness data inside remote databases. If service tiers change or the app server is decommissioned, user logs are lost. The architecture required a cloud persistence mechanism that stores data directly inside the user's personal Google Drive in an open, universally auditable spreadsheet format that trainees can open directly in Google Sheets, Microsoft Excel, or Apple Numbers.

---

## Decision Drivers
- **Driver 1 (User Data Sovereignty & BYOS)**: Bring-Your-Own-Storage model storing records exclusively in the user's private Google Drive under a dedicated `'Workout Tracker'` folder.
- **Driver 2 (Human Auditability & Spreadsheet Portability)**: Open `.xlsx` tabular file format allowing direct inspection, pivot table analysis, and external CSV/Excel exports.
- **Driver 3 (Reflection-Free Runtime Performance)**: Dart compile-time type safety requiring reflection-free entity mapping to comply with Flutter Ahead-Of-Time (AOT) compilation across iOS, Android, and web.

---

## Considered Options

### Option 1: Custom Reflection-Free ExcelORM Engine over Google Drive Spreadsheets (Chosen)
- **Description**: Lightweight custom ORM layer in `lib/data/orm/` that converts domain models to and from `.xlsx` byte streams, persisting to two master Drive spreadsheets: `Exercise_DB.xlsx` (exercises) and `Daily_record.xlsx` (logged sets).
- **Pros**:
  - Zero recurring cloud hosting or backend database costs.
  - Complete user transparency: trainees can open files in Google Drive anytime.
  - Zero reflection overhead, fully compatible with Flutter AOT.
- **Cons**:
  - Binary spreadsheet encoding/decoding must be managed in-process.
  - Requires in-memory relational indexing and two-tier caching to avoid network round-trip latency.

### Option 2: Cloud Firestore / Supabase Backend
- **Description**: Standard cloud SQL or NoSQL database with client authentication.
- **Pros**:
  - Native real-time listeners and row-level updates.
- **Cons**:
  - Ongoing infrastructure expenses.
  - Traps user data in closed databases requiring custom export tools.

---

## Decision Outcome
**Chosen Option**: **Option 1: Custom Reflection-Free ExcelORM Engine over Google Drive Spreadsheets**

### Justification
Option 1 fundamentally aligns with the core product philosophy of user privacy and lifetime data portability. By implementing `WorkoutDbContext` on top of `ExcelContext`, the application provides robust relational entity mapping (`Exercise.excelMapper`, `DailyRecord.excelMapper`) without sacrificing Flutter performance.

---

## Consequences

### Positive Consequences
- Trainees retain 100% control over their fitness data inside Google Drive.
- The app operates serverlessly with zero backend maintenance overhead.
- Spreadsheet files can be inspected and edited externally in Excel or Google Sheets.

### Negative Consequences / Trade-offs & Mitigations
- **Full File Rewrites**: Updating records requires rewriting spreadsheet byte streams rather than row-level delta mutations.
  - **Mitigation**: Implemented backward date-bounded loading (`loadRecentDailyRecords`) and debounced background write queues (`GoogleDriveService.syncDailyRecordsToDriveInBackground`).
- **Relational Query Overhead**: Spreadsheets do not provide native foreign key indexing.
  - **Mitigation**: `WorkoutDbContext` indexes exercise GUIDs in-memory for instant relational lookups.

---

## Source Code & Test Traceability
- **Implementation Core**: `lib/data/orm/excel_context.dart`, `lib/data/orm/entity_mapper.dart`, `lib/data/orm/excel_query.dart`
- **Context / ORM Wiring**: `lib/data/context/workout_db_context.dart` (Lines 8–188) and `lib/data/services/google_drive_service.dart`
- **Automated Regression Test**:
  - `test/excel_orm_test.dart` (Lines 152–183, test name: `'Daily_record.xlsx roundtrip encoding and decoding preserves typed fields'`)
  - `test/excel_orm_test.dart` (Lines 185–226, test name: `'recent daily rows load backwards and stop before the date boundary'`)
