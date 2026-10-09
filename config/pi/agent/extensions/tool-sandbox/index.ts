/**
 * tool-sandbox extension: always-on, global validation of risky built-in tool
 * calls (`edit`, `write`, `bash`) before execution. See SPEC.md /
 * agent/extensions/tool-sandbox/README.md for the full policy.
 *
 * Stateless and unconditional — applies in every session regardless of any
 * other extension's state.
 *
 * A single `tool_call` handler dispatches to the per-tool gate logic: `pathGate`
 * (path.ts) for `edit`/`write`, `shellGate` (shell.ts) for `bash`. No-ops for
 * every other tool.
 */

import type {
    ExtensionAPI,
    ExtensionContext,
    ToolCallEvent,
    ToolCallEventResult,
} from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";
import { pathGate } from "./path.ts";
import { shellGate } from "./shell.ts";

export default function (pi: ExtensionAPI): void {
    pi.on(
        "tool_call",
        (
            event: ToolCallEvent,
            ctx: ExtensionContext,
        ): Promise<ToolCallEventResult | undefined> | ToolCallEventResult | undefined => {
            if (isToolCallEventType("edit", event) || isToolCallEventType("write", event)) {
                return pathGate(event, ctx);
            }
            if (isToolCallEventType("bash", event)) {
                return shellGate(event, ctx);
            }
            return undefined;
        },
    );
}
