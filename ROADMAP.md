# Flutter Flavor Orchestrator 1.0.0 Roadmap

This document defines high-value features to reach a stable `1.0.0` release.

Each item includes:
- **Why it matters**
- **Technical scope**
- **Coding-agent instructions**
- **Acceptance criteria**

---

## Package-version roadmap

### ✅ `v0.1.x` (released)
- Initial CLI (`apply`, `list`, `info`, `validate`), YAML config parser.
- Android processor (AndroidManifest, Gradle/Gradle KTS, google-services.json).
- iOS processor (Info.plist, Xcode project, GoogleService-Info.plist).
- File mappings (`file_mappings`) with recursive directory copy and atomic replacement.
- `FileManager` backup/rollback, dry-run apply (`--dry-run`), external config path (`--config`).

### ✅ `v0.2.0` (released)
- Dry-run apply mode with destination-presence validation.
- CLI help and usage updates.

### ✅ `v0.3.0` (done — planning foundation)
- **`OperationKind`** enum — typed operation kinds (`copyFile`, `copyDirectory`, `writeFile`, `skip`).
- **`PlannedOperation`** — immutable descriptor for a single orchestration step with `toJson()`.
- **`ExecutionPlan`** — ordered collection of `PlannedOperation`s with metadata, counts, and `toJson()`.
- **`AssetProcessor.planFileMappings()`** — generates operations without executing (shared planning phase).
- **`FlavorOrchestrator._buildExecutionPlan()`** — internal method called by `apply` and reused by future `plan` command.
- All three models exported as public API.

### ✅ `v0.4.0` (preview release)
- Feature 1: `plan` command (text output first).
- Baseline operation summaries per platform and flavor.
- `FlavorOrchestrator.planFlavor()` public method returning `ExecutionPlan` without executing.
- `--output json` for machine-readable plan output.

### ✅ `v0.5.0` (safety release)
- Feature 2: automatic backup before non-dry-run `apply`.
- Initial `rollback --latest` support.

### ✅ `v0.6.0` (conflict protection)
- Feature 7: conflict detection and destructive-operation guardrails (`--force`).
- Pre-apply validation of overlapping mappings and duplicate targets.

### ✅ `v0.7.0` (automation contract)
- Feature 5: machine-readable output (`--output json`) for `list`, `info`, `validate`, `plan`, `rollback`.
- Standardized exit codes and stable JSON top-level keys.

### `v0.8.0` (schema hardening)
- Feature 3: strict config schema + versioning/migrations scaffold.
- `validate --strict` + deprecation/unknown-key handling.

### `v0.9.0` (diagnostics maturity)
- Feature 4 (partial): `doctor` command with core checks and actionable suggestions.
- JSON output support added to `doctor`.

### `v1.0.0` (stable milestone)
- Feature 4 (complete): production-ready `doctor` checks and full CI readiness.
- Stability hardening pass, docs finalization, changelog/migration notes, and release contract freeze.
- No breaking config changes after this tag without migration path.

### `v1.1.0` (post-1.0 enhancements)
- Feature 6: environment variable interpolation (`${VAR}`, `${VAR:-default}`).
- Feature 8: `init` command for guided config scaffolding.

---

## Must-have for 1.0.0

## 1) `plan` command (safe execution preview)

**Why it matters**
Gives users confidence before mutating project files and reduces accidental misconfiguration.

**Technical scope**
- Add CLI command: `plan`.
- Reuse orchestration pipeline used by `apply`, but do not write files.
- Produce an ordered operation list (copy, replace, delete, mkdir, skipped).
- Show per-platform and per-flavor summary with totals.

**Coding-agent instructions**
1. Update `bin/flutter_flavor_orchestrator.dart`:
   - Add `_buildPlanCommand()` with options: `--flavor`, `--config`, `--platform`, `--verbose`, `--output` (`text|json`).
   - Register the command in `ArgParser` and `switch` dispatch.
2. In orchestrator layer (`lib/src/orchestrator.dart`), add `planFlavor(...)` returning `ExecutionPlan` (model already exists from v0.3.0).
3. Reuse `_buildExecutionPlan()` (already refactored in v0.3.0) for `planFlavor`.
4. Add text and JSON output rendering using the `ExecutionPlan.toJson()` already available.
5. Add tests:
   - command parsing
   - generated operation list order
   - text output snapshot-style assertions
   - JSON schema shape assertions

**Acceptance criteria**
- `flutter_flavor_orchestrator plan --flavor dev` returns exit code `0` and no file mutation.
- `--output json` returns deterministic machine-readable output.
- Plan output matches actual `apply` behavior for same inputs.

---

## 2) Automatic backup + `rollback` command

**Why it matters**
Provides a recovery path after failed/incorrect apply operations.

**Technical scope**
- Before non-dry-run `apply`, create a timestamped snapshot of affected files.
- Persist metadata (flavor, timestamp, files, checksums) in a hidden state directory, e.g. `.ffo/backups/`.
- Add command: `rollback` with selectors (`--latest`, `--id`).

**Coding-agent instructions**
1. Add backup storage utility in `lib/src/utils/` (e.g. `backup_manager.dart`).
2. Backup only files targeted by execution plan (not whole project).
3. Add checksum validation to detect manual edits before rollback; if mismatch, require `--force`.
4. Add CLI command parser + handler for `rollback`.
5. Add unit tests for:
   - backup creation
   - metadata persistence
   - successful rollback
   - checksum mismatch handling

**Acceptance criteria**
- `apply` creates backup metadata and restorable artifacts.
- `rollback --latest` restores previous state and returns exit code `0`.
- Conflicts are reported clearly with non-zero exit code.

---

## 3) Strict config schema + versioning/migrations

**Why it matters**
Prevents ambiguous configs and allows safe evolution of YAML format over time.

**Technical scope**
- Require top-level `schema_version` (starting at `1`).
- Add strict mode that fails on unknown/deprecated keys.
- Add migration helpers for future schema changes.

**Coding-agent instructions**
1. Extend parser model (`lib/src/models/` + `lib/src/config_parser.dart`) to include schema metadata.
2. Add `validate --strict` behavior:
   - unknown keys => error
   - deprecated keys => error in strict mode, warning otherwise.
3. Create a migration interface and register migration `v1 -> v1` no-op now (future-proof scaffold).
4. Ensure all parse/validate errors include actionable key path (e.g. `flavors.dev.file_mappings[2].source`).
5. Expand tests for invalid shapes, unknown keys, strict/non-strict behavior.

**Acceptance criteria**
- Missing `schema_version` fails validation with clear remediation message.
- `validate --strict` rejects unknown keys.
- Non-strict mode remains backward-friendly with warnings.

---

## 4) `doctor` command (preflight diagnostics)

**Why it matters**
Users can detect setup issues before attempting `apply`, especially in CI and onboarding.

**Technical scope**
- Add command: `doctor`.
- Check required files/directories referenced by config.
- Check platform project presence (`android/`, `ios/`) when requested.
- Return categorized findings: error/warning/info.

**Coding-agent instructions**
1. Add `doctor` parser + handler with options: `--config`, `--platform`, `--output` (`text|json`).
2. Implement diagnostics module (`lib/src/diagnostics/doctor.dart`) with small composable checks.
3. Standardize diagnostic record model: `code`, `severity`, `message`, `suggestion`, `path`.
4. Reuse in `validate` where possible to avoid duplicate check logic.
5. Add tests for failing and passing scenarios, including JSON output contract.

**Acceptance criteria**
- `doctor` runs without mutating files.
- Exit code is non-zero if any error-level finding exists.
- Output includes actionable suggestions.

---

## 5) Machine-readable output (`--output json`)

**Why it matters**
Enables robust CI integration and predictable automation.

**Technical scope**
- Add global or per-command output format option.
- Support JSON for `list`, `info`, `validate`, `plan`, `doctor`, `rollback`.
- Preserve existing human-readable output as default.

**Coding-agent instructions**
1. Introduce shared output formatter interface in `lib/src/utils/`.
2. Implement `TextFormatter` and `JsonFormatter`.
3. Update command handlers to return typed result objects instead of directly writing text.
4. Keep stderr reserved for errors; write command payloads to stdout.
5. Add tests asserting stable top-level JSON keys per command.

**Acceptance criteria**
- All supported commands return valid JSON under `--output json`.
- Existing text output remains unchanged without `--output` flag.

---

## Should-have (if schedule allows)

## 6) Environment variable interpolation in config

**Why it matters**
Supports secrets and environment-specific paths in CI/CD without hardcoding.

**Technical scope**
- Parse `${VAR}` and `${VAR:-default}` placeholders.
- Configurable behavior for missing vars (`error` default).

**Coding-agent instructions**
1. Add interpolation utility before model validation, preserving source paths for error reporting.
2. Ensure interpolation runs on string values only.
3. Prevent recursive/self-referential expansion loops.
4. Add tests covering default values and missing env vars.

**Acceptance criteria**
- Placeholder expansion works deterministically across platforms.
- Missing required env var causes clear validation error.

---

## 7) Conflict detection and destructive-operation guardrails

**Why it matters**
Avoids silent overwrites and dangerous replacements.

**Technical scope**
- Detect duplicate target paths and overlapping replacement scopes.
- Require explicit `--force` for destructive operations.

**Coding-agent instructions**
1. Add pre-apply conflict analyzer operating on execution plan.
2. Surface conflicts with stable error codes.
3. Block apply unless `--force` is passed for allowed conflict classes.
4. Add tests for duplicate mapping and overlap detection.

**Acceptance criteria**
- Conflicts fail fast before any file mutation.
- `--force` behavior is explicit and documented.

---

## Could-have (post-1.0)

## 8) `init` command (guided config scaffolding)

**Why it matters**
Speeds onboarding and reduces initial configuration mistakes.

**Technical scope**
- Scan project tree and generate starter `flavor_config.yaml`.
- Optional interactive prompts for flavor names and mapping templates.

**Coding-agent instructions**
1. Implement non-interactive first (`--yes`, `--output-path`), then optional interactive mode.
2. Reuse parser models to generate valid schema-compliant config.
3. Add template presets (minimal, firebase, branding).

**Acceptance criteria**
- Generated config validates immediately with `validate`.

---

## Recommended implementation order

1. ✅ Shared operation planning refactor (foundation for `plan`, safety checks, backups) — **done in v0.3.0**
2. ✅ `plan` command — **done in v0.4.0**
3. ✅ Backup + `rollback` — **done in v0.5.0**
4. ✅ Conflict detection and destructive-operation guardrails — **done in v0.6.0**
5. ✅ Output formatter abstraction + JSON output — **done in v0.7.0**
6. Schema versioning + strict validation
7. `doctor` command
8. Env-var interpolation
9. `init` command

---

## Definition of done for 1.0.0

- Public CLI contract documented in `README.md` with examples for all 1.0 commands.
- Changelog entries for breaking changes and migration notes.
- Test coverage for command parsing + core orchestration logic + error paths.
- Deterministic exit codes and stable JSON structure for CI use.
- No file mutation in preview/diagnostic commands (`plan`, `doctor`, `validate`).
- Clear error messages with remediation steps for common misconfigurations.
- CI pipeline updated to run new commands and validate expected outputs.
- All new features behind a `1.0.0` release tag with appropriate version bump in `pubspec.yaml`.
- Documentation updated to reflect new capabilities and usage patterns.

