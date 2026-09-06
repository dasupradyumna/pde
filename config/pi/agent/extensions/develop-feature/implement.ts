/**
 * `/implement` command: the third phase of the develop-feature workflow. Picks the
 * next pending slice from PLAN.md and hands it to the agent with an unrestricted
 * (within [read, bash, edit, write]) implementation turn.
 */

import { existsSync } from "node:fs";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { getState, persistState } from "./state.ts";
import { applyToolsForCurrentPhase } from "./phase-tools.ts";
import { navigateToSessionStart } from "./session-nav.ts";
import { listArtifactSlugsWithFile, planPath, planRelativePath, specRelativePath } from "./slug.ts";
import {
    findFirstPendingSlice,
    getSliceDetail,
    loadPlanStatusList,
    writeSliceState,
} from "./plan-format.ts";
import { isImplementedPhase, parseImplementedPhase } from "./types.ts";

function buildImplementKickoff(
    slug: string,
    sliceNumber: number,
    sliceTitle: string,
    sliceDetail: string | undefined,
): string {
    if (!sliceDetail || sliceDetail.length == 0) {
        sliceDetail = "(no additional detail provided for this slice)";
    }

    return `Implement slice ${sliceNumber} of the plan for "${slug}": **${sliceTitle}**

${sliceDetail}

Follow test-driven development: write tests first, then implement the minimum code needed to
make them pass, run the tests, and repeat until everything is green.

\`${specRelativePath(slug)}\` and \`${planRelativePath(slug)}\` are available via \`read\` if you
need more context on the overall feature or this slice's place in it.

IMPORTANT: Do NOT run \`git commit\`, \`git push\`, or any other command that mutates git history.
The user will review your changes and commit separately via \`/commit\` once this slice is ready.`;
}

export function registerImplement(pi: ExtensionAPI): void {
    pi.registerCommand("implement", {
        description: "Implement the next pending slice of the plan",
        getArgumentCompletions: (prefix) => {
            return listArtifactSlugsWithFile(process.cwd(), "PLAN.md", prefix).map((slug) => ({
                value: slug,
                label: slug,
            }));
        },
        handler: async (args, ctx) => {
            const state = getState(ctx);
            let slug: string;

            if (state === undefined) {
                const trimmed = args.trim();
                if (trimmed.length === 0) {
                    ctx.ui.notify("Usage: /implement <feature-slug>", "warning");
                    return;
                }
                slug = trimmed;
            } else if (state.phase === "planned") {
                if (args.trim().length > 0) {
                    ctx.ui.notify(
                        "No arguments expected once a feature has been planned in this session.",
                        "warning",
                    );
                    return;
                }
                slug = state.feature;
            } else if (isImplementedPhase(state.phase)) {
                const progress = parseImplementedPhase(state.phase)!;
                if (progress.x >= progress.y) {
                    ctx.ui.notify(
                        `All slices for "${state.feature}" are already implemented and committed.`,
                        "warning",
                    );
                    return;
                }
                if (args.trim().length > 0) {
                    ctx.ui.notify(
                        "No arguments expected once a feature has been planned in this session.",
                        "warning",
                    );
                    return;
                }
                slug = state.feature;
            } else if (state.phase === "implementing") {
                ctx.ui.notify("A slice is currently pending review. Run /commit first.", "warning");
                return;
            } else {
                ctx.ui.notify(
                    `\`/implement\` is not available right now (current phase: "${state.phase}").`,
                    "warning",
                );
                return;
            }

            const plan = planPath(ctx.cwd, slug);
            if (!existsSync(plan)) {
                ctx.ui.notify(
                    `No PLAN.md found for "${slug}". Run /plan first, or check the slug.`,
                    "warning",
                );
                return;
            }

            const loaded = await loadPlanStatusList(plan);
            if (!loaded.ok) {
                ctx.ui.notify(`${loaded.reason} Cannot pick a slice.`, "warning");
                return;
            }
            const { content, statusList } = loaded.plan;

            const pending = findFirstPendingSlice(statusList);
            if (!pending) {
                ctx.ui.notify("No pending slices left in PLAN.md.", "warning");
                return;
            }

            const detail = getSliceDetail(content, pending.number);
            await writeSliceState(plan, content, pending.number, "-");

            await navigateToSessionStart(pi, ctx);
            persistState(pi, { feature: slug, phase: "implementing" });
            applyToolsForCurrentPhase(pi, ctx);
            pi.sendUserMessage(buildImplementKickoff(slug, pending.number, pending.title, detail));
        },
    });
}
