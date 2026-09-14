/**
 * `/plan` command + `write_plan` tool: the second phase of the develop-feature workflow.
 * Turns a written SPEC.md into a slice-by-slice PLAN.md.
 */

import { existsSync } from "node:fs";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { navigateToSessionStart, readState, transitionTo } from "../workflow.ts";
import {
    listArtifactSlugsWithFile,
    planPath,
    planRelativePath,
    registerWriteArtifactTool,
    specPath,
    specRelativePath,
    validatePlan,
} from "../artifacts.ts";

function buildPlanKickoff(slug: string, specRelPath: string): string {
    return `Read \`${specRelPath}\` now - it's the finalized spec for this feature.

Your job is to break it down into a PLAN.md: a sequence of vertical, independent,
sequentially-implementable slices. Each slice should be a coherent, reviewable, shippable
unit of work that builds on the previous ones - not a horizontal layer (for e.g. prefer
"user can submit the login form end-to-end" over "add backend routes" then "add frontend
forms" as separate slices unless there's a good reason to split that way).

When you're ready, call \`write_plan\` exactly once with the full PLAN.md content. It takes a
single \`content\` parameter and enforces this EXACT format:

\`\`\`markdown
# <feature-title>

<overall-feature-description>

## Status

- [ ] 1. <slice1 title>
- [ ] 2. <slice2 title>

## Slice 1: <slice1 title>
<description / acceptance criteria for this slice>

## Slice 2: <slice2 title>
<description / acceptance criteria for this slice>
\`\`\`

Rules for this format:
- The "## Status" section must be present, with one "- [ ] N. <title>" line per slice.
- Slice numbers in the status list must start at 1 and be consecutive with no gaps.
- Every status checkbox must start as "[ ]" (unchecked).
- Every slice number in the status list needs a matching "## Slice N: <title>" heading
  later in the document, with the EXACT SAME title text as in the status list.
- Every "## Slice N: ..." heading in the document must appear in the status list too
  (no extra/stray/missing headings), and each slice number must appear exactly once (no
  duplicate headings).

If \`write_plan\` rejects your content, it will tell you exactly what's wrong (e.g. a
numbering gap, a title mismatch, a missing or duplicate heading) - fix it and call
\`write_plan\` again in the same turn.`;
}

function buildPlanFeedbackKickoff(feedback: string, planRelPath: string): string {
    return `The user has feedback on the current PLAN.md (\`${planRelPath}\`):
"""
${feedback}
"""

Discuss and refine as needed, then call \`write_plan\` again with the complete, updated PLAN.md
(the same required format rules from before still apply) once the user confirms it's final.`;
}

export function registerPlan(pi: ExtensionAPI): void {
    pi.registerCommand("plan", {
        description:
            "Plan the currently clarified feature into implementation slices, or " +
            "revise the plan for the current one with feedback",
        getArgumentCompletions: (prefix) => {
            // Cheap heuristic: we can't read session state here (no ctx), so we always
            // offer completions from .artifacts/*/SPEC.md - harmless when args aren't
            // expected (that branch is guarded/validated in the handler regardless).
            return listArtifactSlugsWithFile(process.cwd(), "SPEC.md", prefix).map((slug) => ({
                value: slug,
                label: slug,
            }));
        },
        handler: async (args, ctx) => {
            const state = readState(ctx);
            let slug: string;

            if (state === undefined) {
                const trimmed = args.trim();
                if (trimmed.length === 0) {
                    ctx.ui.notify("Usage: /plan <feature-slug>", "warning");
                    return;
                }
                slug = trimmed;
            } else if (state.phase === "clarified") {
                if (args.trim().length > 0) {
                    ctx.ui.notify(
                        "No arguments expected once a feature has been clarified in this session.",
                        "warning",
                    );
                    return;
                }
                slug = state.feature;
            } else if (state.phase === "planned") {
                const feedback = args.trim();
                if (feedback.length === 0) {
                    ctx.ui.notify("Usage: /plan <feedback>", "warning");
                    return;
                }

                transitionTo(pi, ctx, { feature: state.feature, phase: "planning" });
                pi.sendUserMessage(
                    buildPlanFeedbackKickoff(feedback, planRelativePath(state.feature)),
                );
                return;
            } else {
                ctx.ui.notify(
                    `\`/plan\` is not available right now (current phase: "${state.phase}").`,
                    "warning",
                );
                return;
            }

            const spec = specPath(ctx.cwd, slug);
            if (!existsSync(spec)) {
                ctx.ui.notify(
                    `No SPEC.md found for "${slug}". Run /clarify first, or check the slug.`,
                    "warning",
                );
                return;
            }

            await navigateToSessionStart(pi, ctx);
            transitionTo(pi, ctx, { feature: slug, phase: "planning" });
            pi.sendUserMessage(buildPlanKickoff(slug, specRelativePath(slug)));
        },
    });

    registerWriteArtifactTool(pi, {
        name: "write_plan",
        label: "write-plan",
        description:
            "Write the final PLAN.md for the feature currently being planned. Call this exactly " +
            "once, with content matching the required PLAN.md format.",
        contentDescription: "Full PLAN.md content in Markdown",
        requiredPhase: "planning",
        guardMessage: "write_plan is only usable while /plan is in progress.",
        validate: validatePlan,
        getPath: planPath,
        nextPhase: "planned",
        successMessage: (path) => `PLAN.md written to ${path}`,
    });
}
