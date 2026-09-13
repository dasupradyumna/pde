/**
 * `/implement` command: the third phase of the develop-feature workflow. Picks the
 * next pending slice from PLAN.md and hands it to the agent with an unrestricted
 * (within [read, bash, edit, write]) implementation turn.
 */

import { existsSync } from "node:fs";
import { Type } from "typebox";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { getState, persistState } from "./state.ts";
import { applyToolsForCurrentPhase } from "./phase-tools.ts";
import { navigateToSessionStart } from "./session-nav.ts";
import { listArtifactSlugsWithFile, planPath, planRelativePath, specRelativePath } from "./slug.ts";
import {
    computeProgress,
    findFirstPendingSlice,
    findReviewSlices,
    getSliceDetail,
    loadPlanStatusList,
    parseStatusSection,
    writeSliceState,
} from "./plan-format.ts";
import { formatImplementedPhase, isImplementedPhase, parseImplementedPhase } from "./types.ts";

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

Once implementation is complete and tests pass, summarize your changes for the user's review.
Do NOT call \`write_commit\` until the user has reviewed the changes and explicitly asks you to
commit. When ready, call \`write_commit\` exactly once with a single \`message\` parameter containing
the full commit message, written to match this project's commit conventions.`;
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
                ctx.ui.notify(
                    "A slice is currently pending review. Review the changes and ask me to " +
                        "commit it before starting a new one.",
                    "warning",
                );
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

    pi.registerTool({
        name: "write_commit",
        label: "write-commit",
        description:
            "Commit the currently implemented and reviewed slice via git. Call this exactly " +
            "once, only after user has explicitly reviewed the changes and asked you to commit.",
        parameters: Type.Object({
            message: Type.String({ description: "Full git commit message" }),
        }),
        async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
            const state = getState(ctx);
            if (!state || state.phase !== "implementing") {
                throw new Error(
                    "write_commit is only usable while a slice is pending review (i.e. right " +
                        "after /implement).",
                );
            }

            let diffResult;
            try {
                diffResult = await pi.exec("git", ["diff", "--cached", "HEAD"], { cwd: ctx.cwd });
            } catch (err) {
                throw new Error(
                    `Failed to run "git diff --cached HEAD": ${err instanceof Error ? err.message : String(err)}`,
                );
            }
            if (diffResult.code !== 0) {
                throw new Error(
                    `"git diff --cached HEAD" failed (is this a git repository?):\n${diffResult.stderr}`,
                );
            }

            const plan = planPath(ctx.cwd, state.feature);
            const loaded = await loadPlanStatusList(plan);
            if (!loaded.ok) {
                throw new Error(loaded.reason);
            }
            const { content, statusList } = loaded.plan;
            const reviewSlices = findReviewSlices(statusList);
            if (reviewSlices.length === 0) {
                throw new Error("No slice is currently pending review in PLAN.md.");
            }
            if (reviewSlices.length > 1) {
                throw new Error(
                    "PLAN.md has multiple slices pending review; fix manually before committing.",
                );
            }
            const slice = reviewSlices[0];

            const diff = diffResult.stdout;
            let committed = false;
            let commitHash: string | undefined;

            if (diff.trim() === "") {
                const proceed = await ctx.ui.confirm(
                    "Nothing to commit",
                    "git diff --cached is empty (did you forget to `git add` your changes first?) - " +
                        "update PLAN.md and session state anyway?",
                );
                if (!proceed) {
                    throw new Error(
                        "Aborted: nothing staged. `git add` your changes and ask me to commit again.",
                    );
                }
            } else {
                const commitResult = await pi.exec("git", ["commit", "-m", params.message], {
                    cwd: ctx.cwd,
                });
                if (commitResult.code !== 0) {
                    throw new Error(`"git commit" failed:\n${commitResult.stderr}`);
                }
                committed = true;

                const revParse = await pi.exec("git", ["rev-parse", "--short", "HEAD"], {
                    cwd: ctx.cwd,
                });
                if (revParse.code === 0) {
                    commitHash = revParse.stdout.trim();
                }
            }

            const newContent = await writeSliceState(plan, content, slice.number, "x");
            const newStatusList = parseStatusSection(newContent);
            const { x, y } = computeProgress(newStatusList ?? []);

            persistState(pi, { feature: state.feature, phase: formatImplementedPhase(x, y) });
            applyToolsForCurrentPhase(pi, ctx);

            let summary = committed
                ? `Committed${commitHash ? ` (${commitHash})` : ""}. Slice ${slice.number} marked done. Progress: ${x}/${y}.`
                : `No commit made (nothing staged). Slice ${slice.number} marked done. Progress: ${x}/${y}.`;
            if (x === y) {
                summary +=
                    ` All slices for "${state.feature}" are implemented and committed. Start a ` +
                    `new session to clarify or plan the next feature.`;
            }

            return {
                content: [{ type: "text", text: summary }],
                details: undefined,
            };
        },
    });
}
