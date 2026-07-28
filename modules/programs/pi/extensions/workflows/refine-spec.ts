import { createHash } from "node:crypto";

export interface SpecificationLocation {
  path: string;
  evidence: string;
  documented: boolean;
  fileCount: number;
}

export interface SpecificationChoice {
  path?: string;
  evidence?: string;
  warning?: string;
  needsUser: boolean;
}

export function chooseSpecificationLocation(locations: SpecificationLocation[]): SpecificationChoice {
  if (locations.length === 0) return { needsUser: true };
  const ranked = [...locations].sort((left, right) => {
    const documentation = Number(right.documented) - Number(left.documented);
    if (documentation !== 0) return documentation;
    return right.fileCount - left.fileCount;
  });
  const first = ranked[0];
  const second = ranked[1];
  if (!first.documented && second && first.fileCount === second.fileCount) return { needsUser: true };
  return {
    path: first.path,
    evidence: first.evidence,
    warning: locations.length > 1
      ? `The project uses several specification locations. Selected ${first.path}; split specification tracking should be fixed.`
      : undefined,
    needsUser: false,
  };
}

export interface RefinementIssue {
  title: string;
  claim: string;
  evidence: Array<{ path: string; excerpt: string }>;
  [key: string]: unknown;
}

export function fingerprintIssue(issue: RefinementIssue): string {
  const evidence = [...issue.evidence]
    .map((item) => `${item.path}\n${item.excerpt}`)
    .sort()
    .join("\n---\n");
  return createHash("sha256").update(`${issue.claim}\n${evidence}`).digest("hex");
}

export function suppressSkippedIssues(issues: RefinementIssue[], skipped: Set<string>): RefinementIssue[] {
  return issues.filter((issue) => !skipped.has(fingerprintIssue(issue)));
}
