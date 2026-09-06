/**
 * `/plan` command + `write_plan` tool: the second phase of the develop-feature workflow.
 * Turns a written SPEC.md into a slice-by-slice PLAN.md.
 */

import { existsSync } from "node:fs";
import { dirname } from "node:path";
import { mkdir, writeFile } from "node:fs/promises";
import { Type } from "typebox";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { withFileMutationQueue } from "@earendil-works/pi-coding-agent";
import { getState, persistState } from "./state.ts";
import { applyToolsForCurrentPhase } from "./phase-tools.ts";
import { navigateToSessionStart } from "./session-nav.ts";
import { listArtifactSlugsWithFile, planPath, specPath, specRelativePath } from "./slug.ts";
import { validatePlan } from "./plan-format.ts";

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

export function registerPlan(pi: ExtensionAPI): void {
    pi.registerCommand("plan", {
        description: "Plan the currently clarified feature into implementation slices",
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
            const state = getState(ctx);
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
            persistState(pi, { feature: slug, phase: "planning" });
            applyToolsForCurrentPhase(pi, ctx);
            pi.sendUserMessage(buildPlanKickoff(slug, specRelativePath(slug)));
        },
    });

    pi.registerTool({
        name: "write_plan",
        label: "write-plan",
        description:
            "Write the final PLAN.md for the feature currently being planned. Call this exactly " +
            "once, with content matching the required PLAN.md format.",
        parameters: Type.Object({
            content: Type.String({ description: "Full PLAN.md content in Markdown" }),
        }),
        async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
            const state = getState(ctx);
            if (!state || state.phase !== "planning") {
                throw new Error("write_plan is only usable while /plan is in progress.");
            }

            const validation = validatePlan(params.content);
            if (!validation.ok) {
                throw new Error(validation.reason);
            }

            const path = planPath(ctx.cwd, state.feature);
            await withFileMutationQueue(path, async () => {
                await mkdir(dirname(path), { recursive: true });
                await writeFile(path, params.content, "utf8");
            });

            persistState(pi, { feature: state.feature, phase: "planned" });
            applyToolsForCurrentPhase(pi, ctx);

            return {
                content: [{ type: "text", text: `PLAN.md written to ${path}` }],
                details: undefined,
            };
        },
    });
}
