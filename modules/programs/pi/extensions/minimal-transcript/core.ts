export interface DiffEntryData {
  path: string;
  patch: string;
  additions: number;
  deletions: number;
  action: "created" | "updated";
}

export function countPatchChanges(patch: string): { additions: number; deletions: number } {
  let additions = 0;
  let deletions = 0;
  let inHunk = false;

  for (const line of patch.split("\n")) {
    if (line.startsWith("@@")) {
      inHunk = true;
    } else if (inHunk && line.startsWith("+")) {
      additions++;
    } else if (inHunk && line.startsWith("-")) {
      deletions++;
    }
  }

  return { additions, deletions };
}

export function diffSummary(data: DiffEntryData): string {
  return `${data.action === "created" ? "created" : "updated"} ${data.path} +${data.additions} −${data.deletions}`;
}
