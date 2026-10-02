# Domain Knowledge Catalog

## 1. Overview & Purpose
The **Domain Knowledge** category records fitness industry, exercise science, and gym domain models that underpin the application. These documents define the conceptual language, metrics, anatomical mappings, and terminology used by strength athletes and fitness enthusiasts, bridging real-world training principles with software domain models.

Every domain entry persisted in this directory must pass the **Domain Knowledge Litmus Test**:
> *"Does this define a real-world fitness, gym, sports-science, or strength-training concept, independent of software implementation details?"*

---

## 2. Naming & Identification Standards
- **File Naming Pattern**: `dom-<topic-slug>.md` (e.g. `dom-workout-splits-and-logging.md`)
- **Identifier Prefix**: `DOM-XXX` (sequential 3-digit zero-padded number, e.g. `DOM-001`)
- **Document Template**: Standardized schema defined in [Domain Knowledge Template](../../../.agents/skills/project-context-memory/templates/domain-knowledge.md)

---

## 3. Active Domain Knowledge Catalog

| ID | File | Concept Name | Entity Mapping | Status |
|:---:|:---|:---|:---|:---:|
| **DOM-001** | [`dom-workout-splits-and-logging.md`](dom-workout-splits-and-logging.md) | Gym Workout Splits, Sets, Reps, and RIR Domain Model | `lib/domain/models/workout_split.dart`, `daily_record.dart`, `exercise.dart` | Active |

---

## 4. Contributing & Modifying Domain Knowledge
1. **Identify Problem-Domain Concepts**: Document gym terminology, training methodologies, anatomical target definitions, or physiological models.
2. **Define Formal Semantics**: Provide clear definitions, unit standards (e.g. kilograms vs pounds, integer reps, RIR scale 0–10), and exercise taxonomy.
3. **Map to Domain Entities**: Cross-reference the conceptual models with Dart classes in `lib/domain/models/`.
4. **Scaffold**: Copy `.agents/skills/project-context-memory/templates/domain-knowledge.md` to `project-context/knowledge/domain/dom-<slug>.md`.
5. **Register**: Add the new record to the catalog table above and update `project-context/index.md`.
6. **Maintenance**: Update when domain concepts evolve or new training modalities are introduced.
