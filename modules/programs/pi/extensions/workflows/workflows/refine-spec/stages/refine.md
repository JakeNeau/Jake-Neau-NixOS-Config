# Refine a specification

Read the workflow input, project instructions, and relevant project documentation. Locate the specification files from documented project conventions. Read only the specification, documentation, and implementation needed to understand the requested change.

If the input is empty, inspect the active specifications and select one clear, high-impact defect. Do not verify the full project.

Prepare a concise, complete specification change. Resolve details supported by the input and project evidence. State any remaining assumption in the design instead of starting another workflow stage. List only specification or closely related documentation files that need edits.

Return one `refinement-proposal` artifact with `workflow_output`. Put the complete proposed text or exact changes in `payload.design`. Put each approved mutation target in `payload.files`. Do not modify files.
