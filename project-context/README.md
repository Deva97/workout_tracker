# Project Context Memory System

Welcome to the **Project Context Memory System** for the Workout Tracker repository. This system establishes a standardized, repository-backed persistent memory architecture for Google Antigravity AI agents and human software engineers.

---

## 1. Overview & Philosophy

In multi-session software development, manual context re-explanation degrades productivity, introduces cognitive drift, and risks breaking established invariants. The Project Context Memory System eliminates context loss by storing durable, verifiable engineering knowledge directly in the git repository under `project-context/`.

### Core Tenets
1. **Repository-Backed Persistence**: Knowledge lives alongside source code and tests, version-controlled and auditable.
2. **Progressive Disclosure**: Agents navigate via a 3-level hierarchical catalog rather than ingesting bulk documentation, conserving context window tokens.
3. **Code & Test Grounded Truth**: Every persisted rule, convention, or decision is directly cross-referenced with working source code in `lib/` and passing automated tests in `test/`. Assumptions without code/test backing are prohibited.
4. **Zero Ephemeral Noise**: Temporary debugging logs, intermediate task states, and scratch files are strictly excluded from repository memory.

---

## 2. Directory Structure

```
workout_tracker/
├── AGENTS.md                                # Root agent guidelines & architecture quick context
├── PROJECT_CONTEXT.md                       # Comprehensive domain model & architecture specification
├── .agents/
│   ├── rules/
│   │   └── project-context-memory.md        # Always-on Antigravity rule defining the 7 essential invariants
│   └── skills/
│       └── project-context-memory/          # Skill governing the 8-stage memory lifecycle
│           ├── SKILL.md                     # Skill definition and trigger specifications
│           ├── references/                  # Reference guides (knowledge-model, classification, update-policy, workflow)
│           └── templates/                   # Standardized markdown templates (BR, CONV, ADR, IDR, DOM)
└── project-context/
    ├── index.md                             # Central progressive disclosure catalog & quick-map
    ├── README.md                            # System guide for humans and AI agents (this file)
    ├── architecture/
    │   └── overview.md                      # Detailed 3-layer Clean Architecture blueprint
    ├── knowledge/
    │   ├── business-rules/                  # Immutable business rules & calculation formulas (br-*.md)
    │   ├── conventions/                     # Coding patterns, architecture standards & workarounds (conv-*.md)
    │   ├── decisions/                       # Architecture Decision Records (adr-*.md)
    │   ├── implementation/                  # Tactical module-level decisions (idr-*.md)
    │   └── domain/                          # Fitness & gym domain models (dom-*.md)
    └── profiles/                            # Preserved scanner profiles (01 through 15)
```

---

## 3. For Human Developers

### Navigating Repository Knowledge
- **Quick Lookup**: Start at [`project-context/index.md`](index.md) for a high-level index of all architectural topics, categories, and scanner profiles.
- **System Architecture**: Read [`project-context/architecture/overview.md`](architecture/overview.md) to understand the Clean Architecture 3-layer design, ExcelORM persistence, and two-tier caching.
- **Specific Rules & Decisions**: Browse the dedicated category READMEs under `project-context/knowledge/` to find active rules, conventions, or ADRs.

### Contributing & Updating Knowledge
1. **Adding a New Record**: Select the appropriate template from `.agents/skills/project-context-memory/templates/` (`business-rule.md`, `convention.md`, `architecture-decision.md`, etc.).
2. **Ground in Source Code**: Always cite concrete file paths and line numbers in `lib/` and corresponding regression tests in `test/`.
3. **Update Category Index**: Add your new document to the catalog table in the corresponding category `README.md` and link it in `project-context/index.md`.
4. **Deprecating Existing Records**: Never delete active documents silently. Update the record's status to `Deprecated` or `Superseded by <ID>` and include rationale.

---

## 4. For AI Agents

### Progressive Disclosure Protocol
To conserve context tokens and maintain high reasoning precision, AI agents must adhere to the 3-level progressive disclosure protocol:

```
Level 1: Entry Point ────────► project-context/index.md (~50-100 lines)
                               Identify relevant knowledge category or scanner profile
                                      │
                                      ▼
Level 2: Category Catalog ───► project-context/knowledge/<category>/README.md
                               Scan table of records to select exact document ID
                                      │
                                      ▼
Level 3: Deep Document ──────► project-context/knowledge/<category>/<prefix>-<slug>.md
                               Retrieve only the specific targeted document
```
> **Rule**: Never ingest all files in `project-context/` bulk-wise. Retrieve only the files necessary for the active task.

### The 8-Stage Memory Lifecycle
Memory operations follow the systematic lifecycle defined in `.agents/skills/project-context-memory/SKILL.md`:
```
DISCOVER ──► CLASSIFY ──► RETRIEVE ──► APPLY ──► IMPLEMENT ──► VALIDATE ──► PERSIST ──► INDEX
```
1. **DISCOVER**: Identify candidate invariants, formulas, or patterns during tasks.
2. **CLASSIFY**: Apply litmus tests from `classification-rules.md` (BR, CONV, ADR, IDR, DOM, or discard Ephemeral).
3. **RETRIEVE**: Check existing category READMEs and `index.md` to prevent duplicate or conflicting records.
4. **APPLY**: Factor retrieved invariants into task plans and architecture decisions.
5. **IMPLEMENT**: Write code strictly complying with retrieved invariants.
6. **VALIDATE**: Run `flutter analyze` and `flutter test` with `BypassSandbox: true` to confirm zero regressions.
7. **PERSIST**: Author the memory document using the appropriate template from `templates/`.
8. **INDEX**: Register the new file in the category `README.md` and root `index.md`.

### Slash Command Usage (`/project-context-memory`)
- `/project-context-memory`: Check memory status or retrieve relevant project rules.
- `/project-context-memory --init`: Session cold start; read root `index.md` and category catalogs.
- `/project-context-memory --query <topic>`: Retrieve knowledge matching `<topic>` (e.g. `workout-splits`, `excel-orm`).
- `/project-context-memory --persist <type>`: Scaffold and commit a new memory document using templates.
- `/project-context-memory --verify`: Audit active memory records against source code and passing test suites.

### Tooling Execution Requirement
When running Flutter CLI tools (`flutter analyze`, `flutter test`, `flutter pub get`) on macOS, subagents must always set `BypassSandbox: true` due to Homebrew directory engine stamp permissions.

---

## 5. Safety, Integrity & Quality Standards

Every operation on the project context memory system must satisfy five non-negotiable gates:

1. **Zero Secrets Gate**: Never store API keys, OAuth tokens, client secrets, passwords, or credentials in any memory document.
2. **Code Traceability Gate**: Every persisted Business Rule, Convention, or ADR must cite real, working code in `lib/` and passing tests in `test/`.
3. **Zero Regression Gate**: `flutter analyze` and `flutter test` must pass with 0 issues before persisting new knowledge.
4. **No Silent Deletion Gate**: Existing knowledge documents must not be deleted or replaced silently. Use status transitions (`Superseded by <ID>` or `Deprecated`) with explicit rationale.
5. **No Production Code Tampering Gate**: Memory initialization and documentation updates must never alter application code in `lib/` or tests in `test/`.
