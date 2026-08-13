export type RefinementMode = "clarify" | "explore";

export type RefinementInput =
  | { action: "switch"; mode: RefinementMode }
  | { action: "write" }
  | { action: "stop" }
  | { action: "message"; text: string };

export function parseRefinementInput(input: string): RefinementInput {
  const text = input.trim();
  const normalized = text.toLowerCase().replace(/[.!?]+$/, "").trim();
  switch (normalized) {
    case "/clarify":
      return { action: "switch", mode: "clarify" };
    case "/explore":
      return { action: "switch", mode: "explore" };
    case "/write":
      return { action: "write" };
    case "/stop":
      return { action: "stop" };
  }

  const instruction = normalized.replace(/^(please|let['’]s|can you|could you|would you)\s+/, "");
  if (/^(switch|change|move|go|return) to (clarification|clarify) mode$/.test(instruction)
    || /^(enter|start|begin) (clarification|clarify) mode$/.test(instruction)) {
    return { action: "switch", mode: "clarify" };
  }
  if (/^(switch|change|move|go|return) to (exploration|explore) mode$/.test(instruction)
    || /^(enter|start|begin) (exploration|explore) mode$/.test(instruction)) {
    return { action: "switch", mode: "explore" };
  }
  if (/^(start|begin|enter|move to|switch to|proceed to) (the )?(writing|write)( stage| mode)?( the)?( specification| spec| plan)?$/.test(instruction)
    || /^(write|draft) (the )?(specification|spec|plan)$/.test(instruction)) {
    return { action: "write" };
  }
  if (/^(stop|end|cancel|exit)( the)? workflow$/.test(instruction)) return { action: "stop" };

  return { action: "message", text };
}
