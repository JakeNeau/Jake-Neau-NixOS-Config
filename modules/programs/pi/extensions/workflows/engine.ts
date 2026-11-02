export type SuccessorSet = string[];
export type Transitions = Record<string, SuccessorSet[]>;

function normalizedSet(set: SuccessorSet): string[] {
  return [...new Set(set)].sort();
}

// Object.hasOwn keeps an inherited key such as "constructor" from passing as a route.
export function outcomeChoices(transitions: Transitions, outcome: string): SuccessorSet[] | undefined {
  return Object.hasOwn(transitions, outcome) ? transitions[outcome] : undefined;
}

export function resolveSuccessorSet(transitions: Transitions, outcome: string): string[] | undefined {
  const choices = outcomeChoices(transitions, outcome);
  if (!choices) throw new Error(`No transition for outcome: ${outcome}`);
  return choices.length === 1 ? normalizedSet(choices[0]) : undefined;
}

export function validateRouterSelection(allowed: SuccessorSet[], selected: SuccessorSet): string[] {
  const normalized = normalizedSet(selected);
  const match = allowed.find((candidate) => {
    const expected = normalizedSet(candidate);
    return expected.length === normalized.length && expected.every((value, index) => value === normalized[index]);
  });
  if (!match) throw new Error(`Router selection is not an allowed successor set: ${normalized.join(", ")}`);
  return [...new Set(match)];
}

// Returns errors instead of throwing, so a caller can ask for a corrected outcome.
export function routeErrors(transitions: Transitions, outcome: string): string[] {
  try {
    resolveSuccessorSet(transitions, outcome);
    return [];
  } catch {
    return [`Outcome ${outcome} has no route. Allowed outcomes: ${Object.keys(transitions).join(", ")}`];
  }
}

export function routerSelectionErrors(allowed: SuccessorSet[], selected: SuccessorSet): string[] {
  try {
    validateRouterSelection(allowed, selected);
    return [];
  } catch (error) {
    return [`${error instanceof Error ? error.message : String(error)}. Allowed sets: ${JSON.stringify(allowed)}`];
  }
}

export interface StageInvocation {
  runId: string;
  invocationId: string;
  stageType: string;
  parentInvocationIds: string[];
  iteration: string;
}

export class InvocationGraph {
  readonly runId: string;
  private readonly invocations: StageInvocation[] = [];
  private readonly byId = new Map<string, StageInvocation>();

  constructor(runId: string) {
    this.runId = runId;
  }

  schedule(stageType: string, parentInvocationIds: string[], iteration = "root"): StageInvocation {
    for (const parent of parentInvocationIds) {
      if (!this.byId.has(parent)) throw new Error(`Unknown parent invocation: ${parent}`);
    }
    if (new Set(parentInvocationIds).size !== parentInvocationIds.length) {
      throw new Error("Parent invocation identities must be unique");
    }
    const invocation: StageInvocation = {
      runId: this.runId,
      invocationId: `${this.runId}/stage-${this.invocations.length + 1}`,
      stageType,
      parentInvocationIds: [...parentInvocationIds],
      iteration,
    };
    this.invocations.push(invocation);
    this.byId.set(invocation.invocationId, invocation);
    return invocation;
  }

  list(): readonly StageInvocation[] {
    return this.invocations;
  }
}

export function joinIsReady(
  join: { mode: "all" | "any"; stages: string[] },
  completed: Array<{ stageType: string; iteration: string }>,
  iteration: string,
): boolean {
  const completedStages = new Set(
    completed.filter((item) => item.iteration === iteration).map((item) => item.stageType),
  );
  if (join.mode === "all") return join.stages.every((stage) => completedStages.has(stage));
  return join.stages.some((stage) => completedStages.has(stage));
}

export async function mapWithConcurrency<T, U>(
  values: T[],
  limit: number,
  action: (value: T, index: number, signal: AbortSignal) => Promise<U>,
  signal?: AbortSignal,
): Promise<U[]> {
  if (values.length === 0) return [];
  // The first failure aborts the sibling actions instead of letting them run on.
  const batch = new AbortController();
  const combined = signal ? AbortSignal.any([signal, batch.signal]) : batch.signal;
  const results = new Array<U>(values.length);
  let next = 0;
  const workers = Array.from({ length: Math.max(1, Math.min(limit, values.length)) }, async () => {
    while (next < values.length && !combined.aborted) {
      const index = next++;
      try {
        results[index] = await action(values[index], index, combined);
      } catch (error) {
        batch.abort();
        throw error;
      }
    }
  });
  await Promise.all(workers);
  // Workers stop early when the caller aborts, so the results would have gaps.
  signal?.throwIfAborted();
  return results;
}
