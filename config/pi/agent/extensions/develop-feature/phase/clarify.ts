/**
 * `/clarify` command + `write_spec` tool: the first phase of the develop-feature
 * workflow. Turns a free-text feature request into a clarifying-questions
 * conversation, ending with a written SPEC.md.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { navigateToSessionStart, readState, transitionTo } from "../workflow.ts";
import { registerWriteArtifactTool, slugifyFeature, specPath, specRelativePath } from "../artifacts.ts";

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
            const state = readState(ctx);

            if (state === undefined) {
                const request = args.trim();
                if (request.length === 0) {
                    ctx.ui.notify("Usage: /clarify <feature request>", "warning");
                    return;
                }

                const title = await generateFeatureTitle(pi, ctx, request);
                const slug = slugifyFeature(title);
                await navigateToSessionStart(pi, ctx);
                transitionTo(pi, ctx, { feature: slug, phase: "clarifying" });
                pi.sendUserMessage(buildClarifyKickoff(request));
            } else if (state.phase === "clarified") {
                const feedback = args.trim();
                if (feedback.length === 0) {
                    ctx.ui.notify("Usage: /clarify <feedback>", "warning");
                    return;
                }

                transitionTo(pi, ctx, { feature: state.feature, phase: "clarifying" });
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

    registerWriteArtifactTool(pi, {
        name: "write_spec",
        label: "write-spec",
        description:
            "Write the final SPEC.md for the feature currently being clarified. Call this exactly" +
            " once, only after the user has explicitly confirmed the requirements are final.",
        contentDescription: "Full SPEC.md content in Markdown",
        requiredPhase: "clarifying",
        guardMessage: "write_spec is only usable while `/clarify` is in progress.",
        getPath: specPath,
        nextPhase: "clarified",
        successMessage: (path) => `SPEC.md written to: ${path}`,
    });
}
