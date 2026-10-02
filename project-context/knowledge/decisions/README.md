# Architecture Decisions Knowledge Catalog (ADRs)

## 1. Overview & Purpose
The **Decisions** category contains Architecture Decision Records (ADRs) documenting high-impact, repository-wide architectural and technical choices. ADRs record the context, considered alternatives, decision outcomes, and consequences of strategic technical directions.

Every decision persisted in this directory must pass the **Architecture Decision Litmus Test**:
> *"Does this represent a high-impact, system-wide design choice regarding persistence, state architecture, security, or external integration that would be costly to reverse?"*

---

## 2. Naming & Identification Standards
- **File Naming Pattern**: `adr-<topic-slug>.md` (e.g. `adr-excel-orm-drive-persistence.md`)
- **Identifier Prefix**: `ADR-XXX` (sequential 3-digit zero-padded number, e.g. `ADR-001`)
- **Document Template**: Standardized schema defined in [Architecture Decision Template](../../../.agents/skills/project-context-memory/templates/architecture-decision.md)

---

## 3. Active Architecture Decisions Catalog

| ID | File | Title | Date | Status | Affected Layers |
|:---:|:---|:---|:---:|:---:|:---|
| **ADR-001** | [`adr-excel-orm-drive-persistence.md`](adr-excel-orm-drive-persistence.md) | Custom ExcelORM for Google Drive Tabular Persistence | 2026-10-02 | Accepted | Data, ORM, Google Drive |
| **ADR-002** | [`adr-cache-first-local-storage.md`](adr-cache-first-local-storage.md) | Two-Tier Cache-First Local Storage Architecture | 2026-10-02 | Accepted | UI, Data, SharedPreferences |
| **ADR-003** | [`adr-debounced-background-sync.md`](adr-debounced-background-sync.md) | Debounced Serialized Background Drive Synchronization Queue | 2026-10-02 | Accepted | Data, GoogleDriveService |

---

## 4. Contributing & Modifying Architecture Decisions
1. **Context & Motivation**: Document the technical challenge or trade-off that necessitated an architectural choice.
2. **Alternative Evaluation**: Enumerate considered alternatives (e.g., SQLite vs Cloud Firestore vs ExcelORM) along with pros and cons.
3. **Decision Outcome**: Detail the chosen approach with clear justification.
4. **Consequences**: Explicitly articulate both positive outcomes and negative trade-offs or technical debt incurred.
5. **Scaffold**: Copy `.agents/skills/project-context-memory/templates/architecture-decision.md` to `project-context/knowledge/decisions/adr-<slug>.md`.
6. **Register**: Add the record to the catalog table above and update `project-context/index.md`.
7. **Supersession**: If an architectural decision is overturned, change its status to `Superseded by ADR-XXX` and document the migration context. Do not delete the historical record.
