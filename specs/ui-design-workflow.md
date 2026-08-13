# Pi UI design workflow

This draft records the design reached during the interrupted `refine-spec` run.
It preserves settled decisions and keeps unresolved choices explicit. It is not
ready for implementation until the remaining decision gates close.

## Spec

### Version 1 boundary

Version 1 manages visual screens through one authoritative structured UI model.
The model records layout, style, content, responsive rules, assets, reusable
structure, and stable node identities. Generated framework code and screenshots
are outputs rather than editable authorities.

Users can edit the same version 1 model in two ways:

- In a parent-owned browser editor, users select elements and change basic
  schema-bound properties and layout.
- Through Pi commands, users inspect the model, propose changes, update approved
  files, render previews, and verify results.

Both paths must use the same schema validator and transactional write path. The
direct editor must not reduce Pi's ability to create and improve the UI. An edit
that cannot map to the model must fail instead of creating editor-only state.
Pi-command-only operation remains an acceptable fallback if direct manipulation
cannot preserve model quality.

Version 1 covers visual screens only. Navigation, overlays, interaction states,
business logic, networking, validation, and durable application state remain
outside scope. The model may reserve extension points for later interactive
flows, but version 1 does not implement them.

Version 1 requires Svelte and Flutter as production targets. React must fit the
same adapter architecture, but it does not gate version 1 acceptance. The point
at which React becomes required remains unresolved.

Generated framework files are replaceable output. Regeneration may overwrite
them. Projects keep custom logic in separate files or explicit adapter
extension points. The system does not import manual changes from generated code
back into the model.

### Structured UI model

The framework-neutral model must contain these portable concepts:

- project metadata and a schema version
- design tokens for color, typography, spacing, radius, elevation, and
  breakpoints
- asset references with paths and hashes
- screens with viewport and responsive rules
- stable node identities
- layout, style, content, and accessibility properties
- reusable UI definitions and instances
- adapter metadata that does not make one framework authoritative

Schema validation must reject unknown required semantics, dangling references,
invalid responsive rules, and unsupported adapter mappings. Migrations must be
explicit and versioned. Serialization must be deterministic so review, hashing,
and generation remain stable.

The exact reuse contract remains unresolved. The current recommendation is
explicit model components with named properties, slots, variants, and stable
instance references. This model best supports deterministic Svelte and Flutter
components, but the user did not accept it during refinement.

### Editor and preview architecture

A dedicated parent Pi extension owns the local preview service, browser editor,
file watching, and cleanup. Workflow children cannot own these resources
because each stage runs in a fresh RPC process.

The browser editor renders the structured model directly. Version 1 includes
element selection and basic content, token, sizing, spacing, alignment, and
responsive-property controls. The exact boundary for dragging, resizing,
component editing, and other direct manipulation remains unresolved.

Every save must:

1. Validate the complete model.
2. Compare the current file hash with the hash read by the editor.
3. Write the model atomically.
4. Report validation or concurrency failures without discarding either version.

A concurrent change stops the save and requires a reload or an explicit merge
choice.

The parent TUI reports the preview URL, selected screen, validation state, and
recent save result. Inline terminal images are optional. A preview URL and a
saved screenshot path must always remain available because terminal image
support varies.

Pi-command changes use a new `/ui-design` workflow. The workflow follows the
existing refinement lifecycle:

1. Discover project documentation, model files, framework targets, and
   validation commands.
2. Inspect the model, source components, tokens, and rendered evidence in
   parallel.
3. Ask one unresolved design question at a time.
4. Propose model changes and exact output paths.
5. Require user approval before changing project files.
6. Hash approved files.
7. Stop if an approved file changes concurrently.
8. Update only approved model or generated files.
9. Render the result.
10. Run fresh structural and visual verification.

Workflow artifacts carry paths, hashes, viewport metadata, decisions, and
bounded summaries. Images and binary assets remain outside artifact JSON. A
child may read a saved image by path when the active model supports images.
Text-only models rely on DOM snapshots, computed properties, and explicit
assertions.

### Browser capability and safety

The workflow engine must define a constrained browser capability rather than
treating `agent_browser` as an ordinary read-only tool. The capability must
distinguish these action classes:

- observing a local preview
- interacting with the local editor or preview
- interacting with an external site
- writing screenshots or downloads

Version 1 workflow stages access only the localhost preview. The parent owns
that preview. They must not submit external forms, use authenticated
profiles, or navigate to arbitrary remote origins. Whether controlled remote
asset lookup is allowed remains unresolved.

Screenshot output must use approved project paths or workflow-owned temporary
paths. A browser action that changes a project file must join the shared
exact-path mutation queue and hash controls.

The parent owns preview startup and cleanup. Workflow stop, cancellation,
reload, and `session_shutdown` must close browser sessions, watchers, servers,
and temporary files idempotently.

### Generation

A framework-neutral adapter receives a validated model and an approved output
manifest. It returns:

- generated files
- diagnostics
- source-to-model identity metadata
- target verification commands

The Svelte adapter generates replaceable Svelte screens and components. The
Flutter adapter generates replaceable Flutter screens and widgets. Both
adapters preserve model component boundaries, tokens, responsive intent,
accessibility metadata where supported, and stable generated names.

Adapters must fail on unsupported semantics. They must not silently approximate
a model feature differently across targets. Project logic extension points must
live outside generated files or appear as stable generated import hooks.

React uses the same adapter contract when added. The core model must not contain
Svelte-only or Flutter-only assumptions.

### Correctness

Verification has four layers:

- **Model correctness** checks schema validity, references, migrations, and
  deterministic serialization.
- **Render correctness** checks DOM or render-tree assertions, computed layout,
  accessibility metadata, and required viewports.
- **Generation correctness** checks deterministic output, framework builds,
  component reuse, and extension-point boundaries.
- **Visual correctness** compares model previews with generated Svelte and
  Flutter renders and requires user approval for intentional baseline changes.

A fresh verifier compares the accepted design, changed model, generated
manifests, rendered evidence, and project validation results. Screenshot
similarity alone cannot establish correctness.

The acceptance matrix remains unresolved. It must define:

- viewports and responsive states
- themes and content states
- fonts and platform rendering settings
- animation handling
- image-difference thresholds
- accessibility checks
- the Flutter render target used for comparable screenshots

### Durable resources

Mockups, assets, baselines, and reusable UI definitions must live outside
`specs/` because specifications are transient. The durable project root and
file format remain unresolved. The current recommendation is `.pi/ui/`, with a
versioned model, assets, baselines, and generated manifests beneath it.

Agents should be able to manage reusable UI elements by stable name. This may
justify a `[[ui:name]]` typed-link resource. Before implementation, the design
must confirm that choice and define discovery roots, canonical names, registry
metadata, adapter behavior, validation, and tests. The system must not add a
link type without its adapter.

### Settled decisions

- The structured UI model is the authoritative editable source.
- Version 1 includes a direct browser editor and Pi-command editing.
- Both editing paths operate on the same validated model.
- Version 1 supports visual screens only.
- Version 1 requires Svelte and Flutter generation targets.
- React must fit the adapter contract but does not gate version 1.
- Generated framework files are replaceable output.
- Custom application logic stays in separate files or explicit extension
  points.
- The browser editor includes selection and basic property and layout editing.
- The user did not settle reusable-element semantics.

### Remaining decision gates

Implementation must not start until the load-bearing gates close:

- Choose explicit model components, reusable visual groups, project-component
  bindings, or token-only reuse.
- Confirm the durable project root and file format.
- Decide whether UI resources receive a typed-link form.
- Define how existing project components and design systems bind to model
  components.
- Define the editor's direct-manipulation boundary beyond selection and basic
  property and layout editing.
- Define the model's exact layout, responsive, styling, content, asset, and
  extension schemas.
- Define the Svelte and Flutter mappings for identity, layout, styling, assets,
  and extension points.
- Define generated output locations and extension-point conventions.
- Specify which browser actions the workflow permits and whether it allows
  remote asset lookup.
- Define preview server, watcher, browser session, and cleanup ownership in
  detail.
- Define the visual and functional acceptance matrix.
- Select the Flutter comparison renderer.
- Define behavior for text-only models and terminals without image rendering.
- Decide whether original-resolution image evidence bypasses Pi's normal image
  resizing.
- Define end-to-end Nix tests for startup, synchronization, generation,
  screenshots, cancellation, and cleanup.
- Decide whether the version 1 schema reserves compatibility for interactive
  flows.
- Decide when React becomes a required target.

These gates do not reopen the authoritative model, version 1 visual-screen
boundary, required Svelte and Flutter targets, or replaceable-output policy.

### Rejected alternatives

- Framework source cannot serve as authority because it cannot provide one
  portable model for deterministic multi-framework generation.
- **Standalone HTML and CSS as authority.** Framework translation would remain
  separate and partly heuristic.
- **Dual-source synchronization.** The system will not reconcile divergence
  between an editable model and editable generated code.
- **Image-first mockups.** Screenshots cannot deterministically encode reuse,
  behavior, or component identity.
- **Pi-command-only version 1.** The later product-boundary decision includes a
  direct editor, subject to the model-quality fallback.
- **Interactive flows in version 1.** The first release excludes interactive
  flows and supports only visual screens.
- **Direct editing, flows, and three required targets in version 1.** This scope
  has excessive cross-platform and validation risk.
- **Managed generated-code regions, one-time export, and round-trip source
  synchronization.** Replaceable generated output is simpler and keeps one
  authority.
- **A complete application model.** Business logic, services, persistence, and
  application state remain outside scope.

### Risks

- A portable schema may expose layout differences that Svelte and Flutter cannot
  render identically without target-specific constraints.
- The direct editor may compromise model quality if it keeps state outside
  validated transactions.
- Browser access may bypass exact-path safety unless policy separately enforces
  observation, interaction, and file output.
- Flutter comparison requires a deterministic renderer, fonts, platform
  settings, and viewport mapping.
- Image-capable behavior depends on the active model and Pi image settings.
- Preview servers, browser sessions, and watchers may leak unless every failure
  path cleans them up idempotently.
- The unresolved reuse contract affects the core schema and both adapters.
- The unresolved storage root and typed-link decision affect discovery,
  registry behavior, and migration.
- Visual differences may be unstable because of fonts, antialiasing, animation,
  and platform rendering.
- Svelte and Flutter fixture builds may be expensive across Linux and macOS.
- Existing workflow mutation controls do not protect browser output.
- A late React adapter may reveal hidden framework assumptions in the portable
  core.

### Assumptions

- The UI design system runs only in trusted local projects.
- The parent Pi session can own a localhost editor and preview service.
- Projects expose deterministic Svelte and Flutter validation commands through
  Nix or documented project tooling.
- Users explicitly approve generated output directories and treat them as
  disposable.
- Version 1 delivers useful static visual screens without interactive-flow
  semantics.
- `.pi/ui/`, explicit model components, and `[[ui:name]]` are recommendations,
  not accepted decisions.
- Saved screenshots and DOM evidence remain outside workflow artifact payloads.
- No existing specification overlaps this feature.

## Plan

The project has no approved implementation plan. Run `refine-plan` only after
the remaining load-bearing decision gates close.

The eventual implementation should extend the existing workflow manager rather
than create a second orchestration engine. A focused UI design extension should
own the model, editor, preview, adapters, and lifecycle. A declarative workflow
should reuse documentation-first discovery, parallel evidence, one-question
checkpoints, exact-path approval, hashing, bounded mutation, and fresh
verification.

Tests must precede production code. The tests must cover schema behavior,
migrations, stable identity, deterministic serialization, and transaction
conflicts. They must also cover adapter manifests, generation determinism,
editor actions, browser policy, preview cleanup, and generated fixture builds.

## Tasks

- [ ] Close the remaining load-bearing decision gates.
- [ ] Run `refine-plan` to produce an implementation-complete plan beside this
  specification.
- [ ] Implement tests before production code.
- [ ] Implement the approved plan through the existing Pi extension and
  workflow architecture.
- [ ] Run the dedicated Pi checks, `nix flake check`, and affected Pi home dry
  builds with `--no-link`.
- [ ] Move durable behavior and rationale into the appropriate `docs/` pages.
- [ ] Delete this transient specification after implementation and durable
  documentation are complete.
