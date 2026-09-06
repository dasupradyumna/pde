/**
 * `/commit` command: the fourth phase of the develop-feature workflow. Reviews the
 * diff produced by the just-finished implementation turn, generates a commit
 * message, commits, and flips the reviewed slice from "[-]" to "[x]" in PLAN.md.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { getState, persistState } from "./state.ts";
import { applyToolsForCurrentPhase } from "./phase-tools.ts";
import { planPath } from "./slug.ts";
import {
    computeProgress,
    findReviewSlices,
    getSliceDetail,
    loadPlanStatusList,
    parseStatusSection,
    writeSliceState,
} from "./plan-format.ts";
import { formatImplementedPhase } from "./types.ts";

const COMMIT_MESSAGE_MODEL = "anthropic/claude-haiku-4-5";
const MAX_DIFF_LINES = 4000;

function truncateDiff(diff: string): string {
    const lines = diff.split("\n");
    if (lines.length <= MAX_DIFF_LINES) return diff;
    const kept = lines.slice(0, MAX_DIFF_LINES);
    return `${kept.join("\n")}\n\n... (diff truncated after ${MAX_DIFF_LINES} lines) ...`;
}

function buildCommitMessagePrompt(
    diff: string,
    sliceTitle: string,
    sliceDetail: string | undefined,
    instructions: string,
): string {
    return `Slice: ${sliceTitle}

${sliceDetail && sliceDetail.length > 0 ? sliceDetail : "(no additional slice detail)"}

${instructions.length > 0 ? `Additional instructions for the commit message (wording/scope guidance only):\n${instructions}\n\n` : ""}Diff:
\`\`\`diff
${diff}
\`\`\`

Output ONLY a concise, conventional commit message. No commentary, no markdown fences.`;
}

export function registerCommit(pi: ExtensionAPI): void {
    pi.registerCommand("commit", {
        description: "Review and commit the current slice's implementation",
        handler: async (args, ctx) => {
            const state = getState(ctx);
            if (!state || state.phase !== "implementing") {
                ctx.ui.notify(
                    `\`/commit\` is only available right after \`/implement\` (current phase: "${state?.phase ?? "none"}").`,
                    "warning",
                );
                return;
            }

            let diffResult;
            try {
                diffResult = await pi.exec("git", ["diff", "--cached", "HEAD"], { cwd: ctx.cwd });
            } catch (err) {
                ctx.ui.notify(
                    `Failed to run "git diff --cached HEAD": ${err instanceof Error ? err.message : String(err)}`,
                    "error",
                );
                return;
            }
            if (diffResult.code !== 0) {
                ctx.ui.notify(
                    `"git diff --cached HEAD" failed (is this a git repository?):\n${diffResult.stderr}`,
                    "error",
                );
                return;
            }

            const plan = planPath(ctx.cwd, state.feature);
            const loaded = await loadPlanStatusList(plan);
            if (!loaded.ok) {
                ctx.ui.notify(`${loaded.reason} Cannot determine which slice to commit.`, "error");
                return;
            }
            const { content, statusList } = loaded.plan;
            const reviewSlices = findReviewSlices(statusList);
            if (reviewSlices.length === 0) {
                ctx.ui.notify("No slice is currently pending review in PLAN.md.", "error");
                return;
            }
            if (reviewSlices.length > 1) {
                ctx.ui.notify(
                    "PLAN.md has multiple slices pending review; fix manually before committing.",
                    "error",
                );
                return;
            }
            const slice = reviewSlices[0];

            const diff = diffResult.stdout;
            let committed = false;
            let commitHash: string | undefined;

            if (diff.trim() === "") {
                const proceed = await ctx.ui.confirm(
                    "Nothing to commit",
                    "git diff is empty (did you forget to `git add` your changes first?) - update" +
                        " PLAN.md and session state anyway?",
                );
                if (!proceed) {
                    ctx.ui.notify("Aborted: nothing to commit and no changes made.", "info");
                    return;
                }
            } else {
                const sliceDetail = getSliceDetail(content, slice.number);
                const prompt = buildCommitMessagePrompt(
                    truncateDiff(diff),
                    slice.title,
                    sliceDetail,
                    args.trim(),
                );

                let genResult;
                try {
                    genResult = await pi.exec(
                        "pi",
                        [
                            "-p",
                            "--no-session",
                            "--model",
                            COMMIT_MESSAGE_MODEL,
                            "--no-tools",
                            "--approve",
                            prompt,
                        ],
                        { cwd: ctx.cwd },
                    );
                } catch (err) {
                    ctx.ui.notify(
                        `Failed to generate commit message: ${err instanceof Error ? err.message : String(err)}`,
                        "error",
                    );
                    return;
                }
                const message = genResult.stdout.trim();
                if (genResult.code !== 0 || message.length === 0) {
                    ctx.ui.notify(
                        `Commit message generation failed (exit code ${genResult.code}):\n${genResult.stderr}`,
                        "error",
                    );
                    return;
                }

                const commitResult = await pi.exec("git", ["commit", "-m", message], {
                    cwd: ctx.cwd,
                });
                if (commitResult.code !== 0) {
                    ctx.ui.notify(`"git commit" failed:\n${commitResult.stderr}`, "error");
                    return;
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

            const summary = committed
                ? `Committed${commitHash ? ` (${commitHash})` : ""}. Slice ${slice.number} marked done. Progress: ${x}/${y}.`
                : `No commit made (nothing to commit). Slice ${slice.number} marked done. Progress: ${x}/${y}.`;
            ctx.ui.notify(summary, "info");
        },
    });
}
