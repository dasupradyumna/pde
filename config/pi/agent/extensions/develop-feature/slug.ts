/**
 * Feature-name slugification and artifact path helpers.
 */

import { existsSync, readdirSync } from "node:fs";
import { join, resolve } from "node:path";

export function slugifyFeature(feature: string): string {
    const slug = feature
        .trim()
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-+|-+$/g, "");
    return slug.length > 0 ? slug : "untitled-feature";
}

const ARTIFACTS_DIR_NAME = ".artifacts";
const SPEC_FILE_NAME = "SPEC.md";
const PLAN_FILE_NAME = "PLAN.md";

export function specPath(cwd: string, slug: string): string {
    return resolve(cwd, join(ARTIFACTS_DIR_NAME, slug, SPEC_FILE_NAME));
}

export function planPath(cwd: string, slug: string): string {
    return resolve(cwd, join(ARTIFACTS_DIR_NAME, slug, PLAN_FILE_NAME));
}

export function specRelativePath(slug: string): string {
    return join(ARTIFACTS_DIR_NAME, slug, SPEC_FILE_NAME);
}

export function planRelativePath(slug: string): string {
    return join(ARTIFACTS_DIR_NAME, slug, PLAN_FILE_NAME);
}

export function artifactsDir(cwd: string): string {
    return resolve(cwd, ARTIFACTS_DIR_NAME);
}

/**
 * List .artifacts/ subfolder (slug) names that contain the given file, filtered by a
 * name prefix. Used for /plan and /implement argument autocompletion.
 */
export function listArtifactSlugsWithFile(cwd: string, fileName: string, prefix: string): string[] {
    const dir = artifactsDir(cwd);
    if (!existsSync(dir)) return [];
    return readdirSync(dir, { withFileTypes: true })
        .filter((entry) => entry.isDirectory())
        .map((entry) => entry.name)
        .filter((name) => name.startsWith(prefix))
        .filter((name) => existsSync(`${dir}/${name}/${fileName}`))
        .sort();
}
