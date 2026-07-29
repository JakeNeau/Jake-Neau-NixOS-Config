# Why Pi uses a hybrid typed-link registry

The shared agent configuration connects resources with `[[type:name]]` tokens.
A token is intentionally small enough to live in prose, but it does not itself
tell Pi where the target file is or how to load it. Leaving that lookup to the
model makes traversal unreliable: paths differ between the source repository,
the Nix store, and project-local configuration, and guessing defeats the purpose
of a named graph.

Pi therefore keeps the human-readable convention and adds a deterministic
resolver beneath it.

## Global knowledge is a build artifact

Global resources come from this flake, so Nix already knows their complete and
immutable source set. Home Manager runs the registry compiler during the build,
rejecting malformed or duplicate global resources before activation. The
resulting manifest contains only routing metadata and store paths; bodies stay
out of the model context.

This is preferable to rescanning global files at every Pi startup. It makes the
registry reproducible, gives it the same lifecycle as the configuration, and
turns graph defects into build failures rather than session surprises.

## Project knowledge belongs to the live checkout

Nix cannot know which repository Pi will open or how that repository will change
between home generations. Project skills, prompts, specs, and docs are therefore
scanned at session startup and reload, after project trust has been granted.

The runtime scanner uses the same compiler as the Nix build. This is the seam
that keeps naming, frontmatter parsing, and link validation identical across the
two layers without making projects rebuild the home whenever a document changes.

## Layers remain separate

The global and project registries are not flattened. A link written inside a
global resource resolves globally; a link written inside a project resource
resolves within that project. This preserves the existing rule that reusable
global guidance must not depend on one repository and that project guidance
must not silently couple itself to one machine's private configuration.

When a user enters an unqualified link that exists in both layers, ambiguity is
reported instead of applying shadowing rules. Canonical IDs remain available
when an explicit layer is required.

## Traversal is one hop at a time

Only the compact `follow_link` tool description and its short usage rule are
always present in the system prompt. The registry lives in extension memory, and
a resource body enters context only after the model follows that exact link.

The resolver also appends canonical link cards to ordinary file reads. This
makes the next hop easy to call without recursively opening it. Automatic graph
walking was rejected because one highly connected skill could pull an
unbounded chain into context and recreate the original context-pressure problem.

The comment policy uses this boundary deliberately. Pi's global `AGENTS.md`
contains only the `[[skill:comments]]` routing instruction and its canonical
global registry ID. The router classifies
a comment and exposes links to focused category policies, so an API contract does
not pull workaround, provenance, directive, and task-marker guidance into the
same turn. `/comment-review` traverses only the categories present in its scope.

## The vocabulary stays earned

Pi initially adapts only its native or project-generic resource kinds: skills,
commands, specs, and docs. Every other type in the convention, such as an agent,
memory, hook, or rule, remains an annotation. MCP and Pi-extension link
adapters are deferred in `TODO.md` until those capabilities earn concrete
semantics.

The native `writing-pi-extensions` skill applies the same test to future work: a
new type is added only for a durable named resource, and only together with its
discovery rule, adapter, validation, and tests.
