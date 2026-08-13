# Synthesize planning evidence

Combine the supplied evidence without adding unsupported claims. Resolve
duplicates and state conflicts between sources. Preserve concise source paths.

Produce the facts, constraints, conflicts, integration points, and open decisions
needed for an implementation-complete plan. Include decisions about file
placement, symbols, interfaces, data flow, error behavior, compatibility,
tests, validation, and documentation when relevant.

Remove questions that project documentation or verified code already answers.
Do not resolve any remaining choice. Return one `evidence-synthesis` artifact
with `workflow_output`.
