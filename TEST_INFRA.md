# Test Infrastructure: Antigravity Persistent Project-Context Memory System

## 1. Test Philosophy

### 1.1 Opaque-Box & Requirement-Driven
The testing strategy for the Antigravity Persistent Project-Context Memory System is strictly **opaque-box** and **requirement-driven**. The test harness treats the implementation as a system under test defined exclusively by the requirements in `ORIGINAL_REQUEST.md`, `PROJECT.md`, and established repository truth:
- **Zero Coupling to Internal Implementation Details**: Tests evaluate observable filesystem artifacts, valid syntax schemas, verifiable cross-file hyperlinks, invariant text adherence, and external tool exits (`flutter analyze`, `flutter test`).
- **Progressive Testability**: The test runner is structured into modular tiers (Tiers 1–4) allowing incremental verification across implementation milestones (M1–M4).
- **Authoritative Output Derivation**: Ground truth for code citations, business rules, split limits, calendar boundaries, 1RM formulas, and caching behavior is derived directly from live application code in `lib/` and passing regression tests in `test/`.

### 1.2 Non-Interference & Safety
- **Zero Production Mutation**: The test harness enforces that no code in `lib/` or `test/` is modified, deleted, or corrupted.
- **Zero Profile Mutation**: The harness verifies that all 15 pre-existing scanner profiles under `project-context/profiles/` remain 100% intact and unmutated.
- **Zero Secrets Guarantee**: Exhaustive regex scanning verifies that no credentials, tokens, OAuth client secrets, or private keys are written to persistent memory files.

---

## 2. Feature Inventory & Tier Mapping

| Feature # | Feature Name | Requirement | Validation Tier | Test Scope |
|:---:|:---|:---:|:---:|:---|
| 1 | Always-On Memory Rule | R1 | Tier 1, Tier 2, Tier 3 | `.agents/rules/project-context-memory.md` existence, line budget (<50 lines), Invariants 1–7 presence, skill name match |
| 2 | Skill Definition (`SKILL.md`) | R2 | Tier 1, Tier 2, Tier 3 | `.agents/skills/project-context-memory/SKILL.md` existence, YAML frontmatter, `/project-context-memory` trigger, 8-stage lifecycle |
| 3 | Reference Guides (4 files) | R2 | Tier 1, Tier 3 | `references/knowledge-model.md`, `classification-rules.md`, `update-policy.md`, `workflow.md` existence and outbound links |
| 4 | Markdown Templates (5 files) | R2 | Tier 1, Tier 3 | `templates/business-rule.md`, `convention.md`, `architecture-decision.md`, `implementation-decision.md`, `domain-knowledge.md` existence and placeholders |
| 5 | Progressive Disclosure Index | R3 | Tier 1, Tier 3 | `project-context/index.md` existence, links to architecture, foundation docs, 5 categories, and all 15 profiles |
| 6 | Repository Memory Guide | R3 | Tier 1, Tier 3 | `project-context/README.md` existence, human & agent usage sections, navigation guide |
| 7 | Architectural Overview Map | R3 | Tier 1, Tier 3, Tier 4 | `project-context/architecture/overview.md` existence, Clean Architecture 3-layer mapping, ExcelORM and caching links |
| 8 | Category Directories & READMEs | R3 | Tier 1, Tier 3 | 5 subdirectories and `README.md` catalogs under `project-context/knowledge/` |
| 9 | Preserved Scanner Profiles | R4 | Tier 1, Tier 2, Tier 3 | All 15 files in `project-context/profiles/` preserved intact, indexed in `index.md` |
| 10 | Foundation Document Links | R4 | Tier 3 | Root `AGENTS.md` and `PROJECT_CONTEXT.md` referenced as authoritative foundation |
| 11 | Split Limits Rule (BR-001) | R5 | Tier 1, Tier 4 | `br-workout-split-limits.md` existence, citation of `workout_split.dart:56` & `widget_test.dart:102` |
| 12 | Calendar Boundaries Rule (BR-002) | R5 | Tier 1, Tier 4 | `br-calendar-week-boundaries.md` existence, citation of `weekly_activity_view_model.dart:40` & `weekly_activity_test.dart:31` |
| 13 | 1RM & PR Rule (BR-003) | R5 | Tier 1, Tier 4 | `br-estimated-1rm-pr-calculation.md` existence, citation of `get_exercise_statistics_use_case.dart:78` & `todays_workout_log_test.dart:270` |
| 14 | Clean Architecture Convention (CONV-001) | R5 | Tier 1, Tier 4 | `conv-clean-architecture-layers.md` existence, citation of `AGENTS.md:7` & `todays_workout_log_test.dart:14` |
| 15 | MVVM & Cache-First Convention (CONV-002) | R5 | Tier 1, Tier 4 | `conv-mvvm-changenotifier.md` existence, citation of `todays_workout_log_view_model.dart:76` & `todays_workout_log_test.dart:309` |
| 16 | Sandbox Bypass Convention (CONV-003) | R5 | Tier 1, Tier 4 | `conv-flutter-tooling-sandbox-bypass.md` existence, documentation of macOS Homebrew cache stamp behavior |
| 17 | ExcelORM Persistence ADR (ADR-001) | R5 | Tier 1, Tier 4 | `adr-excel-orm-drive-persistence.md` existence, citation of `excel_context.dart` & `excel_orm_test.dart:152` |
| 18 | Cache-First Storage ADR (ADR-002) | R5 | Tier 1, Tier 4 | `adr-cache-first-local-storage.md` existence, citation of `local_storage_service.dart` & `widget_test.dart:123` |
| 19 | Debounced Sync Queue ADR (ADR-003) | R5 | Tier 1, Tier 4 | `adr-debounced-background-sync.md` existence, citation of `google_drive_service.dart:666` & `features_and_optimizations_test.dart:233` |
| 20 | Splits & Logging Domain (DOM-001) | R5 | Tier 1, Tier 4 | `dom-workout-splits-and-logging.md` existence, domain model citations |
| 21 | Zero Secrets & Data Leaks | Safety | Tier 2 | Regex audit against API keys, OAuth secrets, private keys, bearer tokens |
| 22 | Zero Unintended Code Modifications | Safety | Tier 2 | Verifies `git status` clean of new changes on `lib/` and `test/` |
| 23 | Static Analysis Quality Gate | Quality | Tier 4 | `flutter analyze` exit code 0, 0 issues found |
| 24 | Regression Test Quality Gate | Quality | Tier 4 | `flutter test` exit code 0, all 55 tests pass |

---

## 3. Tiered Test Architecture

```
+-------------------------------------------------------------------------------+
|                       AUTOMATED VALIDATION RUNNER                             |
|                 (tool/verify_project_context_memory.sh)                       |
+-------------------------------------------------------------------------------+
       |                     |                     |                     |
       v                     v                     v                     v
+--------------+      +--------------+      +--------------+      +--------------+
|    TIER 1    |      |    TIER 2    |      |    TIER 3    |      |    TIER 4    |
|   Feature    |      |  Boundary &  |      |Cross-Feature |      | Real-World   |
|   Coverage   |      | Corner Cases |      | Combinations |      |  Grounding   |
+--------------+      +--------------+      +--------------+      +--------------+
| * 29 Target  |      | * YAML Front-|      | * index.md   |      | * Source line|
|   Files      |      |   matter     |      |   Link Health|      |   citations  |
| * 15 Profiles|      | * Invariants |      | * Category   |      | * Test line  |
| * 5 Checks / |      |   1-7 check  |      |   Link Health|      |   citations  |
|   Feature    |      | * Profile    |      | * Template   |      | * flutter    |
| * Directory  |      |   Preserve   |      |   Cross-Links|      |   analyze = 0|
|   Hierarchy  |      | * 0 Secrets  |      | * Rule Skill |      | * flutter    |
| * Minimum    |      | * 0 Code     |      |   Binding    |      |   test = 0   |
|   Sizes      |      |   Mutation   |      |              |      |              |
+--------------+      +--------------+      +--------------+      +--------------+
```

### 3.1 Tier 1: Feature Coverage (Existence & Structural Integrity)
- **Target File Universe (29 Files)**:
  - 1 Rule: `.agents/rules/project-context-memory.md`
  - 1 Skill: `.agents/skills/project-context-memory/SKILL.md`
  - 4 References: `references/{knowledge-model,classification-rules,update-policy,workflow}.md`
  - 5 Templates: `templates/{business-rule,convention,architecture-decision,implementation-decision,domain-knowledge}.md`
  - 3 Root Knowledge Files: `project-context/{index.md,README.md,architecture/overview.md}`
  - 5 Category Catalogs: `project-context/knowledge/{business-rules,conventions,decisions,implementation,domain}/README.md`
  - 10 Bootstrap Documents: 3 `br-*.md`, 3 `conv-*.md`, 3 `adr-*.md`, 1 `dom-*.md`
- **Scanner Profile Universe (15 Files)**:
  - `project-context/profiles/{01-architecture,02-navigation,03-state,04-testing,05-security,06-performance,07-error-handling,08-typescript,09-component-design,10-accessibility,11-linting-formatting,12-pitfalls,13-build-tools,14-observability,15-offline-architecture}.md`
- **Minimum Criteria**: Every target file must exist, be a regular file, and possess non-zero byte size.

### 3.2 Tier 2: Boundary & Corner Cases (Format, Safety & Invariants)
- **YAML Frontmatter Integrity**:
  - `SKILL.md` begins and ends with `---`.
  - Parses `name: project-context-memory`.
  - Parses `description:` mentioning `/project-context-memory`.
- **Rule Conciseness & Invariants**:
  - Line count under 50 lines to prevent agent context degradation.
  - Contains all 7 numbered invariants verbatim or semantically.
- **Profile Preservation**:
  - All 15 files exist and retain original titles (`Profile 01: ...` through `Profile 15: ...`).
  - No profiles deleted or added.
  - `08-typescript.md` preserved with title `# Profile 08: Language & Type System`.
- **Zero Secrets & Credentials Audit**:
  - Automated regex scan across all files in `.agents/` and `project-context/` for:
    - Google API Keys (`AIza[0-9A-Za-z-_]{35}`)
    - OpenAI / Generic API Keys (`sk-[a-zA-Z0-9]{20,}`)
    - Private Keys (`BEGIN [A-Z ]*PRIVATE KEY`)
    - Passwords and Tokens (`(bearer|token|secret|password)\s*[:=]\s*["'][^"']{8,}["']`)
  - Fails if any secret pattern matches.
- **Zero Production Mutation**:
  - Confirms no new untracked or modified files were introduced into `lib/` or `test/`.

### 3.3 Tier 3: Cross-Feature Combinations (Link Health & Interoperability)
- **Root Index (`index.md`) Link Health**:
  - Extracts all Markdown links `[text](target)`.
  - Resolves target paths relative to `project-context/`.
  - Verifies target file exists on disk.
  - Confirms all 15 profiles in `profiles/` are linked.
  - Confirms root `AGENTS.md` and `PROJECT_CONTEXT.md` are linked.
  - Confirms all 5 knowledge category directories are linked.
- **Category READMEs Link Health**:
  - Extracts all Markdown links from each category `README.md`.
  - Verifies target document exists on disk.
- **Skill References & Templates Interlinking**:
  - Verifies `SKILL.md` links to all 4 references and all 5 templates.
  - Verifies Invariant 2 in `.agents/rules/project-context-memory.md` references the exact skill name `project-context-memory`.

### 3.4 Tier 4: Real-World Scenarios (Code Grounding & Regression Gates)
- **Source Code Citation Validity**:
  - Extracts every `lib/...` citation across bootstrap documents.
  - Verifies file existence in `lib/`.
  - Verifies referenced line numbers exist and match declared concepts.
- **Test Code Citation Validity**:
  - Extracts every `test/...` citation across bootstrap documents.
  - Verifies file existence in `test/`.
  - Verifies referenced test case names exist in the test file.
- **Static Analysis Gate**:
  - Executes `flutter analyze` (with macOS `BypassSandbox: true` requirement documented).
  - Asserts exit code 0 (`No issues found!`).
- **Regression Test Suite Gate**:
  - Executes `flutter test`.
  - Asserts exit code 0 (all 55 unit and widget tests pass).

---

## 4. Test Runner Invocation & Usage

### 4.1 Invocation Commands

The test runner is located at `tool/verify_project_context_memory.sh` and is executable.

```bash
# Run all validation tiers (default)
./tool/verify_project_context_memory.sh

# Run specific tier
./tool/verify_project_context_memory.sh --tier 1
./tool/verify_project_context_memory.sh --tier 2
./tool/verify_project_context_memory.sh --tier 3
./tool/verify_project_context_memory.sh --tier 4

# Run structural checks without executing Flutter test suite (fast loop)
./tool/verify_project_context_memory.sh --skip-flutter

# Run with verbose diagnostic logging
./tool/verify_project_context_memory.sh --verbose

# Display help and usage
./tool/verify_project_context_memory.sh --help
```

### 4.2 Sandboxing Note for AI Agents
When executing Flutter commands (`flutter analyze`, `flutter test`) via agent tooling on macOS, Flutter attempts to write cache stamps into Homebrew directories (`/opt/homebrew/share/flutter/bin/cache/`). Agents must specify `BypassSandbox: true` in `run_command` invocations.

### 4.3 Exit Codes
- `0`: All executed checks passed successfully.
- `1`: One or more validation checks failed.
