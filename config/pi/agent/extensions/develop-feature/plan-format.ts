/**
 * PLAN.md grammar (parse / validate / mutate) plus the shared file I/O entry points
 * for reading and writing PLAN.md. This is the only place that touches PLAN.md on
 * disk; /plan's write_plan tool writes the initial file itself (via
 * withFileMutationQueue directly, since it's a one-shot full-content write with no
 * read-modify-write need), but /implement and /commit both read-then-mutate-then-write
 * a single slice's checkbox state, which is what loadPlanStatusList/writeSliceState below
 * are for.
 *
 * Enforced format:
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

import { readFile, writeFile } from "node:fs/promises";
import { withFileMutationQueue } from "@earendil-works/pi-coding-agent";

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
 * instead of - or alongside - parseSliceHeadings). */
export function parseSliceHeadingEntries(content: string): { number: number; title: string }[] {
    const entries: { number: number; title: string }[] = [];
    const re = new RegExp(SLICE_HEADING_RE, "gm");
    let m: RegExpExecArray | null;
    while ((m = re.exec(content))) {
        entries.push({ number: Number(m[1]), title: m[2] });
    }
    return entries;
}

/** Map slice number -> title, from "## Slice N: title" headings anywhere in the doc.
 * If a number appears more than once, the last occurrence wins (see
 * parseSliceHeadingEntries / validatePlan for duplicate detection). */
export function parseSliceHeadings(content: string): Map<number, string> {
    const map = new Map<number, string>();
    for (const entry of parseSliceHeadingEntries(content)) {
        map.set(entry.number, entry.title);
    }
    return map;
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
    // per-number occurrence count (avoids re-parsing the document a second time via
    // parseSliceHeadings, which would redo the same regex scan).
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
