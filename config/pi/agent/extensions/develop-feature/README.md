# Develop Feature Workflow

Pi extension implementing **Clarify -> Plan -> Implement** workflow for feature development, driven
by a single session-persisted state machine. Registers `/clarify`, `/plan`, `/implement` commands.

## Workflow

Three major phases: each starts with a command, and ends in a user-approved tool call that writes an
artifact (file or commit) and advances `State { feature, phase }`.
Artifacts live on disk at `.artifacts/<feature-slug>/{SPEC,PLAN}.md`.

| From phase | Trigger | To phase | Notes |
|---|---|---|---|
| `NONE` | `/clarify <request>` | `clarifying` | Slugifies a title from the request; starts fresh. |
| `clarifying` | `write_spec` tool call | `clarified` | Writes user-approved `SPEC.md`. |
| `clarified` | `/clarify <feedback>` | `clarifying` | Use feedback to revise created `SPEC.md`. |
| `NONE` | `/plan <feature>` | `planning` | Create plan from existing `<feature>`. |
| `clarified` | `/plan` | `planning` | Create plan from `SPEC.md` in same session. |
| `planning` | `write_plan` tool call | `planned` | Writes user-validated `PLAN.md`. |
| `planned` | `/plan <feedback>` | `planning` | Use feedback to revise created `PLAN.md`. |
| `NONE` | `/implement <feature>` | `implementing` | Picks next slice from existing `<feature>`. |
| `planned` | `/implement` | `implementing` | Picks next slice from `PLAN.md` in same session. |
| `implementing` | `write_commit` tool call | `implemented:X/Y` | Commits and marks slice as done. |
| `implemented:X/Y` (X<Y) | `/implement` | `implementing` | Advances to the next slice. |
| `implemented:X/Y` (X=Y) | — | — | Terminal; start a new session for the next feature. |

**NOTE**: `X` / `Y` denote completed / total slices in `implemented:X/Y` state. 

## Files

- **`index.ts`**  Extension entrypoint. Registers the three commands, the bash gate on `tool_call`,
  and the `session_start` hook that restores tools/status for the current phase.
- **`workflow.ts`**: State-machine core: `State` shape, `implemented:X/Y` helpers, phase-name type
  (`TransientPhase`), persisted read/write (`readState`/`writeState` via append-only session
  entries), phase-to-tools/status map (`PHASE_TOOLS`/`applyToolsForCurrentPhase`), the
  `transitionTo` helper combining both, and `navigateToSessionStart` for resetting session context
  before each kickoff.
- **`bash-policy.ts`**: Regex denylists / allowlist gating `bash` tool calls per phase (`strict` for
  clarifying/planning, `base` for implementing) plus a user-confirm fallback. Phase keys are typed
  from `workflow.ts`'s shared phase-name type.
- **`artifacts.ts`**: Artifact I/O and `PLAN.md` grammar (sole owner of `PLAN.md` I/O). Feature
  slugification, `.artifacts/<slug>/{SPEC,PLAN}.md` path helpers, slug autocompletion for `/plan`
  and `/implement` commands; `PLAN.md` parsing/validation and its slice-checkbox mutation
  (`[ ]` -> `[-]` -> `[x]`); generalized artifact write helper (`writeArtifact`) and the write-tool
  factory (`registerWriteArtifactTool`) behind `write_spec`/`write_plan`.
- **`phase/clarify.ts`**: Phase 1; `/clarify` command + `write_spec` tool, and kickoff prompts.
- **`phase/plan.ts`**: Phase 2; `/plan` command + `write_plan` tool, and kickoff prompts.
- **`phase/implement.ts`**: Phase 3; `/implement` command + `write_commit` tool, and kickoff prompts.
