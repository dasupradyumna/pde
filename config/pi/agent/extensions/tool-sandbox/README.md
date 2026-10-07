# `tool-sandbox`

Always-on, global Pi extension. Validates every `edit`, `write`, and `bash` built-in tool call
*before* execution: `edit`/`write` are gated by filesystem-path containment (`path.ts`); `bash` is
gated by regex-based command classification of a heuristically decomposed composite command
(`shell.ts`), which also reuses `path.ts` to close path-based bypasses (`cd`, redirects, `mkdir`,
`touch`). Unconditional — active in every session regardless of any other extension's state
(including `develop-feature`'s separate, phase-gated `bash-policy.ts`, which this extension does
not read, modify, or coordinate with). This file is agent-facing reference, not human prose: it
exists so an agent can predict/explain a rejection without reading the source.

## Allowed roots & dot-entry rule

A filesystem target (`edit`/`write` path, or a `bash` `cd`/redirect/`mkdir`/`touch` target) is
in-sandbox only if it resolves (realpath, tilde-expanded, normalized) under one of:

- **Project root** — `ctx.cwd`, realpath'd.
- **Temp root** — `os.tmpdir()`, realpath'd (not a hardcoded `/tmp`).

**Blanket dot-entry rule**: any path segment starting with `.`, at any depth, under either
allowed root — file or directory — is always rejected (`protected-dot-entry`). No exceptions, no
allowlist (e.g. no `.github`/`.vscode` carve-out).

`~user/...` paths are rejected outright (`unsupported-home-reference`); bare `~`/`~/...` is
expanded to `os.homedir()` first.

## Reason-string format (every `block: true` result)

```
tool-sandbox: [<class-name>] <guidance message>
<Command: <raw command> | Path: <original input> (resolved: <canonical path>)>
```

`<class-name>` is the stable, kebab-case key used in every table below — always
cross-referenceable back to this README. `<guidance message>` is class-specific and actionable
(never a generic "blocked" string).

## `path.ts` — edit/write gate (no confirmation dialog, ever)

| `className` | message |
|---|---|
| `outside-sandbox` | This path resolves outside both the project root and the system temp directory. The edit/write tools may only target files inside the current project (or inside the temp directory for scratch files). Use a path inside the project, or ask the user to modify files elsewhere themselves. Project root: `<projectRoot>`; temp root: `<tempRoot>`. |
| `protected-dot-entry` | This path targets a dot-prefixed file or directory ('`<segment>`'), which is always protected from agent edits, with no exceptions (e.g. `.git`, `.artifacts`, `.env`). If this file genuinely needs to change, ask the user to edit it directly. |
| `unsupported-home-reference` | Paths referencing another user's home directory (`~username`) are not supported and are blocked outright. Use an absolute path or a path relative to the project instead. Project root: `<projectRoot>`. |

## `shell.ts` — bash gate

### `SHELL_DENYLIST` (checked first; any match anywhere in a segment denies the whole command)

| `name` | message |
|---|---|
| `fork-bomb` | This command matches a fork-bomb pattern and is always blocked. Do not retry with an obfuscated variant; this class of command is never permitted. |
| `destructive-delete` | Recursive/force deletion and raw disk-level commands (rm -rf, dd, mkfs, shred) are always blocked to prevent irreversible data loss. If specific files need removing, use a narrower, explicit `rm` without `-r`/`-f`, or ask the user to run the destructive command themselves. |
| `privilege-escalation` | Privilege escalation (sudo/su) is always blocked. If elevated permissions are required, ask the user to run the command themselves. |
| `system-power` | Commands that shut down, reboot, or power off the system are always blocked. This is never appropriate from an automated tool call; confirm with the user whether a restart is actually needed. |
| `pipe-to-shell` | Piping a command's output directly into a shell interpreter is always blocked, since the executed content cannot be reviewed first. Write the output to a file, inspect it, then ask the user to run it if it's safe. |
| `interactive-editor` | Interactive editors are always blocked because they would hang this tool call waiting for terminal input. Use the edit/write tools to modify files instead. |
| `process-substitution` | Process substitution (`<(...)`/`>(...)`) is always blocked; it can disguise arbitrary command execution as a redirect target. Rewrite the command without it — e.g. write intermediate output to a temp file first, or use a plain pipe. |

### `SHELL_ASKLIST` (prompts via `ctx.ui.confirm`, unless no UI — see below)

| `name` | message |
|---|---|
| `process-signal` | This command sends a signal to a running process, which can terminate unrelated work. Confirming with the user before proceeding. |
| `remote-network` | This command talks to a remote system (network transfer or remote shell), which is a potential data-exfiltration or exposure risk. Confirming with the user before proceeding. |
| `permission-change` | This command changes file permissions or ownership, which can weaken security or lock out access. Confirming with the user before proceeding. |
| `package-install` | This command installs, removes, or upgrades packages, which can affect the environment beyond this project. Confirming with the user before proceeding. |
| `service-control` | This command starts, stops, or reconfigures a system service, which can affect other running processes. Confirming with the user before proceeding. |
| `filesystem-copy-move` | This command copies or moves files, which can overwrite existing content at the destination. Confirming with the user before proceeding. |
| `filesystem-link` | This command creates a filesystem link, which can alias or redirect future reads/writes to a location outside the project — including outside the sandbox roots, if the link's target does. Confirming with the user before proceeding. |
| `unmatched-command` (default; not in any table) | This command doesn't match any pre-approved safe pattern, so it requires user confirmation before running. |

### `SHELL_ALLOWLIST` (skips the confirm prompt; no message needed)

Unconditional: `ls`, `cat`, `echo`, `pwd`, `head`, `tail`, `wc`, `which`, `diff`, `rg`, `fd` — never
mutate the filesystem.

Conditional (reaching this table at all requires passing the §`cd`/path-target checks below
first — on failure those checks DENY the whole command instead of falling through here):
`cd`, `mkdir`, `touch`.

`find` and `xargs` are deliberately **not** allowlisted — they fall through to the default
`unmatched-command` ASK.

### Git: allowlist-only (`GIT_ALLOWLIST`), independent of the three tables above

Only these `git` forms are ALLOW — everything else `git`-prefixed is DENY, regardless of what it
is (future/obscure subcommands included):

- `status`, `diff`, `log`, `show`, `blame` (any args).
- Read-only `branch`/`tag`/`remote`: no args, or `-a`/`-v`/`-l`/`--list` flags only (plus `remote
  show <name>`).

| `className` | message |
|---|---|
| `git-mutation` | Only read-only git commands (status, diff, log, show, blame, and read-only branch/tag/remote listings) are permitted from automated tool calls. Git history and working-tree mutation (commit, push, checkout, reset, merge, rebase, stash, clean, etc.) is reserved for the user — ask them to run this git command themselves. |

This covers `add`, `commit`, `push`, `checkout`/`restore`, `reset`, `merge`, `rebase`,
`cherry-pick`, `revert`, `stash`, `clean`, `init`, `clone`, `rm`, `config`, `submodule`, and any
other non-allowlisted subcommand.

### `cd` / path-target bypass-closing (reuses `path.ts`'s `validateSandboxPath`)

A running `currentBaseDir` is tracked across a composite command's segments, starting at
`ctx.cwd`. These checks run interleaved with per-segment classification above and, on failure,
DENY the *whole* command immediately (pre-empting the generic tables, including for
`cd`/`mkdir`/`touch`, which can only reach `SHELL_ALLOWLIST` after passing the relevant check
here).

| `className` | trigger | message |
|---|---|---|
| `cd-dynamic-target` | `cd` target contains `$(`, backtick, or `$VAR`/`${VAR}` | This command's `cd` target cannot be statically verified (it depends on a variable or command substitution), so it can't be confirmed to stay inside the project or temp directory. Use a literal, static path with `cd`. |
| `cd-outside-sandbox` | `cd` target fails `validateSandboxPath` | This command changes directory (`cd`) to a location outside the project root and outside the system temp directory, so the rest of the command was not evaluated and the entire command was blocked. Keep all operations inside the project directory (or the temp directory for scratch work). |
| `path-target-dynamic` | redirect (`>`, `>>`, `&>`, `>&`, `n>`, ...) or `tee`/`cp`/`mv`/`mkdir`/`touch` target contains `$(`, backtick, or `$VAR`/`${VAR}` | This command's target path cannot be statically verified (it depends on a variable or command substitution), so it can't be confirmed to stay inside the project or temp directory. Use a literal, static path instead. |
| `path-target-outside-sandbox` | same targets, fails `validateSandboxPath` (`/dev/null` is exempt) | This command's output/destination/created path resolves outside the project root and outside the system temp directory, or targets a protected dot-entry (e.g. `.git`). Write to a path inside the project (or the temp directory for scratch work) instead. |

For `cp`/`mv` only the last non-flag operand (the destination) is validated; for `mkdir`/`touch`
*every* non-flag operand is validated (both accept multiple paths).

**`ln` is deliberately excluded** from this scan — it stays unconditionally `filesystem-link`
(ASK) regardless of its target, and is never path-validated. A hardlink's own path is legitimately
inside the sandbox; only its *inode* aliases something outside, which a path check can't detect —
so path-validating `ln` would add no real safety over the human-confirmation step it can't bypass
anyway.

### No-UI ASK fallback

If any segment classifies ASK (including `unmatched-command`) and `ctx.hasUI` is `false`, the
command is **DENIED** automatically (no prompt possible) with that class's message plus: "No
interactive UI is available in this session to request confirmation, so this command was blocked
automatically. Ask the user to run it, or use an alternative built only from pre-approved
commands." On decline (UI available), the reason is that class's message prefixed with "command
declined by user."

## Known limitations (not solved by this extension)

- **Alias/function/obfuscation evasion** (e.g. `alias x=rm; x -rf /`, base64-encoded `eval`) —
  requires real shell execution tracing; regex classification can't catch it.
- **Indirect invocation** via `find -exec`, `xargs`, `env`, `nohup`, `setsid`, `timeout`,
  `parallel` — not individually classified or unwrapped; falls to default `unmatched-command` ASK
  (or whatever the outer command classifies as), the wrapped command itself is never separately
  classified.
- **Hardlinks**: a hardlink inside an allowed root sharing an inode with a file outside it passes
  path-containment (checked by path, not inode); mutating it mutates the external file too. `ln`
  is unconditionally ASK (`filesystem-link`) instead of path-validated, for exactly this reason
  (see above). Symlinks have the analogous risk.
- **Heredoc bodies** (`cat <<EOF > file`) are not parsed as commands; only the redirect target
  (`> file`) is validated, not the heredoc content.
- **`powershell` tool** (`PowerShellToolCallEvent`) is out of scope — Linux-only setup.
- **Other extensions' custom tools** (e.g. `develop-feature`'s `write_spec`/`write_plan`/
  `write_commit`, which shell out internally) are out of scope — not `edit`/`write`/`bash` tool
  calls, and are the responsibility of whichever extension defines them.
