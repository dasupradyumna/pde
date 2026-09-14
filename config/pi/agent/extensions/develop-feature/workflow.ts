/**
 * State-machine core for the develop-feature extension: the persisted `State` shape,
 * the `implemented:X/Y` phase-string helpers, the phase-name catalog and per-phase
 * tool/status application, the persisted-state read/write pair, session-start
 * navigation, and a plain state-transition helper composing the latter two.
 */

import type {
    ExtensionAPI,
    ExtensionCommandContext,
    ExtensionContext,
} from "@earendil-works/pi-coding-agent";

export interface State {
    feature: string;
    phase: string;
}

/** Parse an "implemented:X/Y" phase string into its numeric parts. */
export function parseImplementedPhase(phase: string): { x: number; y: number } | undefined {
    const match = /^implemented:(\d+)\/(\d+)$/.exec(phase);
    if (!match) return undefined;
    return { x: Number(match[1]), y: Number(match[2]) };
}

export function isImplementedPhase(phase: string): boolean {
    return parseImplementedPhase(phase) !== undefined;
}

export function formatImplementedPhase(x: number, y: number): string {
    return `implemented:${x}/${y}`;
}

// The set of transient (gated, in-progress) phase names, shared by `PHASE_TOOLS` here and
// `PHASE_BASH_POLICY` in bash-policy.ts.
export const TRANSIENT_PHASES = ["clarifying", "planning", "implementing"] as const;
export type TransientPhase = (typeof TRANSIENT_PHASES)[number];

/**
 * Single persisted signal driving the whole develop-feature state machine: a
 * session custom entry of type "develop-feature-state". Appended on every
 * transition, never mutated; the latest entry is the current value.
 */
export const STATE_ENTRY_TYPE = "develop-feature";

export function readState(ctx: ExtensionContext): State | undefined {
    const entries = ctx.sessionManager.getEntries();
    for (let i = entries.length - 1; i >= 0; i--) {
        const entry = entries[i];
        if (entry.type === "custom" && entry.customType === STATE_ENTRY_TYPE) {
            return entry.data as State | undefined;
        }
    }
    return undefined;
}

export function writeState(pi: ExtensionAPI, data: State): void {
    pi.appendEntry(STATE_ENTRY_TYPE, data);
}

export const PHASE_TOOLS: Record<TransientPhase, string[]> = {
    clarifying: ["read", "bash", "write_spec"],
    planning: ["read", "bash", "write_plan"],
    implementing: ["read", "bash", "edit", "write", "write_commit"],
};

const STATUS_KEY = "develop-feature";

/**
 * Apply the correct active-tool set and status-line text for whatever the current persisted phase
 * is. Call this: (a) from session_start (covers startup/reload/resume/fork - this alone also
 * neutralizes write_spec/write_plan's auto-activation on registration), and (b) immediately after
 * every writeState() call in every command/tool.
 */
export function applyToolsForCurrentPhase(pi: ExtensionAPI, ctx: ExtensionContext): void {
    const state = readState(ctx);
    const restricted = state ? PHASE_TOOLS[state.phase as TransientPhase] : undefined;
    pi.setActiveTools(restricted ?? ["read", "bash", "edit", "write"]);
    ctx.ui.setStatus(
        STATUS_KEY,
        state ? ctx.ui.theme.fg("success", `${state.feature} (${state.phase})`) : undefined,
    );
}

/**
 * Plain transition helper: writes the new state and applies its tools/status in one call,
 * without re-reading state back from the session. Each phase/*.ts file calls this directly at
 * its own writeState+applyToolsForCurrentPhase call sites.
 */
export function transitionTo(pi: ExtensionAPI, ctx: ExtensionContext, state: State): void {
    writeState(pi, state);
    applyToolsForCurrentPhase(pi, ctx);
}

/**
 * Navigate to the true root of the session tree (parentId === null), which resets
 * the leaf to empty (verified against agent-session.js: navigateTree() sets
 * newLeafId = targetEntry.parentId when the target is a user/custom message; for the
 * root entry that parentId is null, which triggers resetLeaf() internally - i.e. a
 * genuinely empty context, not "context including entry 1"). Skips navigation
 * entirely if the session has no entries yet (nothing to reset). No summarization.
 */
export async function navigateToSessionStart(
    pi: ExtensionAPI,
    ctx: ExtensionCommandContext,
): Promise<void> {
    const root = ctx.sessionManager.getEntries().find((e) => e.parentId === null);
    if (!root) return;
    await ctx.navigateTree(root.id, { summarize: false });
}
