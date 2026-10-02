# Convention: Mandatory BypassSandbox for Flutter Tooling on macOS

## Metadata
| Field | Value |
|---|---|
| **ID** | `CONV-003` |
| **Title** | Mandatory BypassSandbox for Flutter Tooling on macOS |
| **Status** | `Active` |
| **Scope** | `Tooling / Environment` |
| **Last Updated** | 2026-10-02 |
| **Author / Origin** | Engineering Team / Specification R5 |

---

## Convention Statement
AI agents executing Flutter command-line operations (`flutter test`, `flutter analyze`, `flutter pub get`, or build scripts invoking them) on macOS developer environments must execute with the parameter `BypassSandbox: true`.

---

## Rationale & Benefits
- **Homebrew Engine Stamp Permission Isolation**: On macOS systems where the Flutter SDK is installed under Homebrew (`/opt/homebrew/share/flutter/bin/flutter`), the Flutter CLI runs internal pre-flight scripts (specifically `update_engine_version.sh`) that write temporary cache stamps to `/opt/homebrew/share/flutter/bin/cache/engine.stamp.tmp.*`.
- **Sandbox Denial Elimination**: Default sandboxed subagent execution environments restrict file modifications outside the active repository workspace. Executing Flutter commands without sandbox bypass results in immediate failure:
  `Operation not permitted` (exit code 1).
- Setting `BypassSandbox: true` grants necessary system permissions for the Flutter toolchain to validate its engine cache without corrupting or modifying system packages.

---

## Code Examples

### Compliant Pattern (Do)
```json
{
  "CommandLine": "flutter test",
  "Cwd": "/Users/devashishraut/StudioProjects/workout_tracker",
  "WaitMsBeforeAsync": 10000,
  "BypassSandbox": true
}
```

### Anti-Pattern (Don't)
```json
// ANTI-PATTERN: Failing to set BypassSandbox: true triggers permission denial
{
  "CommandLine": "flutter test",
  "Cwd": "/Users/devashishraut/StudioProjects/workout_tracker",
  "WaitMsBeforeAsync": 10000,
  "BypassSandbox": false
}
```

---

## Permitted Exceptions & Nuances
- Pure file inspection, text manipulation, and git status commands that do not execute the Flutter or Dart CLI do not invoke `/opt/homebrew/share/flutter/bin/` and may safely run within standard sandboxes.

---

## Enforcing Mechanisms & Linters
- **Tooling Execution Standard**: Documented in `AGENTS.md` and `.agents/teamwork/worker_m3/DISPATCH.md`.
- **E2E Validation Guard**: `./tool/verify_project_context_memory.sh` relies on this convention during Tier 4 execution.

---

## Source Code & Test Citations
- **Reference Code**:
  - `/opt/homebrew/share/flutter/bin/internal/update_engine_version.sh` (Line 71: `/opt/homebrew/share/flutter/bin/cache/engine.stamp.tmp.*`)
- **Verifying Test**:
  - `tool/verify_project_context_memory.sh` (Lines 612–633): Validates that `flutter analyze` and `flutter test` pass with 0 issues when executed with the appropriate environment permissions.
