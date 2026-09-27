/**
 * No `cd` PWD - Modify system prompt to prevent CWD redundancy in shell commands.
 *
 * Hooks `before_agent_start` and ensures the prompt carries a section forbidding `cd`-into-CWD
 * shell command prefixes. Pi's prompt already states the resolved CWD, but ships no explicit
 * instruction against `cd`-prefixing it.
 *
 * The section specifies a literal path, so an inherited one (subagent receives its parent's prompt
 * verbatim) is rewritten for the current session's CWD instead of pointing at the parent's CWD.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Target section heading and first line prefix.
// These are used as markers for guarding against duplication and subagent inheritance.
const SECTION_HEADING = "# Avoid Redundant CWD Prefix in Shell Commands";
const SECTION_LINE1_PREFIX = "Current working directory (absolute path):";

/**
 * Ensure the system prompt carries the working-directory section for `cwd`.
 * Removes CWD snippet that Pi adds to the system prompt by default.
 *
 * @param systemPrompt - Current resolved system prompt.
 * @param cwd - Resolved current working directory.
 * @returns The system prompt with the target section present.
 */
function ensureCWDSectionInSystemPrompt(systemPrompt: string, cwd: string): string {
    // Construct the CWD section for the system prompt
    const section_lines = [
        SECTION_HEADING,
        "",
        `${SECTION_LINE1_PREFIX} ${cwd}.`,
        `Shell commands already execute in \`${cwd}\`. NEVER prefix a command with \`cd\` into the`,
        `current working directory - neither \`cd $(pwd) &&\` nor \`cd ${cwd} &&\`.`,
        "Just run the command directly.",
    ];
    const section = section_lines.join("\n");

    // Idempotency check to prevent duplication
    if (systemPrompt.includes(section)) {
        return systemPrompt;
    }

    // Handle stale section contents due to system prompt inheritance by subagent
    // A child agent may run in a different working directory than the parent agent
    // NOTE: This is probably for gotgenes subagent implementation. Left for future reference.
    const lines = systemPrompt.split("\n");
    const heading = lines.indexOf(SECTION_HEADING);
    if (heading !== -1 && lines[heading + 2]?.startsWith(SECTION_LINE1_PREFIX)) {
        lines.splice(heading, section_lines.length, ...section_lines);
        return lines.join("\n");
    }

    // Pi already states resolved CWD; its system prompt ends with the below footer, and that line
    // survives downstream shaping (e.g. pi-anthropic-auth, which rewrites the preamble span).
    // Remove this existing CWD snippet that Pi adds by default
    const pi_cwd_line = lines.indexOf(`Current working directory: ${cwd}`);
    if (pi_cwd_line !== -1) {
        lines.splice(pi_cwd_line - 1, 2);
    }

    return `${lines.join("\n")}\n\n${section}`;
}

export default function (pi: ExtensionAPI): void {
    pi.on("before_agent_start", (event, ctx) => ({
        systemPrompt: ensureCWDSectionInSystemPrompt(event.systemPrompt, ctx.cwd),
    }));
}
