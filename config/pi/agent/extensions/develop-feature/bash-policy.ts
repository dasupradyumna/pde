/**
 * Composable bash denylists + confirm gate, applied per-phase during gated phases of
 * the develop-feature state machine.
 */

import {
    isToolCallEventType,
    type ExtensionAPI,
    type ExtensionContext,
    type ToolCallEvent,
    type ToolCallEventResult,
} from "@earendil-works/pi-coding-agent";
import { getState } from "./state.ts";

// Applies to every gated phase (clarifying, planning, implementing).
export const BASH_DENYLIST_BASE: RegExp[] = [
    // Fork bomb
    /:\(\)\s*\{\s*:\|:&\s*\};:/,
    // Destructive file-system mutation
    /\bdd\b/i,
    /\bmkfs(\.\w+)?\b/i,
    /\brm\s+(-\w*r\w*f\w*|-\w*f\w*r\w*|--recursive\b.*--force\b|--force\b.*--recursive\b)/i,
    /\bshred\b/i,
    // Privilege Elevation
    /\bsudo\b/i,
    /\bsu\b/i,
    // System power commands
    /\b(shutdown|reboot|halt|poweroff)\b/i,
    /\b(kill|pkill|killall)\b/i,
    // Download & pipe to shell
    /\b(curl|wget)\b.*\|\s*(sh|bash|zsh)\b/i,
    // Git history mutation
    /\bgit\s+(commit|push|add|reset|checkout|merge|rebase|stash|cherry-pick|revert|tag|branch|clean|init|rm)\b/i,
    // Interactive editors would hang a tool call
    /\b(n?vim?|nano|emacs|code|subl)\b/i,
];

// Additional denied shell commands for "clarifying" and "planning" phases.
export const BASH_DENYLIST_STRICT: RegExp[] = [
    // File-system mutation
    /\bcp\b/i,
    /\bln\b/i,
    /\bmkdir\b/i,
    /\bmv\b/i,
    /\brm\b/i,
    /\brmdir\b/i,
    /\btee\b/i,
    /\btouch\b/i,
    /\btruncate\b/i,
    // System user group mutation
    /\bchgrp\b/i,
    /\bchmod\b/i,
    /\bchown\b/i,
    // System control
    /\bservice\s+\S+\s+(start|stop|restart)/i,
    /\bsystemctl\s+(start|stop|restart|enable|disable)/i,
    // Shell redirection
    /(^|[^<])>(?!>)/,
    />>/,
    // Package management
    /\bapt(-get)?\s+(install|remove|purge|update|upgrade)/i,
    /\bbrew\s+(install|uninstall|upgrade)/i,
    /\bnpm\s+(install|uninstall|update|ci|link|publish)/i,
    /\bpip\s+(install|uninstall)/i,
    /\bpnpm\s+(add|remove|install|publish)/i,
    /\byarn\s+(add|remove|install|publish)/i,
];

// Commands pre-approved to skip the interactive confirm.
export const BASH_ALLOWLIST: RegExp[] = [
    /\becho\b/i,
    /\bfd\b/i,
    /\bgit\s+(diff|status)\b/i,
    /\bhead\b/i,
    /\brg\b/i,
    /\bwc\b/i,
];

const PHASE_BASH_POLICY: Record<string, "strict" | "base"> = {
    clarifying: "strict",
    planning: "strict",
    implementing: "base",
};

/** Register once (in index.ts) via pi.on("tool_call", createBashGate(pi)). */
export function createBashGate(pi: ExtensionAPI) {
    return async (
        event: ToolCallEvent,
        ctx: ExtensionContext,
    ): Promise<ToolCallEventResult | void> => {
        if (!isToolCallEventType("bash", event)) return;
        const state = getState(ctx);
        const policy = state ? PHASE_BASH_POLICY[state.phase] : undefined;
        if (!policy) return; // not in a gated phase - no restriction

        const command = event.input.command;
        const denylist =
            policy === "strict"
                ? [...BASH_DENYLIST_BASE, ...BASH_DENYLIST_STRICT]
                : BASH_DENYLIST_BASE;

        if (denylist.some((rx) => rx.test(command))) {
            return {
                block: true,
                reason: `develop-feature: command blocked by "${policy}" policy.\nCommand: ${command}`,
            };
        }
        if (BASH_ALLOWLIST.some((rx) => rx.test(command))) return;

        const ok = await ctx.ui.confirm("develop-feature", `Allow bash command?\n${command}`);
        if (!ok) return { block: true, reason: "develop-feature: command declined by user." };
    };
}
