// Injects the development-flow map into the model context — the same text the
// Claude Code session-flow-map hook injects; keep the two in sync.
const FLOW_MAP = `Development flow — the entry-point skill for each moment:
- Creative work ahead (a feature, design, or architecture choice): settle the
  design interactively via [[skill:brainstorming]]; capture it in a [[skill:specs]] file.
- Turning an approved design into an implementation plan: [[skill:writing-plans]]
  fills the spec's ## Plan / ## Tasks; verify with the plan-verifier agent.
- Implementing: delegate non-trivial code to the code-writer agent; code written
  directly follows [[skill:test-driven-development]] (RED-GREEN-REFACTOR).
- A bug or unexpected failure: [[skill:systematic-debugging]] — find the root
  cause before any fix, never patch blind.
- Code-review feedback arrives: [[skill:receiving-code-review]] — verify before
  implementing, no performative agreement.
- About to claim something is done, fixed, or passing:
  [[skill:verification-before-completion]] — evidence, never "should".
- A development branch is complete: [[skill:finishing-a-development-branch]] —
  tests first, then merge locally / keep / discard; never push or open a PR
  unprompted.
See [[skill:using-skills]] for how skills are discovered and linked.`;

// before_agent_start fires on every user prompt, and it is the only event
// whose handler result injects a message (a session_start handler's return is
// discarded by the runner), so a module-level guard keeps the map to one
// injection per omp process.
let injected = false;

// omp (verified at 16.4.8) loads loose .ts files under ~/.omp/agent/extensions/
// and calls each default-exported factory with its extension API.
export default function (api: {
  on(event: string, handler: () => unknown): void;
}) {
  api.on("before_agent_start", () => {
    if (injected) return;
    injected = true;
    // display: false keeps the message out of the transcript UI; the content
    // still lands in the agent's message stream.
    return {message: {customType: "flow-map", content: FLOW_MAP, display: false}};
  });
}
