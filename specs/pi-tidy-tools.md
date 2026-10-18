## Spec

Replace the `minimal-transcript` extension and its Pi patch with the
third-party `pi-tidy-tools` extension. Nix installs the extension and its
settings declaratively.

### Purpose

The minimal transcript hides too much content and has bugs. It hides tool
calls, tool results, intermediate assistant messages, and custom entries from
other extensions.

`pi-tidy-tools` compacts tool rows instead of hiding them. Each row states the
agent's goal for the call, the target, and a result summary. For an edit, the
summary is a `+adds/-dels` count. The full output and diff remain one
expansion away.

### Scope

- Remove the `minimal-transcript` extension, its Pi patch, its checks, and its
  home entry point.
- Remove the activity-line rule from the global Pi agent instructions.
- Add `pi-tidy-tools` as a non-flake input. Build it with Nix and install a
  store-backed entry point.
- Declare the `pi-tidy-tools` settings and Pi's `hideThinkingBlock` setting.
  Apply them on each home activation.
- Update the Pi documentation.

### Behavior

After the change, an interactive Pi session behaves as follows:

1. The transcript shows user prompts, all assistant text, and tool rows.
2. A tool row for `read`, `write`, `edit`, `bash`, `grep`, `find`, or `ls` uses
   the `default` layout:
   - Line 1 shows the tool and the agent's goal for the call.
   - Line 2 shows the target and a result summary.
3. An `edit` row shows `+adds/-dels`. A text `write` row shows a line count.
4. `Alt+O` (`app.tools.expand`) expands every tool row. An expanded `edit` row
   shows a colored diff with line numbers.
5. `/diff` shows the colored diffs of the previous turn's successful `edit` and
   `write` calls, including new files and overwrites.
6. Each `codemode` script starts with a `// @reasoning: <goal>` line. The row
   shows that goal. A nested model call writes a one-sentence summary of the
   finished script. The main model never sees that summary.
7. MCP tools and tools from other extensions keep Pi's default rendering.
8. Pi hides thinking blocks.
9. `/tidy` commands change settings for the current session. The next home
   activation restores the declared values.

### Constraints

- Install everything declaratively. Do not use `pi install`, manual edits to
  settings files, or `/tidy pi-fff setup`.
- Do not hand-edit `flake.nix`. Declare the input in `flake-file.inputs` and run
  `nix run .#write-flake`.
- Do not include physical copies of libraries that Pi supplies:
  `@earendil-works/*` and `typebox`.
- Do not run `nix flake update`, `hr`, `nr`, or `nrr`.

### Non-goals

- No replacement for the `minimal-transcript` diff entries. Old sessions keep
  their `minimal-transcript-diff` entries, but Pi no longer renders them.
- No grouping of consecutive tool calls.
- No `pi-fff` integration.
- No change to the `Ctrl+Shift+O` conflict between `/diff` and
  `app.tree.filter.cycleBackward`. Use the `/diff` command.

### Acceptance criteria

- `nix flake check` passes.
- The `jakeneau` home builds on `redwood` and evaluates on every other host
  that declares that user.
- No file under `modules/` or `docs/` refers to `minimal-transcript`, except a
  statement that old diff entries no longer render.
- The `pi-third-party-extensions` check loads `pi-tidy-tools` and finds its
  `tidy` and `diff` commands.
- The `pi-fish-shell` check covers both new actions.
- The manual checks in the final task pass.

## Plan

### Verified facts

- `mkPiPackage` in `modules/programs/pi/pi.nix` overrides the llm-agents Pi
  package. It adds `patches/minimal-transcript.patch`, adds `pkgs.makeWrapper`,
  and runs `patches/minimal-transcript.test.mjs` and the `ask-user` tests in
  `preInstall`. Its `postFixup` wraps `pi` with `PI_MINIMAL_TRANSCRIPT=1`.
- `minimalTranscriptSource`, `mkPiMinimalTranscriptCheck`, the
  `pi-minimal-transcript` entry in `perSystem.checks`, and the
  `.pi/agent/extensions/minimal-transcript/index.ts` entry in `fixedHomeFiles`
  are the only other `pi.nix` references.
- `modules/programs/pi/config/AGENTS.md` ends with the activity-line paragraph.
  Only the minimal-transcript status row reads that line.
- The `workflow-review` entry has its own renderer in
  `extensions/workflows/index.ts`. Pi shows proposals without the patch.
- `mkPiSettingsUpdater` (`pi-settings-update`) selects a jq filter by action.
  It refuses symbolic links and non-regular files. It fails on malformed JSON
  without a write. It keeps the file mode and skips unchanged writes. It
  creates a missing file with mode 600.
- The `pi-fish-shell` check (`mkPiFishShellCheck`) tests every updater action.
- `mkPiThirdPartyExtensionsCheck` writes one re-export per extension. It loads
  all of them in one RPC `get_commands` call and greps for command names. It
  also asserts that `@earendil-works` and `typebox` are absent from
  `node_modules`.
- `.pi/agent/keybindings.json` binds `app.tools.expand` to `alt+o`.
- Upstream facts from the specification, not rechecked here:
  - The npm package is `@mobrienv/pi-tidy-tools` 0.5.4.
  - The source is the `packages/pi-tidy-tools` workspace of
    `github:mikeyobrien/pi-tidy-tools`. The repository root holds the
    `package-lock.json`.
  - The entry point is `index.ts`, and `semver` is the only runtime
    dependency.
  - `prepack` runs `node ../../scripts/bundle-core.mjs .`.
  - The extension reads `~/.pi/agent/pi-tidy-tools.json` and saves it by an
    atomic rename.

### Design decisions

1. **Source:** Add a non-flake `github:mikeyobrien/pi-tidy-tools` input. It
   tracks the default branch like the other extension inputs. The root
   lockfile pins `semver`.
2. **Build:** Use `buildNpmPackage` in workspace mode. Run `prepack` as the
   build script. Pass `--ignore-scripts` to the install hook's `npm pack`, so
   that pack lifecycle scripts cannot delete the bundle before the copy.
3. **Fallback:** Use the fallback only if `importNpmLock` rejects the workspace
   lockfile or `bundle-core.mjs` fails in the sandbox. Replace the input with
   the npm tarball
   `https://registry.npmjs.org/@mobrienv/pi-tidy-tools/-/pi-tidy-tools-0.5.4.tgz`.
   Add a second tarball input for `semver` at the newest version that
   satisfies the package's range. `mkPiTidyTools` then becomes a `runCommand`
   that copies the tarball and places `semver` in `node_modules/semver`. This
   keeps the `pi-usage-limits` precedent: a release requires a URL change.
   Record the fallback in the documentation if it is used.
4. **Settings:** Activation merges the declared keys into the live files. A
   Home Manager link would fail after the first `/tidy` save. The extension's
   rename replaces the link with a regular file, and Home Manager then refuses
   to overwrite that file.
5. **Declared values:**
   - `pi-tidy-tools.json`: `enabled = true`, `mode = "default"`,
     `icons = true`, `outputReasoning = true`. Spec behavior 9 needs
     `enabled`. Without that key, `/tidy` could disable the extension across
     activations.
   - `settings.json`: `hideThinkingBlock = true`.
   - Leave `outputReasoningModel` undeclared, so that the extension uses its
     default model.
6. **Keybindings:** Make no change.

### `modules/programs/pi/pi.nix`

- `mkPiPackage`: keep `overrideAttrs` with only the `ask-user` lines in
  `preInstall`. Remove `patches`, the `nativeBuildInputs` addition, the
  `minimal-transcript.test.mjs` line, and `postFixup`.
- Remove `minimalTranscriptSource`, `mkPiMinimalTranscriptCheck`,
  `pi-minimal-transcript` in `perSystem.checks`, and the `minimal-transcript`
  entry in `fixedHomeFiles`.
- Add `mkPiTidyTools` after `mkPiAgentBrowserNative`:
  - `pname = "pi-tidy-tools"`.
  - `version = npmVersion (inputs.pi-tidy-tools + "/packages/pi-tidy-tools")`.
  - `src = inputs.pi-tidy-tools`.
  - `npmDeps = pkgs.importNpmLock { npmRoot = inputs.pi-tidy-tools; }`.
  - `npmConfigHook = pkgs.importNpmLock.npmConfigHook`.
  - `npmWorkspace = "packages/pi-tidy-tools"`.
  - `npmBuildScript = "prepack"`.
  - `npmPackFlags = [ "--ignore-scripts" ]`.
  - In `postInstall`, set
    `root="$out/lib/node_modules/@mobrienv/pi-tidy-tools"`.
  - Then run `rm -rf "$root/node_modules"/{@earendil-works,typebox}`.
  - Then run `find "$root/node_modules" -xtype l -delete`. This removes the
    copied workspace links, which point outside the output.
- Add
  `pi-tidy-tools-root = "${mkPiTidyTools pkgs}/lib/node_modules/@mobrienv/pi-tidy-tools"`
  to the `config` `let` block.
- Add the `.pi/agent/extensions/pi-tidy-tools/index.ts` entry to
  `fixedHomeFiles`. It contains
  `export { default } from "${pi-tidy-tools-root}/index.ts";`.
- `mkPiSettingsUpdater`: add two cases, and require `[ "$#" -eq 2 ]` in each:
  - `set-tidy-tools` uses the filter
    `.enabled = true | .mode = "default" | .icons = true | .outputReasoning = true`.
  - `hide-thinking` uses the filter `.hideThinkingBlock = true`.
  - The existing shared code handles links, malformed JSON, modes, and no-op
    writes. Unknown actions still exit with code 2.
- `home.activation`: add two entries with
  `lib.hm.dag.entryAfter [ "writeBoundary" ]`:
  - `piTidyTools` runs
    `set-tidy-tools "$HOME/.pi/agent/pi-tidy-tools.json"`.
  - `piHideThinking` runs `hide-thinking "$HOME/.pi/agent/settings.json"`.
  - Both use `$DRY_RUN_CMD ${settingsUpdater}/bin/pi-settings-update`.
  - A malformed file or a link makes activation fail with the updater's
    message and leaves the file unchanged.
- `flake-file.inputs`: add
  `pi-tidy-tools = { url = "github:mikeyobrien/pi-tidy-tools"; flake = false; };`
  after `pi-subagents`.
- Change the first sentence of the comment above `flake-file.inputs` to "Pi
  comes from llm-agents.nix." Pi no longer receives a patch. The `ask-user`
  tests still change the derivation, so the remaining sentence about the local
  Bun build stays true.

### Tests

- `mkPiFishShellCheck`: add these assertions after the usage-bar block.
  - Run `set-tidy-tools` on
    `{"mode":"result","icons":false,"outputReasoning":false,"outputReasoningModel":"fixture"}`.
  - Assert the four declared values.
  - Assert that `outputReasoningModel` is still `fixture`.
  - Run the action a second time and assert an unchanged `sha256sum`.
  - Run the action on a missing `$TMPDIR/agent/pi-tidy-tools.json`.
  - Assert that `jq -c .` returns
    `{"enabled":true,"mode":"default","icons":true,"outputReasoning":true}`.
  - Run `hide-thinking` on `{"theme":"light","hideThinkingBlock":false}`.
  - Assert `hideThinkingBlock = true` and `theme = light`.
  - Assert that a second run leaves the `sha256sum` unchanged.
- `mkPiThirdPartyExtensionsCheck`:
  - Add `tidyToolsRoot` to the `let` block, and add `tidy-tools` to the
    `mkdir` list.
  - Write `extensions/tidy-tools/index.ts` as a re-export of
    `${tidyToolsRoot}/index.ts`.
  - Append `--extension ./extensions/tidy-tools/index.ts` to
    `extension_args`.
  - Add `grep -q '"name":"tidy"' rpc.jsonl` and
    `grep -q '"name":"diff"' rpc.jsonl`. A name collision would produce
    `diff:1` and fail this grep.
  - Add `test ! -e ${tidyToolsRoot}/node_modules/@earendil-works` and
    `test ! -e ${tidyToolsRoot}/node_modules/typebox`.

### Other files

- Delete `modules/programs/pi/extensions/minimal-transcript/`.
- Delete `modules/programs/pi/patches/minimal-transcript.patch`.
- Delete `modules/programs/pi/patches/minimal-transcript.test.mjs`.
- `modules/programs/pi/config/AGENTS.md`: delete the final paragraph, which
  starts with "Before each tool batch".
- `specs/pi-tune.md`:
  - In the `tests/core.test.ts` bullet, drop "using the
    `minimal-transcript/tests/extension.test.ts` pattern".
  - Replace "Minimal mode already hides custom messages and tool rows. During
    tuning the TUI therefore shows only the spinner, `ask_user` dialogs, and
    the choice dialog." with "During tuning the TUI shows the exchange's tool
    rows, `ask_user` dialogs, and the choice dialog."
- Regenerate `flake.nix` with `nix run .#write-flake`. Add only the new lock
  entry with `nix flake lock`, which leaves the existing inputs pinned.

### Documentation

- `docs/reference/pi.md`:
  - In "The declaration", replace "The module patches the packaged JavaScript
    and rebuilds the Bun executable locally with cached npm dependencies."
    with this statement: the module runs the `ask-user` tests inside the Pi
    build, so Nix rebuilds the Bun executable locally with cached npm
    dependencies.
  - Replace "## Transcript modes" with "## Tool rows". Describe spec behaviors
    1 to 9 and the `Alt+O` binding. Name the declared `pi-tidy-tools.json`
    values and `hideThinkingBlock`. State that activation restores them after
    a `/tidy` or `/settings` change.
  - In the same section, state that the extension is a non-flake input built
    from the upstream lockfile without Pi's host libraries.
  - In the same section, state that old `minimal-transcript-diff` entries no
    longer render.
  - In the `pi-usage-bar` bullet, delete "The footer remains visible in both
    transcript modes."
  - In "Managed policy", add `hideThinkingBlock` to the keys that
    `settings.json` does not leave mutable.
  - Add the tidy-tools and hide-thinking activations to the sentence that
    lists which activations refuse malformed JSON and links.
- `docs/reference/pi-workflows.md`: change "shows the complete design in both
  normal and minimal transcript modes" to "shows the complete design".

## Tasks

1. In `pi.nix`, remove the minimal-transcript patch, wrapper, check, source
   binding, and home entry. Delete the three minimal-transcript paths.
2. Delete the activity-line paragraph from
   `modules/programs/pi/config/AGENTS.md`.
3. Add the `pi-tidy-tools` input and update the comment above
   `flake-file.inputs`. Regenerate `flake.nix` and lock only the new input.
4. Add `mkPiTidyTools`, `pi-tidy-tools-root`, and the home entry point. If the
   workspace build fails, apply design decision 3.
5. Add the `set-tidy-tools` and `hide-thinking` updater actions and the
   `piTidyTools` and `piHideThinking` activation entries.
6. Extend `mkPiFishShellCheck` and `mkPiThirdPartyExtensionsCheck` as
   described in "Tests".
7. Update `docs/reference/pi.md`, `docs/reference/pi-workflows.md`, and
   `specs/pi-tune.md`.
8. Meet the acceptance criteria.
9. After the user runs `hr`, check these results in a new Pi session:
   - An edit row shows the goal, the path, and `+adds/-dels`.
   - `Alt+O` expands an edit into a diff.
   - `/diff` shows the previous turn's changes.
   - A `codemode` script shows its goal line and output summary.
   - The Home Assistant MCP tools still work through `codemode`.
   - Pi hides thinking blocks.
   - Pi resumes an old session that contains `minimal-transcript-diff` entries
     without errors.
   - After `/tidy mode result` and another `hr`,
     `~/.pi/agent/pi-tidy-tools.json` again contains `mode = "default"`.
