import { existsSync, realpathSync } from "node:fs";
import { basename, dirname, isAbsolute, relative, resolve } from "node:path";

export class RefinementTargetError extends Error {
  readonly correctiveAction: string;

  constructor(message: string, correctiveAction: string) {
    super(message);
    this.name = "RefinementTargetError";
    this.correctiveAction = correctiveAction;
  }
}

export function canonicalTarget(cwd: string, path: string): string {
  const absolute = isAbsolute(path) ? resolve(path) : resolve(cwd, path);
  if (existsSync(absolute)) return realpathSync(absolute);
  const missing: string[] = [];
  let current = absolute;
  while (!existsSync(current)) {
    const parent = dirname(current);
    if (parent === current) return absolute;
    missing.unshift(basename(current));
    current = parent;
  }
  return resolve(realpathSync(current), ...missing);
}

export function approvedTargets(cwd: string, location: string, paths: string[]): string[] {
  const root = canonicalTarget(cwd, location);
  return paths.map((path) => {
    const target = canonicalTarget(cwd, path);
    const rel = relative(root, target);
    if (rel.startsWith("..") || isAbsolute(rel)) {
      throw new RefinementTargetError(
        `Proposed file is outside the specification location: ${path}`,
        `Regenerate the proposal with only specification files under ${location} in payload.files. Move implementation and documentation paths into the design or integration text.`,
      );
    }
    return target;
  });
}

export function approvedPlanTargets(
  cwd: string,
  location: string,
  specificationPath: string,
  planPaths: string[],
): string[] {
  const [specification] = approvedTargets(cwd, location, [specificationPath]);
  if (!existsSync(specification)) {
    throw new RefinementTargetError(
      `The plan specification does not exist: ${specificationPath}`,
      "Choose an existing specification before proposing its implementation plan.",
    );
  }
  const plans = approvedTargets(cwd, location, planPaths);
  for (const plan of plans) {
    if (dirname(plan) !== dirname(specification)) {
      throw new RefinementTargetError(
        `Proposed plan is not in the same directory as its specification: ${plan}`,
        "Regenerate the proposal with every plan beside its existing specification.",
      );
    }
  }
  return plans;
}
