/**
 * develop-feature extension: registers /clarify, /plan, /implement for a
 * Clarify -> Plan -> Implement feature-development workflow, backed
 * entirely by a single session-persisted state machine.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { registerClarify } from "./clarify.ts";
import { registerPlan } from "./plan.ts";
import { registerImplement } from "./implement.ts";
import { createBashGate } from "./bash-policy.ts";
import { applyToolsForCurrentPhase } from "./phase-tools.ts";

export default function (pi: ExtensionAPI): void {
    registerClarify(pi);
    registerPlan(pi);
    registerImplement(pi);

    pi.on("tool_call", createBashGate(pi));

    // Single recovery/neutralization hook: covers startup, /reload, /resume, /fork,
    // and also neutralizes write_spec/write_plan's auto-activation on first load.
    pi.on("session_start", async (_event, ctx) => {
        applyToolsForCurrentPhase(pi, ctx);
    });
}
