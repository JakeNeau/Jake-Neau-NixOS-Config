# Rust code intelligence and debugging

## Spec

### Decision

Add a declarative Pi code-intelligence suite for Rust as two focused extensions
sharing a small project-discovery library:

- a Rust intelligence extension backed by `rust-analyzer` over LSP; and
- a Rust debugger extension backed by CodeLLDB over DAP.

The intelligence extension improves structural reading and context selection;
the debugger extension supplies runtime evidence. Existing documentation-first
and systematic-debugging skills continue to govern how Pi investigates and
reasons. The extensions provide mechanisms rather than replacing those
workflows.

A single combined extension was rejected because language-server navigation and
stateful debugger control have different lifecycles and will need to grow
independently. CLI-only parsing of Cargo, compiler, and LLDB output was rejected
because it loses structured language semantics and creates brittle debugger
integration. LSP and DAP establish clean seams through which other languages can
be added later without generalizing the Rust implementation prematurely.

### Architecture

The suite consists of:

- `rust-intelligence`, which owns one lazily started `rust-analyzer` connection
  per active Cargo workspace;
- `rust-debugger`, which owns at most one lazily started CodeLLDB session; and
- `rust-project`, an internal shared library for workspace, documentation, and
  Cargo discovery.

Long-lived processes start only when a tool action needs them. Session shutdown,
reload, abort, debugger exit, and process failure all perform idempotent cleanup.
The initial debugger supports launching Cargo binaries and tests only; attaching
to an existing process is outside scope.

The shared library locates the Cargo workspace from Pi's current directory, runs
`cargo metadata`, discovers packages and targets, and maps project guidance from
`AGENTS.md`, `CLAUDE.md`, `README.md`, and Markdown below `docs/`. It maintains
only an in-memory, mtime-aware cache. It returns focused documentation excerpts,
headings, and command examples relevant to a task instead of injecting whole
documents.

The project map is internal runtime machinery, not a durable resource navigated
by agents, so the suite introduces no typed-link kind.

### Declarative packaging

All source and dependencies are declared by `modules/programs/pi/pi.nix`.
Extension source remains under `modules/programs/pi/extensions/` and Home
Manager installs generated entry points beneath `~/.pi/agent/extensions/`.
Those entry points receive absolute Nix-store paths for `rust-analyzer`,
CodeLLDB, and required LLVM runtime components.

The suite performs no runtime downloads, imperative package installation,
`rustup` invocation, or direct mutation of the managed Pi configuration.
Project-documented toolchains and command wrappers take precedence when they use
direct Cargo or `nix develop --command cargo`; Nix-provided tools are the
deterministic fallback. Other documented commands remain guidance for Pi's
ordinary reproduction step but are not interpreted or executed by the debugger.
Runtime processes, temporary debugger artifacts, and in-memory caches are
ephemeral.

The package must evaluate on the Pi users' `x86_64-linux` and
`aarch64-darwin` homes. Tests are Nix checks, and the relevant Pi home outputs
are dry-built where the current machine can build them and evaluated otherwise.

### Rust intelligence

The intelligence extension registers one `rust_code` tool with these actions:

- `overview`: workspace packages, targets, documentation map, and important
  entry points;
- `symbol`: locate symbols by name;
- `definition`: resolve a symbol or source position;
- `hover`: retrieve compiler-derived type and documentation information;
- `references`: find usages;
- `callers`: obtain incoming and outgoing call hierarchy;
- `diagnostics`: report compiler-aware errors and warnings; and
- `context`: produce a compact task-specific documentation and code bundle.

Queries accept a symbol name or a path and source position. Ambiguous symbol
names return candidates rather than selecting one silently. Responses retain
source paths and ranges so Pi can verify or expand them with ordinary file
reads.

A context bundle ranks and combines relevant project guidance, symbol
signatures and definitions, nearby implementations, important callers or
references, and current diagnostics. It is bounded by Pi's standard line and
byte limits and favors structural excerpts over entire files. Truncation is
reported explicitly, with complete output retained temporarily when useful.

### Rust debugger

The debugger extension registers:

- `rust_debug_start`, which accepts a debugging goal and optional package,
  target, test filter, arguments, and environment; and
- `rust_debug`, which controls breakpoints, continuation, stepping, threads,
  stacks, scopes, variables, expression evaluation, and session termination.

Starting a session searches project documentation for relevant commands and
constraints, inspects Cargo metadata, ranks candidate targets, and either
selects deterministically or returns candidates when the choice is genuinely
ambiguous. It builds through a supported Cargo/Nix command form with Cargo JSON
output, extracts the produced executable path, starts CodeLLDB, initializes DAP,
and launches to the initial stop or requested breakpoint.

The debugger summarizes state around the selected thread and frame. Pi requests
deeper scopes and variables explicitly instead of receiving the complete
process state. Documentation informs command and target selection, but Markdown
shell snippets are never executed blindly.

### Investigation behavior and safety

Prompt guidance directs Pi to:

1. consult relevant project documentation;
2. use diagnostics and structural navigation;
3. reproduce the failure with the documented test or run command;
4. form a concrete root-cause hypothesis;
5. launch the debugger when runtime state is needed to test that hypothesis;
6. inspect only the necessary frames, variables, and expressions; and
7. stop the debugger before editing, then verify the eventual fix normally.

Pi may autonomously launch local Cargo binaries and tests within a trusted
current workspace. The initial debugger does not attach, elevate privileges,
run remotely, evaluate shell command strings, or execute outside that
workspace. Arguments are passed directly to child processes. Builds, adapter
startup, and DAP requests have explicit timeouts; readiness is condition-based
rather than sleep-based. Abort and shutdown terminate the whole child process
tree.

Debugger observations are evidence, not conclusions. Reaching a breakpoint or
observing one value does not itself establish a root cause, and debugger tools
do not modify source files.

### Testing and acceptance

Tests are written before production code and run through Nix.

Unit coverage includes workspace and documentation discovery, Cargo metadata and
compiler JSON parsing, symbol and context ranking, output limits, LSP and DAP
framing, debugger state transitions, cancellation, timeouts, cleanup, and
cross-platform path handling.

Fake LSP and DAP servers cover request correlation, asynchronous diagnostics and
debugger events, malformed responses, adapter failure, process exit during a
request, and repeated cleanup. A documented Rust fixture workspace exercises
real `rust-analyzer` definition, reference, caller, diagnostic, and context
queries; automatic target discovery; Cargo executable extraction; CodeLLDB
launch; a breakpoint; local-variable and stack inspection; continuation; and
clean termination.

The feature is accepted when Pi can use the fixture's documentation to select
the appropriate workflow, investigate it without broad file reads, reproduce a
failure, and inspect the decisive runtime value through DAP. Linux receives a
live build and debugger smoke test on NixOS. Darwin configuration and packages
must evaluate from NixOS, with the live macOS debugger smoke test performed on
an Apple host.

### Growth path and trade-offs

Rust is the only first-class language in this change. The shared protocol and
project boundaries permit later LSP and DAP adapters, but no language-neutral
framework is built until a second language proves the common interface. The
initial implementation favors accurate compiler and debugger semantics over a
persistent semantic index or embeddings. If repeated startup or lexical context
ranking becomes a measured bottleneck, those internals can be replaced behind
the existing tool contracts.

Autonomous debugging intentionally accepts the cost and risk of executing
trusted project code. The launch-only, workspace-only boundary preserves the
primary benefit while deferring platform-specific process attachment and remote
execution.

## Plan

**Goal:** Add declarative Rust-aware code navigation, compact context retrieval,
and autonomous launch-only debugging to Pi on NixOS and macOS.

**Architecture:** Two Pi extension factories share project discovery, process,
and Content-Length protocol modules. `rust-intelligence` speaks LSP to a lazy
`rust-analyzer`; `rust-debugger` builds Cargo targets and speaks DAP to a lazy
CodeLLDB server. Pure modules are tested independently, protocol behavior is
tested against fake peers, and a Rust fixture exercises the real packaged
programs.

**Tech stack:** TypeScript loaded directly by Pi, Node's built-in test runner and
process/network APIs, LSP, DAP, Cargo JSON messages, `rust-analyzer`, CodeLLDB,
Nix, and Home Manager.

**Global constraints:** All dependencies and installed extension entry points
are declared in `modules/programs/pi/pi.nix`; no runtime downloads or imperative
package installation; Rust only; `x86_64-linux` and `aarch64-darwin`; launch-only
local debugging in a trusted current Cargo workspace; direct Cargo and
`nix develop --command cargo` execution only; one active debugger; standard Pi
output limits; long-lived processes start lazily and shut down idempotently.

**Implementation status:** Built and fully verified on `x86_64-linux`.
`aarch64-darwin` evaluates successfully; its live rust-analyzer and CodeLLDB
check remains tracked in `TODO.md`, so this spec remains until that check passes.

**Files:**

- `modules/programs/pi/extensions/rust-tools/protocol.ts` owns Content-Length
  framing, request correlation, events, timeouts, and connection shutdown.
- `modules/programs/pi/extensions/rust-tools/process.ts` owns abort-aware child
  execution and process-tree termination.
- `modules/programs/pi/extensions/rust-tools/project.ts` owns workspace,
  documentation, Cargo command, metadata, target, artifact, and diagnostic
  discovery.
- `modules/programs/pi/extensions/rust-tools/lsp.ts` owns the
  `rust-analyzer` lifecycle and typed LSP operations.
- `modules/programs/pi/extensions/rust-tools/intelligence.ts` defines the
  `rust_code` extension factory and bounded result assembly.
- `modules/programs/pi/extensions/rust-tools/dap.ts` owns CodeLLDB startup and
  typed DAP session operations.
- `modules/programs/pi/extensions/rust-tools/debugger.ts` defines
  `rust_debug_start` and `rust_debug` and enforces the debugger state machine.
- `modules/programs/pi/extensions/rust-tools/tests/` contains unit, fake-peer,
  and real Rust fixture tests.
- `modules/programs/pi/pi.nix` builds the tests, supplies immutable executable
  paths, and installs both extension entry points.

## Tasks

### Task 1: Shared process and protocol foundation

**Files:**
- Create: `modules/programs/pi/extensions/rust-tools/process.ts`
- Create: `modules/programs/pi/extensions/rust-tools/protocol.ts`
- Create: `modules/programs/pi/extensions/rust-tools/tests/process.test.ts`
- Create: `modules/programs/pi/extensions/rust-tools/tests/protocol.test.ts`

**Interfaces:**
- Produces: `runProcess(request: ProcessRequest): Promise<ProcessResult>`,
  `stopProcessTree(child): Promise<void>`, and `ContentLengthConnection` with
  `request`, `notify`, `onNotification`, and idempotent `close` methods.
- `ProcessRequest` carries executable, argv, cwd, env, timeout, and abort signal;
  `ProcessResult` carries exit code, stdout, stderr, and timeout/abort state.

- [ ] Write tests that prove stdout/stderr capture, argument preservation,
  abort/timeout termination, fragmented frames, multiple frames per chunk,
  response correlation, notifications, request errors, and repeated close.
- [ ] Run `node --experimental-strip-types --test modules/programs/pi/extensions/rust-tools/tests/{process,protocol}.test.ts` and confirm failure because the modules do not exist.
- [ ] Implement only the process and framing interfaces required by the tests,
  using direct `spawn` arguments and no shell.
- [ ] Re-run the two tests and require zero failures and no leaked child process.

### Task 2: Documentation and Cargo project discovery

**Files:**
- Create: `modules/programs/pi/extensions/rust-tools/project.ts`
- Create: `modules/programs/pi/extensions/rust-tools/tests/project.test.ts`
- Create: `modules/programs/pi/extensions/rust-tools/tests/fixtures/workspace/Cargo.toml`
- Create: `modules/programs/pi/extensions/rust-tools/tests/fixtures/workspace/README.md`
- Create: `modules/programs/pi/extensions/rust-tools/tests/fixtures/workspace/docs/debugging.md`
- Create: `modules/programs/pi/extensions/rust-tools/tests/fixtures/workspace/crates/demo/Cargo.toml`
- Create: `modules/programs/pi/extensions/rust-tools/tests/fixtures/workspace/crates/demo/src/lib.rs`
- Create: `modules/programs/pi/extensions/rust-tools/tests/fixtures/workspace/crates/demo/src/main.rs`
- Create: `modules/programs/pi/extensions/rust-tools/tests/fixtures/workspace/crates/demo/tests/regression.rs`

**Interfaces:**
- Produces: `discoverRustProject(options): Promise<RustProject>`,
  `searchProjectDocs(project, query, limits): DocExcerpt[]`,
  `listDebugTargets(project): DebugTarget[]`,
  `buildDebugTarget(project, selection, runtime): Promise<BuiltTarget>`, and
  `collectCargoDiagnostics(project, runtime): Promise<RustDiagnostic[]>`.
- `RustProject` records root, manifest, packages, targets, documentation
  sections, and the selected direct-Cargo or `nix develop --command cargo`
  invocation without storing a persistent index.

- [ ] Write tests for ancestor workspace discovery, Cargo metadata parsing,
  heading-aware documentation ranking, command extraction without execution,
  target disambiguation, JSON artifact selection, compiler diagnostics, and
  rejection outside a Cargo workspace.
- [ ] Run `node --experimental-strip-types --test modules/programs/pi/extensions/rust-tools/tests/project.test.ts` and confirm failure because the project module does not exist.
- [ ] Implement project discovery with deterministic lexical ranking, mtime
  invalidation, direct argv execution, and Cargo JSON parsing.
- [ ] Re-run the project test and the Task 1 tests and require zero failures.

### Task 3: Rust-analyzer client and intelligence extension

**Files:**
- Create: `modules/programs/pi/extensions/rust-tools/lsp.ts`
- Create: `modules/programs/pi/extensions/rust-tools/intelligence.ts`
- Create: `modules/programs/pi/extensions/rust-tools/tests/lsp.test.ts`
- Create: `modules/programs/pi/extensions/rust-tools/tests/intelligence.test.ts`

**Interfaces:**
- Produces: `RustAnalyzerSession` with `symbols`, `definition`, `hover`,
  `references`, `incomingCalls`, `outgoingCalls`, `diagnostics`, and `close`;
  and `createRustIntelligence(config): ExtensionFactory`.
- `rust_code` accepts actions `overview`, `symbol`, `definition`, `hover`,
  `references`, `callers`, `diagnostics`, and `context`, plus optional query,
  path, line, column, direction, and result limit.

- [ ] Write a fake LSP peer test for initialize/initialized sequencing,
  workspace-symbol ambiguity, locations, hover markup, call hierarchy,
  asynchronous diagnostics, timeout, server exit, and shutdown.
- [ ] Write extension tests with a minimal fake Pi API proving schema
  registration, lazy startup, source-range preservation, bounded context output,
  truncation reporting, and session-shutdown cleanup.
- [ ] Run `node --experimental-strip-types --test modules/programs/pi/extensions/rust-tools/tests/{lsp,intelligence}.test.ts` and confirm failure because the LSP and extension modules do not exist.
- [ ] Implement the LSP session and `rust_code` extension factory, using
  `StringEnum` for action values and Pi's truncation utilities.
- [ ] Re-run all Rust-tool tests and require zero failures.

### Task 4: CodeLLDB DAP client and debugger extension

**Files:**
- Create: `modules/programs/pi/extensions/rust-tools/dap.ts`
- Create: `modules/programs/pi/extensions/rust-tools/debugger.ts`
- Create: `modules/programs/pi/extensions/rust-tools/tests/dap.test.ts`
- Create: `modules/programs/pi/extensions/rust-tools/tests/debugger.test.ts`

**Interfaces:**
- Produces: `CodeLldbSession` with `launch`, `setBreakpoint`, `continue`,
  `stepIn`, `next`, `stepOut`, `threads`, `stackTrace`, `scopes`, `variables`,
  `evaluate`, and `close`; and `createRustDebugger(config): ExtensionFactory`.
- `rust_debug_start` accepts goal, package, target, target kind, test filter,
  argv, and environment. `rust_debug` accepts actions `breakpoint`, `continue`,
  `step_in`, `step_over`, `step_out`, `stack`, `scopes`, `variables`, `evaluate`,
  and `stop` with the identifiers required by each action.

- [ ] Write fake DAP tests for TCP startup, initialize/launch/configurationDone
  ordering, stopped and terminated events, breakpoint verification, stepping,
  stack/scope/variable/evaluate requests, timeout, adapter exit, and idempotent
  stop.
- [ ] Write extension tests proving project-trust enforcement, one-session
  enforcement, ambiguous-target return without launch, autonomous build and
  launch, action validation, concise state rendering, abort, and shutdown.
- [ ] Run `node --experimental-strip-types --test modules/programs/pi/extensions/rust-tools/tests/{dap,debugger}.test.ts` and confirm failure because the DAP and debugger modules do not exist.
- [ ] Implement the DAP session and debugger extension with direct argv,
  bounded output, explicit state transitions, and complete cleanup.
- [ ] Re-run all Rust-tool tests and require zero failures.

### Task 5: Declarative Nix wiring and real integration

**Files:**
- Modify: `modules/programs/pi/pi.nix`
- Create: `modules/programs/pi/extensions/rust-tools/tests/integration.test.ts`

**Interfaces:**
- Produces: per-system `checks.pi-rust-tools`; immutable generated extension
  entry points for `rust-intelligence` and `rust-debugger`; absolute paths for
  Node, Cargo, rustc, rust-analyzer, Nix, and CodeLLDB.

- [ ] Write an integration test that starts the real packaged
  `rust-analyzer`, checks definition/reference/hover/call-hierarchy/diagnostic
  behavior in the fixture, builds a target, starts real CodeLLDB, hits a
  breakpoint, reads a local variable and stack, continues, and exits.
- [ ] Add the test to a temporary direct Node invocation with executable paths
  from `nix eval`; run it and confirm it fails before Nix wiring supplies the
  required environment.
- [ ] Add a Nix test derivation that copies immutable sources, runs every Node
  test, and supplies packaged executable paths. Install generated Home Manager
  entry points that call both factories with those same paths.
- [ ] Format `modules/programs/pi/pi.nix` with `alejandra` and run the dedicated
  Nix check, requiring all unit, fake-peer, and supported live integration tests
  to pass.

### Task 6: Extensive verification and retirement

**Files:**
- Modify: `specs/rust-code-intelligence.md`
- Create: `docs/explanation/pi-rust-code-intelligence.md`

**Interfaces:**
- Consumes every tool and check from Tasks 1-5; produces verified configuration
  and durable explanation of the architecture.

- [ ] Run every Node test directly and through `checks.pi-rust-tools`, with zero
  failures, warnings, orphan processes, or leftover sockets.
- [ ] Run the Rust fixture acceptance flow end to end through both extension
  factories and verify focused context, target discovery, breakpoint stop,
  variable value, stack, continuation, and cleanup.
- [ ] Run `nix flake check` and dry-build the affected NixOS Pi homes with
  `--no-link`; evaluate the affected aarch64-darwin Pi home derivations from
  NixOS.
- [ ] Inspect the complete diff, run `git diff --check`, verify every spec
  requirement against fresh command output, and surface the macOS live smoke
  test as pending if no Apple host is available.
- [ ] Graduate the durable rationale into the appropriate Diátaxis page and
  remove this consumed spec only after implementation and available-platform
  verification are complete.
