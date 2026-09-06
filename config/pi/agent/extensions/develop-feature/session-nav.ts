/**
 * Navigate-to-session-start helper: resets the active leaf to a genuinely empty
 * context before kicking off a new phase (/clarify, /plan, /implement).
 */

import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";

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
