# Project: Antigravity Persistent Project-Context Memory System

## Architecture
- **Layer 1: Rules Layer**: `.agents/rules/project-context-memory.md` (Always-on Antigravity rule declaring the 7 essential invariants).
- **Layer 2: Skills Layer**: `.agents/skills/project-context-memory/` (Skill definition, 8-stage lifecycle, 4 reference guides, 5 markdown templates).
- **Layer 3: Knowledge Repository**: `project-context/` (Progressive disclosure catalog `index.md`, developer guide `README.md`, architecture blueprint `architecture/overview.md`, 5 category catalogs under `knowledge/`, and preserved `profiles/`).
- **Layer 4: Grounded Knowledge**: Bootstrap markdown documents in `knowledge/` with verified line citations to `lib/` and `test/`.
- **Layer 5: Automated Opaque-Box E2E Validation**: Independent test harness verifying structural integrity, link validity, secret exclusion, and clean passes on `flutter analyze` and `flutter test`.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Always-On Memory Rule | Concise rule at `.agents/rules/project-context-memory.md` with Invariants 1–7 | M1 | Survey R1 |
| 2 | Memory Skill Definition | Skill at `.agents/skills/project-context-memory/SKILL.md` with YAML frontmatter, `/project-context-memory` trigger, and 8-stage lifecycle | M1 | Survey R2 |
| 3 | Knowledge Model Reference | Reference guide at `references/knowledge-model.md` defining ontology and authority hierarchy | M1 | Survey R2 |
| 4 | Classification Rules Reference | Reference guide at `references/classification-rules.md` with litmus tests for all categories and ephemeral exclusion | M1 | Survey R2 |
| 5 | Update Policy Reference | Reference guide at `references/update-policy.md` for conflict resolution and zero-silent-overwrite deprecation | M1 | Survey R2 |
| 6 | Memory Workflow Reference | Reference guide at `references/workflow.md` detailing cold-start, retrieval, and persistence workflows | M1 | Survey R2 |
| 7 | Standard Artifact Templates | 5 templates in `templates/` (`business-rule.md`, `convention.md`, `architecture-decision.md`, `implementation-decision.md`, `domain-knowledge.md`) | M1 | Survey R2 |
| 8 | Progressive Disclosure Index | Root catalog at `project-context/index.md` indexing architecture, categories, and 15 profiles | M2 | Survey R3 |
| 9 | Repository Memory Guide | Documentation at `project-context/README.md` for human and agent interaction | M2 | Survey R3 |
| 10 | Architectural Overview Map | System map at `project-context/architecture/overview.md` documenting Clean Architecture, ExcelORM, and 2-tier caching | M2 | Survey R3 |
| 11 | Category Subdirectories & READMEs | 5 subdirectories and READMEs under `project-context/knowledge/` (`business-rules`, `conventions`, `decisions`, `implementation`, `domain`) | M2 | Survey R3 |
| 12 | Profile Preservation & Linking | Preserves all 15 scanner profiles in `project-context/profiles/` and links them from `index.md` | M2 | Survey R4 |
| 13 | Foundation Document Integration | Integrates and cross-references root `AGENTS.md` and `PROJECT_CONTEXT.md` as foundational truth | M2 | Survey R4 |
| 14 | Bootstrap: Split Day Limits (BR-001) | Document `br-workout-split-limits.md` citing `workout_split.dart:56` and `widget_test.dart:102` | M3 | Survey R5 |
| 15 | Bootstrap: Mon–Sun Week Boundaries (BR-002) | Document `br-calendar-week-boundaries.md` citing `weekly_activity_view_model.dart:40` and `weekly_activity_test.dart:31` | M3 | Survey R5 |
| 16 | Bootstrap: Estimated 1RM & PR (BR-003) | Document `br-estimated-1rm-pr-calculation.md` citing `get_exercise_statistics_use_case.dart:78` and `todays_workout_log_test.dart:270` | M3 | Survey R5 |
| 17 | Bootstrap: Clean Architecture Layers (CONV-001) | Document `conv-clean-architecture-layers.md` citing `AGENTS.md:7` and `todays_workout_log_test.dart:14` | M3 | Survey R5 |
| 18 | Bootstrap: MVVM & Cache-First (CONV-002) | Document `conv-mvvm-changenotifier.md` citing `todays_workout_log_view_model.dart:76` and `todays_workout_log_test.dart:309` | M3 | Survey R5 |
| 19 | Bootstrap: macOS Sandbox Bypass (CONV-003) | Document `conv-flutter-tooling-sandbox-bypass.md` documenting Flutter CLI cache permissions requirement | M3 | Survey R5 |
| 20 | Bootstrap: ExcelORM Drive Persistence (ADR-001) | Document `adr-excel-orm-drive-persistence.md` citing `excel_context.dart`, `workout_db_context.dart`, `excel_orm_test.dart:152` | M3 | Survey R5 |
| 21 | Bootstrap: Cache-First Local Storage (ADR-002) | Document `adr-cache-first-local-storage.md` citing `local_storage_service.dart`, `widget_test.dart:123` | M3 | Survey R5 |
| 22 | Bootstrap: Debounced Background Sync (ADR-003) | Document `adr-debounced-background-sync.md` citing `google_drive_service.dart:666`, `features_and_optimizations_test.dart:233` | M3 | Survey R5 |
| 23 | Bootstrap: Workout Splits & Logging Domain (DOM-001) | Document `dom-workout-splits-and-logging.md` citing domain models and set logging rules | M3 | Survey R5 |
| 24 | E2E Opaque-Box Validation Suite | Automated test suite verifying all 29 artifacts, link health, YAML validity, code line accuracy, and 0 secrets | M4 / Test Track | Acceptance Criteria |
| 25 | Regression Integrity & Quality Gate | Clean passes on `flutter analyze` (0 issues), `flutter test` (55/55 passed), 0 modifications to `lib/` and `test/` | M4 | Acceptance Criteria |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Rule & Skill Infrastructure (R1, R2) | `.agents/rules/project-context-memory.md`, `.agents/skills/project-context-memory/` (SKILL.md, 4 references, 5 templates) | none | PLANNED |
| M2 | Knowledge Directory Structure & Indexing (R3, R4) | `project-context/` (`index.md`, `README.md`, `architecture/overview.md`, 5 category READMEs, profile preservation & cross-linking) | M1 | PLANNED |
| M3 | Grounded Knowledge Bootstrap (R5) | Initial 10 knowledge documents (3 BR, 3 CONV, 3 ADR, 1 DOM) with source/test citations, catalog updates | M2 | PLANNED |
| M4 | Final E2E Validation & Adversarial Hardening | Execute 100% E2E test suite, adversarial challenger stress-testing, forensic integrity audit | M3, TEST_READY.md | PLANNED |

## Interface Contracts
### Rule ↔ Skill Interface
- `.agents/rules/project-context-memory.md` explicitly delegates governance of memory operations to `.agents/skills/project-context-memory/SKILL.md`.
- Skill name `project-context-memory` matches the name referenced in Invariant 2 of the rule.

### Skill ↔ Repository Knowledge Interface
- Skill documents the 8-stage lifecycle (`DISCOVER → CLASSIFY → RETRIEVE → APPLY → IMPLEMENT → VALIDATE → PERSIST → INDEX`).
- Skill references point to templates in `.agents/skills/project-context-memory/templates/`.
- Newly generated memory documents are stored strictly under `project-context/knowledge/<category>/` using template schemas.
- Category READMEs catalog entries matching `project-context/index.md`.

### Knowledge ↔ Codebase Interface
- Every Business Rule, Convention, and ADR MUST cite real, existing source code file paths and line numbers in `lib/`.
- Every Business Rule, Convention, and ADR MUST cite real, existing test file paths and test descriptions in `test/`.
- No files in `lib/` or `test/` shall be modified.

## Code Layout
- `.agents/rules/project-context-memory.md`: Always-on invariant rule.
- `.agents/skills/project-context-memory/`: Skill definition and supporting references/templates.
- `project-context/`: Knowledge tree.
  - `index.md`: Root progressive disclosure index.
  - `README.md`: Human developer & agent guide.
  - `architecture/overview.md`: Architectural blueprint.
  - `profiles/`: Preserved 15 scanner profiles (untouched).
  - `knowledge/`:
    - `business-rules/`: `README.md`, `br-*.md`
    - `conventions/`: `README.md`, `conv-*.md`
    - `decisions/`: `README.md`, `adr-*.md`
    - `implementation/`: `README.md`, `idr-*.md`
    - `domain/`: `README.md`, `dom-*.md`
