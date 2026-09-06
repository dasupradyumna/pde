/**
 * Shared types for the develop-feature extension's session-persisted state machine.
 */

export interface State {
    feature: string;
    phase: string;
}

export const TRANSIENT_PHASES = ["clarifying", "planning", "implementing"] as const;
export type TransientPhase = (typeof TRANSIENT_PHASES)[number];

/** Parse an "implemented:X/Y" phase string into its numeric parts. */
export function parseImplementedPhase(phase: string): { x: number; y: number } | undefined {
    const match = /^implemented:(\d+)\/(\d+)$/.exec(phase);
    if (!match) return undefined;
    return { x: Number(match[1]), y: Number(match[2]) };
}

export function isImplementedPhase(phase: string): boolean {
    return parseImplementedPhase(phase) !== undefined;
}

export function formatImplementedPhase(x: number, y: number): string {
    return `implemented:${x}/${y}`;
}
