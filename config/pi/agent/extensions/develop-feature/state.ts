/**
 * Single persisted signal driving the whole develop-feature state machine: a
 * session custom entry of type "develop-feature-state". Appended on every
 * transition, never mutated; the latest entry is the current value.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { State } from "./types.ts";

export const STATE_ENTRY_TYPE = "develop-feature";

export function getState(ctx: ExtensionContext): State | undefined {
    const entries = ctx.sessionManager.getEntries();
    for (let i = entries.length - 1; i >= 0; i--) {
        const entry = entries[i];
        if (entry.type === "custom" && entry.customType === STATE_ENTRY_TYPE) {
            return entry.data as State | undefined;
        }
    }
    return undefined;
}

export function persistState(pi: ExtensionAPI, data: State): void {
    pi.appendEntry(STATE_ENTRY_TYPE, data);
}
