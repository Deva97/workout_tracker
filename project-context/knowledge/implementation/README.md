# Implementation Decisions Knowledge Catalog (IDRs)

## 1. Overview & Purpose
The **Implementation Decisions** category contains Implementation Decision Records (IDRs). Unlike broad system-level ADRs, IDRs capture localized, tactical engineering choices made within specific modules, widgets, or services. They document non-obvious algorithms, performance trade-offs, and component-level patterns that prevent regression during localized refactoring.

Every implementation decision persisted in this directory must pass the **Implementation Decision Litmus Test**:
> *"Does this document a localized, tactical algorithm, data structure, or module-level design pattern that is bounded within a single feature or subsystem?"*

---

## 2. Naming & Identification Standards
- **File Naming Pattern**: `idr-<topic-slug>.md` (e.g. `idr-single-pass-statistics.md`)
- **Identifier Prefix**: `IDR-XXX` (sequential 3-digit zero-padded number, e.g. `IDR-001`)
- **Document Template**: Standardized schema defined in [Implementation Decision Template](../../../.agents/skills/project-context-memory/templates/implementation-decision.md)

---

## 3. Active Implementation Decisions Catalog

| ID | File | Title | Module | Status |
|:---:|:---|:---|:---|:---:|
| *Pending* | *None currently registered* | *New IDRs will be cataloged here upon creation* | — | — |

> *Note*: Future module-level decisions (e.g. single-pass statistics aggregation algorithms, custom chart painters, or local storage serialization strategies) should be documented here as development progresses.

---

## 4. Contributing & Modifying Implementation Decisions
1. **Identify Tactical Scope**: Ensure the decision applies to a specific module or component rather than repository-wide architecture (which belongs in `decisions/`).
2. **Document Problem & Strategy**: Clearly describe the localized problem, why the specific algorithm or data structure was selected, and any discarded tactical alternatives.
3. **Link Source Code & Tests**: Cite the exact file paths in `lib/` and unit test assertions in `test/`.
4. **Scaffold**: Copy `.agents/skills/project-context-memory/templates/implementation-decision.md` to `project-context/knowledge/implementation/idr-<slug>.md`.
5. **Register**: Add the new record to the catalog table above and update `project-context/index.md`.
6. **Maintenance**: Mark as `Superseded by IDR-XXX` if replaced by an updated implementation pattern.
