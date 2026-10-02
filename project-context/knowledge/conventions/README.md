# Conventions Knowledge Catalog

## 1. Overview & Purpose
The **Conventions** category records established coding patterns, architectural standards, UI construction rules, and platform tooling workarounds applied across the repository. Conventions ensure codebase uniformity, maintainability, and predictable developer workflows.

Every convention persisted in this directory must pass the **Convention Litmus Test**:
> *"Does this dictate how code, tests, UI components, or developer tooling must be structured, implemented, or executed?"*

---

## 2. Naming & Identification Standards
- **File Naming Pattern**: `conv-<topic-slug>.md` (e.g. `conv-clean-architecture-layers.md`)
- **Identifier Prefix**: `CONV-XXX` (sequential 3-digit zero-padded number, e.g. `CONV-001`)
- **Document Template**: Standardized schema defined in [Convention Template](../../../.agents/skills/project-context-memory/templates/convention.md)

---

## 3. Active Conventions Catalog

| ID | File | Convention Title | Scope | Enforcing Mechanism | Status |
|:---:|:---|:---|:---:|:---|:---:|
| **CONV-001** | [`conv-clean-architecture-layers.md`](conv-clean-architecture-layers.md) | 3-Layer Clean Architecture & Dependency Direction | Architecture | Root `AGENTS.md:7-13`, `test/todays_workout_log_test.dart:14-25` | Active |
| **CONV-002** | [`conv-mvvm-changenotifier.md`](conv-mvvm-changenotifier.md) | MVVM Presentation with ChangeNotifier & Cache-First Rendering | UI / State | `lib/ui/features/workout_log/view_models/todays_workout_log_view_model.dart:76-116`, `test/todays_workout_log_test.dart:309-360` | Active |
| **CONV-003** | [`conv-flutter-tooling-sandbox-bypass.md`](conv-flutter-tooling-sandbox-bypass.md) | Mandatory BypassSandbox for Flutter Tooling on macOS | Tooling / Env | macOS Homebrew cache permissions; subagent `BypassSandbox: true` flag | Active |

---

## 4. Contributing & Modifying Conventions
1. **Discover**: Identify recurring design patterns, architectural consensus, or tooling requirements.
2. **Verify Pattern Consistency**: Ensure the convention is genuinely supported by current codebase structure and verified by existing tests or CLI commands.
3. **Check for Duplicates**: Search this catalog to prevent conflicting or overlapping conventions.
4. **Scaffold**: Copy `.agents/skills/project-context-memory/templates/convention.md` to `project-context/knowledge/conventions/conv-<slug>.md`.
5. **Populate**: Include Do vs Don't code examples, rationale, and enforcing files or tests.
6. **Register**: Add the new convention entry to the catalog table above and update `project-context/index.md`.
7. **Deprecation**: If a convention is replaced by a newer standard, transition its status to `Deprecated` or `Superseded by CONV-XXX` with an explicit migration note.
