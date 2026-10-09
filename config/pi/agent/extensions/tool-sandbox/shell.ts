/**
 * Bash command-classification gate for the tool-sandbox extension.
 *
 * Decomposes a composite `bash` tool-call command into its constituent pieces
 * (heuristically — no shell-parser dependency, see SPEC §7.3) and classifies each
 * piece as DENY / ASK / ALLOW against the tables in §7.1, aggregating per §7.5.
 *
 * `git`-prefixed segments are classified separately, via the allowlist-only scheme
 * in §7.2 (`GIT_ALLOWLIST`), which takes precedence over the generic
 * `SHELL_DENYLIST`/`SHELL_ASKLIST`/`SHELL_ALLOWLIST` tables and over the generic
 * unmatched→ASK default for the `git` command name.
 *
 * `cd`/redirect-target bypass-closing (§7.4) is interleaved with the per-segment
 * classification below, reusing `validateSandboxPath` from `path.ts` so no path
 * logic is duplicated between the two gates.
 */

import type {
    BashToolCallEvent,
    ExtensionContext,
    ToolCallEventResult,
} from "@earendil-works/pi-coding-agent";
import { validateSandboxPath } from "./path.ts";

/**
 * `deny`/`ask` entries must carry a `message`; `allow` entries never produce a rejection.
 * `SHELL_DENYLIST`/`SHELL_ASKLIST`/`SHELL_ALLOWLIST` below are each a `Record<string,
 * ShellCommandClass>` keyed by the class's `name` (SPEC §7.1) — the key *is* the name, so it's
 * not duplicated inside the value.
 */
export interface ShellCommandClass {
    pattern: RegExp;
    action: "deny" | "ask" | "allow";
    message?: string;
}

/**
 * `SHELL_DENYLIST` — matched first; any match anywhere in a segment denies the
 * whole command immediately (SPEC §7.1).
 *
 * `process-substitution` is listed here for documentation/README purposes (it's a
 * DENY class like any other), but is actually detected by a dedicated unquoted,
 * whole-raw-command scan that runs *before* decomposition (SPEC §7.3 step 1) — so
 * it is never reached via the per-segment loop below in practice.
 */
export const SHELL_DENYLIST: Record<string, ShellCommandClass> = {
    "fork-bomb": {
        pattern: /:\s*\(\s*\)\s*\{\s*:\s*\|\s*:\s*&\s*;?\s*\}\s*;\s*:/,
        action: "deny",
        message:
            "This command matches a fork-bomb pattern and is always blocked. Do not retry with an " +
            "obfuscated variant; this class of command is never permitted.",
    },
    "destructive-delete": {
        pattern: new RegExp(
            String.raw`\brm\b(?=[\s\S]*(?:(?:^|\s)-[a-zA-Z]*r[a-zA-Z]*(?:\s|$)|--recursive\b))` +
                String.raw`(?=[\s\S]*(?:(?:^|\s)-[a-zA-Z]*f[a-zA-Z]*(?:\s|$)|--force\b))` +
                String.raw`|\bdd\b` +
                String.raw`|\bmkfs(?:\.\w+)?\b` +
                String.raw`|\bshred\b`,
        ),
        action: "deny",
        message:
            "Recursive/force deletion and raw disk-level commands (rm -rf, dd, mkfs, shred) are always " +
            "blocked to prevent irreversible data loss. If specific files need removing, use a narrower, " +
            "explicit `rm` without `-r`/`-f`, or ask the user to run the destructive command themselves.",
    },
    "privilege-escalation": {
        pattern: /\b(?:sudo|su)\b/,
        action: "deny",
        message:
            "Privilege escalation (sudo/su) is always blocked. If elevated permissions are required, ask " +
            "the user to run the command themselves.",
    },
    "system-power": {
        pattern: /\b(?:shutdown|reboot|halt|poweroff)\b/,
        action: "deny",
        message:
            "Commands that shut down, reboot, or power off the system are always blocked. This is never " +
            "appropriate from an automated tool call; confirm with the user whether a restart is actually " +
            "needed.",
    },
    "pipe-to-shell": {
        // Broadened per spec amendment: any command piped into a shell interpreter is in scope,
        // not just curl/wget — the risk is the unreviewed execution, not the download.
        pattern: /\|\s*(?:[\w./-]*\/)?(?:sh|bash|zsh|\$SHELL)\b/,
        action: "deny",
        message:
            "Piping a command's output directly into a shell interpreter is always blocked, since the " +
            "executed content cannot be reviewed first. Write the output to a file, inspect it, then " +
            "ask the user to run it if it's safe.",
    },
    "interactive-editor": {
        pattern: /\b(?:vim|nvim|nano|emacs|code|subl)\b/,
        action: "deny",
        message:
            "Interactive editors are always blocked because they would hang this tool call waiting for " +
            "terminal input. Use the edit/write tools to modify files instead.",
    },
    "process-substitution": {
        pattern: /<\(|>\(/,
        action: "deny",
        message:
            "Process substitution (`<(...)`/`>(...)`) is always blocked; it can disguise arbitrary " +
            "command execution as a redirect target. Rewrite the command without it — e.g. write " +
            "intermediate output to a temp file first, or use a plain pipe.",
    },
};

const UNMATCHED_COMMAND_MESSAGE =
    "This command doesn't match any pre-approved safe pattern, so it requires user confirmation before " +
    "running.";

/** `SHELL_ASKLIST` — prompts via `ctx.ui.confirm`, unless no UI (SPEC §7.1). */
export const SHELL_ASKLIST: Record<string, ShellCommandClass> = {
    "process-signal": {
        pattern: /\b(?:kill|pkill|killall)\b/,
        action: "ask",
        message:
            "This command sends a signal to a running process, which can terminate unrelated work. " +
            "Confirming with the user before proceeding.",
    },
    "remote-network": {
        pattern: /\b(?:curl|wget|ssh|scp|rsync|nc|netcat|ftp)\b/,
        action: "ask",
        message:
            "This command talks to a remote system (network transfer or remote shell), which is a " +
            "potential data-exfiltration or exposure risk. Confirming with the user before proceeding.",
    },
    "permission-change": {
        pattern: /\b(?:chmod|chown|chgrp)\b/,
        action: "ask",
        message:
            "This command changes file permissions or ownership, which can weaken security or lock out " +
            "access. Confirming with the user before proceeding.",
    },
    "package-install": {
        pattern:
            /\b(?:apt-get|apt|brew|npm|pip|pnpm|yarn)\b[^\n]*\b(?:install|remove|uninstall|upgrade)\b/,
        action: "ask",
        message:
            "This command installs, removes, or upgrades packages, which can affect the environment " +
            "beyond this project. Confirming with the user before proceeding.",
    },
    "service-control": {
        pattern:
            /\bservice\b[^\n]*\b(?:start|stop|restart)\b|\bsystemctl\b[^\n]*\b(?:start|stop|restart|enable|disable)\b/,
        action: "ask",
        message:
            "This command starts, stops, or reconfigures a system service, which can affect other " +
            "running processes. Confirming with the user before proceeding.",
    },
    "filesystem-copy-move": {
        pattern: /\b(?:cp|mv)\b/,
        action: "ask",
        message:
            "This command copies or moves files, which can overwrite existing content at the " +
            "destination. Confirming with the user before proceeding.",
    },
    "filesystem-link": {
        pattern: /\bln\b/,
        action: "ask",
        message:
            "This command creates a filesystem link, which can alias or redirect future reads/writes to " +
            "a location outside the project — including outside the sandbox roots, if the link's target " +
            "does. Confirming with the user before proceeding.",
    },
};

/**
 * `SHELL_ALLOWLIST` — skips the confirm prompt; no message needed (SPEC §7.1).
 *
 * `mkdir`/`touch`/`cd` reach this table too, but (unlike the rest of this list) doing so is
 * *conditional*: the §7.4 checks below (`checkCdTarget`/`checkPathTargets`) validate their
 * target path(s) via `validateSandboxPath` first — any failure denies the whole command
 * immediately (`cd-dynamic-target`/`cd-outside-sandbox` for `cd`; `path-target-dynamic`/
 * `path-target-outside-sandbox` for `mkdir`/`touch`) and this table is never reached. `ln` is
 * deliberately excluded from both this table and the §7.4 scan — it stays unconditionally ASK
 * (`filesystem-link`, above), since its hardlink risk isn't one a path check can close (§7.4).
 */
export const SHELL_ALLOWLIST: Record<string, ShellCommandClass> = Object.fromEntries(
    ["ls", "cat", "echo", "pwd", "head", "tail", "wc", "which", "diff", "rg", "fd", "mkdir", "touch", "cd"].map(
        (name): [string, ShellCommandClass] => [
            name,
            { pattern: new RegExp(String.raw`\b${name}\b`), action: "allow" },
        ],
    ),
);

/**
 * `GIT_ALLOWLIST` — the *only* way a `git`-prefixed segment can classify as ALLOW
 * (SPEC §7.2): read-only subcommands (`status`/`diff`/`log`/`show`/`blame`, which
 * never mutate regardless of flags/args), plus read-only forms of
 * `branch`/`tag`/`remote` — no args, or `-a`/`-v`/`-l`/`--list` flags only (and,
 * for `remote`, the read-only `show <name>` form). Anything `git`-prefixed that
 * doesn't match one of these is `git-mutation` DENY (§7.2) — this table overrides
 * the generic `SHELL_DENYLIST`/`SHELL_ASKLIST`/`SHELL_ALLOWLIST` tables, and the
 * generic unmatched→ASK default, entirely for the `git` command name.
 */
export const GIT_ALLOWLIST: Record<string, ShellCommandClass> = {
    status: { pattern: /^git\s+status\b/, action: "allow" },
    diff: { pattern: /^git\s+diff\b/, action: "allow" },
    log: { pattern: /^git\s+log\b/, action: "allow" },
    show: { pattern: /^git\s+show\b/, action: "allow" },
    blame: { pattern: /^git\s+blame\b/, action: "allow" },
    "branch-readonly": {
        pattern: /^git\s+branch(?:\s+(?:-a|-v|-l|--list))*\s*$/,
        action: "allow",
    },
    "tag-readonly": {
        pattern: /^git\s+tag(?:\s+(?:-a|-v|-l|--list))*\s*$/,
        action: "allow",
    },
    "remote-readonly": {
        pattern: /^git\s+remote(?:\s+(?:-a|-v|-l|--list))*\s*$|^git\s+remote\s+show\b/,
        action: "allow",
    },
};

const GIT_MUTATION_MESSAGE =
    "Only read-only git commands (status, diff, log, show, blame, and read-only branch/tag/remote " +
    "listings) are permitted from automated tool calls. Git history and working-tree mutation " +
    "(commit, push, checkout, reset, merge, rebase, stash, clean, etc.) is reserved for the user " +
    "— ask them to run this git command themselves.";

/**
 * Classifies a `git`-prefixed effective command per SPEC §7.2: allowlist-only,
 * independent of (and taking precedence over) the generic DENY→ASK→ALLOW tables.
 */
function classifyGitCommand(effective: string): {
    action: "deny" | "allow";
    className: string;
    message?: string;
} {
    for (const [name, entry] of Object.entries(GIT_ALLOWLIST)) {
        if (entry.pattern.test(effective)) {
            return { action: "allow", className: name };
        }
    }
    return { action: "deny", className: "git-mutation", message: GIT_MUTATION_MESSAGE };
}

/** A single classified command fragment (top-level segment or recursively-extracted subshell). */
interface ClassifiedSegment {
    action: "deny" | "ask" | "allow";
    className: string;
    message?: string;
    /** The raw text of the segment that produced this classification (for ASK prompts, Slice 3). */
    segmentText: string;
    /**
     * Set by the §7.4 `cd`/path-target checks when they deny: signals that decomposition must
     * stop immediately (no further segments — including sibling top-level segments and anything
     * after this point in a subshell — are classified), since the whole command is already DENY.
     */
    stop?: boolean;
}

/** Current quote state (`null` = unquoted) shared by every scanner below. */
type QuoteState = '"' | "'" | null;

/**
 * Scans the full raw command for an unquoted `<(` or `>(` anywhere (SPEC §7.3 step 1).
 * This runs once, globally, before decomposition — any match denies the whole command
 * immediately, so there's no need to understand nested structure beyond quote state.
 */
export function hasUnquotedProcessSubstitution(raw: string): boolean {
    let quote: QuoteState = null;
    for (let i = 0; i < raw.length; i++) {
        const ch = raw[i];
        if (quote) {
            if (ch === "\\" && quote === '"') i++;
            else if (ch === quote) quote = null;
        } else {
            if (ch === "\\") i++;
            else if (ch === "'" || ch === '"') quote = ch;
            else if ((ch === "<" || ch === ">") && raw[i + 1] === "(") return true;
        }
    }
    return false;
}

/**
 * Top-level split (SPEC §7.3 step 2): tokenizes `text` at unquoted, unescaped,
 * depth-0 occurrences of `;`, `&&`, `&`, and newline — tracking quote state and
 * paren/brace depth for `$(...)`/`` `...` ``/`(...)`/`{...}`.
 *
 * Deliberately NOT split at a bare `|`: SPEC §7.3 step 5 itself relies on a pipeline
 * (e.g. `curl ... | sh`) being tested as one piece of segment text so that
 * `pipe-to-shell` can see both sides of the pipe — splitting at `|` would
 * make that pattern unmatchable. Bare `|` therefore stays part of its segment.
 */
function splitTopLevel(text: string): string[] {
    const segments: string[] = [];
    let current = "";
    let depth = 0;
    let quote: QuoteState = null;
    let inBacktick = false;

    const push = () => {
        segments.push(current);
        current = "";
    };

    for (let i = 0; i < text.length; i++) {
        const ch = text[i];

        if (quote) {
            current += ch;
            if (ch === "\\" && quote === '"' && i + 1 < text.length) {
                current += text[++i];
                continue;
            }
            if (ch === quote) quote = null;
            continue;
        }
        if (inBacktick) {
            current += ch;
            if (ch === "\\" && i + 1 < text.length) {
                current += text[++i];
                continue;
            }
            if (ch === "`") inBacktick = false;
            continue;
        }
        if (ch === "\\" && i + 1 < text.length) {
            current += ch + text[++i];
            continue;
        }
        if (ch === "'" || ch === '"') {
            quote = ch;
            current += ch;
            continue;
        }
        if (ch === "`") {
            inBacktick = true;
            current += ch;
            continue;
        }
        if (depth === 0 && (ch === "\n" || ch === ";")) {
            push();
            continue;
        }
        if (depth === 0 && ch === "&") {
            if (text[i + 1] === "&") {
                push();
                i++;
                continue;
            }
            push();
            continue;
        }
        if (ch === "(" || ch === "{") {
            depth++;
            current += ch;
            continue;
        }
        if (ch === ")" || ch === "}") {
            depth = Math.max(0, depth - 1);
            current += ch;
            continue;
        }
        if (depth === 0 && ch === "|" && text[i + 1] === "|") {
            push();
            i++;
            continue;
        }
        current += ch;
    }
    push();

    return segments.map((s) => s.trim()).filter((s) => s.length > 0);
}

/** Finds the matching `)` for a `(` at `openIndex`, honoring nested parens and quotes. */
function extractParenGroup(text: string, openIndex: number): { content: string; end: number } {
    let depth = 0;
    let quote: QuoteState = null;
    const start = openIndex + 1;
    for (let i = openIndex; i < text.length; i++) {
        const ch = text[i];
        if (quote) {
            if (ch === "\\" && quote === '"') {
                i++;
                continue;
            }
            if (ch === quote) quote = null;
            continue;
        }
        if (ch === "\\") {
            i++;
            continue;
        }
        if (ch === "'" || ch === '"') {
            quote = ch;
            continue;
        }
        if (ch === "(") depth++;
        else if (ch === ")") {
            depth--;
            if (depth === 0) return { content: text.slice(start, i), end: i + 1 };
        }
    }
    return { content: text.slice(start), end: text.length };
}

/**
 * Extracts the inner content of every `$(...)` and backtick-quoted region in `text`
 * (SPEC §7.3 step 3), including occurrences inside double-quoted strings (where
 * command substitution still expands), but not inside single-quoted strings.
 */
function extractSubshellContents(text: string): string[] {
    const results: string[] = [];
    let quote: QuoteState = null;
    for (let i = 0; i < text.length; i++) {
        const ch = text[i];
        if (quote === "'") {
            if (ch === "'") quote = null;
            continue;
        }
        if (quote === '"') {
            if (ch === "\\") {
                i++;
                continue;
            }
            if (ch === '"') {
                quote = null;
                continue;
            }
        } else if (ch === "\\") {
            i++;
            continue;
        } else if (ch === "'") {
            quote = "'";
            continue;
        } else if (ch === '"') {
            quote = '"';
            continue;
        }

        if (ch === "$" && text[i + 1] === "(") {
            const { content, end } = extractParenGroup(text, i + 1);
            results.push(content);
            i = end - 1;
            continue;
        }
        if (ch === "`") {
            const end = text.indexOf("`", i + 1);
            if (end === -1) break;
            results.push(text.slice(i + 1, end));
            i = end;
            continue;
        }
    }
    return results;
}

/** Strips leading `NAME=value` environment assignments (SPEC §7.3 step 4). */
function stripLeadingEnvAssignments(segment: string): string {
    return segment.replace(/^(?:[A-Za-z_][A-Za-z0-9_]*=\S*\s+)*/, "").trim();
}

// --- SPEC §7.4: `cd`/path-target bypass-closing -----------------------------------------

const CD_DYNAMIC_TARGET_MESSAGE =
    "This command's `cd` target cannot be statically verified (it depends on a variable or " +
    "command substitution), so it can't be confirmed to stay inside the project or temp " +
    "directory. Use a literal, static path with `cd`.";

const CD_OUTSIDE_SANDBOX_MESSAGE =
    "This command changes directory (`cd`) to a location outside the project root and outside " +
    "the system temp directory, so the rest of the command was not evaluated and the entire " +
    "command was blocked. Keep all operations inside the project directory (or the temp " +
    "directory for scratch work).";

const PATH_TARGET_DYNAMIC_MESSAGE =
    "This command's target path cannot be statically verified (it depends on a variable or " +
    "command substitution), so it can't be confirmed to stay inside the project or temp " +
    "directory. Use a literal, static path instead.";

const PATH_TARGET_OUTSIDE_SANDBOX_MESSAGE =
    "This command's output/destination/created path resolves outside the project root and " +
    "outside the system temp directory, or targets a protected dot-entry (e.g. `.git`). Write " +
    "to a path inside the project (or the temp directory for scratch work) instead.";

/** `$(`, a backtick, or a `$VAR`/`${VAR}` reference anywhere — not statically resolvable. */
const DYNAMIC_TARGET_RE = /\$\(|`|\$\{[A-Za-z_][A-Za-z0-9_]*\}|\$[A-Za-z_][A-Za-z0-9_]*/;

function isDynamicTarget(target: string): boolean {
    return DYNAMIC_TARGET_RE.test(target);
}

/** Strips one layer of matching surrounding `'...'`/`"..."` quoting, if present. */
function stripQuotes(token: string): string {
    if (token.length >= 2) {
        const first = token[0];
        const last = token[token.length - 1];
        if ((first === '"' || first === "'") && first === last) {
            return token.slice(1, -1);
        }
    }
    return token;
}

/**
 * Splits `text` into whitespace-separated words, treating a quoted span as a single word
 * (quotes are kept in the returned word — unquote separately via `stripQuotes`).
 */
function splitWords(text: string): string[] {
    const words: string[] = [];
    let current = "";
    let quote: QuoteState = null;
    for (let i = 0; i < text.length; i++) {
        const ch = text[i];
        if (quote) {
            current += ch;
            if (ch === "\\" && quote === '"' && i + 1 < text.length) current += text[++i];
            else if (ch === quote) quote = null;
            continue;
        }
        if (ch === "\\" && i + 1 < text.length) {
            current += ch + text[++i];
            continue;
        }
        if (ch === "'" || ch === '"') {
            quote = ch;
            current += ch;
            continue;
        }
        if (/\s/.test(ch)) {
            if (current.length > 0) {
                words.push(current);
                current = "";
            }
            continue;
        }
        current += ch;
    }
    if (current.length > 0) words.push(current);
    return words;
}

/** Splits `text` at unquoted, depth-0, bare `|` (pipeline stage boundaries). */
function splitPipelineStages(text: string): string[] {
    const stages: string[] = [];
    let current = "";
    let depth = 0;
    let quote: QuoteState = null;
    for (let i = 0; i < text.length; i++) {
        const ch = text[i];
        if (quote) {
            current += ch;
            if (ch === "\\" && quote === '"' && i + 1 < text.length) current += text[++i];
            else if (ch === quote) quote = null;
            continue;
        }
        if (ch === "\\" && i + 1 < text.length) {
            current += ch + text[++i];
            continue;
        }
        if (ch === "'" || ch === '"') {
            quote = ch;
            current += ch;
            continue;
        }
        if (ch === "(" || ch === "{") {
            depth++;
            current += ch;
            continue;
        }
        if (ch === ")" || ch === "}") {
            depth = Math.max(0, depth - 1);
            current += ch;
            continue;
        }
        if (depth === 0 && ch === "|") {
            stages.push(current);
            current = "";
            continue;
        }
        current += ch;
    }
    stages.push(current);
    return stages;
}

/**
 * If `effective` is a `cd` invocation, returns its target: the first non-flag operand
 * (`-` itself counts as a target, meaning "previous directory"), or `"~"` for a bare `cd`
 * (SPEC §7.4 — `cd` with no argument goes to `$HOME`, which must still be validated).
 * Returns `null` if `effective` isn't a `cd` invocation at all.
 */
function extractCdTarget(effective: string): string | null {
    const words = splitWords(effective);
    if (words[0] !== "cd") return null;
    const operand = words.slice(1).find((w) => w === "-" || !w.startsWith("-"));
    return operand === undefined ? "~" : stripQuotes(operand);
}

/**
 * Validates a `cd` target against `baseDir` (SPEC §7.4). Returns a deny classification if the
 * target is dynamic or resolves outside the sandbox; otherwise returns the resolved directory
 * to use as `currentBaseDir` for subsequent segments.
 */
function checkCdTarget(
    target: string,
    baseDir: string,
): { deny: { className: string; message: string } } | { resolvedBaseDir: string } {
    if (target === "-" || isDynamicTarget(target)) {
        return { deny: { className: "cd-dynamic-target", message: CD_DYNAMIC_TARGET_MESSAGE } };
    }
    const result = validateSandboxPath(target, baseDir);
    if (!result.ok) {
        return { deny: { className: "cd-outside-sandbox", message: CD_OUTSIDE_SANDBOX_MESSAGE } };
    }
    return { resolvedBaseDir: result.path };
}

/** Command names whose operand(s) are path targets to validate (SPEC §7.4). `ln` is excluded. */
const PATH_TARGET_COMMANDS = new Set(["tee", "cp", "mv", "mkdir", "touch"]);

/** Redirect operators: `>`, `>>`, `&>`, `>&`, `1>`, `2>`, digit-prefixed `n>`/`n>>`, etc. */
const REDIRECT_TARGET_RE = /(\d+)?(&>>|&>|>>|>&|>)\s*("(?:[^"\\]|\\.)*"|'[^']*'|\S+)/g;

/**
 * Scans `effective` (one classification segment) for every redirect/`tee`/`cp`/`mv`/`mkdir`/
 * `touch` target operand (SPEC §7.4), returning each as its raw (possibly still-quoted) token.
 */
function collectPathTargets(effective: string): string[] {
    const targets: string[] = [];

    for (const match of effective.matchAll(REDIRECT_TARGET_RE)) {
        const [, , operator, rawToken] = match;
        if ((operator === ">&" || operator === "&>") && /^\d+$/.test(rawToken!)) {
            continue; // file-descriptor duplication (e.g. `2>&1`), not a path
        }
        targets.push(rawToken!);
    }

    for (const stage of splitPipelineStages(effective)) {
        const words = splitWords(stripLeadingEnvAssignments(stage.trim()));
        const command = words[0];
        if (!command || !PATH_TARGET_COMMANDS.has(command)) continue;
        const operands = words.slice(1).filter((w) => !w.startsWith("-"));
        if (operands.length === 0) continue;
        if (command === "cp" || command === "mv") {
            targets.push(operands[operands.length - 1]!);
        } else {
            targets.push(...operands);
        }
    }

    return targets;
}

/**
 * Validates every path-target operand found in `effective` against `baseDir` (SPEC §7.4).
 * Returns a deny classification for the first dynamic or out-of-sandbox target found, skipping
 * `/dev/null`; otherwise returns `null` (all targets, if any, are valid).
 */
function checkPathTargets(
    effective: string,
    baseDir: string,
): { className: string; message: string } | null {
    for (const rawTarget of collectPathTargets(effective)) {
        if (isDynamicTarget(rawTarget)) {
            return { className: "path-target-dynamic", message: PATH_TARGET_DYNAMIC_MESSAGE };
        }
        const target = stripQuotes(rawTarget);
        if (target === "/dev/null") continue;
        const result = validateSandboxPath(target, baseDir);
        if (!result.ok) {
            return { className: "path-target-outside-sandbox", message: PATH_TARGET_OUTSIDE_SANDBOX_MESSAGE };
        }
    }
    return null;
}

// -----------------------------------------------------------------------------------------

function classifyEffectiveCommand(effective: string): {
    action: "deny" | "ask" | "allow";
    className: string;
    message?: string;
} {
    if (/^git\b/.test(effective)) {
        return classifyGitCommand(effective);
    }

    for (const [name, entry] of Object.entries(SHELL_DENYLIST)) {
        if (entry.pattern.test(effective)) {
            return { action: "deny", className: name, message: entry.message };
        }
    }
    for (const [name, entry] of Object.entries(SHELL_ASKLIST)) {
        if (entry.pattern.test(effective)) {
            return { action: "ask", className: name, message: entry.message };
        }
    }
    for (const [name, entry] of Object.entries(SHELL_ALLOWLIST)) {
        if (entry.pattern.test(effective)) {
            return { action: "allow", className: name };
        }
    }
    return { action: "ask", className: "unmatched-command", message: UNMATCHED_COMMAND_MESSAGE };
}

/**
 * Decomposes `raw` into its constituent segments (top-level splits, plus recursively
 * extracted/decomposed subshell contents) and classifies each one (SPEC §7.3 steps
 * 2–5), interleaved in segment order with the §7.4 `cd`/path-target bypass-closing
 * checks against a running `currentBaseDir` (`baseDirRef`, mutated as `cd` segments are
 * validated). Assumes the caller has already run the step-1 process-substitution
 * short-circuit.
 *
 * A `$(...)`/backtick subshell runs in a *forked* copy of `baseDirRef` — a `cd` inside a
 * subshell doesn't change the outer shell's directory — but a §7.4 deny found inside one
 * still denies the whole command immediately (`stop: true`), since the subshell's command
 * genuinely executes wherever it targets, forked base dir or not.
 */
function decomposeAndClassifyInternal(raw: string, baseDirRef: { current: string }): ClassifiedSegment[] {
    const results: ClassifiedSegment[] = [];

    // Global DENY pre-scan: a few patterns (the classic fork-bomb's trailing `;`
    // separating the function definition from its invocation; a curl-piped-to-shell
    // download-exec pipeline) are only recognizable across a top-level separator
    // that the step-2 split below breaks on. Since DENY always blocks the *whole*
    // command regardless of which fragment triggered it, scanning the untouched
    // text first is equivalent to (and a superset of) scanning every segment.
    for (const [name, entry] of Object.entries(SHELL_DENYLIST)) {
        if (name === "process-substitution") continue; // handled by the dedicated step-1 scan
        if (entry.pattern.test(raw)) {
            results.push({ action: "deny", className: name, message: entry.message, segmentText: raw });
            return results;
        }
    }

    for (const segment of splitTopLevel(raw)) {
        for (const nested of extractSubshellContents(segment)) {
            const nestedResults = decomposeAndClassifyInternal(nested, { current: baseDirRef.current });
            results.push(...nestedResults);
            if (nestedResults.some((r) => r.stop)) return results;
        }

        const effective = stripLeadingEnvAssignments(segment);
        if (effective.length === 0) continue;

        const cdTarget = extractCdTarget(effective);
        if (cdTarget !== null) {
            const cdCheck = checkCdTarget(cdTarget, baseDirRef.current);
            if ("deny" in cdCheck) {
                results.push({ ...cdCheck.deny, action: "deny", segmentText: segment, stop: true });
                return results;
            }
            baseDirRef.current = cdCheck.resolvedBaseDir;
        } else {
            const pathTargetDeny = checkPathTargets(effective, baseDirRef.current);
            if (pathTargetDeny) {
                results.push({ ...pathTargetDeny, action: "deny", segmentText: segment, stop: true });
                return results;
            }
        }

        const classification = classifyEffectiveCommand(effective);
        results.push({ ...classification, segmentText: segment });
    }
    return results;
}

/**
 * Decomposes and classifies `raw` (SPEC §7.3) with `cd`/path-target bypass-closing (SPEC §7.4)
 * interleaved, starting `currentBaseDir` at `baseDir` (`ctx.cwd`, from the caller).
 */
export function decomposeAndClassify(raw: string, baseDir: string): ClassifiedSegment[] {
    return decomposeAndClassifyInternal(raw, { current: baseDir });
}

/** Builds the §3 reason-string format for a `bash` DENY result. */
function formatShellDenyReason(className: string, message: string, rawCommand: string): string {
    return `tool-sandbox: [${className}] ${message}\nCommand: ${rawCommand}`;
}

/** De-duplicates classified segments by `className`, preserving first-seen order. */
function dedupeByClassName(segments: ClassifiedSegment[]): ClassifiedSegment[] {
    const seen = new Set<string>();
    const result: ClassifiedSegment[] = [];
    for (const segment of segments) {
        if (seen.has(segment.className)) continue;
        seen.add(segment.className);
        result.push(segment);
    }
    return result;
}

/**
 * Builds the `ctx.ui.confirm` prompt body (SPEC §7.5): the full raw command,
 * followed by each distinct ASK-triggering segment's className + message.
 */
function formatAskConfirmMessage(askSegments: ClassifiedSegment[], rawCommand: string): string {
    const bullets = askSegments.map((segment) => `- [${segment.className}] ${segment.message}`).join("\n");
    return `Command: ${rawCommand}\n\nThis command requires confirmation for the following reason(s):\n${bullets}`;
}

/** Builds the §3/§7.5 reason-string for a declined ASK confirmation. */
function formatAskDeclineReason(askSegments: ClassifiedSegment[], rawCommand: string): string {
    const lines = askSegments.map(
        (segment) => `tool-sandbox: [${segment.className}] command declined by user. ${segment.message}`,
    );
    return `${lines.join("\n")}\nCommand: ${rawCommand}`;
}

/** Builds the §7.5 no-UI DENY reason-string (ASK auto-blocked without an interactive UI). */
function formatAskNoUIReason(askSegments: ClassifiedSegment[], rawCommand: string): string {
    const lines = askSegments.map(
        (segment) =>
            `tool-sandbox: [${segment.className}] ${segment.message} No interactive UI is available in this ` +
            "session to request confirmation, so this command was blocked automatically. Ask the user to run " +
            "it, or use an alternative built only from pre-approved commands.",
    );
    return `${lines.join("\n")}\nCommand: ${rawCommand}`;
}

/**
 * `tool_call` gate logic for `bash` tool calls per SPEC §7, dispatched to by
 * `index.ts`'s single `tool_call` handler (already narrowed to `bash` by the
 * caller — this function does not re-check the tool name).
 *
 * Implements DENY (whole-command block), ASK (confirm dialog, with a no-UI
 * fallback to DENY), and ALLOW (pass-through) aggregation per §7.5.
 */
export async function shellGate(
    event: BashToolCallEvent,
    ctx: ExtensionContext,
): Promise<ToolCallEventResult | undefined> {
    const rawCommand = event.input.command;

    if (hasUnquotedProcessSubstitution(rawCommand)) {
        const procSub = SHELL_DENYLIST["process-substitution"]!;
        return {
            block: true,
            reason: formatShellDenyReason("process-substitution", procSub.message!, rawCommand),
        };
    }

    const classified = decomposeAndClassify(rawCommand, ctx.cwd);
    const denied = classified.find((segment) => segment.action === "deny");
    if (denied) {
        return {
            block: true,
            reason: formatShellDenyReason(denied.className, denied.message!, rawCommand),
        };
    }

    const asked = dedupeByClassName(classified.filter((segment) => segment.action === "ask"));
    if (asked.length > 0) {
        if (!ctx.hasUI) {
            return { block: true, reason: formatAskNoUIReason(asked, rawCommand) };
        }
        const confirmed = await ctx.ui.confirm("tool-sandbox", formatAskConfirmMessage(asked, rawCommand));
        if (!confirmed) {
            return { block: true, reason: formatAskDeclineReason(asked, rawCommand) };
        }
    }

    return undefined;
}
