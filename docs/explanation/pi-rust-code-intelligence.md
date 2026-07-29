# Pi's Rust code intelligence

Pi uses compiler and debugger protocols for Rust rather than approximating
program structure from text searches or parsing debugger output. The goal is to
make code reading more selective and debugging more evidential without turning
Pi into a language-specific IDE.

## Two mechanisms, two lifecycles

Rust navigation and Rust debugging are separate extensions. The intelligence
extension starts `rust-analyzer` lazily and speaks the Language Server Protocol;
the debugger starts CodeLLDB only for an active investigation and speaks the
Debug Adapter Protocol. They share Cargo workspace and project-documentation
discovery, but neither owns the other's process or state.

This split reflects their different jobs. Language intelligence is reusable
throughout a session and answers structural questions such as definitions,
types, references, and call hierarchy. A debugger executes project code, has a
shorter and riskier lifecycle, and exists to test a concrete runtime hypothesis.
Keeping the boundary explicit also lets a future language reuse one side without
requiring the other.

## Documentation before convention

Cargo metadata can say which targets exist, but it cannot explain which command
the project expects, when a test is appropriate, or why a workflow has unusual
constraints. The shared project layer therefore searches `AGENTS.md`,
`CLAUDE.md`, `README.md`, and the Markdown documentation tree before falling
back to Cargo conventions.

Documentation is guidance, not executable input. The extensions expose relevant
sections and recognize only direct Cargo and `nix develop --command cargo`
forms. They never execute arbitrary shell snippets extracted from Markdown.
This preserves docs-first behavior without turning prose into an implicit build
script.

## Structural context instead of broad reads

The intelligence extension combines documentation excerpts with
`rust-analyzer` symbols, source ranges, hover information, references, callers,
and Cargo diagnostics. Results remain source-addressable and bounded, so Pi can
inspect a small relevant slice and use ordinary file reads when it needs the
full implementation.

There is deliberately no persistent semantic database or embedding index. A
lazy language server gives authoritative Rust semantics with less duplicated
machinery. Because Rust analysis can execute build scripts and procedural
macros, starting `rust-analyzer` or Cargo diagnostics requires project trust. If
startup or lexical documentation ranking becomes a measured bottleneck, those
internals can change without changing the Pi tool contract.

## Autonomous but bounded debugging

Pi may launch a local Cargo binary or test under CodeLLDB when runtime evidence
is needed. It must first consult project guidance, reproduce the failure, and
state the hypothesis the debugger will test. Debugger observations remain
evidence rather than conclusions; source changes still follow the normal
root-cause and verification workflow.

The initial boundary is intentionally narrow: one launch-only session in the
trusted current Cargo workspace, with no attachment, elevation, remote
execution, or shell evaluation. Builds and protocol requests have explicit
timeouts, and every abort, reload, exit, or session shutdown tears down the
adapter and debuggee process tree.

What the automated check proves is narrower than it first looks. The
`pi-rust-tools` flake check exercises the Debug Adapter Protocol client against a
mock adapter, not against a real debugger. Two integration tests drive a real
debuggee under CodeLLDB, and they skip themselves when the environment cannot
obtain macOS permission to debug a process. Each skip prints its reason: real
CodeLLDB debugging remains UNVERIFIED in that environment.

The cause is the build environment rather than the platform or the Nix sandbox,
which this machine leaves disabled. Only an interactive session can obtain macOS
permission to debug a process, and a Nix build runs unattended as a build user.
The same launch succeeds when the user runs those tests interactively on the same
machine. A probe launch detects the refusal, and the tests skip only on that
error. Any other launch failure still fails the check.

So a green check is evidence about the client and its wiring, not about the
debugger. Trusting real CodeLLDB debugging on a machine needs an interactive run
of the same tests there.

## Declarative ownership

The extensions, tests, `rust-analyzer`, CodeLLDB, Cargo, rustc, LLVM runtime,
and generated Pi entry points are all owned by the Pi Home Manager declaration.
Generated entry points use absolute Nix-store paths and a declarative tool path;
there are no runtime downloads, `rustup` operations, or imperative edits under
`~/.pi`.

Rust is the first supported language. LSP and DAP are the growth seams, but a
generic multi-language framework is deferred until a second language reveals
which abstractions are actually shared.
