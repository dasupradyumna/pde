/**
 * Shared path-validation core for the tool-sandbox extension, plus the edit/write
 * tool_call gate built on top of it.
 *
 * `validateSandboxPath` is the single source of truth for "is this filesystem path
 * safe to mutate" — reused as-is by shell.ts (redirect / `cd` targets) in later
 * slices, so no path logic is duplicated between the two gates.
 */

import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import {
    type ExtensionContext,
    type ToolCallEvent,
    type ToolCallEventResult,
    isToolCallEventType,
} from "@earendil-works/pi-coding-agent";

/** Stable, kebab-case rule identifiers — also the row key in README.md's class tables. */
export type PathValidationClassName =
    "outside-sandbox" | "protected-dot-entry" | "unsupported-home-reference";

export type ValidateSandboxPathResult =
    | { ok: true; path: string }
    | { ok: false; className: PathValidationClassName; message: string; path: string };

/** Leading `~` immediately followed by a non-`/` character, e.g. `~bob/x` (not bare `~` or `~/x`). */
const HOME_REFERENCE_RE = /^~[^/]/;

function outsideSandboxMessage(projectRoot: string, tempRoot: string): string {
    return (
        "This path resolves outside both the project root and the system temp directory. The " +
        "edit/write tools may only target files inside the current project (or inside the temp " +
        "directory for scratch files). Use a path inside the project, or ask the user to modify " +
        "files elsewhere themselves. " +
        `Project root: \`${projectRoot}\`. Temp directory: \`${tempRoot}\`.`
    );
}

function unsupportedHomeReferenceMessage(projectRoot: string): string {
    return (
        "Paths referencing another user's home directory (`~username`) are not supported and are " +
        "blocked outright. Use an absolute path or a path relative to the project instead. " +
        `Project root: \`${projectRoot}\`.`
    );
}

function protectedDotEntryMessage(segment: string): string {
    return (
        `This path targets a dot-prefixed file or directory ('${segment}'), which is always ` +
        "protected from agent edits, with no exceptions (e.g. `.git`, `.artifacts`, `.env`). If " +
        "this file genuinely needs to change, ask the user to edit it directly."
    );
}

/** True iff `target` is `root` or lives underneath it. */
function isContainedIn(root: string, target: string): boolean {
    const rel = path.relative(root, target);
    return rel === "" || (!rel.startsWith("..") && !path.isAbsolute(rel));
}

/**
 * `fs.realpathSync`, walking up to the nearest existing ancestor for paths that don't
 * exist yet (new files/dirs), then re-appending the lexically-normalized missing suffix.
 */
function realpathWithMissingTail(resolvedPath: string): string {
    const missingSegments: string[] = [];
    let current = resolvedPath;
    for (;;) {
        try {
            const real = fs.realpathSync(current);
            return missingSegments.length > 0
                ? path.join(real, ...missingSegments.reverse())
                : real;
        } catch (err) {
            const code = (err as NodeJS.ErrnoException).code;
            if (code !== "ENOENT" && code !== "ENOTDIR") throw err;
            const parent = path.dirname(current);
            if (parent === current) throw err; // reached filesystem root and it's missing
            missingSegments.push(path.basename(current));
            current = parent;
        }
    }
}

/**
 * Validate a raw path (as passed to `edit`/`write`, or a `bash` redirect/`cd` target)
 * against the tool-sandbox policy (SPEC §5.2):
 *
 * 1. Reject `~user` references outright (can't safely replicate Pi's resolution).
 * 2. Expand a bare `~` or `~/...` prefix to the user's home directory.
 * 3. Resolve relative paths against `baseDir`.
 * 4. Lexically normalize.
 * 5. Canonicalize via `fs.realpathSync` (walking up for not-yet-existing paths).
 * 6. Containment check against the project root (`baseDir`, realpath'd) and the
 *    system temp directory (`os.tmpdir()`, realpath'd).
 * 7. Blanket dot-entry check (any segment, any depth, files and dirs alike).
 */
export function validateSandboxPath(rawPath: string, baseDir: string): ValidateSandboxPathResult {
    const projectRoot = fs.realpathSync(baseDir);

    if (HOME_REFERENCE_RE.test(rawPath)) {
        return {
            ok: false,
            className: "unsupported-home-reference",
            message: unsupportedHomeReferenceMessage(projectRoot),
            path: rawPath,
        };
    }

    let expanded = rawPath;
    if (expanded === "~") {
        expanded = os.homedir();
    } else if (expanded.startsWith("~/")) {
        expanded = path.join(os.homedir(), expanded.slice(2));
    }

    const resolvedPath = path.isAbsolute(expanded)
        ? path.resolve(expanded)
        : path.resolve(baseDir, expanded);

    const canonicalPath = realpathWithMissingTail(resolvedPath);

    const tempRoot = fs.realpathSync(os.tmpdir());
    const matchedRoot = [projectRoot, tempRoot].find((root) => isContainedIn(root, canonicalPath));
    if (!matchedRoot) {
        return {
            ok: false,
            className: "outside-sandbox",
            message: outsideSandboxMessage(projectRoot, tempRoot),
            path: canonicalPath,
        };
    }

    const relativeToRoot = path.relative(matchedRoot, canonicalPath);
    const segments = relativeToRoot.split(path.sep).filter((segment) => segment.length > 0);
    const dotSegment = segments.find((segment) => segment.startsWith("."));
    if (dotSegment !== undefined) {
        return {
            ok: false,
            className: "protected-dot-entry",
            message: protectedDotEntryMessage(dotSegment),
            path: canonicalPath,
        };
    }

    return { ok: true, path: canonicalPath };
}

/** Builds the §3 reason-string format for a path-validation failure. */
function formatPathReason(
    rawPath: string,
    result: Extract<ValidateSandboxPathResult, { ok: false }>,
): string {
    return (
        `tool-sandbox: [${result.className}] ${result.message}\n` +
        `Path: ${rawPath} (resolved: ${result.path})`
    );
}

/**
 * Factory producing the `tool_call` handler that gates `edit`/`write` tool calls per
 * SPEC §6. No-ops for any other tool. Never shows a confirmation dialog — pure
 * allow/deny.
 */
export function createPathGate() {
    return (event: ToolCallEvent, ctx: ExtensionContext): ToolCallEventResult | undefined => {
        if (!isToolCallEventType("edit", event) && !isToolCallEventType("write", event)) {
            return undefined;
        }

        const result = validateSandboxPath(event.input.path, ctx.cwd);
        if (result.ok) return undefined;

        return { block: true, reason: formatPathReason(event.input.path, result) };
    };
}
