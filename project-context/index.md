# Project Context Memory Index

Welcome to the root progressive disclosure index of the **Workout Tracker** repository. This catalog serves as the primary navigation hub for AI agents and human engineers during session initialization and task execution.

---

## 1. Progressive Disclosure Quick-Map

Agents should consult this quick-map to retrieve targeted knowledge without ingesting unnecessary context:

```
Task Need                                           Target Location
────────────────────────────────────────────────────────────────────────────────────────
System Rules & Agent Invariants                     ../AGENTS.md & ../.agents/rules/project-context-memory.md
System Architecture & Clean Layers                  architecture/overview.md
Split Limits, Week Bounds, 1RM Calculations         knowledge/business-rules/README.md
Coding Patterns, MVVM, Sandbox Workarounds          knowledge/conventions/README.md
ExcelORM, Drive Sync, Local Storage Strategy        knowledge/decisions/README.md
Module-Level Tactical Algorithms                    knowledge/implementation/README.md
Gym Concepts, Sets, Reps, RIR Semantics             knowledge/domain/README.md
Deep Codebase Scan Reports                          profiles/ (Table in §5 below)
Governance, Lifecycle & Memory Slash Commands       README.md & ../.agents/skills/project-context-memory/SKILL.md
```

---

## 2. Authoritative Root Foundation

The root repository documentation provides foundational invariants that take precedence across all agent sessions:

- [`AGENTS.md`](../AGENTS.md): Primary AI developer guidelines, 3-Layer Clean Architecture rules, Google Drive sync rules, and test verification standards.
- [`PROJECT_CONTEXT.md`](../PROJECT_CONTEXT.md): Exhaustive technical specification covering ExcelORM schemas (`Exercise_DB.xlsx`, `Daily_record.xlsx`), SharedPreferences cache keys, and view hierarchy.

---

## 3. System Architecture

Detailed architectural specifications and component mapping are documented in:

- [`architecture/overview.md`](architecture/overview.md): Comprehensive architectural blueprint covering:
  - **3-Layer Clean Architecture**: Domain (`lib/domain/`), Data (`lib/data/`), and UI (`lib/ui/`).
  - **Custom ExcelORM Engine**: Reflection-free streaming persistence over Google Drive spreadsheets.
  - **Two-Tier Caching**: Instant (0ms) `SharedPreferences` cache coupled with 1500ms debounced, serialized background Drive sync.
  - **Entry Points Map**: Key class and service file index across `lib/`.

---

## 4. Knowledge Base Categories

| Category | Directory / Catalog | Focus & Active Topics |
|---|---|---|
| **Business Rules** | [`knowledge/business-rules/`](knowledge/business-rules/README.md) | Invariant logic: Split limits (`BR-001`), Mon–Sun week boundaries (`BR-002`), Epley 1RM formula (`BR-003`). |
| **Conventions** | [`knowledge/conventions/`](knowledge/conventions/README.md) | Engineering standards: Clean Architecture (`CONV-001`), MVVM & Cache-First (`CONV-002`), macOS Sandbox Bypass (`CONV-003`). |
| **Architecture Decisions** | [`knowledge/decisions/`](knowledge/decisions/README.md) | System-level ADRs: ExcelORM persistence (`ADR-001`), Two-tier cache (`ADR-002`), Debounced background sync (`ADR-003`). |
| **Implementation Decisions** | [`knowledge/implementation/`](knowledge/implementation/README.md) | Tactical IDRs: Module-level algorithm trade-offs and component patterns. |
| **Domain Knowledge** | [`knowledge/domain/`](knowledge/domain/README.md) | Domain models: Gym splits, set metrics, reps, and RIR scale (`DOM-001`). |

---

## 5. Automated Scanner Profiles Index

All 15 scanner profiles under [`profiles/`](profiles/) are preserved intact and provide detailed codebase scans across key engineering dimensions:

| Profile # | Profile Document | Topic & Focus Area |
|:---:|:---|:---|
| 01 | [`profiles/01-architecture.md`](profiles/01-architecture.md) | Clean Architecture layers, MVVM with ChangeNotifier, custom Excel ORM. |
| 02 | [`profiles/02-navigation.md`](profiles/02-navigation.md) | Imperative Flutter Navigator push/pop and MaterialPageRoute flows. |
| 03 | [`profiles/03-state.md`](profiles/03-state.md) | State management: ChangeNotifier ViewModels, ValueNotifier SyncState. |
| 04 | [`profiles/04-testing.md`](profiles/04-testing.md) | 55 automated tests covering unit, widget, ORM, and feature suites. |
| 05 | [`profiles/05-security.md`](profiles/05-security.md) | Google Sign-In OAuth2 and Bring-Your-Own-Storage privacy model. |
| 06 | [`profiles/06-performance.md`](profiles/06-performance.md) | 1500ms debounced sync, upload serialization, and single-pass metrics. |
| 07 | [`profiles/07-error-handling.md`](profiles/07-error-handling.md) | Drive API fallback, SyncState.error propagation, input validation. |
| 08 | [`profiles/08-typescript.md`](profiles/08-typescript.md) | Language & Type System: Dart null safety and generic type models. |
| 09 | [`profiles/09-component-design.md`](profiles/09-component-design.md) | ModularCard, StatusBadge, and atomic UI component design. |
| 10 | [`profiles/10-accessibility.md`](profiles/10-accessibility.md) | Material 3 accessibility, touch target sizing, and semantics. |
| 11 | [`profiles/11-linting-formatting.md`](profiles/11-linting-formatting.md) | Flutter linter ruleset and analysis options configuration. |
| 12 | [`profiles/12-pitfalls.md`](profiles/12-pitfalls.md) | Technical debt, legacy folder coexistence, and cache purge isolation. |
| 13 | [`profiles/13-build-tools.md`](profiles/13-build-tools.md) | Flutter build toolchain and dependency declarations. |
| 14 | [`profiles/14-observability.md`](profiles/14-observability.md) | Debug logging, console instrumentation, and runtime inspection. |
| 15 | [`profiles/15-offline-architecture.md`](profiles/15-offline-architecture.md) | SharedPreferences offline caching and resilient synchronization. |

---

## 6. Governance & Skill Integration

- **User & Agent Guide**: [`project-context/README.md`](README.md) details navigation, contribution steps, and quality standards.
- **Always-On Antigravity Rule**: [`.agents/rules/project-context-memory.md`](../.agents/rules/project-context-memory.md) defines the 7 essential memory invariants.
- **Agent Skill & Lifecycle**: [`.agents/skills/project-context-memory/SKILL.md`](../.agents/skills/project-context-memory/SKILL.md) governs the 8-stage lifecycle (`DISCOVER → CLASSIFY → RETRIEVE → APPLY → IMPLEMENT → VALIDATE → PERSIST → INDEX`) and `/project-context-memory` slash command.
