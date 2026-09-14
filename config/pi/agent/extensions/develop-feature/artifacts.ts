/**
 * Everything artifact-related for the develop-feature extension: feature-name
 * slugification, `.artifacts/<slug>/{SPEC,PLAN}.md` path helpers, PLAN.md grammar
 * (parse/validate/mutate), and the shared write-artifact I/O helper + tool-
 * registration factory used by `write_spec`/`write_plan`.
 *
 * PLAN.md format enforced here:
 *
 * ## Status
 *
 * - [ ] 1. <slice title>
 * - [ ] 2. <slice title>
 *
 * ## Slice 1: <slice title>
 * <description / acceptance criteria>
 *
 * ## Slice 2: <slice title>
 * ...
 *
 * Checkbox states: `[ ]` not started, `[-]` pending review, `[x]` implemented & committed.
 */

import { existsSync, readdirSync } from "node:fs";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { Type } from "typebox";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { withFileMutationQueue } from "@earendil-works/pi-coding-agent";
import { readState, transitionTo } from "./workflow.ts";

export function slugifyFeature(feature: string): string {
    const slug = feature
        .trim()
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-+|-+$/g, "");
    return slug.length > 0 ? slug : "untitled-feature";
}

const ARTIFACTS_DIR_NAME = ".artifacts";
const SPEC_FILE_NAME = "SPEC.md";
const PLAN_FILE_NAME = "PLAN.md";

/** Shared shape behind specPath/planPath/specRelativePath/planRelativePath below: every
 * artifact lives at .artifacts/<slug>/<fileName>, either resolved against a cwd or as a
 * cwd-relative path. */
function artifactPath(cwd: string, slug: string, fileName: string): string {
    return resolve(cwd, join(ARTIFACTS_DIR_NAME, slug, fileName));
}

function artifactRelativePath(slug: string, fileName: string): string {
    return join(ARTIFACTS_DIR_NAME, slug, fileName);
}

export function specPath(cwd: string, slug: string): string {
    return artifactPath(cwd, slug, SPEC_FILE_NAME);
}

export function planPath(cwd: string, slug: string): string {
    return artifactPath(cwd, slug, PLAN_FILE_NAME);
}

export function specRelativePath(slug: string): string {
    return artifactRelativePath(slug, SPEC_FILE_NAME);
}

export function planRelativePath(slug: string): string {
    return artifactRelativePath(slug, PLAN_FILE_NAME);
}

export function artifactsDir(cwd: string): string {
    return resolve(cwd, ARTIFACTS_DIR_NAME);
}

/**
 * List .artifacts/ subfolder (slug) names that contain the given file, filtered by a
 * name prefix. Used for /plan and /implement argument autocompletion.
 */
export function listArtifactSlugsWithFile(cwd: string, fileName: string, prefix: string): string[] {
    const dir = artifactsDir(cwd);
    if (!existsSync(dir)) return [];
    return readdirSync(dir, { withFileTypes: true })
        .filter((entry) => entry.isDirectory())
        .map((entry) => entry.name)
        .filter((name) => name.startsWith(prefix))
        .filter((name) => existsSync(`${dir}/${name}/${fileName}`))
        .sort();
}

export interface SliceStatus {
    number: number;
    title: string;
    state: " " | "-" | "x";
}

const STATUS_LINE_RE = /^- \[([ x-])\] (\d+)\. (.+)$/;
const SLICE_HEADING_RE = /^## Slice (\d+): (.+)$/m;
/** Prefix marking the start of any top-level "## " section heading (used to find the
 * end of the current section when scanning line-by-line). */
const SECTION_HEADING_PREFIX = "## ";

/**
 * Parse the "## Status" block into an ordered list of checkbox entries.
 * Returns undefined if no "## Status" heading is found at all.
 */
export function parseStatusSection(content: string): SliceStatus[] | undefined {
    const lines = content.split("\n");
    const headingIndex = lines.findIndex((l) => l.trim() === "## Status");
    if (headingIndex === -1) return undefined;
    const statusList: SliceStatus[] = [];
    for (let i = headingIndex + 1; i < lines.length; i++) {
        const line = lines[i];
        if (line.startsWith(SECTION_HEADING_PREFIX)) break; // next section
        const match = STATUS_LINE_RE.exec(line);
        if (match) {
            statusList.push({
                state: match[1] as SliceStatus["state"],
                number: Number(match[2]),
                title: match[3],
            });
        }
    }
    return statusList;
}

/** All "## Slice N: title" headings anywhere in the doc, in document order, including
 * any duplicate slice numbers (callers that care about duplicates should inspect this
 * directly, as validatePlan does). */
export function parseSliceHeadingEntries(content: string): { number: number; title: string }[] {
    const entries: { number: number; title: string }[] = [];
    const re = new RegExp(SLICE_HEADING_RE, "gm");
    let m: RegExpExecArray | null;
    while ((m = re.exec(content))) {
        entries.push({ number: Number(m[1]), title: m[2] });
    }
    return entries;
}

export type ValidationResult = { ok: true } | { ok: false; reason: string };

/**
 * Full validation for a freshly-authored PLAN.md (write_plan uses this before
 * writing). Rules: "## Status" section present; checkboxes numbered consecutively
 * from 1 with no gaps; every checkbox starts as "[ ]"; every status-list number has
 * a matching "## Slice N: <same title>" heading later in the document.
 */
export function validatePlan(content: string): ValidationResult {
    const statusList = parseStatusSection(content);
    if (!statusList || statusList.length === 0) {
        return {
            ok: false,
            reason: 'Missing or empty "## Status" section with "- [ ] N. title" entries.',
        };
    }
    for (let i = 0; i < statusList.length; i++) {
        if (statusList[i].number !== i + 1) {
            return {
                ok: false,
                reason: `Status list must be numbered consecutively from 1 with no gaps (found ${statusList[i].number} at position ${i + 1}).`,
            };
        }
        if (statusList[i].state !== " ") {
            return {
                ok: false,
                reason: `All slices must start as "[ ]" (slice ${statusList[i].number} is "[${statusList[i].state}]").`,
            };
        }
    }
    // Single pass over the parsed headings, building both the lookup map and the
    // per-number occurrence count (avoids re-parsing the document a second time).
    const headings = new Map<number, string>();
    const headingCounts = new Map<number, number>();
    for (const entry of parseSliceHeadingEntries(content)) {
        headings.set(entry.number, entry.title);
        headingCounts.set(entry.number, (headingCounts.get(entry.number) ?? 0) + 1);
    }
    for (const [number, count] of headingCounts) {
        if (count > 1) {
            return {
                ok: false,
                reason: `Duplicate "## Slice ${number}: ..." heading (appears ${count} times).`,
            };
        }
    }

    if (headings.size !== statusList.length) {
        return {
            ok: false,
            reason: `Status list has ${statusList.length} slice(s) but found ${headings.size} "## Slice N: ..." heading(s) in the document.`,
        };
    }

    for (const s of statusList) {
        const title = headings.get(s.number);
        if (title === undefined) {
            return { ok: false, reason: `Missing "## Slice ${s.number}: ${s.title}" heading.` };
        }
        if (title !== s.title) {
            return {
                ok: false,
                reason: `Title mismatch for slice ${s.number}: status list says "${s.title}", heading says "${title}".`,
            };
        }
    }

    return { ok: true };
}

export function findFirstPendingSlice(statusList: SliceStatus[]): SliceStatus | undefined {
    return statusList.find((s) => s.state === " ");
}

export function findReviewSlices(statusList: SliceStatus[]): SliceStatus[] {
    return statusList.filter((s) => s.state === "-");
}

export function computeProgress(statusList: SliceStatus[]): { x: number; y: number } {
    return { x: statusList.filter((s) => s.state === "x").length, y: statusList.length };
}

/**
 * Replace exactly one status line's checkbox state leaving everything else byte-for-byte unchanged.
 */
export function setSliceState(
    content: string,
    number: number,
    newState: SliceStatus["state"],
): string {
    const lines = content.split("\n");
    for (let i = 0; i < lines.length; i++) {
        const match = STATUS_LINE_RE.exec(lines[i]);
        if (match && Number(match[2]) === number) {
            lines[i] = `- [${newState}] ${number}. ${match[3]}`;
            break;
        }
    }
    return lines.join("\n");
}

/** Extract the body text under "## Slice N: ..." up to the next "## " heading or EOF. */
export function getSliceDetail(content: string, number: number): string | undefined {
    const lines = content.split("\n");
    const startRe = new RegExp(`^## Slice ${number}: `);
    const start = lines.findIndex((l) => startRe.test(l));
    if (start === -1) return undefined;
    const rest = lines.slice(start + 1);
    const end = rest.findIndex((l) => l.startsWith(SECTION_HEADING_PREFIX));
    return (end === -1 ? rest : rest.slice(0, end)).join("\n").trim();
}

export interface LoadedPlan {
    content: string;
    statusList: SliceStatus[];
}

export type LoadPlanResult = { ok: true; plan: LoadedPlan } | { ok: false; reason: string };

/**
 * Read a PLAN.md file and parse its Status section. Returns an error result (instead
 * of throwing) when the file is missing/malformed (no Status section), since both
 * callers (/implement, /commit) need to surface this as a user-facing notify rather
 * than crash.
 */
export async function loadPlanStatusList(planFilePath: string): Promise<LoadPlanResult> {
    const content = await readFile(planFilePath, "utf8");
    const statusList = parseStatusSection(content);
    if (!statusList) {
        return { ok: false, reason: "PLAN.md is missing or malformed (no Status section)." };
    }
    return { ok: true, plan: { content, statusList } };
}

/**
 * Mutate one slice's checkbox state and persist it back to disk, guarded by the
 * shared file-mutation queue. Returns the new full content.
 */
export async function writeSliceState(
    planFilePath: string,
    content: string,
    number: number,
    newState: SliceStatus["state"],
): Promise<string> {
    const updated = setSliceState(content, number, newState);
    await withFileMutationQueue(planFilePath, async () => {
        await writeFile(planFilePath, updated, "utf8");
    });
    return updated;
}

/**
 * Generalized write-artifact I/O: ensure the parent directory exists, then write the
 * full file content, all guarded by the shared file-mutation queue. Used by both
 * write_spec and write_plan (via registerWriteArtifactTool below).
 */
export async function writeArtifact(path: string, content: string): Promise<void> {
    await withFileMutationQueue(path, async () => {
        await mkdir(dirname(path), { recursive: true });
        await writeFile(path, content, "utf8");
    });
}

export interface WriteArtifactToolConfig {
    /** Tool name, e.g. "write_spec". */
    name: string;
    /** Tool label, e.g. "write-spec". */
    label: string;
    /** Tool description shown to the model. */
    description: string;
    /** Description of the single `content` string parameter. */
    contentDescription: string;
    /** Phase this tool is only usable in (guard fails otherwise). */
    requiredPhase: string;
    /** Error message thrown when the phase guard fails. */
    guardMessage: string;
    /** Optional content validation run before writing (e.g. PLAN.md grammar). */
    validate?: (content: string) => ValidationResult;
    /** Resolves the on-disk path to write to, given the current feature slug. */
    getPath: (cwd: string, feature: string) => string;
    /** Phase to transition to after a successful write. */
    nextPhase: string;
    /** Builds the tool's returned success text from the written file's path. */
    successMessage: (path: string) => string;
}

/**
 * Shared write-artifact tool-registration factory: write_spec and write_plan
 * duplicate not just the write logic but the whole registerTool() shape (single
 * `content` string parameter, a phase guard, the write, the transition, and an
 * identical text-content return shape). write_commit is NOT built via this factory -
 * its parameters, git side effects, and multi-step validation differ enough to stay
 * bespoke.
 */
export function registerWriteArtifactTool(pi: ExtensionAPI, config: WriteArtifactToolConfig): void {
    pi.registerTool({
        name: config.name,
        label: config.label,
        description: config.description,
        parameters: Type.Object({
            content: Type.String({ description: config.contentDescription }),
        }),
        async execute(_toolCallId, params, _signal, _onUpdate, ctx: ExtensionContext) {
            const state = readState(ctx);
            if (!state || state.phase !== config.requiredPhase) {
                throw new Error(config.guardMessage);
            }

            if (config.validate) {
                const validation = config.validate(params.content);
                if (!validation.ok) {
                    throw new Error(validation.reason);
                }
            }

            const path = config.getPath(ctx.cwd, state.feature);
            await writeArtifact(path, params.content);

            transitionTo(pi, ctx, { feature: state.feature, phase: config.nextPhase });

            return {
                content: [{ type: "text", text: config.successMessage(path) }],
                details: undefined,
            };
        },
    });
}
