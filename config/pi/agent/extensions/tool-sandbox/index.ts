/**
 * tool-sandbox extension: always-on, global validation of risky built-in tool
 * calls (`edit`, `write`, `bash`) before execution. See SPEC.md /
 * agent/extensions/tool-sandbox/README.md for the full policy.
 *
 * Stateless and unconditional — unlike develop-feature's bash-policy.ts, this
 * applies in every session regardless of any other extension's state.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { createPathGate } from "./path.ts";
import { createShellGate } from "./shell.ts";

export default function (pi: ExtensionAPI): void {
    pi.on("tool_call", createPathGate());
    pi.on("tool_call", createShellGate(pi));
}
