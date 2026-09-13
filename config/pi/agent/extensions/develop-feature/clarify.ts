/**
 * `/clarify` command + `write_spec` tool: the first phase of the develop-feature
 * workflow. Turns a free-text feature request into a clarifying-questions
 * conversation, ending with a written SPEC.md.
 */

import { dirname } from "node:path";
import { mkdir, writeFile } from "node:fs/promises";
import { Type } from "typebox";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { withFileMutationQueue } from "@earendil-works/pi-coding-agent";
import { getState, persistState } from "./state.ts";
import { applyToolsForCurrentPhase } from "./phase-tools.ts";
import { navigateToSessionStart } from "./session-nav.ts";
import { slugifyFeature, specPath, specRelativePath } from "./slug.ts";

const FEATURE_TITLE_MODEL = "anthropic/claude-haiku-4-5";
const MAX_FALLBACK_TITLE_LENGTH = 30;

function buildFeatureTitlePrompt(request: string): string {
    return `Feature request:
"""
${request}
"""

Output ONLY the shortest representative title for this feature request: strictly AT MOST
${MAX_FALLBACK_TITLE_LENGTH} characters, no quotes, no punctuation, no markdown, no commentary.`;
}

async function generateFeatureTitle(
    pi: ExtensionAPI,
    ctx: ExtensionContext,
    request: string,
): Promise<string> {
    const fallback = request.trim().slice(0, MAX_FALLBACK_TITLE_LENGTH);
    try {
        const result = await pi.exec(
            "pi",
            [
                "-p",
                "--no-session",
                "--model",
                FEATURE_TITLE_MODEL,
                "--no-tools",
                "--approve",
                buildFeatureTitlePrompt(request),
            ],
            { cwd: ctx.cwd },
        );
        const title = result.stdout.trim();
        if (result.code !== 0 || title.length === 0) return fallback;
        return title;
    } catch {
        return fallback;
    }
}

function buildClarifyKickoff(request: string): string {
    return `The user wants to develop a new feature. Their request:
"""
${request}
"""

Your job right now is to turn this into a clear, complete SPEC.md through a back-and-forth
clarifying conversation. Follow these rules:

- Before asking anything, use \`read\`/\`bash\` to explore the existing codebase so your questions
  are grounded in how this project actually works (structure, conventions, and existing related
  features) rather than generic.
- Ask clarifying questions in a batch. NEVER ask questions one at a time. If more clarification is
  required after user answers a batch, ask another batch of follow-up questions.
- Focus your questions on scope (what's in/out), edge cases, constraints (technical, compatibility,
  performance), and success criteria (how we'll know this is done and correct).
- Keep going until the requirements are genuinely clear and complete enough to write a precise,
  unambiguous SPEC.md.
- Do NOT call \`write_spec\` until the user has explicitly confirmed the requirements are final and
  they're ready for you to write the spec.
- When the user confirms, call \`write_spec\` exactly once with the full SPEC.md content in
  Markdown. Note that \`write_spec\` takes a single \`content\` parameter (no path or feature name
  parameter - the destination is already fixed for this session).`;
}

function buildClarifyFeedbackKickoff(feedback: string, specRelPath: string): string {
    return `The user has feedback on the current SPEC.md (\`${specRelPath}\`):
"""
${feedback}
"""

Discuss and refine as needed, following the same rules as before (grounded in the codebase, etc.),
then call \`write_spec\` again with the complete, updated SPEC.md after the user approves it.`;
}

export function registerClarify(pi: ExtensionAPI): void {
    pi.registerCommand("clarify", {
        description:
            "Start clarifying a new feature request, or " +
            "revise existing spec for the current one with feedback",
        handler: async (args, ctx) => {
            const state = getState(ctx);

            if (state === undefined) {
                const request = args.trim();
                if (request.length === 0) {
                    ctx.ui.notify("Usage: /clarify <feature request>", "warning");
                    return;
                }

                const title = await generateFeatureTitle(pi, ctx, request);
                const slug = slugifyFeature(title);
                await navigateToSessionStart(pi, ctx);
                persistState(pi, { feature: slug, phase: "clarifying" });
                applyToolsForCurrentPhase(pi, ctx);
                pi.sendUserMessage(buildClarifyKickoff(request));
            } else if (state.phase === "clarified") {
                const feedback = args.trim();
                if (feedback.length === 0) {
                    ctx.ui.notify("Usage: /clarify <feedback>", "warning");
                    return;
                }

                persistState(pi, { feature: state.feature, phase: "clarifying" });
                applyToolsForCurrentPhase(pi, ctx);
                pi.sendUserMessage(
                    buildClarifyFeedbackKickoff(feedback, specRelativePath(state.feature)),
                );
            } else {
                ctx.ui.notify(
                    `\`/clarify\` is not available right now (current phase: "${state.phase}").`,
                    "warning",
                );
            }
        },
    });

    pi.registerTool({
        name: "write_spec",
        label: "write-spec",
        description:
            "Write the final SPEC.md for the feature currently being clarified. Call this exactly" +
            " once, only after the user has explicitly confirmed the requirements are final.",
        parameters: Type.Object({
            content: Type.String({ description: "Full SPEC.md content in Markdown" }),
        }),
        async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
            const state = getState(ctx);
            if (!state || state.phase !== "clarifying") {
                throw new Error("write_spec is only usable while `/clarify` is in progress.");
            }

            const path = specPath(ctx.cwd, state.feature);
            await withFileMutationQueue(path, async () => {
                await mkdir(dirname(path), { recursive: true });
                await writeFile(path, params.content, "utf8");
            });

            persistState(pi, { feature: state.feature, phase: "clarified" });
            applyToolsForCurrentPhase(pi, ctx);

            return {
                content: [{ type: "text", text: `SPEC.md written to: ${path}` }],
                details: undefined,
            };
        },
    });
}
