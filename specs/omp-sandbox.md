# Scoped OMP sandbox

## Spec

### Goal

On Linux, make `omp` safe to run with automatic tool approval by moving the security boundary below OMP. The normal command must run inside a kernel-enforced Bubblewrap sandbox scoped to the current Git project. The project is fully writable; unrelated host data is neither readable nor writable. Broader host access requires a separate, explicitly confirmed host-shell launch.

This protects the rest of the workstation from routine model mistakes and malicious project instructions. It does not protect the selected project from OMP, protect project contents from the model provider, isolate the host network, or provide a separate-kernel boundary.

The sandbox entrypoints, boundaries, failure behavior, and acceptance contract below are Linux-only unless a clause says otherwise. Darwin keeps the upstream `omp` package, the existing `always-ask` policy, and CodeCompanion's inherited ACP filesystem capabilities; it receives no Bubblewrap launcher, sandbox state, or Linux user services.

### Chosen architecture

Use Bubblewrap as the primary boundary, with a systemd user scope for lifecycle and resource control. Bubblewrap starts from an empty mount namespace and adds only enumerated paths. This fail-closed allowlist is simpler and easier to audit than exposing the host root and masking selected paths.

Bubblewrap is preferred over rootless Podman because this task needs a small filesystem/process boundary rather than an OCI image lifecycle. A KVM microVM would provide a stronger separate-kernel boundary, but its guest state, toolchain, networking, and Nix integration are disproportionate for the default workflow. The launcher remains a clean seam: a microVM-backed profile can replace Bubblewrap later without changing the `omp`/`omp-unconfined` user contract.

The shared host network is an explicit trade-off. OMP, web research, Git remotes, and package downloads continue to work, but OMP can transmit any data visible inside the selected project and can reach host/LAN services. No network-isolation claim may be made.

### Entrypoints

`omp` becomes an immutable Nix-store launcher rather than the upstream binary directly. Before OMP starts, the launcher:

1. resolves the canonical Git worktree root from the current directory;
2. preserves the current directory as a relative path beneath that root;
3. validates every host path that will be mounted;
4. constructs the systemd scope and Bubblewrap arguments without sourcing or evaluating repository-controlled files; and
5. starts the upstream OMP binary inside `/workspace` with an explicit yolo approval mode.

Launching `omp` outside a Git worktree fails with a clear error. It never falls back to unconfined execution and does not silently treat an arbitrary current directory as trusted.

`omp-unconfined` starts the upstream binary against the existing host OMP state and `always-ask` policy. Before launch it prints that the process can access the full user account and requires an interactive host-terminal confirmation. There is no noninteractive confirmation bypass. Calling the upstream binary or `omp-unconfined` from inside a running sandbox cannot escape the namespaces already inherited.

### Project and Git boundary

The canonical worktree root is mounted read-write at `/workspace`. OMP starts at the equivalent relative working directory so launching from a project subdirectory preserves context. The whole selected project, including its `.git` directory and any secrets stored in the worktree, is intentionally within the trust boundary.

Filesystem symlinks are not grants. A link whose target is outside the mounted project resolves to an absent path inside the sandbox.

A normal repository whose Git directory is inside the worktree needs no additional access. A linked worktree has external Git metadata. The launcher must show each canonical external Git directory it proposes to mount and require host-side confirmation before OMP starts. Rejection aborts the launch. Only the exact Git directory and common directory required by that worktree are mounted; neither their parent directories nor sibling worktrees are exposed. A repository-controlled `.git` pointer never widens access silently.

### Filesystem view

The sandbox is assembled additively.

Writable paths:

- `/workspace`, backed by the selected worktree;
- confirmed external Git metadata for a linked worktree;
- private tmpfs instances for `/tmp`, `/run`, and `/dev/shm`; and
- one persistent OMP state directory dedicated to the canonical project path.

Read-only paths:

- `/nix/store`;
- resolved Nix profile targets needed to expose the installed command-line toolchain without mounting the real profile directories;
- minimal generated identity, Git identity, resolver, certificate, locale, timezone, and Nix client configuration;
- `/etc/resolv.conf` and `/etc/hosts` when needed for the selected normal-network policy.

The sole host inter-process communication channel is the exact Nix daemon socket, subject to the trust check below. Connecting to it is an active capability, not read-only filesystem access.

The real host root and home are absent. In particular, the sandbox does not receive unrelated repositories; SSH, GPG, Age/SOPS, cloud, Kubernetes, password-store, browser, or host OMP credentials; user shell startup files; arbitrary `/etc`; host `/proc` or `/sys`; physical devices; or D-Bus, SSH-agent, GPG-agent, Docker/Podman, graphical-session, journal, and systemd control sockets.

A minimal Git configuration supplies declared user name and email for local commits but no credential helper, signing key, include directive, URL rewrite, or executable hook outside the project. Network access alone therefore does not expose host Git credentials.

### Process and environment boundary

Bubblewrap creates fresh user, PID, IPC, and UTS namespaces; a fresh `/proc`; and a minimal `/dev`. The launched process has no capabilities. The launcher uses a new controlling session, dies with its parent, closes unrelated inherited file descriptors, and disables creation of further user namespaces after setup. No agent-accessible mount, namespace, portal, D-Bus, container-engine, or systemd control channel exists.

The environment is cleared and rebuilt from an allowlist. It includes only required terminal, locale, sandbox-home, curated toolchain, Nix client, and model-gateway values. Ambient credential variables, shell startup configuration, proxy credentials, agent sockets, graphical-session variables, and container control variables are omitted.

A systemd user scope owns the complete Bubblewrap process tree. It provides deterministic cleanup and guards against a fork or memory-exhaustion accident with `TasksMax=2048`, `MemoryHigh=75%`, and `MemoryMax=90%`. It does not impose a CPU quota. These limits apply to sandbox descendants, not to builders started by the host Nix daemon.

### Nix access

The sandbox mounts `/nix/store` read-only and exposes only `/nix/var/nix/daemon-socket/socket`, with `NIX_REMOTE=daemon`. No writable profile, daemon state directory, or other `/nix/var/nix` path is mounted.

The full store is an intentional read-boundary exception: it exposes every world-readable store path, including any secret incorrectly copied into a derivation. Closure-only mounts were rejected because daemon builds created after launch would remain invisible. Secrets must continue to live outside the Nix store, as required elsewhere in this repository.

At every launch, the host-side launcher reads the effective Nix `allowed-users` and `trusted-users` client configuration, then queries the running daemon with `nix store info --store daemon --json`. It parses `*`, the current username, and `@group` entries against the account database. The daemon socket is mounted only when configuration allows the user, configuration does not trust the user, and the live daemon independently reports `trusted: false`. Either source reporting trust—or any denied, stale, malformed, oversized, or ambiguous result—omits the socket and warns that sandboxed Nix builds are disabled. The current machine satisfies this invariant: `allowed-users = *`, `trusted-users = root`, and the live daemon reports the account untrusted.

This permits ordinary daemon-backed builds today, but daemon-side builders, downloads, disk use, and resource consumption are outside the Bubblewrap/systemd scope. The design does not claim to contain those daemon operations.

### OMP state and authentication

The real `~/.omp/agent` directory is never mounted. Its `agent.db` contains provider credentials and is outside the project boundary.

Each canonical project path maps to a persistent sandbox state directory keyed by a stable cryptographic hash of that path. Only that exact directory is mounted into the sandbox. It contains project-specific OMP sessions, cache, mutable runtime settings, and gateway client configuration. The launcher must not use repository-controlled state or policy to construct the sandbox.

Global AGENTS/RULES content, skills, agent definitions, extensions, and MCP declarations come from immutable Nix-store sources. Scoped OMP receives yolo through a runtime setting whose precedence is above global and project configuration. Project configuration may change OMP behavior inside the sandbox but cannot change mounts, namespaces, environment filtering, resource controls, or credential exposure.

Provider credentials remain in host-side services:

1. An OMP auth-broker systemd user service owns the existing host OAuth database and refresh tokens.
2. An OMP auth-gateway systemd user service connects to that broker and binds to loopback only.
3. Scoped OMP uses OMP's `pi-native` gateway transport.
4. The sandbox receives only the gateway bearer. It never receives the broker bearer, OAuth refresh token, or provider access token.
5. The gateway bearer authorizes model use but is useful only against the loopback-bound gateway; it is not an upstream provider credential.

The broker and gateway are declarative, hardened user services, but their token files and writable database remain runtime state outside Nix. The gateway is the only model-credential channel reachable from the sandbox. If it is unavailable, scoped OMP fails with a gateway diagnostic and never falls back to the host credential database.

Scoped and unconfined OMP histories remain separate. This prevents sandbox-controlled state from becoming input to a later unconfined session.

### Boundary expansion

A running scoped session cannot expand its filesystem authority. Any helper, socket, mutable policy file, or prompt API capable of granting a new host path would also be callable by yolo OMP and is prohibited.

To access another project, the user exits to the trusted host shell and launches `omp` from that project's worktree. To access the host generally, the user exits and runs `omp-unconfined`, then confirms the warning. Linked-worktree metadata confirmation occurs before OMP starts and displays the exact paths being added.

### Failure behavior

All security-sensitive failures are fail-closed:

- no Git worktree: abort;
- path canonicalization or validation failure: abort;
- linked-worktree metadata not confirmed: abort;
- Bubblewrap, namespace, or systemd-scope setup failure: abort before OMP starts;
- missing immutable OMP configuration source: abort;
- auth gateway unavailable: no local-credential fallback;
- Nix user trusted: omit the daemon socket and continue with an explicit warning; and
- requested host path absent from the mount allowlist: leave it absent rather than substituting a broader parent mount.

The launcher must report which invariant failed and the safe recovery action. It must never retry by weakening the sandbox.

### Verification and acceptance

Verification must exercise the real generated launcher in a temporary Git repository, not merely inspect Bubblewrap arguments.

The implementation is accepted only when all of the following are observed:

1. Files can be created, edited, executed, renamed, and deleted under the selected project.
2. An unrelated repository, the real home, representative credential paths, `/etc/nixos` when it is not the selected project, and a symlink escaping the project are unreadable and unwritable.
3. `/nix/store`, the curated toolchain, local Git metadata, normal outbound networking, and an untrusted-daemon Nix build work.
4. Host processes, `/run/user/$UID`, and host control/agent sockets are absent.
5. A scoped OMP model request succeeds through the gateway and a Bash tool call executes without an approval prompt.
6. Broker, provider, host OMP, SSH, Age/SOPS, and representative ambient environment secrets are absent from the Bash environment and filesystem.
7. A real linked worktree shows the exact external Git metadata paths, rejects them safely, and works after host confirmation without exposing their parent or sibling paths.
8. `omp` outside Git fails without starting upstream OMP.
9. `omp-unconfined` requires interactive confirmation and retains the existing `always-ask` policy.
10. Killing the launcher cleans up the sandbox process tree; task and memory limits are active. CPU and disk remain intentionally unquotaed, including writes to the project/state and daemon writes to `/nix/store`.
11. The effective Nix trust check mounts the daemon socket for the current untrusted user and omits it under a controlled trusted-user test.
12. The focused OMP sandbox check, package build, both affected NixOS system dry-builds, and both affected Linux standalone home activation-package dry-builds pass with `--no-link`; Aspen's candidate-source Neovim and activation derivation paths evaluate locally because Redwood has no Darwin builder. No project-wide suite runs and no configuration is activated during verification.

### Documentation and lifecycle

Durable documentation must update the OMP reference with the generated launcher, services, state split, and security invariants; update the coding-agent explanation with the scoped-yolo rationale, alternatives, and accepted trade-offs; and add a task-oriented guide covering scoped use, linked-worktree confirmation, unconfined use, failures, and the network/Nix caveats. The documentation must state plainly that the project and its data remain exposed to yolo OMP and ordinary outbound networking.

After implementation, behavioral verification, documentation, and review are complete, this transient spec is deleted. The code and Diátaxis documentation become the source of truth.

### Security basis

The design relies on Bubblewrap's empty-root mount namespace and explicit bind model, not on OMP approvals: <https://github.com/containers/bubblewrap/blob/main/README.md> and <https://manpages.debian.org/trixie/bubblewrap/bwrap.1.en.html>.

The Nix daemon socket is conditioned on Nix's warning that trusted users are effectively root-equivalent: <https://nix.dev/manual/nix/2.34/command-ref/conf-file#conf-trusted-users>.

Systemd supplies additive lifecycle/resource controls rather than the primary filesystem boundary because its own documentation describes limitations in filesystem sandboxing and graceful feature disablement: <https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html#Sandboxing>.

## Plan

**Goal:** Deliver the approved Linux-only, project-scoped `omp` boundary while preserving upstream OMP, `always-ask`, and inherited ACP filesystem capabilities on Darwin.

### Fixed constraints

- OMP is v17.0.0 from `llm-agents.nix`, tag `v17.0.0`, commit `d5cd24f39a951bfbd50dc8f50bcf095d59694d6c`.
- Linux redwood and spruce receive the wrapper and two user services; Darwin aspen receives the unchanged upstream derivation, no services, and the unchanged activation-merged `always-ask` policy.
- `flake.programs.oh-my-pi` remains the only delivery declaration. `flake.nix` is generated and is never edited. No new flake input or non-Nix package manager is introduced.
- The sandbox shares the host network by design. The project, isolated project state, confirmed filtered Git metadata, full read-only Nix store, and—only for an allowed but untrusted user—the exact daemon socket are the only host-data exceptions.
- Systemd supplies cleanup and task/memory controls; Bubblewrap supplies the filesystem/process boundary. CPU and writable project/state/store disk are intentionally unquotaed, and daemon builders remain outside the user scope.
- Verification evidence is checkout-specific and becomes stale after any relevant edit. Restart at the earliest affected Task 5 gate and rerun every downstream behavioral, platform, build, documentation, and review gate before relying on the result or retiring this spec.

### Source-verified OMP and ACP contract

1. OMP scalar flags resolve left-to-right and `--` terminates parsing. The wrapper constructs the explicit `launch` or `acp` subcommand first, then immutable `--config <policy>` and `--approval-mode yolo`, then validated caller arguments. It rejects `--`, `--config`, `--profile`, `--provider`, `--api-key`, `--approval-mode`, `--auto-approve`, `--yolo`, `--cwd`, `--mode`, and their equals forms. Only argv element zero equal to `acp` selects ACP. Source: `cli-commands.ts:90-143`, `cli/args.ts:112-125,258-273`, `cli/flag-tables.ts:121-142,236-249`, `main.ts:1133-1157`.
2. `models.yml` is an override-only `openai-codex` entry with `baseUrl: http://127.0.0.1:4000`, an `apiKey` command generated from `lib.getExe' pkgs.coreutils "cat"` plus `/run/omp-gateway-bearer`, and `transport: pi-native`; it contains no discovery or copied model catalog. The command uses an absolute immutable store path, so neither `PATH` nor project content can redirect secret resolution. OMP resolves it once, trims/caches stdout for the process lifetime, and never needs the bearer in its environment or argv. The immutable policy disables `ollama`, `llama.cpp`, and `lm-studio`, prefers `openai-codex`, and supplies yolo, while the explicit runtime flag remains highest precedence. Caller `--model` must be `openai-codex/<id>`. Source: `model-registry.ts:278-334,1272-1355,1794-1829`, `models-config-schema.ts:257-286`, `models-config.ts:31-78`, `pi-native-client.ts:105-126,160-173`.
3. The launcher reads the gateway token with `O_NOFOLLOW`, verifies uid/mode/one line, and performs authenticated loopback `GET /v1/models` with `http.client`, no proxies/redirects/DNS. It requires an `owned_by: openai-codex` model and an exact requested model. Pi-native returns directly and cannot fall through to a provider SDK. Source: `model-registry.ts:320-330`, `pi-native-client.ts:105-126`, `stream.ts:1121-1140`, `auth-gateway/server.ts:540-621,758-795`.
4. Gateway startup fetches a broker snapshot before bind, so the gateway has `After=`/`Wants=` and `Restart=on-failure`; `Wants=` co-starts the broker without propagating a later broker restart or failure into a healthy gateway. Authenticated `/v1/models`, never `/healthz`, is readiness. OMP writes its runtime tokens without trailing newlines, so the service wrapper uses `$(<file)` rather than bare `read` under `errexit`.
5. OMP ACP passes the client's absolute cwd unchanged. The project is therefore mounted at `/workspace` and as a second canonical-address alias behind empty parents. A reserved-destination check rejects any root/Git destination that equals or covers `/`, `/nix`, `/proc`, `/dev`, `/run`, `/home/omp`, `/workspace`, or `/etc`.
6. CodeCompanion 19.18 inherits `fs.readTextFile`/`fs.writeTextFile`. Linux assigns `adapter.parameters.clientCapabilities = vim.empty_dict()` after extension so JSON is `{}`, not `[]`, and tools stay inside Bubblewrap. Darwin does not receive this assignment. OMP ACP emits each tool start as `tool_call` and its terminal `failed`/`completed` outcome as `tool_call_update`, correlated by `toolCallId`; acceptance therefore proves the exact denied read and completed final Bash call rather than counting starts. Source: CodeCompanion `adapters/acp/claude_code.lua:31-38`, `acp/init.lua:66-69`; OMP `acp-agent.ts:376-414,749-883`, `acp-event-mapper.ts:190-241`.

### Exact file and output map

| Path | Action | Responsibility |
|---|---|---|
| `modules/programs/oh-my-pi/_sandbox-package.nix` | Create | Pure `{ pkgs, lib, upstreamOmp, mcpNixos, configSrc, sharedSkillsSrc }` factory returning `{ package, assets, check }`. |
| `modules/programs/oh-my-pi/sandbox/launcher.py` | Create | Complete production launcher and importable test seams in Task 2's normative listing. |
| `modules/programs/oh-my-pi/sandbox/test_launcher.py` | Create | Complete standard-library regression listing in Task 1. |
| `modules/programs/oh-my-pi/sandbox/acceptance.py` | Create | Real-boundary modes: filesystem, linked-worktree, gateway, scope, state, model, ACP, all. |
| `modules/programs/oh-my-pi/oh-my-pi.nix` | Modify | Bind upstream/factory once; expose Linux package/apps/check; select wrapper on Linux/upstream on Darwin; declare Linux services. |
| `modules/programs/nvf/nvf.nix` | Modify | Preserve `{ "omp", "acp" }`; assign `vim.empty_dict()` only on Linux after adapter extension. |
| `docs/reference/oh-my-pi.md` | Modify | Exact mechanics, failure table, platform table, commands. |
| `docs/explanation/coding-agents.md` | Modify | Boundary rationale, alternatives, ACP trade-off, accepted risks. |
| `docs/how-to/use-scoped-omp.md` | Create | Flat task guide for scoped/linked/ACP/unconfined/recovery use. |
| `docs/README.md` | Modify | Add the flat how-to link. |
| `specs/omp-sandbox.md` | Delete after all gates | Retire only after behavior, dry-builds, docs, and review are clean. |

Linux per-system outputs are `packages.omp-sandbox`, `apps.omp-sandbox-exec`, `apps.omp-sandbox-acceptance`, and `checks.omp-sandbox`. The package contains `omp`, `omp-unconfined`, `omp-sandbox-exec`, `omp-auth-gateway-service`, and `omp-sandbox-acceptance`.

### Exact launcher interfaces

The normative Python in Task 2 is authoritative. Its exported seams are:

```python
CommandRunner = Callable[
    [Sequence[str], Mapping[str, str]],
    subprocess.CompletedProcess[str],
]
class ProcessFactory(Protocol):
    def __call__(
        self, argv: Sequence[str], *,
        env: Mapping[str, str] | None = None,
        start_new_session: bool = False,
        pass_fds: tuple[int, ...] = (),
    ) -> subprocess.Popen[bytes]: ...

def run_capture(argv: Sequence[str], environment: Mapping[str, str], timeout: float = 10, check: bool = True) -> subprocess.CompletedProcess[str]: ...
def terminate_process_group(process: subprocess.Popen, grace: float = 5) -> int: ...
def wait_owned_process(process: subprocess.Popen) -> int: ...
def resolve_host_context() -> HostContext: ...
def pin_path(path: Path, expected_type: int) -> PinnedPath: ...
def duplicate_pin(source: PinnedPath) -> PinnedPath: ...
def close_pins(paths: Iterable[PinnedPath | None]) -> None: ...
def pin_paths(requests: Iterable[tuple[Path, int]], pin: Callable = pin_path) -> tuple[PinnedPath, ...]: ...
def validate_pins(paths: Iterable[PinnedPath | None]) -> None: ...
def validate_current_path(path: PinnedPath) -> None: ...
def resolve_git_context(cwd: Path, run: CommandRunner) -> GitContext: ...
def confirm_external_git(context: GitContext, run: CommandRunner, tty_path: str = "/dev/tty") -> None: ...
def validate_external_git_pins(context: GitContext) -> None: ...
def project_state(host: HostContext, root_path: Path) -> PinnedPath: ...
def parse_daemon_info(text: str) -> bool: ...
def nix_socket_policy(host: HostContext, run: CommandRunner) -> tuple[PinnedPath | None, str | None]: ...
def validate_scoped_args(args: Sequence[str]) -> tuple[str, list[str], str | None]: ...
def build_environment(host: HostContext, profiles: Sequence[Path], nix_socket: PinnedPath | None) -> dict[str, str]: ...
def build_bwrap_argv(host: HostContext, git_context: GitContext, state: PinnedPath, runtime: RuntimeFiles, command: Sequence[str], nix_socket: PinnedPath | None, profiles: Sequence[Path], bind_pins: list[PinnedPath]) -> list[str]: ...
def run_scope(host: HostContext, inner_arguments: Sequence[str], popen: ProcessFactory = subprocess.Popen) -> int: ...
def verify_scope(host: HostContext, unit: str) -> None: ...
def run_bwrap(bwrap_argv: Sequence[str], bind_pins: list[PinnedPath], popen: ProcessFactory = subprocess.Popen) -> int: ...
def main(arguments: Sequence[str] | None = None) -> int: ...
```

Pinned sources establish immutable identity; each Bubblewrap 0.11.2 `--bind-fd`/`--ro-bind-fd` occurrence receives its own duplicated descriptor because Bubblewrap consumes that fd after one bind. No `/proc/self/fd` pathname or duplicate fd is reused. The public launcher first re-executes the immutable module as `inner-scoped`/`inner-exec` under `systemd-run --user --scope`. The inner mode verifies its generated unit in `/proc/self/cgroup` and verifies task/memory/no-CPU properties before resolving host paths. It opens/pins sources inside the scope, validates every source descriptor, separately requires the live daemon-socket pathname to still name its pin, and transactionally creates only the per-operation duplicates referenced by the Bubblewrap argv. The parent closes those duplicates immediately after `Popen`; Bubblewrap consumes the child copies. An immutable Python trampoline closes every descriptor above 2 before the model-controlled command, so Yama `ptrace_scope=1` is irrelevant and neither the user bus nor any mount pin survives into model-controlled code. A direct private-mode invocation fails scope verification.

### Executor sequence and invariants

1. Resolve uid/gid, username and primary group from the account database, `/run/user/$UID`, and the owned Unix bus socket. Validate bus ownership through the pinned descriptor and require its pathname to retain the same device/inode/socket type before every systemd client call. Ambient home/PWD/XDG/D-Bus values have no authority. Nix `@group` authorization matches the daemon exactly: peer primary group or username membership in that group’s account-database record.
2. Resolve Git with absolute substituted Git and a newly constructed sterile environment. Require a worktree; canonicalize root/git/common; reject malformed results; pin source descriptors. For linked worktrees, print the exact sorted external path set as JSON strings and require literal `yes` from `/dev/tty`; re-query before and after the answer, then require each approved pathname to retain its pinned identity immediately before Bubblewrap spawn. Ordinary repositories neither prompt nor perform confirmation-time re-queries.
3. For linked worktrees, bind common metadata, unconditionally tmpfs-mask `hooks` and `worktrees`, and rebind only the selected admin directory. Highest-precedence `GIT_CONFIG_COUNT/KEY_n/VALUE_n` disables hooks/helpers/signing; `/etc/gitconfig` supplies only identity/safe defaults. Object alternates are never resolved/mounted.
4. Validate the canonical alias and every Git destination against the reserved-destination policy. Bind no alias parent content.
5. Create `~/.local/state/omp-sandbox/projects/<lowercase-sha256(canonical-root)>` under the passwd home with owner/symlink checks and mode 0700; pin it and mount at `/home/omp/.omp`. Immutable assets overlay models/policy-support/agents/skills/extensions, while project `config.yml` remains writable.
6. Resolve profile/current-system targets strictly to store directories and add only store `bin` paths. The fixed curated PATH includes browser and `nil`. The full `/nix/store` is read-only.
7. Query effective `allowed-users` and `trusted-users` with absolute Nix and sterile Nix variables, then query live trust with `nix store info --store daemon --json`. Parse config `*`/username/effective `@group` tokens and a bounded strict daemon object inside the failure boundary. Mount the exact socket only when both sources establish allowed-but-untrusted access; trusted/disallowed/denied/stale/malformed/oversized/group failures omit it and warn.
8. Generate pinned passwd, group, hosts, resolver, Git, and Nix client files. Set fixed `C.UTF-8`, store `LOCALE_ARCHIVE`, `TZ=UTC`, and store `TZDIR`.
9. Build Bubblewrap from empty tmpfs root with user/PID/IPC/UTS isolation, fresh proc/dev/tmp/run/dev-shm, no caps or nested user namespaces, shared network, read-only store/certs/assets, writable project/Git/state, and no host process/session/control/credential sockets.
10. Clear the environment, then set only identity/home/path/locale/cert/OMP path, command-scope Git, and optional Nix daemon variables. No authentication material enters the environment or argv. Scoped OMP alone resolves the gateway bearer from a pinned mode-0600 runtime file through its immutable `!cat` API-key setting. Provider/OAuth/broker/SSH/GPG/Age/SOPS/cloud/Kubernetes/proxy/desktop/container variables remain absent.
11. Scoped OMP performs authenticated readiness before Bubblewrap. `omp-sandbox-exec` applies the same boundary without reading/injecting gateway credentials. `omp-unconfined` uses `/dev/tty`, accepts only literal `yes`, rejects approval overrides, and execs explicit upstream `launch --approval-mode always-ask`.
12. The outer scope uses `TasksMax=2048`, `MemoryHigh=75%`, `MemoryMax=90%`, no CPU quota, signal forwarding, `--collect`, and exact-unit cleanup. The inner process and Bubblewrap are members of that scope; source pins and temporary files remain alive through child exit, while parent-side per-bind duplicates close immediately after spawn.

### Verification contract

- RED/GREEN uses only `nix build .#checks.x86_64-linux.omp-sandbox --no-link`.
- Real boundary uses the checked-in acceptance modes, including a target-host run with `ptrace_scope=1`.
- Service/platform/adapter shape uses the exact focused eval/headless commands in Tasks 3-4.
- Final verification runs `nix flake check`, dry-builds both affected Linux systems and homes plus the package/check, and evaluates the candidate-source Darwin home. It never activates a generation.
- Every entrypoint-level fail-closed probe owns a file/command or unique upstream-output sentinel proving the protected command did not execute. Leaf parser/validator unit tests assert their local invariant without claiming entrypoint reachability. Actual secret values—not only variable names—are excluded from output, final-command argv/environment, process metadata where readable, and a real Bash tool child environment. Production subprocesses start in owned groups; captured streams are drained concurrently with a 1 MiB retention cap; preflight commands have a fixed deadline; and interruption/timeout sends TERM, then KILL, verifies descendants are gone, and reaps the leader.

## Tasks

### Task 1: Package immutable assets and wire the test harness

**Files:**

- Create: `modules/programs/oh-my-pi/_sandbox-package.nix`
- Create: `modules/programs/oh-my-pi/sandbox/launcher.py`
- Create: `modules/programs/oh-my-pi/sandbox/test_launcher.py`
- Create: `modules/programs/oh-my-pi/sandbox/acceptance.py`
- Modify: `modules/programs/oh-my-pi/oh-my-pi.nix`

**Interfaces:**

- Consumes: the pinned `upstreamOmp`, existing `configSrc`, `sharedSkillsSrc`, and `lib.getExe pkgs.mcp-nixos`.
- Produces: `{ package, assets, check }` internally and the Linux per-system output `checks.omp-sandbox`. The package derivation is intentionally lazy and unexposed until Task 2 completes every launcher body and `__main__` dispatch; no public wrapper is runnable or installed at this commit point.
- Invariant: every executable/dependency/asset path is substituted by Nix. Tests inject fakes through Python call parameters only; production never reads an executor/dependency override from the environment.

- [ ] **Step 1: Add failing asset and executor-interface tests**

  Create `test_launcher.py` with `unittest` cases that import `launcher.py` and assert:

  ```python
  import os
  import unittest
  from pathlib import Path

  import launcher
  class PackageContractTests(unittest.TestCase):
      def test_assets_are_complete_and_immutable(self):
          root = Path(os.environ["OMP_SANDBOX_ASSETS"])
          models = (root / "agent/models.yml").read_text()
          self.assertRegex(
              models,
              r'\Aproviders:\n'
              r'  openai-codex:\n'
              r'    baseUrl: http://127\.0\.0\.1:4000\n'
              r'    apiKey: "!/nix/store/[0-9a-z]{32}-coreutils-[^/\n]+'
              r'/bin/cat /run/omp-gateway-bearer"\n'
              r'    transport: pi-native\n\Z',
          )
          self.assertEqual(
              (root / "agent/policy.yml").read_text(),
              "tools:\n"
              "  approvalMode: yolo\n"
              "disabledProviders:\n"
              "  - ollama\n"
              "  - llama.cpp\n"
              "  - lm-studio\n"
              "modelProviderOrder:\n"
              "  - openai-codex\n"
              "symbolPreset: nerd\n",
          )
          self.assertTrue((root / "agent/AGENTS.md").is_file())
          self.assertTrue((root / "agent/RULES.md").is_file())
          self.assertTrue((root / "agent/mcp.json").is_file())
          flow_maps = tuple((root / "agent/extensions").glob("*.ts"))
          self.assertEqual(len(flow_maps), 1)
          self.assertIn("const FLOW_MAP", flow_maps[0].read_text())
          self.assertEqual(len(tuple((root / "agent/agents").glob("*.md"))), 18)
          self.assertEqual(len(tuple((root / "agent/skills").glob("*/SKILL.md"))), 18)

      def test_public_modes_are_fixed(self):
          self.assertEqual(launcher.PUBLIC_MODES, ("scoped", "unconfined", "exec"))
          self.assertFalse(hasattr(launcher, "dependency_from_environment"))
  ```

  Append the following complete test support and regression classes in the same file; later RED steps enable each class before its production body is copied, so this is the single normative test implementation rather than prose the implementer must invent:

  ```python
  import contextlib
  import dataclasses
  import grp
  import http.client
  import json
  import os
  import pathlib
  import pwd
  import signal
  import socket
  import stat
  import subprocess
  import sys
  import tempfile
  import types
  import unittest
  from unittest import mock

  import launcher

  class FakeTTY:
      def __init__(self, answer):
          self.answer = answer
          self.output = ""
      def __enter__(self):
          return self
      def __exit__(self, *_):
          return False
      def write(self, value):
          self.output += value
      def readline(self):
          return self.answer

  class FinishedProcess:
      def __init__(self, returncode=0):
          self.returncode = returncode
      def wait(self, timeout=None):
          return self.returncode

  class LauncherTestCase(unittest.TestCase):
      def setUp(self):
          self.temporary = tempfile.TemporaryDirectory(prefix="omp-unit-")
          self.addCleanup(self.temporary.cleanup)
          self.root = pathlib.Path(self.temporary.name)
          self.pins = []
          self.sockets = []
          self.addCleanup(self.close_resources)

      def close_resources(self):
          launcher.close_pins(self.pins)
          for item in self.sockets:
              item.close()

      def make_unix_socket(self):
          path = self.root / f"daemon-{len(self.sockets)}.sock"
          server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
          server.bind(os.fspath(path))
          self.sockets.append(server)
          return path

      def make_repo(self, name="repo"):
          repo = self.root / name
          repo.mkdir()
          subprocess.run([launcher.GIT, "init", "-q", str(repo)], check=True)
          subprocess.run(
              [launcher.GIT, "-C", str(repo), "config", "user.name", "Probe"],
              check=True,
          )
          subprocess.run(
              [launcher.GIT, "-C", str(repo), "config", "user.email",
               "probe@example.invalid"],
              check=True,
          )
          (repo / "tracked").write_text("tracked\n")
          subprocess.run(
              [launcher.GIT, "-C", str(repo), "add", "tracked"], check=True,
          )
          subprocess.run(
              [launcher.GIT, "-C", str(repo), "commit", "-qm", "probe"],
              check=True,
          )
          return repo.resolve()

      def keep_pin(self, path, expected_type):
          pinned = launcher.pin_path(path, expected_type)
          self.pins.append(pinned)
          return pinned

      def make_host(self):
          home = self.root / "home"
          runtime = self.root / "run"
          home.mkdir(exist_ok=True)
          runtime.mkdir(exist_ok=True)
          bus_path = runtime / "bus"
          bus = socket.socket(socket.AF_UNIX)
          bus.bind(os.fspath(bus_path))
          self.sockets.append(bus)
          bus_pin = self.keep_pin(bus_path, stat.S_IFSOCK)
          identity = pwd.getpwuid(os.getuid())
          return launcher.HostContext(
              os.getuid(), os.getgid(), identity.pw_name,
              grp.getgrgid(os.getgid()).gr_name,
              home.resolve(), runtime.resolve(), bus_pin,
          )

  @unittest.skip("enabled in Task 2 Step 1")
  class ResolutionAndStateTests(LauncherTestCase):
      def test_outside_git_is_rejected_by_resolver(self):
          with self.assertRaisesRegex(launcher.SandboxError, "command failed: git"):
              launcher.resolve_git_context(self.root, launcher.run_capture)

      def test_subdirectory_and_ambient_git_poison_are_ignored(self):
          repo = self.make_repo()
          child = repo / "a" / "b"
          child.mkdir(parents=True)
          poison = {
              "GIT_DIR": str(self.root / "other"),
              "GIT_WORK_TREE": str(self.root),
              "GIT_CONFIG_COUNT": "1",
              "GIT_CONFIG_KEY_0": "include.path",
              "GIT_CONFIG_VALUE_0": str(self.root / "host-config"),
              "GIT_CONFIG_GLOBAL": str(self.root / "host-config"),
              "GIT_OBJECT_DIRECTORY": str(self.root / "objects"),
              "GIT_ALTERNATE_OBJECT_DIRECTORIES": str(self.root / "alternate"),
          }
          with mock.patch.dict(os.environ, poison):
              context = launcher.resolve_git_context(child, launcher.run_capture)
          self.pins.extend((
              context.root, context.git_dir, context.common_dir,
              context.selected_worktree_admin,
          ))
          self.assertEqual(context.root.host_path, repo)
          self.assertEqual(context.relative_cwd, pathlib.PurePosixPath("a/b"))
          self.assertEqual(context.external_confirmation_paths, ())
          with (
              mock.patch("builtins.open", side_effect=AssertionError("tty opened")),
              mock.patch("launcher.git_paths", side_effect=AssertionError("Git queried")),
          ):
              launcher.confirm_external_git(context, launcher.run_capture)

      def test_linked_worktree_requires_literal_confirmation_and_hides_sibling(self):
          repo = self.make_repo("main")
          linked = self.root / "linked"
          sibling = self.root / "sibling"
          subprocess.run(
              [launcher.GIT, "-C", str(repo), "worktree", "add", "-q", str(linked)],
              check=True,
          )
          subprocess.run(
              [launcher.GIT, "-C", str(repo), "worktree", "add", "-q", str(sibling)],
              check=True,
          )
          context = launcher.resolve_git_context(linked, launcher.run_capture)
          self.pins.extend((
              context.root, context.git_dir, context.common_dir,
              context.selected_worktree_admin,
          ))
          expected_paths = tuple(sorted((
              repo / ".git",
              repo / ".git" / "worktrees" / linked.name,
          ), key=os.fspath))
          self.assertEqual(context.external_confirmation_paths, expected_paths)
          rejected = FakeTTY("yes \n")
          with mock.patch("builtins.open", return_value=rejected):
              with self.assertRaisesRegex(launcher.SandboxError, "not confirmed"):
                  launcher.confirm_external_git(context, launcher.run_capture)
          accepted = FakeTTY("yes\n")
          with mock.patch("builtins.open", return_value=accepted):
              launcher.confirm_external_git(context, launcher.run_capture)
          expected_prompt = (
              "OMP sandbox must mount these external Git metadata paths:\n"
              + "\n".join(json.dumps(os.fspath(path)) for path in expected_paths)
              + "\nType yes to continue: "
          )
          self.assertEqual(accepted.output, expected_prompt)

      def test_changed_metadata_path_fails_confirmation(self):
          main = self.make_repo("changed-main")
          linked = self.root / "changed-linked"
          subprocess.run(
              [launcher.GIT, "-C", str(main), "worktree", "add", "-q", str(linked)],
              check=True,
          )
          context = launcher.resolve_git_context(linked, launcher.run_capture)
          self.pins.extend((
              context.root, context.git_dir, context.common_dir,
              context.selected_worktree_admin,
          ))
          changed = (
              context.root.host_path,
              self.root / "changed-git",
              self.root / "changed-common",
          )
          with mock.patch("launcher.git_paths", return_value=changed):
              with self.assertRaisesRegex(launcher.SandboxError, "changed"):
                  launcher.confirm_external_git(context, launcher.run_capture)

      def test_metadata_change_after_confirmation_fails_closed(self):
          main = self.make_repo("race-main")
          linked = self.root / "race-linked"
          subprocess.run(
              [launcher.GIT, "-C", str(main), "worktree", "add", "-q", str(linked)],
              check=True,
          )
          context = launcher.resolve_git_context(linked, launcher.run_capture)
          self.pins.extend((
              context.root, context.git_dir, context.common_dir,
              context.selected_worktree_admin,
          ))
          expected = (
              context.root.host_path,
              context.git_dir.host_path,
              context.common_dir.host_path,
          )
          changed = (
              context.root.host_path,
              self.root / "changed-after-git",
              self.root / "changed-after-common",
          )
          with (
              mock.patch("builtins.open", return_value=FakeTTY("yes\n")),
              mock.patch("launcher.git_paths", side_effect=(expected, changed)),
          ):
              with self.assertRaisesRegex(launcher.SandboxError, "changed"):
                  launcher.confirm_external_git(context, launcher.run_capture)

      def test_pinned_descriptor_survives_path_replacement(self):
          repo = self.make_repo()
          pinned = self.keep_pin(repo, stat.S_IFDIR)
          original = (pinned.device, pinned.inode)
          moved = self.root / "moved"
          repo.rename(moved)
          repo.mkdir()
          launcher.validate_pins((pinned,))
          self.assertEqual(
              (os.fstat(pinned.fd).st_dev, os.fstat(pinned.fd).st_ino), original,
          )
          argv = []
          bind_pins = []
          launcher.add_pin_bind(
              argv, "--bind", pinned, "/workspace", bind_pins,
          )
          launcher.add_pin_bind(
              argv, "--bind", pinned, "/canonical-alias", bind_pins,
          )
          self.assertEqual(len(bind_pins), 2)
          first_duplicate, second_duplicate = bind_pins
          self.pins.extend(bind_pins)
          self.assertEqual(len({first_duplicate.fd, second_duplicate.fd}), 2)
          for duplicate in bind_pins:
              self.assertNotEqual(duplicate.fd, pinned.fd)
              self.assertEqual(
                  (duplicate.device, duplicate.inode),
                  (pinned.device, pinned.inode),
              )
          self.assertEqual(
              argv,
              [
                  "--bind-fd", str(first_duplicate.fd), "/workspace",
                  "--bind-fd", str(second_duplicate.fd), "/canonical-alias",
              ],
          )

      def test_state_hash_mode_and_second_launch_path_are_stable(self):
          host = self.make_host()
          repo = self.make_repo()
          first = launcher.project_state(host, repo)
          second = launcher.project_state(host, repo)
          self.pins.extend((first, second))
          expected = __import__("hashlib").sha256(os.fsencode(repo)).hexdigest()
          self.assertEqual(first.host_path.name, expected)
          self.assertEqual(stat.S_IMODE(first.mode), 0o700)
          self.assertEqual(first.host_path, second.host_path)

      def test_symlinked_or_wrong_owner_state_fails_closed(self):
          host = self.make_host()
          outside = self.root / "outside"
          outside.mkdir()
          (host.home / ".local").symlink_to(outside, target_is_directory=True)
          with self.assertRaisesRegex(launcher.SandboxError, "unsafe"):
              launcher.project_state(host, self.make_repo())
          (host.home / ".local").unlink()
          real_lstat = os.lstat
          def wrong_owner(path):
              result = real_lstat(path)
              if pathlib.Path(path).name == "omp-sandbox":
                  return types.SimpleNamespace(
                      st_mode=result.st_mode, st_uid=os.getuid() + 1,
                  )
              return result
          with mock.patch("launcher.os.lstat", side_effect=wrong_owner):
              with self.assertRaisesRegex(launcher.SandboxError, "unsafe"):
                  launcher.project_state(host, self.make_repo("second"))

  @unittest.skip("enabled in Task 2 Step 3")
  class TrustEnvironmentAndMountTests(LauncherTestCase):
      def fake_nix_runner(
          self, allowed, trusted, live_trusted=False, live_payload=None,
          fail_live=False,
      ):
          def runner(argv, environment):
              self.assertEqual(environment["NIX_USER_CONF_FILES"], "/dev/null")
              self.assertEqual(environment["NIX_REMOTE"], "")
              if argv[1:3] == ["store", "info"]:
                  if fail_live:
                      raise OSError("live daemon query denied")
                  value = live_payload
                  if value is None:
                      value = json.dumps({
                          "trusted": live_trusted,
                          "url": "daemon",
                          "version": "test",
                      })
              else:
                  value = allowed if argv[-1] == "allowed-users" else trusted
              return subprocess.CompletedProcess(argv, 0, value + "\n", "")
          return runner

      def test_nix_policy_covers_live_and_config_failure_classes(self):
          host = self.make_host()
          socket_path = self.make_unix_socket()
          primary = f"@{host.groupname}"
          allowed, warning = launcher.nix_socket_policy(
              host, self.fake_nix_runner(primary, "root"),
              socket_path=socket_path,
          )
          self.pins.append(allowed)
          self.assertIsNotNone(allowed)
          self.assertIn("untrusted", warning)
          context = launcher.resolve_git_context(
              self.make_repo("trusted-nix"), launcher.run_capture,
          )
          state = launcher.project_state(host, context.root.host_path)
          self.pins.extend((
              context.root, context.git_dir, context.common_dir,
              context.selected_worktree_admin, state,
          ))
          trusted_cases = (
              self.fake_nix_runner("*", primary),
              self.fake_nix_runner("*", "root", live_trusted=True),
          )
          for runner in trusted_cases:
              with self.subTest(trusted_runner=runner):
                  denied, warning = launcher.nix_socket_policy(
                      host, runner, socket_path=socket_path,
                  )
                  self.assertIsNone(denied)
                  self.assertIn("root-equivalent", warning)
                  environment = launcher.build_environment(host, (), denied)
                  self.assertNotIn("NIX_REMOTE", environment)
                  bind_pins = []
                  try:
                      with launcher.runtime_files(host) as runtime:
                          argv = launcher.build_bwrap_argv(
                              host, context, state, runtime,
                              [launcher.BASH, "-c", "true"],
                              denied, (), bind_pins,
                          )
                      self.assertNotIn(
                          "/nix/var/nix/daemon-socket/socket", argv,
                      )
                      self.assertNotIn("NIX_REMOTE", argv)
                  finally:
                      launcher.close_pins(bind_pins)
          cases = (
              (self.fake_nix_runner("other", "root"), "not in Nix allowed-users"),
              (self.fake_nix_runner("'*", "root"), "could not be verified"),
              (self.fake_nix_runner("*", "root", fail_live=True),
               "could not be verified"),
          )
          for runner, expected in cases:
              with self.subTest(expected=expected):
                  denied, warning = launcher.nix_socket_policy(
                      host, runner, socket_path=socket_path,
                  )
                  self.assertIsNone(denied)
                  self.assertIn(expected, warning)
          invalid_live = (
              "{}",
              '{"url":"daemon","trusted":0}',
              '{"url":"other","trusted":false}',
              "[]",
              "x" * 4097,
          )
          for payload in invalid_live:
              with self.subTest(payload=payload[:40]):
                  denied, warning = launcher.nix_socket_policy(
                      host,
                      self.fake_nix_runner(
                          "*", "root", live_payload=payload,
                      ),
                      socket_path=socket_path,
                  )
                  self.assertIsNone(denied)
                  self.assertIn("could not be verified", warning)

      def test_nix_group_matching_follows_daemon_membership(self):
          host = self.make_host()
          def no_lookup(_name):
              raise AssertionError("primary group must not require lookup")
          primary = launcher.parse_user_set(
              f"@{host.groupname}", host, no_lookup,
          )
          self.assertIn(host.username, primary)
          records = {
              "member": types.SimpleNamespace(gr_mem=[host.username]),
              "other": types.SimpleNamespace(gr_mem=["somebody-else"]),
          }
          def lookup(name):
              if name not in records:
                  raise KeyError(name)
              return records[name]
          self.assertIn(
              host.username, launcher.parse_user_set("@member", host, lookup),
          )
          self.assertNotIn(
              host.username,
              launcher.parse_user_set("@other @missing", host, lookup),
          )

      def test_runtime_file_context_closes_every_pin(self):
          host = self.make_host()
          with launcher.runtime_files(host) as files:
              pins = (
                  files.passwd, files.group, files.hosts, files.resolv,
                  files.gitconfig, files.nixconfig,
              )
              descriptors = [item.fd for item in pins]
              for descriptor in descriptors:
                  os.fstat(descriptor)
          for descriptor in descriptors:
              with self.assertRaises(OSError):
                  os.fstat(descriptor)

      def test_pin_construction_is_transactional(self):
          source = self.root / "pin-source"
          source.write_text("source")
          descriptor = os.open(source, os.O_RDONLY)
          with (
              mock.patch("launcher.os.open", return_value=descriptor),
              mock.patch("launcher.os.fstat", side_effect=OSError("fstat failed")),
              self.assertRaises(launcher.SandboxError),
          ):
              launcher.pin_path(source, stat.S_IFREG)
          with self.assertRaises(OSError):
              os.fstat(descriptor)

          first = self.keep_pin(source, stat.S_IFREG)
          calls = 0
          def fail_second(path, expected_type):
              nonlocal calls
              calls += 1
              if calls == 2:
                  raise OSError("later pin failed")
              return first
          with self.assertRaisesRegex(OSError, "later pin failed"):
              launcher.pin_paths(
                  ((source, stat.S_IFREG), (source, stat.S_IFREG)),
                  fail_second,
              )
          with self.assertRaises(OSError):
              os.fstat(first.fd)

      def test_environment_is_allowlisted_and_git_settings_are_command_scope(self):
          host = self.make_host()
          environment = launcher.build_environment(host, (), None)

          for name in (
              "SSH_AUTH_SOCK", "GPG_AGENT_INFO", "SOPS_AGE_KEY",
              "AWS_SECRET_ACCESS_KEY", "KUBECONFIG", "OPENAI_API_KEY",
              "HTTP_PROXY", "http_proxy", "DBUS_SESSION_BUS_ADDRESS",
              "XDG_RUNTIME_DIR",
          ):
              self.assertNotIn(name, environment)
          self.assertEqual(environment["GIT_CONFIG_COUNT"], "4")
          self.assertEqual(environment["GIT_CONFIG_VALUE_0"], "/dev/null")
          self.assertEqual(environment["GIT_CONFIG_VALUE_1"], "")
          self.assertNotIn("NIX_REMOTE", environment)
          self.assertNotIn("OMP_AUTH_GATEWAY_BEARER", environment)
          with_nix = launcher.build_environment(host, (), host.bus_socket)
          self.assertEqual(with_nix["NIX_REMOTE"], "daemon")

      def test_existing_profile_target_outside_store_aborts(self):
          host = self.make_host()
          profile = host.home / ".nix-profile"
          target = self.root / "mutable-profile"
          target.mkdir()
          profile.symlink_to(target, target_is_directory=True)
          with self.assertRaisesRegex(launcher.SandboxError, "immutable store"):
              launcher.resolve_profile_targets(host)

      def test_reserved_alias_destinations_and_ancestors_fail(self):
          for reserved in launcher.RESERVED_DESTINATIONS:
              for destination in (reserved, *reserved.parents):
                  with self.subTest(reserved=reserved, destination=destination):
                      with self.assertRaisesRegex(launcher.SandboxError, "policy"):
                          launcher.validate_mount_destination(destination)
          launcher.validate_mount_destination(self.root / "repo")

      def test_external_git_metadata_cannot_cover_project_alias(self):
          root = self.root / "metadata" / "project"
          with self.assertRaisesRegex(launcher.SandboxError, "covers project"):
              launcher.validate_git_destinations(root, (root.parent,))
          launcher.validate_git_destinations(root, (root / ".git",))

      def test_bwrap_namespace_prefix_is_supported(self):
          host = self.make_host()
          context = launcher.resolve_git_context(
              self.make_repo("namespace-prefix"), launcher.run_capture,
          )
          state = launcher.project_state(host, context.root.host_path)
          self.pins.extend((
              context.root, context.git_dir, context.common_dir,
              context.selected_worktree_admin, state,
          ))
          bind_pins = []
          try:
              with launcher.runtime_files(host) as runtime:
                  argv = launcher.build_bwrap_argv(
                      host, context, state, runtime,
                      [launcher.BASH, "-c", "true"], None, (), bind_pins,
                  )
              self.assertEqual(argv[:12], [
                  launcher.BWRAP, "--die-with-parent", "--new-session",
                  "--unshare-user", "--unshare-pid", "--unshare-ipc",
                  "--unshare-uts", "--disable-userns",
                  "--cap-drop", "ALL", "--clearenv", "--tmpfs",
              ])
              self.assertNotIn("--unshare-all", argv)
              self.assertNotIn("--unshare-net", argv)
          finally:
              launcher.close_pins(bind_pins)

  @unittest.skip("enabled in Task 2 Step 5")
  class CliGatewayAndScopeTests(LauncherTestCase):
      def test_exact_scoped_and_unconfined_argv(self):
          command, model = launcher.scoped_omp_command([
              "acp", "--model", "openai-codex/gpt-5.6-sol",
          ])
          self.assertEqual(command, [
              launcher.UPSTREAM_OMP, "acp", "--config",
              str(launcher.ASSETS / "agent/policy.yml"),
              "--approval-mode", "yolo",
              "--model", "openai-codex/gpt-5.6-sol",
          ])
          self.assertEqual(model, "openai-codex/gpt-5.6-sol")
          self.assertEqual(
              launcher.unconfined_command(["hello"]),
              [launcher.UPSTREAM_OMP, "launch",
               "--approval-mode", "always-ask", "hello"],
          )

      def test_unconfined_rejects_every_approval_override(self):
          for option in ("--approval-mode", "--auto-approve", "--yolo"):
              for arguments in ([option, "yolo"], [f"{option}=yolo"]):
                  with self.subTest(arguments=arguments):
                      with self.assertRaisesRegex(
                          launcher.SandboxError, "override is not allowed",
                      ):
                          launcher.unconfined_command(arguments)

      def test_forbidden_flags_and_model_forms(self):
          self.assertEqual(launcher.FORBIDDEN_OPTIONS, (
              "--config", "--profile", "--provider", "--api-key",
              "--approval-mode", "--auto-approve", "--yolo", "--cwd", "--mode",
          ))
          for option in launcher.FORBIDDEN_OPTIONS:
              for arguments in ([option, "value"], [f"{option}=value"]):
                  with self.subTest(arguments=arguments):
                      with self.assertRaises(launcher.SandboxError):
                          launcher.validate_scoped_args(arguments)
          for arguments in (
              ["--"], ["--model"], ["--model", "gpt-5"],
              ["--model=openai-codex/"],
          ):
              with self.subTest(arguments=arguments):
                  with self.assertRaises(launcher.SandboxError):
                      launcher.validate_scoped_args(arguments)
          self.assertEqual(
              launcher.validate_scoped_args(["--no-tools", "acp"])[0], "launch",
          )

      def test_gateway_token_no_follow_and_permissions(self):
          host = self.make_host()
          token_dir = host.home / ".omp"
          token_dir.mkdir()
          token = token_dir / "auth-gateway.token"
          token.write_text("secret-without-newline")
          token.chmod(0o600)
          self.assertEqual(launcher.read_gateway_bearer(host),
                           "secret-without-newline")
          for invalid in (b"", b"leading\nsecret", b"secret\n", b"two\nlines", b"\xff"):
              with self.subTest(invalid=invalid):
                  token.write_bytes(invalid)
                  token.chmod(0o600)
                  with self.assertRaises(launcher.SandboxError):
                      launcher.read_gateway_bearer(host)
          token.write_text("secret-without-newline")
          metadata = token.stat()
          with mock.patch(
              "launcher.os.fstat",
              return_value=mock.Mock(
                  st_mode=metadata.st_mode, st_uid=host.uid + 1,
              ),
          ):
              with self.assertRaisesRegex(launcher.SandboxError, "unsafe"):
                  launcher.read_gateway_bearer(host)
          token.chmod(0o644)
          with self.assertRaisesRegex(launcher.SandboxError, "unsafe"):
              launcher.read_gateway_bearer(host)
          token.unlink()
          token.symlink_to(self.root / "elsewhere")
          with self.assertRaisesRegex(launcher.SandboxError, "unsafe"):
              launcher.read_gateway_bearer(host)

      def http_factory(self, status, body):
          requests = []
          class Response:
              def __init__(self):
                  self.status = status
              def read(self, _limit):
                  return body
          class Connection:
              def request(self, method, path, headers):
                  requests.append((method, path, headers))
              def getresponse(self):
                  return Response()
              def close(self):
                  pass
          factory = lambda *_args, **_kwargs: Connection()
          factory.requests = requests
          return factory

      def test_gateway_catalog_success_and_failure_classes(self):
          success = json.dumps({
              "data": [{"id": "gpt-5.6-sol", "owned_by": "openai-codex"}],
          }).encode()
          factory = self.http_factory(200, success)
          with mock.patch(
              "launcher.http.client.HTTPConnection", factory,
          ):
              launcher.gateway_ready("actual-secret", "openai-codex/gpt-5.6-sol")
          self.assertEqual(factory.requests, [(
              "GET", "/v1/models",
              {"Authorization": "Bearer actual-secret"},
          )])
          failures = (
              (302, success),
              (401, b"unauthorized actual-secret"),
              (200, b"{"),
              (200, b"[]"),
              (200, json.dumps({"data": []}).encode()),
              (200, json.dumps({
                  "data": [{"id": "x", "owned_by": "anthropic"}],
              }).encode()),
              (200, success),
              (200, b"x" * (1024 * 1024 + 1)),
          )
          for index, (status, body) in enumerate(failures):
              requested = (
                  "openai-codex/missing" if index == len(failures) - 2 else None
              )
              with (
                  self.subTest(status=status, index=index),
                  mock.patch(
                      "launcher.http.client.HTTPConnection",
                      self.http_factory(status, body),
                  ),
              ):
                  with self.assertRaises(launcher.SandboxError) as raised:
                      launcher.gateway_ready("actual-secret", requested)
                  self.assertNotIn("actual-secret", str(raised.exception))
                  self.assertNotIn(body.decode(errors="ignore"), str(raised.exception))

      def test_gateway_timeout_fails_without_fallback(self):
          with mock.patch(
              "launcher.http.client.HTTPConnection", side_effect=TimeoutError,
          ):
              with self.assertRaisesRegex(launcher.SandboxError, "not ready"):
                  launcher.gateway_ready("secret", None)

      def test_gateway_http_protocol_failures_are_normalized(self):
          for error in (
              http.client.BadStatusLine("malformed actual-secret"),
              http.client.IncompleteRead(b"partial actual-secret"),
          ):
              with (
                  self.subTest(error=type(error).__name__),
                  mock.patch(
                      "launcher.http.client.HTTPConnection", side_effect=error,
                  ),
              ):
                  with self.assertRaisesRegex(
                      launcher.SandboxError, "not ready",
                  ) as raised:
                      launcher.gateway_ready("actual-secret", None)
                  self.assertNotIn("actual-secret", str(raised.exception))

      def test_gateway_failure_aborts_entrypoint_before_runtime_or_upstream(self):
          host = self.make_host()
          repo = self.make_repo("gateway-entrypoint")
          context = launcher.resolve_git_context(repo, launcher.run_capture)
          state = launcher.project_state(host, repo)
          probe_sentinel = self.root / "gateway-probed"
          upstream_sentinel = self.root / "upstream-ran"

          def reject_gateway(_bearer, _model):
              probe_sentinel.write_text("probed\n")
              raise launcher.SandboxError("gateway not ready")

          def forbidden_upstream(*_args, **_kwargs):
              upstream_sentinel.write_text("ran\n")
              return 0

          with (
              mock.patch("launcher.resolve_host_context", return_value=host),
              mock.patch("launcher.verify_scope"),
              mock.patch("launcher.resolve_git_context", return_value=context),
              mock.patch("launcher.confirm_external_git"),
              mock.patch("launcher.project_state", return_value=state),
              mock.patch("launcher.resolve_profile_targets", return_value=()),
              mock.patch("launcher.nix_socket_policy", return_value=(None, None)),
              mock.patch("launcher.read_gateway_bearer", return_value="secret"),
              mock.patch("launcher.gateway_ready", side_effect=reject_gateway),
              mock.patch("launcher.runtime_files") as runtime,
              mock.patch("launcher.run_bwrap", side_effect=forbidden_upstream) as run_bwrap,
          ):
              with self.assertRaisesRegex(launcher.SandboxError, "not ready"):
                  launcher.main([
                      "inner-scoped", "--model",
                      "openai-codex/gpt-5.6-sol", "--help",
                  ])

          self.assertTrue(probe_sentinel.exists())
          self.assertFalse(upstream_sentinel.exists())
          runtime.assert_not_called()
          run_bwrap.assert_not_called()

      def test_unsafe_state_aborts_entrypoint_before_spawn(self):
          host = self.make_host()
          for kind in ("symlink", "wrong-owner"):
              with self.subTest(kind=kind):
                  repo = self.make_repo(f"state-entrypoint-{kind}")
                  context = launcher.resolve_git_context(
                      repo, launcher.run_capture,
                  )
                  ownership = contextlib.nullcontext()
                  if kind == "symlink":
                      outside = self.root / "state-entrypoint-outside"
                      outside.mkdir(exist_ok=True)
                      (host.home / ".local").symlink_to(
                          outside, target_is_directory=True,
                      )
                  else:
                      real_lstat = os.lstat
                      def wrong_owner(path):
                          result = real_lstat(path)
                          if pathlib.Path(path).name == "omp-sandbox":
                              return types.SimpleNamespace(
                                  st_mode=result.st_mode,
                                  st_uid=os.getuid() + 1,
                              )
                          return result
                      ownership = mock.patch(
                          "launcher.os.lstat", side_effect=wrong_owner,
                      )
                  with (
                      ownership,
                      mock.patch("launcher.resolve_host_context",
                                 return_value=host),
                      mock.patch("launcher.verify_scope"),
                      mock.patch("launcher.resolve_git_context",
                                 return_value=context),
                      mock.patch("launcher.confirm_external_git"),
                      mock.patch("launcher.resolve_profile_targets") as profiles,
                      mock.patch("launcher.runtime_files") as runtime,
                      mock.patch("launcher.run_bwrap") as run_bwrap,
                  ):
                      with self.assertRaisesRegex(
                          launcher.SandboxError, "unsafe",
                      ):
                          launcher.main([
                              "inner-exec", launcher.UPSTREAM_OMP, "--help",
                          ])
                  profiles.assert_not_called()
                  runtime.assert_not_called()
                  run_bwrap.assert_not_called()
                  if kind == "symlink":
                      (host.home / ".local").unlink()

      def test_final_git_revalidation_aborts_before_bubblewrap_spawn(self):
          host = self.make_host()
          repo = self.make_repo("git-race-entrypoint")
          context = launcher.resolve_git_context(repo, launcher.run_capture)
          state = launcher.project_state(host, repo)
          runtime = mock.Mock(
              passwd=None, group=None, hosts=None, resolv=None,
              gitconfig=None, nixconfig=None, gateway=None,
          )
          with (
              mock.patch("launcher.resolve_host_context", return_value=host),
              mock.patch("launcher.verify_scope"),
              mock.patch("launcher.resolve_git_context", return_value=context),
              mock.patch("launcher.confirm_external_git"),
              mock.patch("launcher.project_state", return_value=state),
              mock.patch("launcher.resolve_profile_targets", return_value=()),
              mock.patch("launcher.nix_socket_policy", return_value=(None, None)),
              mock.patch(
                  "launcher.runtime_files",
                  return_value=contextlib.nullcontext(runtime),
              ),
              mock.patch("launcher.build_bwrap_argv",
                         return_value=[launcher.BWRAP, "--version"]),
              mock.patch(
                  "launcher.validate_external_git_pins",
                  side_effect=launcher.SandboxError("Git metadata pin changed"),
              ),
              mock.patch("launcher.run_bwrap") as run_bwrap,
          ):
              with self.assertRaisesRegex(
                  launcher.SandboxError, "Git metadata pin changed",
              ):
                  launcher.execute_scoped_command(
                      [launcher.UPSTREAM_OMP, "--help"], False,
                  )
          run_bwrap.assert_not_called()

      def test_run_bwrap_passes_and_closes_only_bind_duplicates(self):
          first = self.root / "first"
          second = self.root / "second"
          first.write_text("1")
          second.write_text("2")
          pins = (
              self.keep_pin(first, stat.S_IFREG),
              self.keep_pin(second, stat.S_IFREG),
          )
          calls = []
          def factory(argv, **kwargs):
              calls.append((argv, kwargs))
              for descriptor in kwargs["pass_fds"]:
                  os.fstat(descriptor)
              return FinishedProcess()
          self.assertEqual(
              launcher.run_bwrap([launcher.BWRAP, "--version"], pins, factory), 0,
          )
          self.assertEqual(set(calls[0][1]["pass_fds"]),
                           {pins[0].fd, pins[1].fd})
          self.assertTrue(calls[0][1]["start_new_session"])
          for pin in pins:
              with self.assertRaises(OSError):
                  os.fstat(pin.fd)

      def test_scope_reentry_argv_and_cleanup_are_exact(self):
          host = self.make_host()
          calls = []
          def factory(argv, **kwargs):
              calls.append((argv, kwargs))
              return FinishedProcess()
          with (
              mock.patch("launcher.canonical", return_value=pathlib.Path("/store/launcher.py")),
              mock.patch("launcher.signal.signal", return_value=signal.SIG_DFL),
              mock.patch(
                  "launcher.run_capture",
                  side_effect=(
                      subprocess.CompletedProcess([], 0, "", ""),
                      subprocess.CompletedProcess([], 3, "", ""),
                  ),
              ) as cleanup,
          ):
              self.assertEqual(
                  launcher.run_scope(host, ["inner-exec", "true"], factory), 0,
              )
          argv, kwargs = calls[0]
          properties = [value for value in argv if value.startswith("--property=")]
          self.assertEqual(properties, [
              "--property=TasksMax=2048",
              "--property=MemoryHigh=75%",
              "--property=MemoryMax=90%",
          ])
          self.assertIn("--same-dir", argv)
          self.assertIn("--expand-environment=no", argv)
          separator = argv.index("--")
          self.assertEqual(
              argv[separator:],
              [
                  "--", sys.executable, "-I", "/store/launcher.py",
                  "inner-exec", "true",
              ],
          )
          self.assertTrue(any(
              value.startswith("--setenv=OMP_SANDBOX_SCOPE_UNIT=")
              for value in argv
          ))
          self.assertTrue(kwargs["start_new_session"])
          self.assertEqual(cleanup.call_count, 2)

      def test_scope_revalidates_user_bus_before_cleanup(self):
          host = self.make_host()
          original_path = host.bus_socket.host_path
          def replace_bus():
              original_path.rename(host.runtime_dir / "original-bus")
              replacement = socket.socket(socket.AF_UNIX)
              replacement.bind(os.fspath(original_path))
              self.sockets.append(replacement)
              return 0
          process = mock.Mock()
          process.wait.side_effect = replace_bus
          with (
              mock.patch("launcher.canonical",
                         return_value=pathlib.Path("/store/launcher.py")),
              mock.patch("launcher.signal.signal", return_value=signal.SIG_DFL),
              mock.patch("launcher.run_capture") as cleanup,
          ):
              with self.assertRaisesRegex(launcher.SandboxError, "replaced"):
                  launcher.run_scope(
                      host, ["inner-exec", "true"],
                      lambda *_args, **_kwargs: process,
                  )
          cleanup.assert_not_called()

      def test_scope_cleanup_rejects_a_still_active_unit(self):
          host = self.make_host()
          cleanup = (
              subprocess.CompletedProcess([], 1, "", "stop failed"),
              subprocess.CompletedProcess([], 0, "active\n", ""),
          )
          with (
              mock.patch("launcher.canonical",
                         return_value=pathlib.Path("/store/launcher.py")),
              mock.patch("launcher.signal.signal", return_value=signal.SIG_DFL),
              mock.patch("launcher.run_capture", side_effect=cleanup),
          ):
              with self.assertRaisesRegex(
                  launcher.SandboxError, "survived cleanup",
              ):
                  launcher.run_scope(
                      host, ["inner-exec", "true"],
                      lambda *_args, **_kwargs: FinishedProcess(),
                  )

      def test_scope_rejects_replaced_user_bus_before_spawn(self):
          host = self.make_host()
          original_path = host.bus_socket.host_path
          original_path.rename(host.runtime_dir / "original-bus")
          replacement = socket.socket(socket.AF_UNIX)
          replacement.bind(os.fspath(original_path))
          self.sockets.append(replacement)
          with mock.patch(
              "launcher.canonical",
              return_value=pathlib.Path("/store/launcher.py"),
          ):
              with self.assertRaisesRegex(launcher.SandboxError, "replaced"):
                  launcher.run_scope(
                      host, ["inner-exec", "true"],
                      lambda *_args, **_kwargs: self.fail("systemd-run spawned"),
                  )
          self.assertTrue(stat.S_ISSOCK(os.fstat(host.bus_socket.fd).st_mode))

      def test_run_capture_bounds_output_and_kills_timed_out_descendants(self):
          child_pid = self.root / "child.pid"
          child_code = (
              "import signal,time; "
              "signal.signal(signal.SIGTERM, signal.SIG_IGN); "
              "time.sleep(60)"
          )
          leader_code = (
              "import pathlib,signal,subprocess,sys,time; "
              "signal.signal(signal.SIGTERM, signal.SIG_IGN); "
              f"child=subprocess.Popen([sys.executable,'-c',{child_code!r}]); "
              f"pathlib.Path({str(child_pid)!r}).write_text(str(child.pid)); "
              "time.sleep(60)"
          )
          with self.assertRaisesRegex(launcher.SandboxError, "timed out"):
              launcher.run_capture(
                  [sys.executable, "-c", leader_code],
                  dict(os.environ),
                  timeout=0.2,
              )
          child = int(child_pid.read_text())
          self.assertIsNotNone(child)
          self.assertFalse(pathlib.Path(f"/proc/{child}").exists())
          with self.assertRaisesRegex(launcher.SandboxError, "output exceeded"):
              launcher.run_capture(
                  [
                      sys.executable, "-c",
                      f"print('x' * {1024 * 1024 + 1})",
                  ],
                  dict(os.environ),
              )

      def test_run_capture_kills_children_after_normal_leader_exit(self):
          for retains_pipe in (False, True):
              with self.subTest(retains_pipe=retains_pipe):
                  child_pid = self.root / f"normal-{retains_pipe}.pid"
                  ready = self.root / f"normal-{retains_pipe}.ready"
                  child_code = (
                      "import pathlib,signal,time; "
                      "signal.signal(signal.SIGTERM, signal.SIG_IGN); "
                      f"pathlib.Path({str(ready)!r}).write_text('ready'); "
                      "time.sleep(60)"
                  )
                  stdio = "" if retains_pipe else (
                      ",stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,"
                      "stderr=subprocess.DEVNULL"
                  )
                  leader_code = (
                      "import pathlib,subprocess,sys,time; "
                      f"child=subprocess.Popen([sys.executable,'-c',{child_code!r}]"
                      f"{stdio}); "
                      f"pathlib.Path({str(child_pid)!r}).write_text(str(child.pid)); "
                      f"ready=pathlib.Path({str(ready)!r}); "
                      "deadline=time.monotonic()+5; "
                      "exec(\"while not ready.exists():\\n"
                      " if time.monotonic() >= deadline: raise RuntimeError('not ready')\\n"
                      " time.sleep(0.01)\")"
                  )
                  launcher.run_capture(
                      [sys.executable, "-c", leader_code], dict(os.environ),
                  )
                  child = int(child_pid.read_text())
                  self.assertFalse(pathlib.Path(f"/proc/{child}").exists())

      def test_private_mode_rejects_missing_scope(self):
          with self.assertRaisesRegex(launcher.SandboxError, "scope identity"):
              launcher.verify_scope(self.make_host(), "")

      def test_private_scope_rejects_nonfinite_resource_properties(self):
          unit = "omp-sandbox-1-deadbeef.scope"
          invalid = (
              "TasksMax=2048\nMemoryHigh=\nMemoryMax=1\n"
              "CPUQuotaPerSecUSec=infinity\n"
          )
          with (
              mock.patch(
                  "launcher.pathlib.Path.read_text",
                  return_value=f"0::/user.slice/{unit}\n",
              ),
              mock.patch(
                  "launcher.run_capture",
                  return_value=subprocess.CompletedProcess(
                      [], 0, invalid, "",
                  ),
              ),
          ):
              with self.assertRaisesRegex(
                  launcher.SandboxError, "unsafe resource properties",
              ):
                  launcher.verify_scope(self.make_host(), unit)

      def test_private_scope_requires_exact_unified_cgroup_component(self):
          host = self.make_host()
          unit = "omp-sandbox-1-deadbeef.scope"
          properties = (
              "TasksMax=2048\nMemoryHigh=1\nMemoryMax=1\n"
              "CPUQuotaPerSecUSec=infinity\n"
          )
          accepted = (
              f"0::/user.slice/{unit}\n",
              f"0::/user.slice/{unit}/child\n",
          )
          rejected = (
              f"0::/user.slice/{unit}-decoy.scope\n",
              "malformed\n",
              f"0::/user.slice/{unit}\n0::/user.slice/{unit}\n",
          )
          for cgroup in accepted:
              with (
                  self.subTest(cgroup=cgroup),
                  mock.patch("launcher.pathlib.Path.read_text",
                             return_value=cgroup),
                  mock.patch(
                      "launcher.run_capture",
                      return_value=subprocess.CompletedProcess(
                          [], 0, properties, "",
                      ),
                  ),
              ):
                  launcher.verify_scope(host, unit)
          for cgroup in rejected:
              with (
                  self.subTest(cgroup=cgroup),
                  mock.patch("launcher.pathlib.Path.read_text",
                             return_value=cgroup),
                  mock.patch("launcher.run_capture") as query,
              ):
                  with self.assertRaises(launcher.SandboxError):
                      launcher.verify_scope(host, unit)
                  query.assert_not_called()

      def test_unconfined_confirmation_is_literal(self):
          for answer in ("yes \n", ""):
              with self.subTest(answer=answer):
                  rejected = FakeTTY(answer)
                  with mock.patch("builtins.open", return_value=rejected):
                      with self.assertRaisesRegex(launcher.SandboxError, "not confirmed"):
                          launcher.confirm_unconfined()
          accepted = FakeTTY("yes\n")
          with mock.patch("builtins.open", return_value=accepted):
              launcher.confirm_unconfined()
          self.assertIn("full host account", accepted.output)
  ```

  The Nix check also compiles the complete checked-in acceptance harness. Actual gateway response bodies, process trees, mount denial, linked-worktree masks, CodeCompanion JSON serialization, network/browser/LSP startup, state precedence, and no-newline upstream token handling remain real-boundary checks rather than mocked unit claims.

  The test uses only the Python standard library; do not add PyYAML or another test dependency.

  Before creating `_sandbox-package.nix`, `launcher.py`, or any asset, observe the asset contract fail for its intended reason with an importable empty test fixture:

  ```sh
  (
    cd modules/programs/oh-my-pi/sandbox
    fixture="$(mktemp -d)"
    trap 'rm -rf "$fixture"' EXIT
    : > "$fixture/launcher.py"
    mkdir "$fixture/assets"
    PYTHONPATH="$fixture" OMP_SANDBOX_ASSETS="$fixture/assets" \
      python3 -m unittest -v \
      test_launcher.PackageContractTests.test_assets_are_complete_and_immutable
  )
  ```

  Expected RED: `FileNotFoundError` for `agent/models.yml`. Any import error is the wrong failure and must be corrected before implementation.

- [ ] **Step 2: Expose the focused check and prove its wiring**

  First change the module's outer expression to define the package functions once:

  ```nix
  {inputs, ...}: let
    upstreamOmpFor = pkgs:
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.omp;
    sandboxFor = pkgs:
      import ./_sandbox-package.nix {
        inherit pkgs;
        inherit (pkgs) lib;
        upstreamOmp = upstreamOmpFor pkgs;
        mcpNixos = pkgs.mcp-nixos;
        configSrc = ./config;
        sharedSkillsSrc = ../agents-shared/skills;
      };
  in {
  ```

  Add only the Linux focused check without changing declaration delivery:

  ```nix
  perSystem = {
    lib,
    pkgs,
    ...
  }:
    lib.mkIf pkgs.stdenv.isLinux {
      checks.omp-sandbox = (sandboxFor pkgs).check;
    };
  ```

  Run:

  ```sh
  nix build .#checks.x86_64-linux.omp-sandbox --no-link
  ```

  Expected: fail during evaluation because `_sandbox-package.nix` does not exist, independently proving the new flake check is wired. The behavior-specific RED was already observed in Step 1.

- [ ] **Step 3: Implement the package factory and immutable asset tree**

  `_sandbox-package.nix` must use this complete construction:

  ```nix
  {
    pkgs,
    lib,
    upstreamOmp,
    mcpNixos,
    configSrc,
    sharedSkillsSrc,
  }: let
    readMarkdown = dir:
      lib.mapAttrs' (
        name: _:
          lib.nameValuePair (lib.removeSuffix ".md" name)
          (builtins.readFile (dir + "/${name}"))
      ) (lib.filterAttrs
        (name: type: type == "regular" && lib.hasSuffix ".md" name)
        (builtins.readDir dir));
    readSkills = dir:
      lib.mapAttrs
      (name: _: builtins.readFile (dir + "/${name}/SKILL.md"))
      (lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir));
    agentFiles =
      {
        "AGENTS.md" = builtins.readFile (configSrc + "/AGENTS.md");
        "RULES.md" = builtins.readFile (configSrc + "/RULES.md");
        "extensions/flow-map.ts" =
          builtins.readFile (configSrc + "/extensions/flow-map.ts");
        "mcp.json" = builtins.toJSON {
          "$schema" = "https://raw.githubusercontent.com/can1357/oh-my-pi/d5cd24f39a951bfbd50dc8f50bcf095d59694d6c/packages/coding-agent/src/config/mcp-schema.json";
          mcpServers.nixos.command = lib.getExe mcpNixos;
        };
        "policy.yml" = ''
          tools:
            approvalMode: yolo
          disabledProviders:
            - ollama
            - llama.cpp
            - lm-studio
          modelProviderOrder:
            - openai-codex
          symbolPreset: nerd
        '';
        "models.yml" = ''
          providers:
            openai-codex:
              baseUrl: http://127.0.0.1:4000
              apiKey: "!${lib.getExe' pkgs.coreutils "cat"} /run/omp-gateway-bearer"
              transport: pi-native
        '';
      }
      // lib.mapAttrs'
      (name: text: lib.nameValuePair "agents/${name}.md" text)
      (readMarkdown (configSrc + "/agents"))
      // lib.mapAttrs'
      (name: text: lib.nameValuePair "skills/${name}/SKILL.md" text)
      (readSkills sharedSkillsSrc);
    assetCommands = lib.concatStringsSep "\n" (lib.mapAttrsToList (
      name: text: let
        source = pkgs.writeText
          "omp-sandbox-${builtins.baseNameOf name}" text;
      in ''
        mkdir -p "$out/agent/${builtins.dirOf name}"
        ln -s ${source} "$out/agent/${name}"
      ''
    ) agentFiles);
    assets = pkgs.runCommand "omp-sandbox-assets" {} assetCommands;
    curatedPath = lib.makeBinPath (with pkgs; [
      bash
      chromium
      coreutils
      curl
      diffutils
      file
      findutils
      git
      gnugrep
      gnused
      gnutar
      gzip
      nix
      openssh
      nil
      systemd
      upstreamOmp
      xz
    ]);
    gatewayService = pkgs.writeShellApplication {
      name = "omp-auth-gateway-service";
      runtimeInputs = [pkgs.coreutils pkgs.gnugrep];
      text = ''
        token_file="$HOME/.omp/auth-broker.token"
        if [[ -L "$token_file" || ! -f "$token_file" ]]; then
          echo "OMP broker token is missing or not a regular file" >&2
          exit 1
        fi
        if [[ "$(${lib.getExe' pkgs.coreutils "stat"} -c %u "$token_file")" != "$UID" ]]; then
          echo "OMP broker token has the wrong owner" >&2
          exit 1
        fi
        permissions="$(${lib.getExe' pkgs.coreutils "stat"} -c %a "$token_file")"
        if (( (8#$permissions & 077) != 0 )); then
          echo "OMP broker token permissions are too broad" >&2
          exit 1
        fi
        if [[ ! -s "$token_file" ]] \
          || [[ "$(${lib.getExe' pkgs.coreutils "wc"} -l < "$token_file")" != 0 ]] \
          || ! ${lib.getExe' pkgs.gnugrep "grep"} -Eq '^[A-Za-z0-9_-]+$' "$token_file"; then
          echo "OMP broker token must be one nonempty ASCII token with no newline" >&2
          exit 1
        fi
        # Validation above rejects every newline before command substitution strips it.
        export OMP_AUTH_BROKER_TOKEN="$(<"$token_file")"
        exec ${lib.getExe upstreamOmp} auth-gateway serve \
          --bind=127.0.0.1:4000
      '';
    };
    acceptance = pkgs.replaceVars ./sandbox/acceptance.py {
      upstreamOmp = lib.getExe upstreamOmp;
    };
    launcher = pkgs.replaceVars ./sandbox/launcher.py {
      inherit assets curatedPath;
      localeArchive = "${pkgs.glibcLocales}/lib/locale/locale-archive";
      tzdir = "${pkgs.tzdata}/share/zoneinfo";
      bwrap = lib.getExe pkgs.bubblewrap;
      bash = lib.getExe pkgs.bash;
      env = lib.getExe' pkgs.coreutils "env";
      git = lib.getExe pkgs.git;
      nix = lib.getExe pkgs.nix;
      systemctl = lib.getExe' pkgs.systemd "systemctl";
      systemdRun = lib.getExe' pkgs.systemd "systemd-run";
      upstreamOmp = lib.getExe upstreamOmp;
    };
    package = pkgs.runCommand "omp-sandbox-launcher" {
      pname = "omp-sandbox-launcher";
      version = upstreamOmp.version;
      meta = {
        mainProgram = "omp";
        platforms = lib.platforms.linux;
      };
      nativeBuildInputs = [pkgs.makeWrapper];
      passthru = {
        inherit upstreamOmp;
        tests.executor = check;
      };
    } ''
      mkdir -p "$out/bin"
      makeWrapper ${lib.getExe pkgs.python3} "$out/bin/omp" \
        --add-flags "-I ${launcher} scoped"
      makeWrapper ${lib.getExe pkgs.python3} "$out/bin/omp-unconfined" \
        --add-flags "-I ${launcher} unconfined"
      makeWrapper ${lib.getExe pkgs.python3} "$out/bin/omp-sandbox-exec" \
        --add-flags "-I ${launcher} exec"
      ln -s ${lib.getExe gatewayService} "$out/bin/omp-auth-gateway-service"
      makeWrapper ${lib.getExe pkgs.python3} "$out/bin/omp-sandbox-acceptance" \
        --add-flags "-I ${acceptance}" \
        --set PATH "$out/bin:${curatedPath}"
    '';
    check = pkgs.runCommand "omp-sandbox-check" {
      nativeBuildInputs = [pkgs.git pkgs.python3];
      OMP_SANDBOX_ASSETS = assets;
    } ''
      cp ${./sandbox/launcher.py} launcher.py
      cp ${./sandbox/test_launcher.py} test_launcher.py
      cp ${./sandbox/acceptance.py} acceptance.py
      substituteInPlace launcher.py \
        --replace-fail '@assets@' '${assets}' \
        --replace-fail '@curatedPath@' '${curatedPath}' \
        --replace-fail '@localeArchive@' '${pkgs.glibcLocales}/lib/locale/locale-archive' \
        --replace-fail '@tzdir@' '${pkgs.tzdata}/share/zoneinfo' \
        --replace-fail '@bwrap@' '${lib.getExe pkgs.bubblewrap}' \
        --replace-fail '@bash@' '${lib.getExe pkgs.bash}' \
        --replace-fail '@env@' '${lib.getExe' pkgs.coreutils "env"}' \
        --replace-fail '@git@' '${lib.getExe pkgs.git}' \
        --replace-fail '@nix@' '${lib.getExe pkgs.nix}' \
        --replace-fail '@systemctl@' '${lib.getExe' pkgs.systemd "systemctl"}' \
        --replace-fail '@systemdRun@' '${lib.getExe' pkgs.systemd "systemd-run"}' \
        --replace-fail '@upstreamOmp@' '${lib.getExe upstreamOmp}'
      ${lib.getExe pkgs.python3} -m unittest -v test_launcher.py
      ${lib.getExe pkgs.python3} -m py_compile acceptance.py
      touch "$out"
    '';
  in {
    inherit assets check package;
  }
  ```

  Keep the schema URL pinned to the verified commit in sandbox assets; the existing unconfined Home Manager file may retain its current upstream URL.

- [ ] **Step 4: Implement the importable launcher shell**

  Create `launcher.py` with the normative imports, Nix-substituted constants, `SandboxError`, dataclasses, protocols, and `PUBLIC_MODES = ("scoped", "unconfined", "exec")` from the complete Task 2 listing. Do not copy behavioral functions or add `__main__` dispatch yet. All behavior classes remain skipped in this task, so the only executable contract is importability plus the fixed public-mode tuple; Task 2 enables each class before adding its transitive production slice.

  No production function reads `OMP_SANDBOX_ASSETS`; that variable is consumed by the package-contract test only.

- [ ] **Step 5: Implement the checked-in behavioral harness**

  Create `sandbox/acceptance.py` with this complete standard-library structure. The literal upstream path is replaced by Nix; the other executables are resolved only from the wrapper's fixed package PATH.

  ```python
  import contextlib
  import http.client
  import hashlib
  import json
  import os
  import pathlib
  import pty
  import pwd
  import queue
  import select
  import shutil
  import secrets
  import signal
  import socket
  import subprocess
  import threading
  import sys
  import tempfile
  import time

  UPSTREAM_OMP = "@upstreamOmp@"
  EXECUTOR = shutil.which("omp-sandbox-exec")
  OMP = shutil.which("omp")
  UNCONFINED = shutil.which("omp-unconfined")
  ACCEPTANCE = shutil.which("omp-sandbox-acceptance")
  GATEWAY_SERVICE = shutil.which("omp-auth-gateway-service")
  SYSTEMCTL = shutil.which("systemctl")
  JOURNALCTL = shutil.which("journalctl")
  GIT = shutil.which("git")
  MODES = (
      "filesystem", "linked-worktree", "gateway", "scope", "cleanup",
      "state", "model", "acp", "unconfined", "all",
  )

  def require(value, message):
      if not value:
          raise RuntimeError(message)
      return value

  def require_secret_absent_from_process_metadata(secret):
      encoded = secret.encode()
      for entry in pathlib.Path("/proc").glob("[0-9]*"):
          try:
              if entry.stat().st_uid != os.getuid():
                  continue
              metadata = (
                  (entry / "cmdline").read_bytes()
                  + (entry / "environ").read_bytes()
              )
          except (FileNotFoundError, PermissionError, ProcessLookupError):
              continue
          require(encoded not in metadata,
                  f"gateway bearer appears in process metadata: {entry.name}")

  OUTPUT_LIMIT = 1024 * 1024
  class CapturedOutput:
      def __init__(self):
          self.data = bytearray()
          self.overflow = False

      def add(self, payload):
          remaining = OUTPUT_LIMIT - len(self.data)
          if remaining > 0:
              self.data.extend(payload[:remaining])
          self.overflow = self.overflow or len(payload) > remaining

      def decode(self):
          return self.data.decode(errors="replace")


  def drain_stream(stream, buffer):
      while True:
          chunk = stream.read(4096)
          if not chunk:
              return
          payload = chunk.encode() if isinstance(chunk, str) else chunk
          buffer.add(payload)

  def drain_descriptor(descriptor, buffer):
      while True:
          try:
              chunk = os.read(descriptor, 4096)
          except OSError:
              return
          if not chunk:
              return
          buffer.add(chunk)

  class ForkedProcess:
      def __init__(self, pid):
          self.pid = pid
          self.returncode = None

      def poll(self):
          if self.returncode is not None:
              return self.returncode
          try:
              done, status = os.waitpid(self.pid, os.WNOHANG)
          except ChildProcessError:
              return self.returncode
          if done:
              self.returncode = os.waitstatus_to_exitcode(status)
          return self.returncode

      def wait(self, timeout=None):
          deadline = None if timeout is None else time.monotonic() + timeout
          while self.poll() is None:
              if deadline is not None and time.monotonic() >= deadline:
                  raise subprocess.TimeoutExpired(self.pid, timeout)
              time.sleep(0.05)
          return self.returncode

  class LineReader:
      def __init__(self, stream):
          self.stream = stream
          self.lines = queue.Queue()
          self.captured = 0
          self.overflow = False
          self.thread = threading.Thread(target=self._read, daemon=True)
          self.thread.start()

      def _read(self):
          try:
              for line in self.stream:
                  self.captured += len(line.encode())
                  self.overflow = self.overflow or self.captured > OUTPUT_LIMIT
                  if not self.overflow:
                      self.lines.put(line)
          finally:
              self.lines.put(None)

      def get(self, timeout):
          return self.lines.get(timeout=timeout)

      def join(self, timeout=5):
          self.thread.join(timeout=timeout)
          require(not self.thread.is_alive(), "line reader did not stop")

      def drain(self):
          require(not self.overflow, "ACP stdout exceeded output limit")
          remaining = []
          while True:
              try:
                  line = self.lines.get_nowait()
              except queue.Empty:
                  return remaining
              if line is None:
                  return remaining
              remaining.append(line)

  def run(argv, cwd=None, check=True, timeout=60, environment=None, pass_fds=()):
      process = subprocess.Popen(
          argv, cwd=cwd, env=environment, stdin=subprocess.DEVNULL,
          stdout=subprocess.PIPE, stderr=subprocess.PIPE, pass_fds=pass_fds,
          start_new_session=True,
      )
      stdout = CapturedOutput()
      stderr = CapturedOutput()
      readers = [
          threading.Thread(target=drain_stream, args=(process.stdout, stdout), daemon=True),
          threading.Thread(target=drain_stream, args=(process.stderr, stderr), daemon=True),
      ]
      for reader in readers:
          reader.start()
      timed_out = False
      try:
          process.wait(timeout=timeout)
      except subprocess.TimeoutExpired:
          timed_out = True
      returncode = terminate_process_group(process)
      for reader in readers:
          reader.join(timeout=5)
          require(not reader.is_alive(), "command output reader did not stop")
      require(not stdout.overflow and not stderr.overflow,
              "command output exceeded limit")
      result = subprocess.CompletedProcess(
          argv, returncode, stdout.decode(), stderr.decode(),
      )
      if timed_out:
          raise subprocess.TimeoutExpired(
              argv, timeout, output=result.stdout, stderr=result.stderr,
          )
      if check and returncode:
          raise subprocess.CalledProcessError(
              returncode, argv, output=result.stdout, stderr=result.stderr,
          )
      return result

  CREATED_REPOSITORIES = []

  def make_repo(root, name):
      repo = pathlib.Path(root, name)
      repo.mkdir()
      run([GIT, "init", "-q", str(repo)])
      run([GIT, "-C", str(repo), "config", "user.name", "OMP Sandbox Probe"])
      run([GIT, "-C", str(repo), "config", "user.email", "probe@example.invalid"])
      (repo / "tracked").write_text("tracked\n")
      run([GIT, "-C", str(repo), "add", "tracked"])
      run([GIT, "-C", str(repo), "commit", "-qm", "probe"])
      return track_state(repo)

  def executor(script, cwd, check=True, timeout=60, environment=None, pass_fds=()):
      return run(
          [EXECUTOR, "--", "sh", "-ceu", script],
          cwd=cwd, check=check, timeout=timeout, environment=environment,
          pass_fds=pass_fds,
      )

  def filesystem():
      require(
          pathlib.Path("/proc/sys/kernel/yama/ptrace_scope").read_text().strip() == "1",
          "target host must enforce kernel.yama.ptrace_scope=1",
      )
      with tempfile.TemporaryDirectory(prefix="omp-accept-") as tmp:
          selected = make_repo(tmp, "selected")
          unrelated = make_repo(tmp, "unrelated")
          secret = unrelated / "secret"
          secret.write_text("outside\n")
          escape = selected / "escape"
          escape.symlink_to(secret)
          subdir = selected / "a" / "b"
          subdir.mkdir(parents=True)
          sentinel = pathlib.Path(tmp, "outside-git-ran")
          for command in (
              [EXECUTOR, "--", "sh", "-c", f"touch {sentinel}"],
              [OMP, "--print", f"Use Bash to touch {sentinel}"],
          ):
              denied = run(command, cwd=tmp, check=False)
              require(denied.returncode == 2,
                      f"outside-Git public command did not fail closed: {command[0]}")
              require(not sentinel.exists(), "outside-Git command executed")
          literal_arguments = ("$", "$HOME", "${HOME}", "${name-default}")
          literal_result = run(
              [
                  EXECUTOR, "--", sys.executable, "-c",
                  "import json,sys; print(json.dumps(sys.argv[1:]))",
                  *literal_arguments,
              ],
              cwd=selected,
          )
          require(
              json.loads(literal_result.stdout.splitlines()[-1])
              == list(literal_arguments),
              "systemd scope changed literal executor arguments",
          )
          inherited = os.open(secret, os.O_RDONLY)
          hostile = dict(os.environ)
          hostile_names = (
              "SSH_AUTH_SOCK", "DBUS_SESSION_BUS_ADDRESS", "OPENAI_API_KEY",
              "AWS_SECRET_ACCESS_KEY", "KUBECONFIG", "SOPS_AGE_KEY",
              "ANTHROPIC_API_KEY", "NIX_REMOTE", "NIX_CONFIG",
          )
          hostile.update({
              name: f"ambient-{secrets.token_hex(8)}"
              for name in hostile_names
          })
          startup_dir = pathlib.Path(tmp, "python-startup")
          startup_dir.mkdir()
          startup_sentinel = pathlib.Path(tmp, "python-startup-ran")
          (startup_dir / "sitecustomize.py").write_text(
              "import pathlib; "
              f"pathlib.Path({str(startup_sentinel)!r}).write_text('ran\\n')"
          )
          hostile["PYTHONPATH"] = str(startup_dir)
          for command in (
              [OMP, "--help"],
              [UNCONFINED, "--help"],
              [ACCEPTANCE, "invalid"],
          ):
              probe = run(
                  command, cwd=tmp, environment=hostile, check=False,
              )
              require(probe.returncode != 0,
                      f"startup isolation probe unexpectedly ran: {command[0]}")
              require(not startup_sentinel.exists(),
                      f"packaged Python startup was not isolated: {command[0]}")
          hostile_values = (
              *(hostile[name] for name in hostile_names),
              str(startup_dir),
          )
          home = pathlib.Path(pwd.getpwuid(os.getuid()).pw_dir)
          home_metadata = home.stat()
          require(
              home_metadata.st_uid == os.getuid() and home.is_dir(),
              "passwd home is not an owned directory",
          )
          fixture_fd, fixture_name = tempfile.mkstemp(
              prefix=".omp-sandbox-credential-", dir=home,
          )
          os.close(fixture_fd)
          home_fixture = pathlib.Path(fixture_name)
          home_value = secrets.token_hex(32)
          home_fixture.write_text(home_value)
          fixture_metadata = home_fixture.lstat()
          require(
              fixture_metadata.st_uid == os.getuid()
              and fixture_metadata.st_mode & 0o777 == 0o600,
              "home credential fixture has unsafe ownership or mode",
          )
          sandbox_home_fixture = pathlib.Path("/home/omp") / home_fixture.name
          denied_paths = [
              secret, home_fixture, sandbox_home_fixture,
              pathlib.Path("/etc/nixos"), home / ".ssh", home / ".gnupg",
              home / ".config/age", home / ".config/sops", home / ".aws",
              home / ".kube", home / ".omp",
          ]
          path_checks = "\n".join(
              f"test ! -r {path}; ! printf hacked > {path} 2>/dev/null"
              for path in denied_paths
          )
          script = f"""
          test "$PWD" = /workspace/a/b
          test "$(cat "{selected / "tracked"}")" = tracked
          printf created > ../../created
          printf edited >> ../../created
          cp ../../created ../../renamed
          rm ../../created
          test "$(cat ../../renamed)" = creatededited
          printf '#!/bin/sh\nprintf ran > executed\n' > ../../tool
          chmod +x ../../tool
          cd ../..
          ./tool
          test "$(cat executed)" = ran
          rm tool executed
          cat /proc/$$/cmdline > sandbox-cmdline
          cat /proc/$$/environ > sandbox-environ
          test ! -r escape
          ! printf hacked > escape 2>/dev/null
          {path_checks}
          test ! -e /run/user
          test ! -e /run/docker.sock
          test ! -e /var/run/docker.sock
          test ! -e /sys
          test ! -e /proc/{os.getpid()}
          if test -e /proc/self/fd/{inherited}; then
            ! grep -q outside /proc/self/fd/{inherited}
          fi
          for descriptor_path in /proc/self/fd/*; do
            descriptor="${{descriptor_path##*/}}"
            test "$descriptor" -le 2
          done
          test -r /nix/store
          test -z "${{SSH_AUTH_SOCK-}}${{DBUS_SESSION_BUS_ADDRESS-}}${{OPENAI_API_KEY-}}${{AWS_SECRET_ACCESS_KEY-}}${{KUBECONFIG-}}${{SOPS_AGE_KEY-}}${{ANTHROPIC_API_KEY-}}"
          test "$(date +%Z)" = UTC
          test "$(printf é | wc -m)" = 1
          command -v git >/dev/null
          command -v nix >/dev/null
          command -v chromium >/dev/null
          chromium --headless --no-sandbox --disable-gpu --dump-dom \
            'data:text/html,<p>omp-sandbox</p>' | grep -q omp-sandbox
          (command -v nixd || command -v nil) >/dev/null
          lsp="$(command -v nixd || command -v nil)"
          "$lsp" --version >/dev/null
          curl --fail --silent --show-error https://example.com/ >/dev/null
          bash_path="$(command -v bash)"
          nix_probe() {{
            nix build --no-link --expr "derivation {{
              name = \\"omp-sandbox-probe\\";
              system = builtins.currentSystem;
              builder = \\"$bash_path\\";
              args = [ \\"-c\\" \\"echo ok > \\$out\\" ];
            }}"
          }}
          if test "${{NIX_REMOTE-}}" = daemon; then
            test -S /nix/var/nix/daemon-socket/socket
            nix_probe
            printf enabled > sandbox-nix-mode
          else
            test -z "${{NIX_REMOTE-}}"
            test ! -e /nix/var/nix/daemon-socket/socket
            ! nix store info --store daemon >/dev/null 2>&1
            printf disabled > sandbox-nix-mode
          fi
          """
          try:
              result = executor(
                  script, subdir, timeout=180, environment=hostile,
                  pass_fds=(inherited,),
              )
              require(home_fixture.read_text() == home_value,
                      "sandbox changed the host-home credential fixture")
              require(
                  (selected / "sandbox-nix-mode").read_text()
                  in ("enabled", "disabled"),
                  "sandbox did not prove one complete Nix access branch",
              )
          finally:
              os.close(inherited)
              home_fixture.unlink(missing_ok=True)
          require(not startup_sentinel.exists(),
                  "executor Python startup was not isolated")
          require((selected / "renamed").read_text() == "creatededited",
                  "project writes did not persist")
          require(secret.read_text() == "outside\n", "unrelated repository changed")
          observed = (
              result.stdout.encode() + result.stderr.encode()
              + (selected / "sandbox-cmdline").read_bytes()
              + (selected / "sandbox-environ").read_bytes()
          )
          for value in (*hostile_values, secret.read_text(), home_value):
              require(value.encode() not in observed,
                      "sandbox disclosed an actual hostile value")

  def run_in_pty(argv, cwd, answer, timeout=30, argv_probe=None):
      pid, master = pty.fork()
      if pid == 0:
          os.chdir(cwd)
          os.execvp(argv[0], argv)
      process = ForkedProcess(pid)
      output = CapturedOutput()
      sent = False
      deadline = time.monotonic() + timeout
      try:
          while time.monotonic() < deadline:
              readable, _, _ = select.select([master], [], [], 0.1)
              if readable:
                  try:
                      chunk = os.read(master, 4096)
                  except OSError:
                      chunk = b""
                  output.add(chunk)
                  require(not output.overflow, "PTY output exceeded limit")
                  if not sent and b"type yes" in output.data.lower():
                      os.write(master, answer.encode() + b"\n")
                      sent = True
              if sent and argv_probe and argv_probe(process.pid):
                  return 0, output.decode()
              returncode = process.poll()
              if returncode is not None:
                  return returncode, output.decode()
          raise RuntimeError("PTY probe timed out")
      finally:
          terminate_process_group(process)
          with contextlib.suppress(OSError):
              os.close(master)

  def confirmed_acp_process(cwd, timeout=30):
      stdin_read, stdin_write = os.pipe()
      stdout_read, stdout_write = os.pipe()
      stderr_read, stderr_write = os.pipe()
      pid, master = pty.fork()
      if pid == 0:
          os.close(stdin_write)
          os.close(stdout_read)
          os.close(stderr_read)
          os.dup2(stdin_read, 0)
          os.dup2(stdout_write, 1)
          os.dup2(stderr_write, 2)
          for descriptor in (stdin_read, stdout_write, stderr_write):
              if descriptor > 2:
                  os.close(descriptor)
          os.chdir(cwd)
          os.execvp(OMP, [OMP, "acp"])
      os.close(stdin_read)
      os.close(stdout_write)
      os.close(stderr_write)
      process = ForkedProcess(pid)
      process.stdin = os.fdopen(stdin_write, "w", buffering=1)
      process.stdout = os.fdopen(stdout_read, "r", buffering=1)
      process.stderr = os.fdopen(stderr_read, "r", buffering=1)
      output = CapturedOutput()
      deadline = time.monotonic() + timeout
      try:
          while time.monotonic() < deadline:
              readable, _, _ = select.select([master], [], [], 0.1)
              if readable:
                  try:
                      chunk = os.read(master, 4096)
                  except OSError:
                      chunk = b""
                  output.add(chunk)
                  require(not output.overflow, "ACP confirmation output exceeded limit")
                  if b"type yes" in output.data.lower():
                      os.write(master, b"yes\n")
                      reader = threading.Thread(
                          target=drain_descriptor, args=(master, output),
                          daemon=True,
                      )
                      reader.start()
                      return process, master, output, reader
              require(process.poll() is None,
                      "linked-worktree ACP exited before confirmation")
          raise RuntimeError("linked-worktree ACP confirmation timed out")
      except BaseException:
          terminate_process_group(process)
          for stream in (process.stdin, process.stdout, process.stderr):
              stream.close()
          with contextlib.suppress(OSError):
              os.close(master)
          raise

  def linked_worktree():
      with tempfile.TemporaryDirectory(prefix="omp-worktree-") as tmp:
          main = make_repo(tmp, "main")
          linked = pathlib.Path(tmp, "linked")
          sibling = pathlib.Path(tmp, "sibling")
          run([GIT, "-C", str(main), "worktree", "add", "-q", str(linked)])
          run([GIT, "-C", str(main), "worktree", "add", "-q", str(sibling)])
          track_state(linked)
          common = pathlib.Path(
              run([GIT, "-C", str(linked), "rev-parse",
                   "--path-format=absolute", "--git-common-dir"]).stdout.strip()
          ).resolve()
          git_dir = pathlib.Path(
              run([GIT, "-C", str(linked), "rev-parse",
                   "--absolute-git-dir"]).stdout.strip()
          ).resolve()
          sibling_admin = common / "worktrees" / sibling.name / "omp-sibling-sentinel"
          sibling_admin.write_text("hidden\n")
          external_parent_sentinel = common.parent / "omp-parent-sentinel"
          external_parent_sentinel.write_text("parent-hidden\n")
          sibling_worktree_sentinel = sibling / "omp-sibling-worktree-sentinel"
          sibling_worktree_sentinel.write_text("sibling-hidden\n")
          hook_sentinel = pathlib.Path(tmp, "hook-ran")
          hook = common / "hooks" / "pre-commit"
          hook.write_text(f"#!/bin/sh\ntouch {hook_sentinel}\n")
          hook.chmod(0o755)
          alternate = pathlib.Path(tmp, "alternate-objects")
          alternate.mkdir()
          (common / "objects/info/alternates").write_text(str(alternate) + "\n")
          reject_sentinel = linked / "rejected-ran"
          code, output = run_in_pty(
              [EXECUTOR, "--", "sh", "-c", f"touch {reject_sentinel}"],
              str(linked), "no",
          )
          require(code == 2 and not reject_sentinel.exists(),
                  "linked-worktree rejection was not fail closed")
          normalized = output.replace("\r\n", "\n")
          prompt_header = "OMP sandbox must mount these external Git metadata paths:\n"
          prompt_start = normalized.index(prompt_header) + len(prompt_header)
          prompt_end = normalized.index("\nType yes to continue: ", prompt_start)
          listed_paths = normalized[prompt_start:prompt_end].splitlines()
          expected_paths = [
              json.dumps(os.fspath(path))
              for path in sorted((common, git_dir), key=os.fspath)
          ]
          require(listed_paths == expected_paths,
                  "prompt did not list the exact external Git path set")
          script = f"""
          test ! -e {sibling_admin}
          test ! -e {hook}
          test ! -e {alternate}
          test ! -e {external_parent_sentinel}
          test ! -e {sibling_worktree_sentinel}
          git commit --allow-empty -m sandbox-hook-check
          """
          code, _ = run_in_pty(
              [EXECUTOR, "--", "sh", "-ceu", script], str(linked), "yes",
          )
          require(code == 0, "confirmed linked worktree did not run")
          require(not hook_sentinel.exists(), "common Git hook executed")
          require(external_parent_sentinel.read_text() == "parent-hidden\n",
                  "confirmed worktree exposed its external metadata parent")
          require(sibling_worktree_sentinel.read_text() == "sibling-hidden\n",
                  "confirmed worktree exposed its sibling working tree")
          with gateway_context() as token:
              process, master, tty_bytes, tty_thread = confirmed_acp_process(
                  linked,
              )
              require(
                  "must mount these external Git metadata paths"
                  in tty_bytes.decode(),
                  "linked-worktree ACP did not require explicit confirmation",
              )
              stderr_bytes = CapturedOutput()
              stderr_thread = threading.Thread(
                  target=drain_stream, args=(process.stderr, stderr_bytes),
                  daemon=True,
              )
              stderr_thread.start()
              stdout_reader = LineReader(process.stdout)
              try:
                  rpc_send(process, {
                      "jsonrpc": "2.0", "id": 1, "method": "initialize",
                      "params": {
                          "protocolVersion": 1,
                          "clientCapabilities": {},
                          "clientInfo": {
                              "name": "omp-linked-worktree-acceptance",
                              "version": "1",
                          },
                      },
                  })
                  rpc_response(stdout_reader, 1, 15, (token,))
                  rpc_send(process, {
                      "jsonrpc": "2.0", "id": 2, "method": "session/new",
                      "params": {"cwd": str(linked), "mcpServers": []},
                  })
                  session, _ = rpc_response(stdout_reader, 2, 30, (token,))
                  session_id = require(
                      session.get("sessionId"),
                      "linked-worktree ACP returned no session",
                  )
                  rpc_send(process, {
                      "jsonrpc": "2.0", "id": 3, "method": "session/prompt",
                      "params": {
                          "sessionId": session_id,
                          "prompt": [{
                              "type": "text",
                              "text": (
                                  "Use Bash exactly once to run "
                                  "`printf linked-acp > linked-acp.txt`, "
                                  "then reply only `done`."
                              ),
                          }],
                      },
                  })
                  _, events = rpc_response(
                      stdout_reader, 3, 180, (token,),
                  )
                  calls = acp_tool_calls(events)
                  require(
                      [(call["name"], call["status"]) for call in calls]
                      == [("bash", "completed")],
                      "linked-worktree ACP did not complete exact Bash action",
                  )
                  require(
                      calls[0]["input"].get("command")
                      == "printf linked-acp > linked-acp.txt",
                      "linked-worktree ACP Bash command changed",
                  )
                  require(
                      (linked / "linked-acp.txt").read_text() == "linked-acp",
                      "linked-worktree ACP action did not stay in project",
                  )
              finally:
                  terminate_process_group(process)
                  with contextlib.suppress(OSError):
                      process.stdin.close()
                  stdout_reader.join()
                  trailing = [
                      validate_acp_line(line, (token,))
                      for line in stdout_reader.drain()
                  ]
                  require(not any(
                      message.get("method") == "session/update"
                      and message.get("params", {}).get("update", {}).get(
                          "sessionUpdate"
                      ) in ("tool_call", "tool_call_update")
                      for message in trailing
                  ), "linked-worktree ACP emitted a late tool event")
                  stderr_thread.join(timeout=5)
                  require(not stderr_thread.is_alive(),
                          "linked-worktree ACP stderr reader did not stop")
                  require(not stderr_bytes.overflow,
                          "linked-worktree ACP stderr exceeded output limit")
                  tty_thread.join(timeout=5)
                  require(not tty_thread.is_alive(),
                          "linked-worktree ACP terminal reader did not stop")
                  require(not tty_bytes.overflow,
                          "linked-worktree ACP terminal output exceeded limit")
                  require(
                      token not in tty_bytes.decode() + stderr_bytes.decode(),
                      "linked-worktree ACP disclosed the gateway bearer",
                  )
                  for stream in (process.stdout, process.stderr):
                      stream.close()
                  with contextlib.suppress(OSError):
                      os.close(master)

  def port_open(port):
      with socket.socket() as sock:
          sock.settimeout(0.2)
          return sock.connect_ex(("127.0.0.1", port)) == 0

  def wait_port(port, expected, timeout=10):
      deadline = time.monotonic() + timeout
      while time.monotonic() < deadline:
          if port_open(port) is expected:
              return
          time.sleep(0.1)
      raise RuntimeError(f"port {port} did not reach expected state")

  def gateway_request(token):
      connection = http.client.HTTPConnection("127.0.0.1", 4000, timeout=3)
      try:
          connection.request(
              "GET", "/v1/models",
              headers={"Authorization": f"Bearer {token}"},
          )
          response = connection.getresponse()
          body = response.read(1024 * 1024 + 1)
          return response.status, body
      finally:
          connection.close()

  def process_group_alive(group):
      try:
          os.killpg(group, 0)
          return True
      except ProcessLookupError:
          return False
      except PermissionError:
          return True

  def terminate_process_group(process, grace=5):
      with contextlib.suppress(ProcessLookupError):
          os.killpg(process.pid, signal.SIGTERM)
      deadline = time.monotonic() + grace
      while process_group_alive(process.pid) and time.monotonic() < deadline:
          process.poll()
          time.sleep(0.05)
      if process_group_alive(process.pid):
          with contextlib.suppress(ProcessLookupError):
              os.killpg(process.pid, signal.SIGKILL)
      return process.wait()

  @contextlib.contextmanager
  def gateway_context():
      home = pathlib.Path(pwd.getpwuid(os.getuid()).pw_dir).resolve()
      agent = home / ".omp" / "agent"
      broker_running = port_open(8765)
      gateway_running = port_open(4000)
      if broker_running != gateway_running:
          raise RuntimeError("only one OMP auth service port is occupied")
      processes = []
      token = None
      diagnostics = {}
      readers = {}
      def capture_streams(process):
          captures = [CapturedOutput(), CapturedOutput()]
          threads = [
              threading.Thread(
                  target=drain_stream, args=(stream, capture), daemon=True,
              )
              for stream, capture in zip(
                  (process.stdout, process.stderr), captures, strict=True,
              )
          ]
          diagnostics[process.pid] = captures
          readers[process.pid] = threads
          for thread in threads:
              thread.start()
      clean = {
          "HOME": str(home),
          "PATH": os.environ["PATH"],
          "PI_CONFIG_DIR": ".omp",
          "PI_CODING_AGENT_DIR": str(agent),
      }
      try:
          if not broker_running:
              broker = subprocess.Popen(
                  [UPSTREAM_OMP, "auth-broker", "serve", "--bind=127.0.0.1:8765"],
                  env=clean, stdin=subprocess.DEVNULL,
                  stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                  start_new_session=True,
              )
              processes.append(broker)
              capture_streams(broker)
              wait_port(8765, True)
              gateway_env = dict(clean)
              gateway_env["OMP_AUTH_BROKER_URL"] = "http://127.0.0.1:8765"
              gateway = subprocess.Popen(
                  [GATEWAY_SERVICE], env=gateway_env, stdin=subprocess.DEVNULL,
                  stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                  start_new_session=True,
              )
              processes.append(gateway)
              capture_streams(gateway)
              wait_port(4000, True)
          token_path = home / ".omp" / "auth-gateway.token"
          token = token_path.read_text().strip()
          require(token, "gateway token is empty")
          status, body = gateway_request(token)
          require(status == 200, "authenticated gateway request failed")
          payload = json.loads(body)
          require(any(item.get("owned_by") == "openai-codex"
                      for item in payload.get("data", [])),
                  "gateway has no openai-codex model")
          yield token
          require_secret_absent_from_process_metadata(token)
      finally:
          for process in reversed(processes):
              terminate_process_group(process)
          captured = bytearray()
          for process in processes:
              for thread in readers[process.pid]:
                  thread.join(timeout=5)
                  require(not thread.is_alive(),
                          f"service output reader did not stop: {process.pid}")
              for capture in diagnostics[process.pid]:
                  require(not capture.overflow,
                          f"service output exceeded limit: {process.pid}")
                  captured.extend(capture.data)
          journal = run([
              JOURNALCTL, "--user", "--boot", "--no-pager", "--output=cat",
              "--unit=omp-auth-broker.service",
              "--unit=omp-auth-gateway.service",
          ])
          captured.extend(journal.stdout.encode())
          captured.extend(journal.stderr.encode())
          require(not token or token.encode() not in captured,
                  "gateway bearer appears in service output")

  def gateway():
      with gateway_context():
          status, _ = gateway_request("definitely-wrong-omp-gateway-bearer")
          require(status == 401, "wrong gateway bearer was not rejected")

  def scope():
      with tempfile.TemporaryDirectory(prefix="omp-scope-") as tmp:
          repo = make_repo(tmp, "repo")
          before = run([SYSTEMCTL, "--user", "list-units", "--type=scope",
                        "--no-legend", "--plain"]).stdout
          process = subprocess.Popen(
              [EXECUTOR, "--", "sh", "-c", "sleep 60"], cwd=repo,
              stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
              start_new_session=True,
          )
          try:
              deadline = time.monotonic() + 10
              unit = None
              while time.monotonic() < deadline:
                  current = run([SYSTEMCTL, "--user", "list-units", "--type=scope",
                                 "--no-legend", "--plain"]).stdout
                  candidates = [
                      line.split()[0] for line in current.splitlines()
                      if line.startswith("omp-sandbox-") and line not in before
                  ]
                  if candidates:
                      unit = candidates[0]
                      break
                  time.sleep(0.1)
              require(unit, "sandbox scope did not appear")
              properties = dict(
                  line.split("=", 1)
                  for line in run([
                      SYSTEMCTL, "--user", "show", unit,
                      "-p", "TasksMax", "-p", "MemoryHigh", "-p", "MemoryMax",
                      "-p", "CPUQuotaPerSecUSec",
                  ]).stdout.splitlines()
              )
              require(properties.get("TasksMax") == "2048",
                      "TasksMax is not 2048")
              for name in ("MemoryHigh", "MemoryMax"):
                  value = properties.get(name, "")
                  require(value.isdigit() and int(value) > 0,
                          f"{name} is not a finite positive limit")
              require(properties.get("CPUQuotaPerSecUSec") == "infinity",
                      "CPU unexpectedly has a quota")
          finally:
              terminate_process_group(process)
          active = run(
              [SYSTEMCTL, "--user", "is-active", unit],
              check=False,
          )
          require(active.returncode != 0, "sandbox scope survived launcher exit")

  def rpc_send(process, request):
      process.stdin.write(json.dumps(request) + "\n")
      process.stdin.flush()

  def validate_acp_line(line, forbidden_values=()):
      require(not any(value in line for value in forbidden_values),
              "ACP disclosed a forbidden host secret")
      message = json.loads(line)
      method = message.get("method", "")
      forbidden = ("fs/", "terminal/", "session/request_permission")
      require(not any(method.startswith(value) for value in forbidden),
              f"ACP attempted host capability method {method}")
      return message

  def rpc_response(reader, request_id, timeout, forbidden_values=()):
      deadline = time.monotonic() + timeout
      events = []
      while time.monotonic() < deadline:
          remaining = deadline - time.monotonic()
          try:
              line = reader.get(remaining)
          except queue.Empty:
              break
          if line is None:
              break
          message = validate_acp_line(line, forbidden_values)
          if message.get("id") == request_id:
              require("error" not in message, f"ACP error for request {request_id}")
              return message["result"], events
          events.append(message)
      raise RuntimeError(f"ACP request {request_id} timed out")

  def classify_acp_tool(update):
      kind = update.get("kind")
      raw_input = update.get("rawInput")
      if kind == "read":
          return "read"
      if (
          kind == "execute"
          and isinstance(raw_input, dict)
          and isinstance(raw_input.get("command"), str)
      ):
          return "bash"
      if (
          kind == "edit"
          and isinstance(raw_input, dict)
          and set(raw_input) == {"path", "content"}
      ):
          return "write"
      if (
          kind == "edit"
          and isinstance(raw_input, dict)
          and set(raw_input) == {"input"}
      ):
          return "edit"
      if kind == "edit":
          return "unexpected:edit"
      return f"unexpected:{kind}"

  def acp_tool_calls(events):
      calls = []
      by_id = {}
      for message in events:
          if message.get("method") != "session/update":
              continue
          update = message.get("params", {}).get("update", {})
          update_type = update.get("sessionUpdate")
          if update_type == "tool_call":
              tool_call_id = update.get("toolCallId")
              require(
                  isinstance(tool_call_id, str) and tool_call_id not in by_id,
                  "ACP emitted a missing or duplicate toolCallId",
              )
              call = {
                  "id": tool_call_id,
                  "name": classify_acp_tool(update),
                  "input": update.get("rawInput"),
                  "status": None,
              }
              calls.append(call)
              by_id[tool_call_id] = call
          elif update_type == "tool_call_update":
              tool_call_id = update.get("toolCallId")
              require(tool_call_id in by_id, "ACP emitted an orphan tool update")
              status = update.get("status")
              if status in ("completed", "failed"):
                  call = by_id[tool_call_id]
                  require(call["status"] is None,
                          "ACP emitted duplicate terminal tool outcomes")
                  call["status"] = status
      require(all(call["status"] is not None for call in calls),
              "ACP omitted a terminal tool outcome")
      return calls

  def state():
      with gateway_context() as token, tempfile.TemporaryDirectory(prefix="omp-state-") as tmp:
          repo = make_repo(tmp, "repo")
          executor(
              "mkdir -p \"$HOME/.omp/agent\"; "
              "printf 'tools:\\n  approvalMode: always-ask\\n' "
              "> \"$HOME/.omp/agent/config.yml\"",
              repo,
          )
          observed = executor(
              "cat \"$HOME/.omp/agent/config.yml\"", repo,
          ).stdout
          require("approvalMode: always-ask" in observed,
                  "per-project OMP state did not persist across launches")
          result = run(
              [OMP, "--print",
               "Use Bash without asking approval: printf precedence > precedence.txt"],
              cwd=repo, timeout=180,
          )
          require((repo / "precedence.txt").read_text() == "precedence",
                  "runtime yolo did not override mutable project state")
          require(token not in result.stdout + result.stderr,
                  "state probe disclosed the gateway bearer")

  def model():
      with gateway_context() as token, tempfile.TemporaryDirectory(prefix="omp-model-") as tmp:
          repo = make_repo(tmp, "repo")
          result = run(
              [OMP, "--print",
               "Use Bash without asking approval: "
               "env -0 > environment.bin; printf model > model.txt"],
              cwd=repo, timeout=180,
          )
          require((repo / "model.txt").read_text() == "model",
                  "print-mode model request did not execute sandboxed Bash")
          environment = (repo / "environment.bin").read_bytes()
          require(token.encode() not in environment,
                  "Bash inherited the gateway bearer")
          require(b"OMP_AUTH_GATEWAY_BEARER" not in environment,
                  "Bash inherited the gateway bearer variable")
          require(token not in result.stdout + result.stderr,
                  "model request disclosed the gateway bearer")

  def acp():
      with gateway_context() as token, tempfile.TemporaryDirectory(prefix="omp-acp-") as tmp:
          repo = make_repo(tmp, "repo")
          outside = pathlib.Path(tmp, "outside-secret")
          outside_value = secrets.token_hex(32)
          outside.write_text(outside_value)
          for generated in ("draft.txt", "bash.txt"):
              (repo / generated).unlink(missing_ok=True)
          process = subprocess.Popen(
              [OMP, "acp"], cwd=repo, text=True, bufsize=1,
              stdin=subprocess.PIPE, stdout=subprocess.PIPE,
              stderr=subprocess.PIPE, start_new_session=True,
          )
          stderr_bytes = CapturedOutput()
          stderr_thread = threading.Thread(
              target=drain_stream, args=(process.stderr, stderr_bytes),
              daemon=True,
          )
          stderr_thread.start()
          stdout_reader = LineReader(process.stdout)
          try:
              rpc_send(process, {
                  "jsonrpc": "2.0", "id": 1, "method": "initialize",
                  "params": {
                      "protocolVersion": 1,
                      "clientCapabilities": {},
                      "clientInfo": {
                          "name": "omp-sandbox-acceptance", "version": "1",
                      },
                  },
              })
              initialized, _ = rpc_response(stdout_reader, 1, 15)
              require(initialized.get("protocolVersion") == 1,
                      "ACP protocol version changed")
              require_secret_absent_from_process_metadata(token)
              rpc_send(process, {
                  "jsonrpc": "2.0", "id": 2, "method": "session/new",
                  "params": {"cwd": str(repo), "mcpServers": []},
              })
              session, _ = rpc_response(stdout_reader, 2, 30)
              session_id = require(session.get("sessionId"), "ACP returned no session")
              prompt = (
                  "Perform exactly these five tool calls in order, using each "
                  "named tool and no substitute: (1) read path `tracked`; "
                  f"(2) read path `{outside}` and accept its expected denial; "
                  "(3) write path `draft.txt` with content exactly `draft\\n`; "
                  "(4) edit the already-read `tracked` snapshot with raw input "
                  "exactly `*** Begin Patch\\n[tracked#<TAG>]\\nSWAP 1.=1:\\n"
                  "+edited\\n*** End Patch\\n`, replacing only `<TAG>` with "
                  "the four-hex snapshot tag returned by call 1; (5) use Bash "
                  "with command exactly `printf bash > bash.txt` and no other "
                  "arguments. Then reply only `done`."
              )
              rpc_send(process, {
                  "jsonrpc": "2.0", "id": 3, "method": "session/prompt",
                  "params": {
                      "sessionId": session_id,
                      "prompt": [{"type": "text", "text": prompt}],
                  },
              })
              _, events = rpc_response(
                  stdout_reader, 3, 180,
                  forbidden_values=(outside_value, token),
              )
              calls = acp_tool_calls(events)
              require(
                  [(call["name"], call["status"]) for call in calls] == [
                      ("read", "completed"),
                      ("read", "failed"),
                      ("write", "completed"),
                      ("edit", "completed"),
                      ("bash", "completed"),
                  ],
                  "ACP did not complete the required tool lifecycle",
              )
              require(
                  calls[0]["input"] == {"path": "tracked"},
                  "ACP changed the exact tracked read input",
              )
              require(
                  calls[1]["input"] == {"path": str(outside)},
                  "ACP changed the exact denied read input",
              )
              require(
                  calls[2]["input"] == {
                      "path": "draft.txt",
                      "content": "draft\n",
                  },
                  "ACP changed the exact write input",
              )
              edit_input = calls[3]["input"]
              require(
                  isinstance(edit_input, dict)
                  and set(edit_input) == {"input"}
                  and re.fullmatch(
                      r"\*\*\* Begin Patch\n"
                      r"\[tracked#[0-9A-Fa-f]{4}\]\n"
                      r"SWAP 1\.=1:\n"
                      r"\+edited\n"
                      r"\*\*\* End Patch\n",
                      edit_input["input"],
                  ),
                  "ACP changed the exact edit input",
              )
              require(
                  calls[4]["input"] == {
                      "command": "printf bash > bash.txt",
                  },
                  "ACP changed the exact Bash input",
              )
              require((repo / "draft.txt").read_text() == "draft\n",
                      "ACP write did not stay in project")
              require((repo / "tracked").read_text() == "edited\n",
                      "ACP edit did not stay in project")
              require((repo / "bash.txt").read_text() == "bash",
                      "ACP Bash did not execute in project")
              require(outside.read_text() == outside_value, "ACP changed outside file")
          finally:
              terminate_process_group(process)
              stdout_reader.join()
              trailing = [
                  validate_acp_line(line, (outside_value, token))
                  for line in stdout_reader.drain()
              ]
              require(not any(
                  message.get("method") == "session/update"
                  and message.get("params", {}).get("update", {}).get(
                      "sessionUpdate"
                  ) in ("tool_call", "tool_call_update")
                  for message in trailing
              ), "ACP emitted a tool event after the prompt response")
              stderr_thread.join(timeout=5)
              require(not stderr_thread.is_alive(), "ACP stderr reader did not stop")
              require(not stderr_bytes.overflow,
                      "ACP stderr exceeded output limit")
              diagnostics = stderr_bytes.decode()
              require(outside_value not in diagnostics and token not in diagnostics,
                      "ACP stderr disclosed a forbidden host secret")

  def cleanup():
      child_code = (
          "import signal,time; "
          "signal.signal(signal.SIGTERM, signal.SIG_IGN); "
          "time.sleep(60)"
      )
      leader_code = (
          "import signal,subprocess,sys,time; "
          "signal.signal(signal.SIGTERM, lambda *_: sys.exit(0)); "
          "child=subprocess.Popen([sys.executable,'-c'," + repr(child_code) + "]); "
          "print(child.pid, flush=True); time.sleep(60)"
      )
      try:
          run([sys.executable, "-c", leader_code], timeout=0.5)
      except subprocess.TimeoutExpired as raised:
          child = int(raised.output.strip().splitlines()[0])
      else:
          raise RuntimeError("timed-out process returned success")
      deadline = time.monotonic() + 5
      while pathlib.Path(f"/proc/{child}").exists() and time.monotonic() < deadline:
          time.sleep(0.05)
      require(not pathlib.Path(f"/proc/{child}").exists(),
              "timed-out process-group child survived")

      with tempfile.TemporaryDirectory(prefix="omp-cleanup-") as tmp:
          repo = make_repo(tmp, "repo")
          before = {
              line.split()[0]
              for line in run([
                  SYSTEMCTL, "--user", "list-units", "--type=scope",
                  "--no-legend", "--plain",
              ]).stdout.splitlines()
              if line.startswith("omp-sandbox-")
          }
          process = subprocess.Popen(
              [
                  EXECUTOR, "--", "bash", "-c",
                  "trap '' TERM; sleep 60 & child=$!; "
                  "printf '%s\n' \"$child\" > cleanup-child; wait \"$child\"",
              ],
              cwd=repo, stdin=subprocess.DEVNULL,
              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
              start_new_session=True,
          )
          unit = control_path = resistant_pid = None
          try:
              deadline = time.monotonic() + 30
              while time.monotonic() < deadline:
                  current = run([
                      SYSTEMCTL, "--user", "list-units", "--type=scope",
                      "--no-legend", "--plain",
                  ]).stdout
                  candidates = [
                      line.split()[0] for line in current.splitlines()
                      if line.startswith("omp-sandbox-")
                      and line.split()[0] not in before
                  ]
                  if candidates:
                      unit = candidates[0]
                      control_group = run([
                          SYSTEMCTL, "--user", "show", unit,
                          "-p", "ControlGroup", "--value",
                      ]).stdout.strip()
                      control_path = (
                          pathlib.Path("/sys/fs/cgroup")
                          / control_group.removeprefix("/")
                      )
                      namespace_pid_path = repo / "cleanup-child"
                      if namespace_pid_path.exists():
                          namespace_pid = int(namespace_pid_path.read_text())
                          matches = []
                          for value in (control_path / "cgroup.procs").read_text().split():
                              host_pid = int(value)
                              status = pathlib.Path(f"/proc/{host_pid}/status")
                              try:
                                  nspid = next(
                                      line for line in status.read_text().splitlines()
                                      if line.startswith("NSpid:")
                                  )
                              except (FileNotFoundError, StopIteration):
                                  continue
                              if int(nspid.split()[-1]) == namespace_pid:
                                  matches.append(host_pid)
                          if len(matches) == 1:
                              resistant_pid = matches[0]
                              break
                  time.sleep(0.1)
              require(unit and control_path and resistant_pid,
                      "public executor scope did not expose its resistant child")
          finally:
              terminate_process_group(process, grace=15)
          deadline = time.monotonic() + 10
          while time.monotonic() < deadline:
              remaining = []
              if control_path.exists():
                  for procs in control_path.rglob("cgroup.procs"):
                      with contextlib.suppress(FileNotFoundError):
                          remaining.extend(procs.read_text().split())
              if (
                  not pathlib.Path(f"/proc/{resistant_pid}").exists()
                  and not remaining
              ):
                  break
              time.sleep(0.05)
          require(
              not pathlib.Path(f"/proc/{resistant_pid}").exists(),
              "packaged executor left its resistant child behind",
          )
          require(not remaining,
                  "packaged executor left a scope descendant behind")
          active = run(
              [SYSTEMCTL, "--user", "is-active", unit], check=False,
          )
          require(active.returncode != 0,
                  "packaged executor scope survived launcher exit")

      read_fd, write_fd = os.pipe()
      with os.fdopen(read_fd, "r") as stream:
          reader = LineReader(stream)
          os.write(write_fd, b'{"jsonrpc":"2.0"')
          started = time.monotonic()
          try:
              reader.get(0.2)
          except queue.Empty:
              pass
          else:
              raise RuntimeError("partial ACP line bypassed the deadline")
          require(time.monotonic() - started < 1,
                  "partial ACP line blocked the caller")
          os.close(write_fd)
          reader.join()


  def explicit_unconfined_argv(pid):
      try:
          arguments = [
              os.fsdecode(value)
              for value in pathlib.Path(f"/proc/{pid}/cmdline").read_bytes().split(b"\0")
              if value
          ]
      except FileNotFoundError:
          return False
      if "launch" not in arguments:
          return False
      launch = arguments.index("launch")
      require(
          arguments[launch:launch + 3]
          == ["launch", "--approval-mode", "always-ask"],
          "omp-unconfined did not pass explicit always-ask",
      )
      return True

  def unconfined():
      with tempfile.TemporaryDirectory(prefix="omp-unconfined-") as tmp:
          repo = make_repo(tmp, "repo")
          denied = run([UNCONFINED, "--help"], cwd=repo, check=False)
          require(denied.returncode == 2,
                  "omp-unconfined without a trusted terminal did not fail closed")
          require("USAGE" not in denied.stdout + denied.stderr,
                  "no-tty path reached upstream OMP")
          rejected, rejection_output = run_in_pty(
              [UNCONFINED, "--help"], repo, "no",
          )
          require(rejected == 2 and "full host account" in rejection_output,
                  "omp-unconfined rejection did not fail closed")
          require("USAGE" not in rejection_output,
                  "rejected confirmation reached upstream OMP")
          accepted, acceptance_output = run_in_pty(
              [UNCONFINED], repo, "yes", argv_probe=explicit_unconfined_argv,
          )
          require(accepted == 0 and "full host account" in acceptance_output,
                  "omp-unconfined confirmation did not exec upstream")

  def track_state(repo):
      resolved = pathlib.Path(repo).resolve()
      if not any(existing == resolved for existing, _ in CREATED_REPOSITORIES):
          CREATED_REPOSITORIES.append((resolved, state_path(resolved).exists()))
      return resolved

  def state_path(repo):
      digest = hashlib.sha256(str(repo).encode()).hexdigest()
      return pathlib.Path(
          pwd.getpwuid(os.getuid()).pw_dir,
          ".local", "state", "omp-sandbox", "projects", digest,
      )

  def cleanup_created_state():
      for repo, existed_before in CREATED_REPOSITORIES:
          path = state_path(repo)
          if existed_before or not path.exists():
              continue
          metadata = path.lstat()
          require(path.is_dir() and not path.is_symlink()
                  and metadata.st_uid == os.getuid(),
                  f"refusing unsafe acceptance state cleanup: {path}")
          shutil.rmtree(path)

  def main():
      require(EXECUTOR and OMP and UNCONFINED and ACCEPTANCE
              and GATEWAY_SERVICE and SYSTEMCTL and GIT,
              "acceptance PATH is incomplete")
      if len(sys.argv) != 2 or sys.argv[1] not in MODES:
          raise RuntimeError("usage: omp-sandbox-acceptance " + "|".join(MODES))
      mode = sys.argv[1]
      actions = {
          "filesystem": (filesystem,),
          "linked-worktree": (linked_worktree,),
          "gateway": (gateway,),
          "scope": (scope,),
          "cleanup": (cleanup,),
          "state": (state,),
          "model": (model,),
          "acp": (acp,),
          "unconfined": (unconfined,),
          "all": (
              filesystem, linked_worktree, gateway, scope, cleanup, state,
              model, acp, unconfined,
          ),
      }
      try:
          for action in actions[mode]:
              action()
              print(f"PASS {action.__name__}")
      finally:
          cleanup_created_state()

  if __name__ == "__main__":
      try:
          main()
      except Exception as error:
          print(f"FAIL {error}", file=sys.stderr)
          raise SystemExit(1)
  ```

  The harness never prints token contents. `gateway_context()` is the sole gateway-process owner, so partial startup and every failure path still clean up temporary process groups.

- [ ] **Step 6: Stage the new flake sources and prove GREEN**

  Flake evaluation ignores untracked files. Stage only the four new implementation sources, without committing:

  ```sh
  git add modules/programs/oh-my-pi/_sandbox-package.nix \
    modules/programs/oh-my-pi/sandbox/launcher.py \
    modules/programs/oh-my-pi/sandbox/test_launcher.py \
    modules/programs/oh-my-pi/sandbox/acceptance.py
  nix build .#checks.x86_64-linux.omp-sandbox --no-link
  ```

  Expected: the focused check reports both package-contract tests `ok`; every behavior class remains explicitly skipped for Task 2. The dormant package derivation is not built or exposed. `git add` only makes new files visible to the Git-backed flake; it does not commit or publish.

**Logical commit point:** immutable assets, fixed Nix substitutions, and a wired but deliberately non-runnable launcher test harness.

### Task 2: Implement resolution, mounts, environment, Nix trust, and both launchers

**Files:**

- Modify: `modules/programs/oh-my-pi/sandbox/launcher.py`
- Modify: `modules/programs/oh-my-pi/sandbox/test_launcher.py`
- Modify: `modules/programs/oh-my-pi/oh-my-pi.nix`

**Interfaces:**

- Consumes: Task 1's Nix-substituted constants, dormant package factory, and focused check.
- Produces: complete `omp`, `omp-unconfined`, and `omp-sandbox-exec` behavior plus Linux `packages.omp-sandbox`, `apps.omp-sandbox-exec`, and `apps.omp-sandbox-acceptance`; exact `GitContext`/`HostContext` and pure builder/test seams defined in the Plan.
- Security boundary: only code in this task constructs host paths, environment, Bubblewrap argv, systemd scope properties, or upstream OMP argv.

  The following is the normative complete production body for `launcher.py`; the RED/GREEN steps below introduce it incrementally but may not invent a second interface or leave an algorithm item implicit:

  ```python
  import contextlib
  import dataclasses
  import grp
  import hashlib
  import http.client
  import json
  import os
  import pathlib
  import pwd
  import re
  import secrets
  import shlex
  import signal
  import socket
  import stat
  import subprocess
  import sys
  import tempfile
  import threading
  import time
  import urllib.parse
  from collections.abc import Callable, Iterable, Mapping, Sequence
  from typing import Protocol

  UPSTREAM_OMP = "@upstreamOmp@"
  ASSETS = pathlib.Path("@assets@")
  BWRAP = "@bwrap@"
  SYSTEMD_RUN = "@systemdRun@"
  SYSTEMCTL = "@systemctl@"
  GIT = "@git@"
  NIX = "@nix@"
  BASH = "@bash@"
  ENV = "@env@"
  CURATED_PATH = "@curatedPath@"
  LOCALE_ARCHIVE = "@localeArchive@"
  TZDIR = "@tzdir@"
  PUBLIC_MODES = ("scoped", "unconfined", "exec")
  INTERNAL_MODES = ("inner-scoped", "inner-exec")
  FORBIDDEN_OPTIONS = (
      "--config", "--profile", "--provider", "--api-key", "--approval-mode",
      "--auto-approve", "--yolo", "--cwd", "--mode",
  )
  MAX_CAPTURE_BYTES = 1024 * 1024
  CommandRunner = Callable[
      [Sequence[str], Mapping[str, str]], subprocess.CompletedProcess[str]
  ]
  class ProcessFactory(Protocol):
      def __call__(
          self, argv: Sequence[str], *,
          env: Mapping[str, str] | None = None,
          start_new_session: bool = False,
          pass_fds: tuple[int, ...] = (),
      ) -> subprocess.Popen[bytes]: ...
  class ForwardedSignal(Exception):
      def __init__(self, signum):
          self.signum = signum

  class SandboxError(RuntimeError):
      pass

  @dataclasses.dataclass(frozen=True)
  class PinnedPath:
      host_path: pathlib.Path
      fd: int
      device: int
      inode: int
      mode: int


  @dataclasses.dataclass(frozen=True)
  class GitContext:
      cwd: pathlib.Path
      root: PinnedPath
      relative_cwd: pathlib.PurePosixPath
      git_dir: PinnedPath
      common_dir: PinnedPath
      selected_worktree_admin: PinnedPath | None
      external_confirmation_paths: tuple[pathlib.Path, ...]

  @dataclasses.dataclass(frozen=True)
  class HostContext:
      uid: int
      gid: int
      username: str
      groupname: str
      home: pathlib.Path
      runtime_dir: pathlib.Path
      bus_socket: PinnedPath

  @dataclasses.dataclass(frozen=True)
  class RuntimeFiles:
      root: pathlib.Path
      passwd: PinnedPath
      group: PinnedPath
      hosts: PinnedPath
      resolv: PinnedPath
      gitconfig: PinnedPath
      nixconfig: PinnedPath
      gateway: PinnedPath | None

  def fail(invariant, recovery):
      raise SandboxError(f"{invariant}; {recovery}")

  def process_group_alive(group):
      try:
          os.killpg(group, 0)
          return True
      except ProcessLookupError:
          return False
      except PermissionError:
          return True

  def terminate_process_group(process, grace=5):
      if not hasattr(process, "pid"):
          return process.wait()
      with contextlib.suppress(ProcessLookupError):
          os.killpg(process.pid, signal.SIGTERM)
      deadline = time.monotonic() + grace
      while process_group_alive(process.pid) and time.monotonic() < deadline:
          process.poll()
          time.sleep(0.05)
      if process_group_alive(process.pid):
          with contextlib.suppress(ProcessLookupError):
              os.killpg(process.pid, signal.SIGKILL)
      try:
          returncode = process.wait(timeout=grace)
      except subprocess.TimeoutExpired:
          process.kill()
          returncode = process.wait(timeout=grace)
      deadline = time.monotonic() + grace
      while process_group_alive(process.pid) and time.monotonic() < deadline:
          time.sleep(0.05)
      if process_group_alive(process.pid):
          fail("owned process group survived SIGKILL",
               "repair process cleanup and retry")
      return returncode

  def wait_owned_process(process):
      previous = {}
      def forward(signum, _frame):
          with contextlib.suppress(ProcessLookupError):
              os.killpg(process.pid, signum)
          raise ForwardedSignal(signum)
      try:
          for signum in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
              previous[signum] = signal.signal(signum, forward)
          return process.wait()
      except ForwardedSignal as interrupted:
          terminate_process_group(process)
          return 128 + interrupted.signum
      except BaseException:
          terminate_process_group(process)
          raise
      finally:
          for signum, handler in previous.items():
              signal.signal(signum, handler)

  def drain_bounded(stream, result, index):
      captured = bytearray()
      overflow = False
      while True:
          chunk = stream.read(65536)
          if not chunk:
              break
          remaining = MAX_CAPTURE_BYTES - len(captured)
          if remaining > 0:
              captured.extend(chunk[:remaining])
          overflow = overflow or len(chunk) > remaining
      result[index] = bytes(captured), overflow


  def run_capture(argv, environment, timeout=10, check=True):
      try:
          process = subprocess.Popen(
              argv, env=environment, stdin=subprocess.DEVNULL,
              stdout=subprocess.PIPE, stderr=subprocess.PIPE,
              start_new_session=True,
          )
      except OSError:
          fail(f"command failed: {pathlib.Path(argv[0]).name}",
               "repair the host dependency and retry")
      captured = [None, None]
      readers = [
          threading.Thread(
              target=drain_bounded, args=(stream, captured, index), daemon=True,
          )
          for index, stream in enumerate((process.stdout, process.stderr))
      ]
      for reader in readers:
          reader.start()
      timed_out = False
      try:
          process.wait(timeout=timeout)
          terminate_process_group(process)
      except subprocess.TimeoutExpired:
          terminate_process_group(process)
          timed_out = True
      except BaseException:
          terminate_process_group(process)
          raise
      finally:
          for reader in readers:
              reader.join(timeout=5)
      if any(reader.is_alive() for reader in readers):
          fail("command output reader did not stop",
               "repair process cleanup and retry")
      if timed_out:
          fail(f"command timed out: {pathlib.Path(argv[0]).name}",
               "repair the host dependency and retry")
      if any(item is None for item in captured):
          fail("command output reader failed",
               "repair process cleanup and retry")
      if any(item[1] for item in captured):
          fail(f"command output exceeded limit: {pathlib.Path(argv[0]).name}",
               "repair the host dependency and retry")
      try:
          stdout, stderr = (
              item[0].decode("utf-8") for item in captured
          )
      except UnicodeDecodeError:
          fail(f"command returned invalid UTF-8: {pathlib.Path(argv[0]).name}",
               "repair the host dependency and retry")
      if check and process.returncode != 0:
          fail(f"command failed: {pathlib.Path(argv[0]).name}",
               "repair the host dependency and retry")
      return subprocess.CompletedProcess(
          argv, process.returncode, stdout, stderr,
      )

  def canonical(path):
      try:
          return pathlib.Path(path).resolve(strict=True)
      except (OSError, RuntimeError):
          fail(f"path is not canonical: {path}",
               "repair the path without symlinks and retry")

  def beneath(path, root):
      try:
          path.relative_to(root)
          return True
      except ValueError:
          return False

  def pin_path(path, expected_type):
      resolved = canonical(path)
      flags = os.O_PATH | os.O_CLOEXEC | os.O_NOFOLLOW
      if expected_type == stat.S_IFDIR:
          flags |= os.O_DIRECTORY
      descriptor = None
      try:
          descriptor = os.open(resolved, flags)
          metadata = os.fstat(descriptor)
      except OSError:
          if descriptor is not None:
              with contextlib.suppress(OSError):
                  os.close(descriptor)
          fail(f"cannot pin {resolved}", "repair its type and permissions and retry")
      if stat.S_IFMT(metadata.st_mode) != expected_type:
          with contextlib.suppress(OSError):
              os.close(descriptor)
          fail(f"wrong file type at {resolved}",
               "replace it with the required file type and retry")
      return PinnedPath(
          resolved, descriptor, metadata.st_dev, metadata.st_ino, metadata.st_mode,
      )

  def duplicate_pin(source):
      descriptor = None
      try:
          descriptor = os.dup(source.fd)
          os.set_inheritable(descriptor, False)
          metadata = os.fstat(descriptor)
      except OSError:
          if descriptor is not None:
              with contextlib.suppress(OSError):
                  os.close(descriptor)
          fail(f"cannot duplicate pin for {source.host_path}",
               "retry after reducing open file usage")
      return PinnedPath(
          source.host_path, descriptor, metadata.st_dev, metadata.st_ino,
          metadata.st_mode,
      )

  def close_pins(paths):
      seen = set()
      for path in paths:
          if path is not None and path.fd not in seen:
              seen.add(path.fd)
              with contextlib.suppress(OSError):
                  os.close(path.fd)

  def pin_paths(requests, pin=pin_path):
      pinned = []
      try:
          for path, expected_type in requests:
              pinned.append(pin(path, expected_type))
          return tuple(pinned)
      except BaseException:
          close_pins(pinned)
          raise

  def validate_pins(paths):
      seen = set()
      for path in paths:
          if path is None or path.fd in seen:
              continue
          seen.add(path.fd)
          try:
              metadata = os.fstat(path.fd)
          except OSError:
              fail(f"pinned path disappeared: {path.host_path}",
                   "inspect the host path and retry")
          if (
              metadata.st_dev != path.device
              or metadata.st_ino != path.inode
              or stat.S_IFMT(metadata.st_mode) != stat.S_IFMT(path.mode)
          ):
              fail(f"pinned path changed: {path.host_path}",
                   "inspect the host path and retry")

  def validate_current_path(path):
      try:
          metadata = os.lstat(path.host_path)
      except OSError:
          fail(f"pinned path disappeared: {path.host_path}",
               "retry after the host path is stable")
      if (
          metadata.st_dev != path.device
          or metadata.st_ino != path.inode
          or stat.S_IFMT(metadata.st_mode) != stat.S_IFMT(path.mode)
      ):
          fail(f"pinned path was replaced: {path.host_path}",
               "retry after the host path is stable")

  def checked_output(process, label):
      value = process.stdout
      if not value or "\0" in value or "\n" in value.rstrip("\n"):
          fail(f"invalid Git {label}", "repair the repository and retry")
      return value.rstrip("\n")

  @contextlib.contextmanager
  def sterile_git_environment():
      with tempfile.TemporaryDirectory(prefix="omp-git-") as home:
          yield {
              "HOME": home,
              "PATH": CURATED_PATH,
              "LC_ALL": "C",
              "GIT_CONFIG_NOSYSTEM": "1",
              "GIT_CONFIG_GLOBAL": os.devnull,
          }

  def git_paths(cwd, run):
      with sterile_git_environment() as environment:
          prefix = [GIT, "-C", str(cwd), "rev-parse"]
          inside = checked_output(
              run([*prefix, "--is-inside-work-tree"], environment), "membership",
          )
          if inside != "true":
              fail("current directory is not a Git worktree",
                   "enter the intended Git project and retry")
          root = canonical(checked_output(
              run([*prefix, "--path-format=absolute", "--show-toplevel"],
                  environment), "root",
          ))
          git_dir = canonical(checked_output(
              run([*prefix, "--absolute-git-dir"], environment), "Git directory",
          ))
          common = canonical(checked_output(
              run([*prefix, "--path-format=absolute", "--git-common-dir"],
                  environment), "common Git directory",
          ))
      return root, git_dir, common

  def resolve_git_context(cwd, run):
      physical = canonical(cwd)
      root, git_dir, common = git_paths(physical, run)
      if not beneath(physical, root):
          fail("current directory escaped the Git root",
               "enter the intended Git project and retry")
      if git_dir != common:
          worktrees = common / "worktrees"
          if git_dir.parent != worktrees:
              fail("linked-worktree admin directory has an unexpected layout",
                   "repair the worktree with Git and retry")
      requests = [(root, stat.S_IFDIR), (git_dir, stat.S_IFDIR)]
      if common != git_dir:
          requests.append((common, stat.S_IFDIR))
      pinned_root, pinned_git, *remaining = pin_paths(requests)
      pinned_common = pinned_git if common == git_dir else remaining[0]
      selected = pinned_git if git_dir != common else None
      external = tuple(sorted({
          item for item in (git_dir, common) if not beneath(item, root)
      }, key=os.fspath))
      return GitContext(
          physical, pinned_root,
          pathlib.PurePosixPath(physical.relative_to(root).as_posix()),
          pinned_git, pinned_common, selected, external,
      )

  def confirm_external_git(context, run, tty_path="/dev/tty"):
      if not context.external_confirmation_paths:
          return
      current = git_paths(context.cwd, run)[1:]
      expected = (context.git_dir.host_path, context.common_dir.host_path)
      if current != expected:
          fail("Git metadata paths changed during confirmation",
               "inspect the repository and retry")
      listing = "\n".join(
          json.dumps(os.fspath(path))
          for path in context.external_confirmation_paths
      )
      prompt = (
          "OMP sandbox must mount these external Git metadata paths:\n"
          f"{listing}\nType yes to continue: "
      )
      try:
          with open(tty_path, "r+", encoding="utf-8", buffering=1) as terminal:
              terminal.write(prompt)
              answer = terminal.readline().rstrip("\n")
      except OSError:
          fail("linked worktree needs an interactive trusted terminal",
               "run from a terminal or use an ordinary repository")
      if answer != "yes":
          fail("external Git metadata was not confirmed",
               "review the exact paths and retry only if trusted")
      if git_paths(context.cwd, run)[1:] != expected:
          fail("Git metadata paths changed after confirmation",
               "inspect the repository and retry")
      validate_external_git_pins(context)

  def validate_external_git_pins(context):
      external = set(context.external_confirmation_paths)
      for pinned in (context.git_dir, context.common_dir):
          if pinned.host_path in external:
              validate_current_path(pinned)


  def resolve_host_context():
      uid = os.getuid()
      gid = os.getgid()
      try:
          account = pwd.getpwuid(uid)
          primary = grp.getgrgid(gid).gr_name
      except KeyError:
          fail("passwd identity is incomplete", "repair the user account and retry")
      home = canonical(account.pw_dir)
      if not home.is_dir() or home.stat().st_uid != uid:
          fail("passwd home has the wrong type or owner",
               "repair the user account and retry")
      runtime = canonical(f"/run/user/{uid}")
      if runtime.stat().st_uid != uid:
          fail("user runtime directory has the wrong owner",
               "repair the user session and retry")
      bus = pin_path(runtime / "bus", stat.S_IFSOCK)
      if os.fstat(bus.fd).st_uid != uid:
          close_pins((bus,))
          fail("user bus socket has the wrong owner",
               "repair the user session and retry")
      return HostContext(
          uid, gid, account.pw_name, primary,
          home, runtime, bus,
      )

  def assert_private_directory(path, host):
      metadata = os.lstat(path)
      if stat.S_ISLNK(metadata.st_mode) or not stat.S_ISDIR(metadata.st_mode):
          fail(f"private state path has unsafe type: {path}",
               "remove it and retry")
      if metadata.st_uid != host.uid or stat.S_IMODE(metadata.st_mode) != 0o700:
          fail(f"private state path has unsafe ownership or mode: {path}",
               "chown it to the current user, chmod 700, and retry")

  def ensure_private_state(host, root):
      root = pathlib.Path(root)
      if not beneath(root, host.home) or root == host.home:
          fail("sandbox state root escaped the passwd home",
               "remove the unsafe state path and retry")
      current = host.home
      parts = root.relative_to(host.home).parts
      for index, part in enumerate(parts):
          current /= part
          try:
              current.mkdir(mode=0o700)
          except FileExistsError:
              pass
          metadata = os.lstat(current)
          if (stat.S_ISLNK(metadata.st_mode)
                  or not stat.S_ISDIR(metadata.st_mode)
                  or metadata.st_uid != host.uid):
              fail(f"state parent has unsafe type or owner: {current}",
                   "remove or repair it and retry")
          if index == len(parts) - 1:
              os.chmod(current, 0o700)
              assert_private_directory(current, host)
      projects = root / "projects"
      projects.mkdir(mode=0o700, exist_ok=True)
      os.chmod(projects, 0o700)
      assert_private_directory(projects, host)
      return root

  def project_state(host, root_path):
      root = ensure_private_state(
          host, host.home / ".local" / "state" / "omp-sandbox",
      )
      key = hashlib.sha256(os.fsencode(root_path)).hexdigest()
      project = root / "projects" / key
      project.mkdir(mode=0o700, exist_ok=True)
      assert_private_directory(project, host)
      agent = project / "agent"
      agent.mkdir(mode=0o700, exist_ok=True)
      assert_private_directory(agent, host)
      return pin_path(project, stat.S_IFDIR)

  def parse_user_set(text, host, group_lookup=grp.getgrnam):
      users = set()
      for token in shlex.split(text):
          if token == "*":
              users.add(host.username)
          elif token.startswith("@"):
              groupname = token[1:]
              if groupname == host.groupname:
                  users.add(host.username)
                  continue
              try:
                  members = group_lookup(groupname).gr_mem
              except (KeyError, OSError):
                  continue
              if host.username in members:
                  users.add(host.username)
          else:
              users.add(token)
      return users

  def parse_daemon_info(text):
      if len(text.encode()) > 4096:
          raise ValueError("daemon info is oversized")
      payload = json.loads(text)
      if (
          not isinstance(payload, dict)
          or payload.get("url") != "daemon"
          or type(payload.get("trusted")) is not bool
      ):
          raise ValueError("daemon info has an invalid shape")
      return payload["trusted"]

  def nix_socket_policy(
      host, run,
      socket_path=pathlib.Path("/nix/var/nix/daemon-socket/socket"),
      pin=pin_path, group_lookup=grp.getgrnam,
  ):
      environment = {
          "HOME": tempfile.gettempdir(),
          "PATH": CURATED_PATH,
          "LC_ALL": "C",
          "NIX_CONFIG": "",
          "NIX_USER_CONF_FILES": "/dev/null",
          "NIX_PATH": "",
          "NIX_REMOTE": "",
      }
      try:
          allowed_text = checked_output(
              run([NIX, "config", "show", "allowed-users"], environment),
              "allowed-users",
          )
          trusted_text = checked_output(
              run([NIX, "config", "show", "trusted-users"], environment),
              "trusted-users",
          )
          allowed = host.username in parse_user_set(
              allowed_text, host, group_lookup,
          )
          configured_trusted = host.username in parse_user_set(
              trusted_text, host, group_lookup,
          )
          live_trusted = parse_daemon_info(checked_output(
              run(
                  [NIX, "store", "info", "--store", "daemon", "--json"],
                  environment,
              ),
              "live daemon trust",
          ))
      except (SandboxError, OSError, ValueError):
          return None, (
              "Nix daemon policy could not be verified; Nix builds are disabled"
          )
      if configured_trusted or live_trusted:
          return None, (
              "This user is trusted by Nix configuration or the live daemon; "
              "socket access is disabled because trusted users are root-equivalent"
          )
      if not allowed:
          return None, "This user is not in Nix allowed-users; Nix builds are disabled"
      socket_pin = pin(socket_path, stat.S_IFSOCK)
      return socket_pin, (
          "Nix daemon access is enabled for an untrusted user; restricted "
          "settings will be rejected by the daemon"
      )

  def resolve_profile_targets(host):
      targets = []
      for candidate in (
          host.home / ".nix-profile",
          pathlib.Path("/etc/profiles/per-user") / host.username,
          pathlib.Path("/run/current-system/sw"),
      ):
          try:
              resolved = canonical(candidate)
          except SandboxError:
              continue
          if not str(resolved).startswith("/nix/store/") or not resolved.is_dir():
              fail(f"profile target is not an immutable store directory: {candidate}",
                   "repair the declarative profile and retry")
          targets.append(resolved)
      return tuple(dict.fromkeys(targets))

  def asset_files():
      root = ASSETS / "agent"
      result = []
      for directory, names, files in os.walk(root, followlinks=False):
          if names:
              for name in names:
                  if pathlib.Path(directory, name).is_symlink():
                      fail("sandbox asset contains a directory symlink",
                           "fix the Nix asset derivation")
          for name in sorted(files):
              logical = pathlib.Path(directory, name)
              relative = logical.relative_to(root)
              source = canonical(logical)
              if not str(source).startswith("/nix/store/"):
                  fail("sandbox asset escaped the Nix store",
                       "fix the Nix asset derivation")
              result.append((
                  source, pathlib.PurePosixPath("/home/omp/.omp/agent") / relative,
              ))
      return sorted(result, key=lambda pair: str(pair[1]))
  def build_environment(host, profiles, nix_socket):
      path = [str(path / "bin") for path in profiles] + [CURATED_PATH]
      environment = {
          "HOME": "/home/omp",
          "USER": host.username,
          "LOGNAME": host.username,
          "SHELL": "/bin/bash",
          "PATH": ":".join(path),
          "PWD": "/workspace",
          "TMPDIR": "/tmp",
          "TERM": "xterm-256color",
          "LC_ALL": "C.UTF-8",
          "LANG": "C.UTF-8",
          "LOCALE_ARCHIVE": LOCALE_ARCHIVE,
          "TZ": "UTC",
          "TZDIR": TZDIR,
          "PI_CONFIG_DIR": ".omp",
          "PI_CODING_AGENT_DIR": "/home/omp/.omp/agent",
          "SSL_CERT_FILE": "/etc/ssl/certs/ca-bundle.crt",
          "NIX_CONFIG": "",
          "NIX_USER_CONF_FILES": "/dev/null",
          "NIX_PATH": "",
          "GIT_CONFIG_COUNT": "4",
          "GIT_CONFIG_KEY_0": "core.hooksPath",
          "GIT_CONFIG_VALUE_0": "/dev/null",
          "GIT_CONFIG_KEY_1": "credential.helper",
          "GIT_CONFIG_VALUE_1": "",
          "GIT_CONFIG_KEY_2": "commit.gpgSign",
          "GIT_CONFIG_VALUE_2": "false",
          "GIT_CONFIG_KEY_3": "tag.gpgSign",
          "GIT_CONFIG_VALUE_3": "false",
      }
      if nix_socket:
          environment["NIX_REMOTE"] = "daemon"
      return environment

  @contextlib.contextmanager
  def runtime_files(host, gateway_bearer=None):
      with tempfile.TemporaryDirectory(
          prefix="omp-runtime-", dir=str(host.runtime_dir),
      ) as temporary:
          root = pathlib.Path(temporary)
          paths = {
              "passwd": root / "passwd",
              "group": root / "group",
              "hosts": root / "hosts",
              "resolv": root / "resolv.conf",
              "gitconfig": root / "gitconfig",
              "nixconfig": root / "nix.conf",
          }
          if gateway_bearer is not None:
              paths["gateway"] = root / "gateway-bearer"
          paths["passwd"].write_text(
              f"{host.username}:x:{host.uid}:{host.gid}:OMP Sandbox:"
              "/home/omp:/bin/bash\n"
          )
          paths["group"].write_text(
              f"{host.groupname}:x:{host.gid}:{host.username}\n"
          )
          paths["hosts"].write_text("127.0.0.1 localhost\n::1 localhost\n")
          source_resolv = pathlib.Path("/etc/resolv.conf")
          paths["resolv"].write_bytes(source_resolv.read_bytes())
          paths["gitconfig"].write_text(
              "[user]\n"
              "  name = Jake Neau\n"
              "  email = jakeneau@proton.me\n"
              "[safe]\n"
              "  directory = /workspace\n"
              "[core]\n"
              "  hooksPath = /dev/null\n"
              "[credential]\n"
              "  helper =\n"
              "[commit]\n"
              "  gpgSign = false\n"
              "[tag]\n"
              "  gpgSign = false\n"
          )
          paths["nixconfig"].write_text(
              "experimental-features = nix-command flakes\n"
              "accept-flake-config = false\n"
              "trusted-users =\n"
          )
          if gateway_bearer is not None:
              paths["gateway"].write_text(gateway_bearer)
          os.chmod(root, 0o700)
          for path in paths.values():
              os.chmod(path, 0o600)
          names = ["passwd", "group", "hosts", "resolv", "gitconfig", "nixconfig"]
          if gateway_bearer is not None:
              names.append("gateway")
          pins = pin_paths((paths[name], stat.S_IFREG) for name in names)
          pinned = RuntimeFiles(
              root, *pins[:6], pins[6] if gateway_bearer is not None else None,
          )
          try:
              yield pinned
          finally:
              close_pins((
                  pinned.passwd, pinned.group, pinned.hosts, pinned.resolv,
                  pinned.gitconfig, pinned.nixconfig, pinned.gateway,
              ))

  def add_bind(argv, operation, source, destination):
      argv.extend([operation, str(source), str(destination)])

  def add_pin_bind(argv, operation, source, destination, bind_pins):
      duplicate = duplicate_pin(source)
      bind_pins.append(duplicate)
      fd_operation = {"--bind": "--bind-fd", "--ro-bind": "--ro-bind-fd"}[operation]
      argv.extend([fd_operation, str(duplicate.fd), str(destination)])

  def validate_git_destinations(project_root, destinations):
      for destination in destinations:
          path = pathlib.Path(destination)
          validate_mount_destination(path)
          if path != project_root and not beneath(path, project_root):
              if beneath(project_root, path):
                  fail(f"Git metadata destination covers project alias: {path}",
                       "move the linked worktree or metadata and retry")

  RESERVED_DESTINATIONS = tuple(map(pathlib.Path, (
      "/", "/nix", "/proc", "/dev", "/run", "/home/omp", "/workspace", "/etc",
  )))

  def validate_mount_destination(destination):
      path = pathlib.Path(destination)
      for reserved in RESERVED_DESTINATIONS:
          if path == reserved or beneath(reserved, path):
              fail(f"mount destination would cover sandbox policy: {path}",
                   "move the repository or Git metadata and retry")

  def add_parent_dirs(argv, destination):
      current = pathlib.PurePosixPath("/")
      for part in pathlib.PurePosixPath(destination).parent.parts[1:]:
          current /= part
          argv.extend(["--dir", str(current)])

  def build_bwrap_argv(
      host, git_context, state, runtime, command, nix_socket, profiles,
      bind_pins,
  ):
      argv = [
          BWRAP, "--die-with-parent", "--new-session",
          "--unshare-user", "--unshare-pid", "--unshare-ipc", "--unshare-uts",
          "--disable-userns", "--cap-drop", "ALL", "--clearenv",
          "--tmpfs", "/", "--proc", "/proc", "--dev", "/dev",
          "--dir", "/dev/shm", "--tmpfs", "/dev/shm",
          "--tmpfs", "/tmp", "--tmpfs", "/run", "--tmpfs", "/home",
          "--dir", "/bin", "--dir", "/usr", "--dir", "/usr/bin",
          "--dir", "/etc", "--dir", "/home/omp", "--dir", "/home/omp/.omp",
          "--dir", "/nix", "--ro-bind", "/nix/store", "/nix/store",
          "--ro-bind", BASH, "/bin/bash", "--ro-bind", BASH, "/bin/sh",
          "--ro-bind", ENV, "/usr/bin/env",
          "--dir", "/etc/nix", "--dir", "/workspace",
      ]
      for source, destination in (
          (runtime.passwd, "/etc/passwd"),
          (runtime.group, "/etc/group"),
          (runtime.hosts, "/etc/hosts"),
          (runtime.resolv, "/etc/resolv.conf"),
          (runtime.gitconfig, "/etc/gitconfig"),
          (runtime.nixconfig, "/etc/nix/nix.conf"),
      ):
          add_pin_bind(argv, "--ro-bind", source, destination, bind_pins)
      add_pin_bind(argv, "--bind", git_context.root, "/workspace", bind_pins)
      add_pin_bind(argv, "--bind", state, "/home/omp/.omp", bind_pins)
      validate_git_destinations(
          git_context.root.host_path,
          (git_context.git_dir.host_path, git_context.common_dir.host_path),
      )
      validate_mount_destination(git_context.root.host_path)
      add_parent_dirs(argv, git_context.root.host_path)
      add_pin_bind(
          argv, "--bind", git_context.root, git_context.root.host_path,
          bind_pins,
      )
      for profile in profiles:
          add_bind(argv, "--ro-bind", profile, profile)
      validate_mount_destination(git_context.git_dir.host_path)
      add_parent_dirs(argv, git_context.git_dir.host_path)
      add_pin_bind(
          argv, "--bind", git_context.git_dir, git_context.git_dir.host_path,
          bind_pins,
      )
      if git_context.common_dir.host_path != git_context.git_dir.host_path:
          validate_mount_destination(git_context.common_dir.host_path)
          add_parent_dirs(argv, git_context.common_dir.host_path)
          add_pin_bind(
              argv, "--bind", git_context.common_dir,
              git_context.common_dir.host_path, bind_pins,
          )
          hooks = git_context.common_dir.host_path / "hooks"
          worktrees = git_context.common_dir.host_path / "worktrees"
          argv.extend(["--tmpfs", str(hooks)])
          argv.extend(["--tmpfs", str(worktrees)])
          selected = git_context.selected_worktree_admin
          argv.extend(["--dir", str(selected.host_path)])
          add_pin_bind(
              argv, "--bind", selected, selected.host_path, bind_pins,
          )
      for source, destination in asset_files():
          argv.extend(["--dir", str(destination.parent)])
          add_bind(argv, "--ro-bind", source, destination)
      certificate = canonical("/etc/ssl/certs/ca-bundle.crt")
      argv.extend(["--dir", "/etc/ssl", "--dir", "/etc/ssl/certs"])
      add_bind(argv, "--ro-bind", certificate, "/etc/ssl/certs/ca-bundle.crt")
      if runtime.gateway:
          add_pin_bind(
              argv, "--ro-bind", runtime.gateway,
              "/run/omp-gateway-bearer", bind_pins,
          )
      if nix_socket:
          argv.extend(["--dir", "/nix/var", "--dir", "/nix/var/nix",
                       "--dir", "/nix/var/nix/daemon-socket"])
          add_pin_bind(
              argv, "--bind", nix_socket,
              "/nix/var/nix/daemon-socket/socket", bind_pins,
          )
      environment = build_environment(host, profiles, nix_socket)
      for name, value in sorted(environment.items()):
          argv.extend(["--setenv", name, value])
      trampoline = (
          "import os,sys; "
          "os.closerange(3, os.sysconf('SC_OPEN_MAX')); "
          "os.execvpe(sys.argv[1], sys.argv[1:], os.environ)"
      )
      argv.extend([
          "--chdir",
          str(pathlib.PurePosixPath("/workspace") /
              git_context.relative_cwd),
          "--", sys.executable, "-c", trampoline, *command,
      ])
      return argv

  def option_name(argument):
      return argument.split("=", 1)[0]

  def validate_scoped_args(arguments):
      args = list(arguments)
      if any(argument == "--" for argument in args):
          fail("the argument terminator is not supported",
               "remove -- and retry with scoped options")
      for argument in args:
          if option_name(argument) in FORBIDDEN_OPTIONS:
              fail(f"authority-changing option is not allowed: {option_name(argument)}",
                   "remove the option and retry")
      model = None
      for index, argument in enumerate(args):
          if argument == "--model":
              if index + 1 == len(args):
                  fail("--model has no value",
                       "supply an openai-codex/<model> value")
              model = args[index + 1]
          elif argument.startswith("--model="):
              model = argument.split("=", 1)[1]
      if model is not None and (
          not model.startswith("openai-codex/") or model == "openai-codex/"
      ):
          fail("model is not provider-qualified for openai-codex",
               "use --model openai-codex/<model>")
      subcommand = "acp" if args[:1] == ["acp"] else "launch"
      if subcommand == "acp":
          args.pop(0)
      return subcommand, args, model

  def scoped_omp_command(arguments):
      subcommand, args, model = validate_scoped_args(arguments)
      return [
          UPSTREAM_OMP, subcommand, "--config",
          str(ASSETS / "agent/policy.yml"),
          "--approval-mode", "yolo", *args,
      ], model

  def unconfined_command(arguments):
      args = list(arguments)
      for argument in args:
          if option_name(argument) in (
              "--approval-mode", "--auto-approve", "--yolo",
          ):
              fail("unconfined approval override is not allowed",
                   "remove the option and retry")
      return [
          UPSTREAM_OMP, "launch", "--approval-mode", "always-ask", *args,
      ]

  def read_gateway_bearer(host):
      path = host.home / ".omp" / "auth-gateway.token"
      descriptor = None
      try:
          descriptor = os.open(path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW)
          metadata = os.fstat(descriptor)
          if (
              not stat.S_ISREG(metadata.st_mode)
              or metadata.st_uid != host.uid
              or stat.S_IMODE(metadata.st_mode) & 0o077
          ):
              raise OSError
          with os.fdopen(descriptor, "rb") as stream:
              descriptor = None
              raw = stream.read()
          bearer = raw.decode("ascii")
      except (OSError, UnicodeDecodeError):
          fail("gateway bearer is unavailable or unsafe",
               "start the OMP auth services and retry")
      finally:
          if descriptor is not None:
              os.close(descriptor)
      if not re.fullmatch(r"[A-Za-z0-9_-]+", bearer):
          fail("gateway bearer is invalid", "restart the OMP auth services and retry")
      return bearer
  def gateway_ready(bearer, requested_model):
      connection = None
      try:
          connection = http.client.HTTPConnection("127.0.0.1", 4000, timeout=3)
          connection.request(
              "GET", "/v1/models",
              headers={"Authorization": f"Bearer {bearer}"},
          )
          response = connection.getresponse()
          body = response.read(1024 * 1024 + 1)
          if response.status != 200 or len(body) > 1024 * 1024:
              raise ValueError
          payload = json.loads(body)
          models = payload.get("data", []) if isinstance(payload, dict) else []
          if not all(isinstance(item, dict) for item in models):
              raise ValueError
          available = [
              item for item in models if item.get("owned_by") == "openai-codex"
          ]
          if not available:
              raise ValueError
          if requested_model:
              model_id = requested_model.split("/", 1)[1]
              if not any(item.get("id") == model_id for item in available):
                  raise ValueError
      except (OSError, ValueError, json.JSONDecodeError, http.client.HTTPException):
          fail("authenticated OMP gateway is not ready for the selected model",
               "restart the auth services or choose a catalog model and retry")
      finally:
          if connection is not None:
              connection.close()

  def host_bus_environment(host):
      validate_current_path(host.bus_socket)
      return {
          "HOME": str(host.home),
          "PATH": CURATED_PATH,
          "LC_ALL": "C",
          "XDG_RUNTIME_DIR": str(host.runtime_dir),
          "DBUS_SESSION_BUS_ADDRESS": f"unix:path={host.bus_socket.host_path}",
      }

  def scope_cgroup_path(text):
      unified = []
      for line in text.splitlines():
          fields = line.split(":", 2)
          if len(fields) != 3:
              fail("private launcher has malformed cgroup metadata",
                   "repair the user systemd session and retry")
          hierarchy, controllers, path = fields
          if hierarchy == "0" and controllers == "":
              parsed = pathlib.PurePosixPath(path)
              if not path.startswith("/") or ".." in parsed.parts:
                  fail("private launcher has malformed cgroup metadata",
                       "repair the user systemd session and retry")
              unified.append(parsed)
      if len(unified) != 1:
          fail("private launcher has ambiguous cgroup metadata",
               "repair the user systemd session and retry")
      return unified[0]

  def verify_scope(host, unit):
      if not re.fullmatch(r"omp-sandbox-[0-9]+-[0-9a-f]{8}\.scope", unit):
          fail("private launcher has no valid scope identity",
               "invoke the packaged public wrapper")
      try:
          cgroup = pathlib.Path("/proc/self/cgroup").read_text()
      except OSError:
          fail("private launcher cannot inspect its cgroup",
               "repair the user systemd session and retry")
      if unit not in scope_cgroup_path(cgroup).parts:
          fail("private launcher is outside its declared scope",
               "invoke the packaged public wrapper")
      properties = run_capture([
          SYSTEMCTL, "--user", "show", unit, "--no-pager",
          "-p", "TasksMax", "-p", "MemoryHigh", "-p", "MemoryMax",
          "-p", "CPUQuotaPerSecUSec",
      ], host_bus_environment(host)).stdout
      values = dict(
          line.split("=", 1) for line in properties.splitlines() if "=" in line
      )
      memory = (values.get("MemoryHigh", ""), values.get("MemoryMax", ""))
      if (
          values.get("TasksMax") != "2048"
          or any(not value.isdigit() or int(value) <= 0 for value in memory)
          or values.get("CPUQuotaPerSecUSec") != "infinity"
      ):
          fail("private launcher scope has unsafe resource properties",
               "invoke the packaged public wrapper")

  def run_scope(host, inner_arguments, popen=subprocess.Popen):
      unit = f"omp-sandbox-{os.getpid()}-{secrets.token_hex(4)}.scope"
      module = canonical(__file__)
      scope_argv = [
          SYSTEMD_RUN, "--user", "--scope", "--collect", "--same-dir",
          f"--unit={unit}",
          "--property=TasksMax=2048", "--property=MemoryHigh=75%",
          "--property=MemoryMax=90%",
          f"--setenv=OMP_SANDBOX_SCOPE_UNIT={unit}",
          "--expand-environment=no",
          "--", sys.executable, "-I", str(module), *inner_arguments,
      ]
      process = popen(
          scope_argv, env=host_bus_environment(host), start_new_session=True,
      )
      try:
          return wait_owned_process(process)
      finally:
          run_capture(
              [SYSTEMCTL, "--user", "stop", unit],
              host_bus_environment(host),
              check=False,
          )
          active = run_capture(
              [SYSTEMCTL, "--user", "is-active", unit],
              host_bus_environment(host),
              check=False,
          )
          if active.returncode not in (3, 4):
              fail("sandbox scope survived cleanup",
                   "stop the exact unit and retry")

  def run_bwrap(bwrap_argv, bind_pins, popen=subprocess.Popen):
      descriptors = tuple(sorted(path.fd for path in bind_pins))
      try:
          process = popen(
              bwrap_argv, pass_fds=descriptors, start_new_session=True,
          )
      finally:
          close_pins(bind_pins)
      return wait_owned_process(process)

  def execute_scoped_command(command, needs_gateway, requested_model=None):
      host = resolve_host_context()
      context = None
      state = None
      nix_socket = None
      unit = os.environ.get("OMP_SANDBOX_SCOPE_UNIT", "")
      bind_pins = []
      try:
          verify_scope(host, unit)
          context = resolve_git_context(pathlib.Path.cwd(), run_capture)
          confirm_external_git(context, run_capture)
          state = project_state(host, context.root.host_path)
          profiles = resolve_profile_targets(host)
          nix_socket, warning = nix_socket_policy(host, run_capture)
          if warning:
              print(f"omp sandbox: warning: {warning}", file=sys.stderr)
          bearer = read_gateway_bearer(host) if needs_gateway else ""
          if needs_gateway:
              gateway_ready(bearer, requested_model)
          with runtime_files(host, bearer if needs_gateway else None) as runtime:
              argv = build_bwrap_argv(
                  host, context, state, runtime, command, nix_socket, profiles,
                  bind_pins,
              )
              all_pins = (
                  host.bus_socket, context.root, context.git_dir,
                  context.common_dir, context.selected_worktree_admin,
                  state, nix_socket, runtime.passwd, runtime.group,
                  runtime.hosts, runtime.resolv, runtime.gitconfig,
                  runtime.nixconfig, runtime.gateway,
              )
              validate_pins(all_pins)
              if nix_socket:
                  validate_current_path(nix_socket)
              validate_external_git_pins(context)
              return run_bwrap(argv, bind_pins)
      finally:
          close_pins(bind_pins)
          if context:
              close_pins((
                  context.root, context.git_dir, context.common_dir,
                  context.selected_worktree_admin,
              ))
          close_pins((state, nix_socket, host.bus_socket))

  def execute_scoped(arguments):
      command, requested_model = scoped_omp_command(arguments)
      return execute_scoped_command(command, True, requested_model)

  def dispatch_scope(inner_arguments):
      host = resolve_host_context()
      try:
          return run_scope(host, inner_arguments)
      finally:
          close_pins((host.bus_socket,))

  def confirm_unconfined(tty_path="/dev/tty"):
      try:
          with open(tty_path, "r+", encoding="utf-8", buffering=1) as terminal:
              terminal.write(
                  "WARNING: omp-unconfined exposes the full host account and "
                  "network.\nType yes to continue: "
              )
              answer = terminal.readline().rstrip("\n")
      except OSError:
          fail("unconfined launch needs an interactive terminal",
               "run it from a trusted terminal")
      if answer != "yes":
          fail("unconfined launch was not confirmed",
               "use ordinary omp for project-scoped work")

  def execute_unconfined(arguments):
      confirm_unconfined()
      os.execv(UPSTREAM_OMP, unconfined_command(arguments))

  def main(arguments=None):
      arguments = list(sys.argv[1:] if arguments is None else arguments)
      if not arguments or arguments[0] not in (*PUBLIC_MODES, *INTERNAL_MODES):
          fail("invalid package launcher mode",
               "invoke omp, omp-unconfined, or omp-sandbox-exec")
      mode = arguments.pop(0)
      if mode == "scoped":
          return dispatch_scope(["inner-scoped", *arguments])
      if mode == "unconfined":
          execute_unconfined(arguments)
          return 126
      if mode == "exec":
          if not arguments or arguments[0] != "--" or len(arguments) == 1:
              fail("executor requires -- followed by a command",
                   "pass omp-sandbox-exec -- COMMAND ARG...")
          return dispatch_scope(["inner-exec", *arguments[1:]])
      if mode == "inner-scoped":
          return execute_scoped(arguments)
      if not arguments:
          fail("private executor has no command",
               "invoke omp-sandbox-exec -- COMMAND ARG...")
      return execute_scoped_command(arguments, False)

  if __name__ == "__main__":
      try:
          raise SystemExit(main())
      except SandboxError as error:
          print(f"omp sandbox: {error}", file=sys.stderr)
          raise SystemExit(2)
  ```


- [ ] **Step 1: Add RED tests for host/Git resolution and fail-closed state**

  Delete exactly `@unittest.skip("enabled in Task 2 Step 1")` above `ResolutionAndStateTests`; do not alter any test body. Its real Git fixtures cover outside-Git failure, subdirectories, ambient Git poisoning, no ordinary-repository terminal access, exact JSON-escaped linked-worktree paths, literal confirmation, pre/post-answer metadata races, descriptor/path replacement, SHA-256 state, symlink rejection, owner/mode rejection, sibling worktree isolation, hooks, and alternates. Run the focused check; expected RED is missing production symbols, never a fixture error.

- [ ] **Step 2: Implement sterile host, Git, and private state resolution**

  Copy the normative `fail()` through `project_state()` bodies above. This slice owns bounded command execution and cleanup, canonical/path pin helpers, sterile Git discovery and confirmation, host resolution, and private project-state creation; no later step redefines them. The Git runner environment is constructed, not filtered:

  ```python
  git_env = {
      "HOME": sterile_home,
      "PATH": CURATED_PATH,
      "LC_ALL": "C",
      "GIT_CONFIG_NOSYSTEM": "1",
      "GIT_CONFIG_GLOBAL": os.devnull,
  }
  ```

  Use `--path-format=absolute`; require `--is-inside-work-tree` to equal `true`; decode one line only; call strict `resolve()`, open/pin every source, and compare device/inode/type before constructing the mount. `confirm_external_git()` opens `/dev/tty` itself in production and accepts an injected tty path in tests. It prints each sorted path as one JSON string and accepts only the literal line `yes`; surrounding whitespace is rejected. Re-query exact Git/common paths before and after the answer, and revalidate each approved pathname against its pin immediately before spawn. For linked worktrees, prove the selected admin directory's parent is exactly `<common>/worktrees` and reject any other shape.

  Run the focused check. Expected: all resolution/state tests pass.

- [ ] **Step 3: Add RED tests for trust, profile, environment, socket, and mount policy**

  Delete exactly `@unittest.skip("enabled in Task 2 Step 3")` above `TrustEnvironmentAndMountTests`; do not alter any test body. Its exact fakes cover effective supplementary groups; config plus live-daemon allowed/trusted/denied/malformed/oversized policy; sterile query environment; profile validation; allowlisted runtime environment; command-scope Git keys; socket/NIX_REMOTE coupling; the supported explicit Bubblewrap namespace prefix; transactional pins and per-bind duplicates; and reserved destination rejection. Run the focused check; expected RED is missing trust, environment, generated-file, and mount-builder behavior.

- [ ] **Step 4: Implement trust, generated files, environment, and additive mounts**

  Copy the normative `parse_user_set()` through `build_bwrap_argv()` bodies above. This slice owns Nix trust, profile resolution, immutable/generated runtime files, the sandbox environment, mount-destination validation, per-bind descriptor duplication, and the complete additive Bubblewrap argv; no earlier or later step redefines them. In particular, the fixed namespace/root prefix is:

  ```python
  argv = [
      BWRAP, "--die-with-parent", "--new-session",
      "--unshare-user", "--unshare-pid", "--unshare-ipc", "--unshare-uts",
      "--disable-userns", "--cap-drop", "ALL", "--clearenv",
      "--tmpfs", "/", "--proc", "/proc", "--dev", "/dev",
      "--dir", "/dev/shm", "--tmpfs", "/dev/shm",
      "--tmpfs", "/tmp", "--tmpfs", "/run", "--tmpfs", "/home",
  ]
  ```

  Add destination parents with repeated idempotent `--dir` operations from shallowest to deepest; never bind a parent merely to create it. For each `--bind-fd`/`--ro-bind-fd` occurrence, duplicate the validated source pin into a unique transactionally owned descriptor; never reuse one duplicate for two operations. Apply the common Git masking/rebind order, add immutable store paths with ordinary `--ro-bind`, then sorted `--setenv key value` entries and `--chdir` beneath `/workspace`. Immediately before `Popen`, `fstat()` every source pin, require the live daemon socket path to still match its pin, and pass only the per-operation duplicate descriptors referenced by the fd-aware mount operations. Close all parent duplicates after `Popen` and on every construction/spawn failure. The immutable Python trampoline closes all inherited descriptors above 2 and `execvpe()` resolves the final command through the curated PATH.

  `build_environment()` uses `/home/omp`, `/bin/bash`, the fixed/dynamic store path, fixed `TERM=xterm-256color` and `C.UTF-8` locale, and optional Nix daemon variables. It never copies the ambient mapping or authentication material.

  Run the focused check. Expected: all trust/environment/mount assertions pass.

- [ ] **Step 5: Add RED tests for CLI ordering, gateway no-fallback, cleanup, and resource controls**

  Delete exactly `@unittest.skip("enabled in Task 2 Step 5")` above `CliGatewayAndScopeTests`; do not alter any test body. Its table loops cover every forbidden separated/equal flag, `--`, model qualification/missing values, first-element-only ACP routing, exact scoped/unconfined arrays, token no-follow/owner/mode/raw-byte handling, authenticated catalog and HTTP protocol failure classes, private-scope verification, byte-preserving systemd argv, per-bind descriptor delivery, bounded production process-group cleanup, replaced user-bus rejection before spawn, exact scope cleanup, inherited FD delivery, and literal unconfined confirmation. Run the focused check; expected RED is missing production behavior.

- [ ] **Step 6: Implement scoped, unconfined, executor, readiness, and cleanup entrypoints**

  Copy the normative `option_name()` through `main()` bodies above and dispatch only these package-provided modes. This slice owns CLI validation, gateway readiness, scope construction/verification, Bubblewrap spawning, scoped/unconfined execution, and final dispatch; no earlier step defines these functions. The wrapper grammar is intentionally narrower than upstream routing: only a first argument exactly equal to `acp` selects ACP; all other allowed arguments select `launch`. This avoids interpreting flag values or prompts as subcommands.

  This is the complete GREEN implementation: public `exec` re-enters the scope as `inner-exec`, which then calls `execute_scoped_command(arguments, False)` directly; scoped OMP validates/builds `(command, requested_model)` and passes both to readiness; unconfined calls the fixed `always-ask` `execv` path only after confirmation.

  Catch `SandboxError` only at `if __name__ == "__main__"`; every raise site uses the exact format `"<invariant failed>; <safe recovery action>"`, and the handler prints `omp sandbox: ` plus that message to stderr and exits 2. Gateway errors never include bearer or body. Do not retry with fewer mounts, inherited environment, direct upstream OMP, or absent scope.

  Only after the focused check is GREEN, extend Task 1's Linux `perSystem` body:

  ```nix
  packages.omp-sandbox = sandbox.package;
  apps.omp-sandbox-exec = {
    type = "app";
    program = "${sandbox.package}/bin/omp-sandbox-exec";
  };
  apps.omp-sandbox-acceptance = {
    type = "app";
    program = "${sandbox.package}/bin/omp-sandbox-acceptance";
  };
  ```

  Bind `sandbox = sandboxFor pkgs` once in that `perSystem` body and keep `checks.omp-sandbox = sandbox.check`. This is the first step that exposes or builds the public wrappers; their complete dispatch now exists.

  Run:

  ```sh
  nix build .#checks.x86_64-linux.omp-sandbox --no-link
  ```

  Expected: every focused test passes, including controlled trusted-user omission and cleanup/resource assertions.

- [ ] **Step 7: Exercise the real generated executor**

  Run only the checked-in real-boundary modes; they own their temporary repositories, randomized hostile environment, inherited descriptor, sentinel commands, and ownership-checked per-project-state cleanup:

  ```sh
  nix build .#omp-sandbox --no-link
  nix run .#omp-sandbox-acceptance -- filesystem
  nix run .#omp-sandbox-acceptance -- linked-worktree
  nix run .#omp-sandbox-acceptance -- scope
  nix run .#omp-sandbox-acceptance -- cleanup
  nix run .#omp-sandbox-acceptance -- unconfined
  ```

  Expected: each prints its one `PASS` line. `filesystem` exercises public `omp` and the raw executor from a subdirectory, selected-project create/read/edit/execute/rename/delete, unrelated/path/symlink read and attempted-write denials, randomized secret/Git/Nix environment removal, passwd-home credential and control-socket absence, `/etc/nixos` absence, fresh `/proc`, inherited-FD closure under the asserted Yama policy, locale/timezone, browser/LSP/network, and required untrusted daemon access. `linked-worktree` proves exact JSON-escaped path confirmation, pre/post-answer path stability, and fail-closed headless behavior. `scope` proves cgroup properties and collection. `cleanup` kills a TERM-resistant packaged executor tree and proves its cgroup PIDs and scope disappear. `unconfined` proves no-tty rejection plus literal `no` and `yes` PTY paths.

**Logical commit point:** complete fail-closed project executor, explicit Nix-trust gate, scoped yolo command, and confirmed unconfined command.

### Task 3: Add Linux auth broker/gateway services and isolated project state

**Files:**

- Modify: `modules/programs/oh-my-pi/oh-my-pi.nix`
- Modify: `modules/programs/oh-my-pi/sandbox/test_launcher.py`

**Interfaces:**

- Consumes: the absolute Task 1 `upstreamOmp`; existing host `~/.omp/agent/agent.db`; OMP-created runtime token files `~/.omp/auth-broker.token` and `~/.omp/auth-gateway.token`.
- Produces: `systemd.user.services.omp-auth-broker` at `127.0.0.1:8765` and `omp-auth-gateway` at `127.0.0.1:4000`; scoped clients receive only the gateway bearer and override-only `openai-codex` pi-native config.
- State split: host services use real `~/.omp`; sandbox state uses `~/.local/state/omp-sandbox/projects/` plus the lowercase SHA-256 of the canonical root, mounted at `/home/omp/.omp`. These trees are never shared.

- [ ] **Step 1: Add failing Home Manager service evals**

  Add targeted assertions for both Linux homes and Darwin:

  ```sh
  nix eval --json '.#homeConfigurations."jakeneau@redwood".config.systemd.user.services' \
    --apply 's: { broker = s.omp-auth-broker; gateway = s.omp-auth-gateway; }'
  nix eval --json '.#homeConfigurations."jakeneau@spruce".config.systemd.user.services' \
    --apply 's: { broker = s.omp-auth-broker; gateway = s.omp-auth-gateway; }'
  nix eval --json '.#homeConfigurations."jakeneau@aspen".config.systemd.user.services' \
    --apply 's: { broker = builtins.hasAttr "omp-auth-broker" s; gateway = builtins.hasAttr "omp-auth-gateway" s; }'
  nix eval --impure --expr '
    let
      flake = builtins.getFlake ("git+file://" + toString ./.);
      pkgs = flake.homeConfigurations."jakeneau@redwood".pkgs;
      home = flake.inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          flake.modules.homeManager.oh-my-pi-config
          {
            home.username = "probe";
            home.homeDirectory = "/home/probe";
            home.stateVersion = "25.05";
          }
        ];
      };
    in assert builtins.attrNames home.config.systemd.user.services == []; true'
  ```

  Expected before implementation: Linux attribute-missing failure; Aspen remains `{"broker":false,"gateway":false}`.

- [ ] **Step 2: Declare the hardened services in the existing Home Manager config**

  Add `config` to the existing config-module arguments. In its `let`, reuse Task 1's outer function and define:

  ```nix
  upstreamOmp = upstreamOmpFor pkgs;
  sandboxPackage = (sandboxFor pkgs).package;
  ompEnabled =
    lib.attrByPath ["programs" "oh-my-pi" "enable"] false config;
  mkAuthService = {
    description,
    execStart,
    after ? [],
    wants ? [],
    environment ? [],
  }: {
    Unit = {
      Description = description;
      After = after;
      Wants = wants;
    };
    Service = {
      Type = "simple";
      ExecStart = execStart;
      Environment = [
        "HOME=${config.home.homeDirectory}"
        "PI_CONFIG_DIR=.omp"
        "PI_CODING_AGENT_DIR=${config.home.homeDirectory}/.omp/agent"
      ] ++ environment;
      UnsetEnvironment = [
        "OMP_PROFILE"
        "PI_PROFILE"
        "XDG_CONFIG_HOME"
        "XDG_DATA_HOME"
        "XDG_STATE_HOME"
        "XDG_CACHE_HOME"
        "OMP_AUTH_BROKER_TOKEN"
      ];
      WorkingDirectory = config.home.homeDirectory;
      Restart = "on-failure";
      RestartSec = "2s";
      TimeoutStopSec = "30s";
      UMask = "0077";
      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      ReadWritePaths = ["${config.home.homeDirectory}/.omp"];
      CapabilityBoundingSet = "";
      LockPersonality = true;
      ProtectControlGroups = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
    };
    Install.WantedBy = ["default.target"];
  };
  ```

  Merge this exact Linux-only content with the existing `home.file` and activation content:

  ```nix
  systemd.user.services = lib.mkIf
    (pkgs.stdenv.isLinux && ompEnabled) {
      omp-auth-broker = mkAuthService {
        description = "OMP host credential broker";
        execStart =
          "${lib.getExe upstreamOmp} auth-broker serve --bind=127.0.0.1:8765";
      };
      omp-auth-gateway = mkAuthService {
        description = "OMP loopback model gateway";
        after = ["omp-auth-broker.service"];
        wants = ["omp-auth-broker.service"];
        execStart = "${sandboxPackage}/bin/omp-auth-gateway-service";
        environment = [
          "OMP_AUTH_BROKER_URL=http://127.0.0.1:8765"
        ];
      };
    };
  ```

  Do not add socket units: OMP 17 opens its own listeners and has no `LISTEN_FDS` path. Do not materialize either bearer in Nix or unit text. Systemd removes manager-supplied profile/config/XDG/broker overrides, then applies the pinned `Environment`; the gateway wrapper reads the runtime broker token after start and exports it only into the gateway process, overriding any mutable `auth.broker.token`. `Restart=on-failure` retries until the initial snapshot succeeds.

- [ ] **Step 3: Verify service definitions and gateway-only client configuration**

  Repeat the four evals. Expected:

  - Redwood and spruce have capitalized `Unit`/`Service`/`Install`, absolute upstream/wrapper store `ExecStart`, exact loopback binds, gateway `After`/`Wants`, pinned HOME/config/agent paths, the complete unset list, restart, hardening, and no bearer value.
  - Aspen reports both false.
  - The config-only module returns an empty service-name list instead of failing on an absent enable option.
  - Task 1 asset test still proves only the `openai-codex` override, no discovery, and no broker/provider credential.

  `TrustEnvironmentAndMountTests.test_environment_is_allowlisted_and_git_settings_are_command_scope` constructs the hostile host mapping and proves no authentication key enters the sandbox launch environment. The gateway bearer is available only through the pinned mode-0600 runtime file consumed by OMP's immutable command-resolved API-key setting; the acceptance harness scans readable live process metadata and proves a real Bash tool child inherits neither the value nor its former variable name. Run `nix run .#omp-sandbox-acceptance -- state`: its first executor launch writes `tools.approvalMode: always-ask` to project `config.yml`, its second reads the same value, and its real scoped `--print` request then creates `precedence.txt` through Bash without a prompt, proving explicit runtime yolo remains highest precedence.

  Make those expectations executable after GREEN:

  ```sh
  nix eval --impure --expr '
    let
      f = builtins.getFlake ("git+file://" + toString ./.);
      check = name:
        let
          c = f.homeConfigurations.${name}.config;
          b = c.systemd.user.services.omp-auth-broker;
          g = c.systemd.user.services.omp-auth-gateway;
          baseEnvironment = [
            "HOME=/home/jakeneau" "PI_CONFIG_DIR=.omp"
            "PI_CODING_AGENT_DIR=/home/jakeneau/.omp/agent"
          ];
          common = s: expectedEnvironment:
            assert builtins.attrNames s == [ "Install" "Service" "Unit" ];
            assert s.Install.WantedBy == [ "default.target" ];
            assert s.Service.Type == "simple";
            assert s.Service.Environment == expectedEnvironment;
            assert s.Service.UnsetEnvironment == [
              "OMP_PROFILE" "PI_PROFILE" "XDG_CONFIG_HOME" "XDG_DATA_HOME"
              "XDG_STATE_HOME" "XDG_CACHE_HOME" "OMP_AUTH_BROKER_TOKEN"
            ];
            assert s.Service.Restart == "on-failure" && s.Service.RestartSec == "2s";
            assert s.Service.TimeoutStopSec == "30s" && s.Service.UMask == "0077";
            assert s.Service.WorkingDirectory == "/home/jakeneau";
            assert s.Service.ReadWritePaths == [ "/home/jakeneau/.omp" ];
            assert s.Service.CapabilityBoundingSet == "";
            assert s.Service.NoNewPrivileges && s.Service.PrivateTmp
              && s.Service.PrivateDevices && s.Service.LockPersonality
              && s.Service.ProtectControlGroups && s.Service.ProtectKernelLogs
              && s.Service.ProtectKernelModules && s.Service.ProtectKernelTunables
              && s.Service.RestrictNamespaces && s.Service.RestrictRealtime
              && s.Service.RestrictSUIDSGID;
            assert s.Service.ProtectSystem == "strict"
              && s.Service.ProtectHome == "read-only";
            assert s.Service.RestrictAddressFamilies == [ "AF_UNIX" "AF_INET" "AF_INET6" ];
            assert s.Service.SystemCallArchitectures == "native";
            true;
        in
          assert common b baseEnvironment;
          assert common g (baseEnvironment ++ [ "OMP_AUTH_BROKER_URL=http://127.0.0.1:8765" ]);
          assert b.Unit.Description == "OMP host credential broker";
          assert b.Unit.After == [] && b.Unit.Wants == [];
          assert g.Unit.Description == "OMP loopback model gateway";
          assert g.Unit.After == [ "omp-auth-broker.service" ];
          assert g.Unit.Wants == [ "omp-auth-broker.service" ];
          assert builtins.length b.Service.ExecStart == 1;
          assert builtins.match "/nix/store/.*omp.*/bin/omp auth-broker serve --bind=127.0.0.1:8765" (builtins.head b.Service.ExecStart) != null;
          assert builtins.length g.Service.ExecStart == 1;
          assert builtins.match "/nix/store/.*omp-auth-gateway-service" (builtins.head g.Service.ExecStart) != null;
          assert builtins.all
            (value: builtins.match ".*BEARER.*" value == null)
            (b.Service.Environment ++ g.Service.Environment);
          true;
      aspen = f.homeConfigurations."jakeneau@aspen".config.systemd.user.services;
    in
      assert check "jakeneau@redwood";
      assert check "jakeneau@spruce";
      assert !builtins.hasAttr "omp-auth-broker" aspen;
      assert !builtins.hasAttr "omp-auth-gateway" aspen;
      true'
  ```

  Expected: `true`. Any wrong value or forbidden bearer makes evaluation fail.

- [ ] **Step 4: Perform a non-activating gateway protocol smoke test**

  The package's checked-in `omp-sandbox-acceptance gateway` mode performs this probe without activation. It first attempts authenticated readiness against an already-running pair. If neither port is listening, it resolves the packaged upstream executable, starts broker and gateway in new temporary process groups with `env -i`, passwd-derived `HOME`, `PI_CONFIG_DIR=.omp`, fixed `PI_CODING_AGENT_DIR`, and the runtime broker token read/exported by `omp-auth-gateway-service`; waits at most ten seconds; and kills both groups in `finally`. If exactly one port is occupied, it aborts instead of mixing service sets.

  Run:

  ```sh
  nix run .#omp-sandbox-acceptance -- gateway
  ```

  Expected: authenticated `/v1/models` returns 200 with at least one `owned_by: openai-codex` entry; a second request with a fixed wrong bearer returns 401; no bearer appears in stdout/stderr/process argv. The probe never uses `/healthz`. Adding a provider requires restarting the gateway so its initial broker snapshot is rebuilt.

**Logical commit point:** per-user Linux credential services, authenticated pi-native gateway, and provably separate host/project state.

### Task 4: Wire Linux delivery while preserving Darwin and safe ACP

**Files:**

- Modify: `modules/programs/oh-my-pi/oh-my-pi.nix`
- Modify: `modules/programs/nvf/nvf.nix`
- Modify: `modules/programs/oh-my-pi/sandbox/test_launcher.py`

**Interfaces:**

- Consumes: Task 1 `sandbox.package`; Task 2 canonical host-path alias; Task 3 gateway.
- Produces: PATH-visible Linux `omp` wrapper, `omp-unconfined`, and executor; unchanged Darwin upstream `omp`; CodeCompanion command `{ "omp", "acp" }` on both platforms; empty client capabilities only on Linux.
- ACP invariant: on Linux the process starts noninteractively in an ordinary repository, the host absolute cwd resolves only to the same mounted project, and no tool can delegate host filesystem/process execution to Neovim. Aspen retains its existing upstream/always-ask ACP bridge behavior.

- [ ] **Step 1: Add failing platform and ACP regression evals**

  Run two behavior-specific assertions against the unchanged candidate checkout:

  ```sh
  nix eval --impure --expr '
    let
      f = builtins.getFlake ("git+file://" + toString ./.);
      packages = f.homeConfigurations."jakeneau@redwood".config.home.packages;
      names = map (p: p.name) packages;
    in
      assert builtins.length
        (builtins.filter (name: name == "omp-sandbox-launcher") names) == 1;
      true'
  nix eval --impure --expr '
    let
      f = builtins.getFlake ("git+file://" + toString ./.);
      lib = f.inputs.nixpkgs.lib;
      lua = f.homeConfigurations."jakeneau@redwood".config.programs.nvf.settings.vim.lazy.plugins."codecompanion.nvim".setupOpts.adapters.acp.omp.expr;
    in
      assert lib.hasInfix
        "adapter.parameters.clientCapabilities = vim.empty_dict()" lua;
      true'
  ```

  Expected RED: the first command fails because Redwood lacks `omp-sandbox-launcher`; the second fails because Linux ACP still advertises inherited filesystem capabilities. An unrelated evaluation failure is not RED and must be fixed before implementation.

- [ ] **Step 2: Select the package at the existing declaration seam**

  Reuse Task 1's outer `upstreamOmpFor` and `sandboxFor` definitions; do not introduce a second factory or package convention.

  Replace only the package expression:

  ```nix
  packages = pkgs: [
    (if pkgs.stdenv.isLinux
     then (sandboxFor pkgs).package
     else upstreamOmpFor pkgs)
  ];
  ```

  Do not change `install.linux`, `install.macos`, `hasEnableOption`, the user declarations, generator, or `flake.nix`.

- [ ] **Step 3: Disable ACP client host capabilities after extension**

  Replace the adapter function with this exact Nix-generated Lua:

  ```nix
  adapters.acp.omp = lib.generators.mkLuaInline ''
    function()
      local adapter = require("codecompanion.adapters").extend("claude_code", {
        name = "omp",
        formatted_name = "oh-my-pi",
        commands = {
          default = { "omp", "acp" },
          yolo = { "omp", "acp" },
        },
        handlers = {
          auth = function() return true end,
        },
      })
      ${lib.optionalString pkgs.stdenv.isLinux "adapter.parameters.clientCapabilities = vim.empty_dict()"}
      return adapter
    end
  '';
  ```

  Update the adjacent comment: Linux ACP is transport/UI only; all filesystem/process tools stay in the sandbox. The stripped bridge means Linux ACP no longer sees unsaved-buffer contents or applies editor-side external-file updates; save files before asking OMP to read them and reload changed buffers through normal Neovim behavior. Do not express a plain empty table or an `extend()` override: deep merge retains inherited filesystem keys and `{}` JSON-encodes as `[]`. `vim.empty_dict()` is required for Linux; the `optionalString` is required so Aspen retains its inherited bridge.

- [ ] **Step 4: Prove platform and adapter preservation**

  Repeat the evals. Expected:

  - Redwood package list includes `omp-sandbox-launcher`.
  - Aspen remains exactly `omp-17.0.0`, has no broker/gateway units, its activation DAG still contains `ompConfigPolicy`, and its Lua has no `vim.empty_dict()` assignment.
  - Redwood ACP Lua contains both `{ "omp", "acp" }` arrays, assigns `vim.empty_dict()` after `extend`, and retains the auth handler.
  - Source review confirms the untouched `configPolicy` remains `tools.approvalMode = "always-ask"` and the immutable AGENTS/RULES/skills/agents/extensions/MCP source counts remain unchanged.

  Rerun the complete assertion expression; do not treat printed Lua/JSON as proof:

  ```sh
  nix eval --impure --expr '
    let
      f = builtins.getFlake ("git+file://" + toString ./.);
      lib = f.inputs.nixpkgs.lib;
      redwood = f.homeConfigurations."jakeneau@redwood".config;
      aspen = f.homeConfigurations."jakeneau@aspen".config;
      packageNames = c: map (p: p.name) c.home.packages;
      redLua = redwood.programs.nvf.settings.vim.lazy.plugins."codecompanion.nvim".setupOpts.adapters.acp.omp.expr;
      aspenLua = aspen.programs.nvf.settings.vim.lazy.plugins."codecompanion.nvim".setupOpts.adapters.acp.omp.expr;
    in
      assert builtins.length (builtins.filter (n: n == "omp-sandbox-launcher") (packageNames redwood)) == 1;
      assert builtins.length (builtins.filter (n: n == "omp-17.0.0") (packageNames aspen)) == 1;
      assert builtins.hasAttr "ompConfigPolicy" aspen.home.activation;
      assert !builtins.hasAttr "omp-auth-broker" aspen.systemd.user.services;
      assert !builtins.hasAttr "omp-auth-gateway" aspen.systemd.user.services;
      assert lib.hasInfix "default = { \"omp\", \"acp\" }" redLua;
      assert lib.hasInfix "yolo = { \"omp\", \"acp\" }" redLua;
      assert lib.hasInfix "auth = function() return true end" redLua;
      assert lib.hasInfix "adapter.parameters.clientCapabilities = vim.empty_dict()" redLua;
      assert !(lib.hasInfix "vim.empty_dict()" aspenLua);
      true'
  ```

  Expected: `true`; each preservation error aborts evaluation.

- [ ] **Step 5: Smoke-test ordinary-repository ACP without host capabilities**

  From a temporary ordinary repository, start the built Linux `omp acp` through a small standard-library Python ACP probe. Send `initialize` with `clientCapabilities: {}` and `session/new` with the canonical host repository cwd; assert both responses arrive, the session cwd is accepted, and stderr contains no linked-worktree prompt. Then require one terminal outcome for every `toolCallId`: the exact in-project read/write/edit/Bash calls complete, while the exact outside-path read fails. Verify the final completed Bash ID has the requested raw command and that observable files/processes stay inside the selected repository/namespace. Inspect the Redwood CodeCompanion adapter object under headless Neovim and assert:

  ```lua
  assert(vim.json.encode(adapter.parameters.clientCapabilities) == "{}")
  assert(vim.deep_equal(adapter.commands.default, { "omp", "acp" }))
  ```

  Run the actual configured Linux adapter under its built Neovim:

  ```sh
  nvim_package="$(nix build --no-link --print-out-paths '.#homeConfigurations."jakeneau@redwood".config.programs.nvf.finalPackage')"
  "$nvim_package/bin/nvim" --headless \
    '+lua local a=require("codecompanion.adapters").resolve("omp"); assert(vim.json.encode(a.parameters.clientCapabilities)=="{}"); assert(vim.deep_equal(a.commands.default,{"omp","acp"}))' \
    +qa
  ```

  Expected: exit 0. This realizes the editor before proving the generated Lua is a JSON object in the actual CodeCompanion runtime; the checked-in `acp` mode separately performs the real OMP initialize/session/tool exchange.

  Aspen is `aarch64-darwin`, and Redwood has no Darwin builder. Keep the proof on the exact candidate checkout by evaluating both Darwin derivations locally; combine these with Step 4's candidate-source Lua/package/service assertions rather than inspecting Aspen's independent checkout:

  ```sh
  nix eval --raw '.#homeConfigurations."jakeneau@aspen".config.programs.nvf.finalPackage.drvPath'
  nix eval --raw '.#homeConfigurations."jakeneau@aspen".activationPackage.drvPath'
  ```

  Expected: two `aarch64-darwin` derivation paths and exit 0. This proves candidate-source Darwin evaluation and preservation without pretending the Linux host can execute or build Darwin artifacts. For a real linked worktree, absence of `/dev/tty` must abort Linux ACP before OMP; with a trusted pty and `yes`, the same ACP probe succeeds.

**Logical commit point:** Linux-only delivery, Darwin preservation, and ACP compatibility without a client-side sandbox escape.

### Task 5: Document and verify end to end

**Files:**

- Modify: `docs/reference/oh-my-pi.md`
- Modify: `docs/explanation/coding-agents.md`
- Create: `docs/how-to/use-scoped-omp.md`
- Modify: `docs/README.md`
- Delete after all gates: `specs/omp-sandbox.md`

**Interfaces:**

- Consumes: final launcher/service/package/ACP behavior from Tasks 1-4.
- Produces: durable reference mechanics, explanation rationale, task workflow, targeted verification evidence, and retirement of this transient spec.

- [ ] **Step 1: Run the complete real-boundary behavioral matrix**


  Run the checked-in modes rather than reimplementing fixtures at the terminal:

  ```sh
  nix run .#omp-sandbox-acceptance -- filesystem
  nix run .#omp-sandbox-acceptance -- linked-worktree
  nix run .#omp-sandbox-acceptance -- gateway
  nix run .#omp-sandbox-acceptance -- scope
  nix run .#omp-sandbox-acceptance -- cleanup
  nix run .#omp-sandbox-acceptance -- state
  nix run .#omp-sandbox-acceptance -- model
  nix run .#omp-sandbox-acceptance -- acp
  nix run .#omp-sandbox-acceptance -- unconfined
  ```

  Expected: each prints exactly one corresponding `PASS` line and exits 0. The focused unit check supplies controlled path/state/token/gateway-down/trusted-user/CLI failure injection that cannot safely be induced on the live account; the Task 3/4 evals prove service/Darwin shape. Together, not either alone, they cover all twelve rows.
  The nine real modes plus the focused unit and platform/headless gates provide these recorded observations:

  1. create/read/edit/execute/rename/delete under the selected project;
  2. deny unrelated repository, passwd-home files, representative SSH/GPG/Age/SOPS/cloud/Kubernetes credentials, `/etc/nixos` when unselected, and an escaping symlink;
  3. expose `/nix/store`, curated/profile-resolved CLI tools, local Git metadata, DNS/HTTPS, headless browser startup, and LSP startup; prove a daemon-backed build only when the system-effective trusted-user parser permits the socket, otherwise prove the socket is absent and a build cannot escape to the daemon;
  4. deny host processes, `/run/user/$UID`, D-Bus, agent, portal, Docker/Podman, journal, and systemd sockets;
  5. preserve subdirectory cwd and the ACP canonical-path alias without exposing alias parents;
  6. abort outside Git and on path/state validation errors without starting the probe command;
  7. make a real linked worktree and sibling; prove exact metadata prompt, `no` rejection, `yes` success, and denial of parent/sibling content;
  8. prove `omp-unconfined` rejects no tty/EOF/non-`yes`, accepts literal `yes`, and executes upstream with explicit `always-ask`;
  9. kill a long-running executor, then prove no descendants remain; the focused argv test must prove exact `TasksMax=2048`, `MemoryHigh=75%`, and `MemoryMax=90%` inputs, while the live scope query proves the task limit, both resolved memory limits, and unquotaed CPU take effect; separately verify/document that disk use is not capped for the writable project/state or daemon-owned `/nix/store`;
  10. prove trusted-user-dependent daemon access at the real boundary and controlled allowed/trusted/malformed parser cases in the focused test;
  11. prove gateway bearer success, wrong-bearer 401, gateway-down failure before OMP, qualified `openai-codex` pi-native request success, no provider SDK/API-key environment, and no broker/host credential fallback;
  12. prove a print-mode scoped OMP model request can invoke Bash without approval, prove Redwood CodeCompanion ACP initialize advertises no filesystem/terminal capability and session cwd succeeds, prove its read/write/edit/Bash stay inside Bubblewrap, and prove Aspen retains its inherited ACP bridge.

  Every entrypoint-level fail-closed probe uses a file/command or unique upstream-output sentinel to prove the protected command did not run. Leaf parser/validator unit tests do not make that broader claim. Do not treat printed Bubblewrap argv as behavioral proof.

- [ ] **Step 2: Check the flake, build Linux, and evaluate Darwin**

  Run:
  ```sh
  nix flake check
  nix build .#checks.x86_64-linux.omp-sandbox --no-link
  nix build .#omp-sandbox --no-link
  nix build '.#homeConfigurations."jakeneau@redwood".activationPackage' --no-link
  nix build '.#homeConfigurations."jakeneau@spruce".activationPackage' --no-link
  nix eval --raw '.#homeConfigurations."jakeneau@aspen".activationPackage.drvPath'
  nix build .#nixosConfigurations.redwood.config.system.build.toplevel --no-link
  nix build .#nixosConfigurations.spruce.config.system.build.toplevel --no-link
  ```

  Expected: the flake check, every Linux build, and the local Aspen cross-system evaluation exit 0. These commands build/evaluate derivations only; they do not activate a system/home or update inputs.

- [ ] **Step 3: Update the OMP reference**

  In `docs/reference/oh-my-pi.md`, replace the unconditional-package description with a platform table and add exact sections for:

  - package factory and the three executable contracts;
  - immutable settings/models/agent assets;
  - canonical worktree, linked metadata, ACP alias, writable/read-only/absent mounts;
  - environment/process/systemd resource policy, including unquotaed CPU and disk;
  - sterile Nix trust query and socket decision;
  - per-project state hash/layout versus host state;
  - broker/gateway units, ports, dependencies, token ownership, readiness, pi-native qualified-model routing, and no fallback;
  - Linux CodeCompanion empty client capability requirement and its unsaved-buffer/external-file-change trade-off;
  - Darwin upstream/always-ask/inherited-ACP preservation;
  - the exact failure table and targeted eval/build commands.

  Keep the existing numtide cache and unconfined config-policy material accurate. State the full-store read exception, daemon-builder resource exception, unquotaed CPU, and uncapped project/state/store disk use explicitly.

- [ ] **Step 4: Update the explanation and add the how-to**

  In `docs/explanation/coding-agents.md`, replace the stale Linux ACP claim that edits route through client permission with the actual boundary: ACP carries chat/UI, while empty Linux client capabilities force tools into Bubblewrap. Explain the loss of unsaved-buffer reads and editor-applied external changes on Linux and state that Aspen retains its inherited bridge. Add why scoped yolo moves approval below OMP, why Bubblewrap plus systemd was chosen over rootless Podman/microVM, and the accepted project/network/full-store/Nix-daemon/CPU/disk risks.

  Create flat `docs/how-to/use-scoped-omp.md` with executable recipes for:

  - run `omp` from a repository or subdirectory;
  - interpret/confirm or reject linked-worktree metadata;
  - use CodeCompanion in an ordinary repository and understand linked-worktree tty failure;
  - run and confirm `omp-unconfined`;
  - recover from outside-Git, gateway, immutable config, state permission, scope/Bubblewrap, and trusted-Nix warnings;
  - understand what is and is not protected, including outbound data exposure, LAN reachability, full-store readability, and daemon builders outside scope.

  Add the page under the existing flat how-to listing in `docs/README.md`; do not create a one-page subfolder or a duplicate explanation page.

- [ ] **Step 5: Review documentation against observed behavior**

  Compare every reference statement and how-to command with Tasks 1-4 code and Step 1 evidence. Any discrepancy is fixed in code or docs before proceeding. The reference owns exact mechanics, the explanation owns rationale/trade-offs, and the how-to owns user actions; do not duplicate whole sections across quadrants.

- [ ] **Step 6: Final focused review and spec retirement**

  Run a final code review over `_sandbox-package.nix`, `launcher.py`, its tests, `oh-my-pi.nix`, `nvf.nix`, and the three docs surfaces. Require a clean verdict on path races, environment poisoning, linked worktrees/alternates, token leakage, ACP client capabilities, CLI precedence, user-scope cleanup, Nix trust parsing, platform gating, and test authenticity. Any edit from this review invalidates prior evidence: restart at the earliest affected Task 5 step, rerun that step and every downstream gate through this review, and repeat until a complete pass observes one unchanged checkout.

  Only after the behavioral matrix, flake check, targeted dry-builds, docs review, and code review are clean, delete `specs/omp-sandbox.md`. If any gate remains unproven, retain the spec and report that exact gate instead of retiring rationale early.

**Logical commit point:** verified end-to-end behavior, durable Diátaxis documentation, and consumed-spec retirement.
