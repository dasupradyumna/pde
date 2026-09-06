/**
 * Tool-set-per-phase: single source of truth for which tools are active in each
 * phase of the develop-feature state machine.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { getState } from "./state.ts";

export const PHASE_TOOLS: Record<string, string[]> = {
    clarifying: ["read", "bash", "write_spec"],
    planning: ["read", "bash", "write_plan"],
    implementing: ["read", "bash", "edit", "write"],
};

/** All builtin tool names, recomputed each call (robust to future builtin additions). */
export function getDefaultToolNames(pi: ExtensionAPI): string[] {
    return pi
        .getAllTools()
        .filter((t) => t.sourceInfo.source === "builtin")
        .map((t) => t.name);
}

/**
 * Apply the correct active-tool set for whatever the current persisted phase is.
 * Call this: (a) from session_start (covers startup/reload/resume/fork - this alone
 * also neutralizes write_spec/write_plan's auto-activation on registration), and
 * (b) immediately after every persistState() call in every command/tool.
 */
export function applyToolsForCurrentPhase(pi: ExtensionAPI, ctx: ExtensionContext): void {
    const state = getState(ctx);
    const restricted = state ? PHASE_TOOLS[state.phase] : undefined;
    pi.setActiveTools(restricted ?? getDefaultToolNames(pi));
}
