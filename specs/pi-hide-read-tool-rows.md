Implement a global Pi extension that toggles the visibility of successful `read` tool rows in the interactive transcript.

Work in the declarative Nix configuration at `/private/etc/nix-darwin`. Do not edit files under `~/.pi/agent/extensions/` directly.

Before changing code:

1. Follow the repository instructions.
2. Read the repository documentation before code.
3. Load `global:skill:documentation`.
4. Load `global:skill:writing`.
5. Load the installed `writing-pi-extensions` skill.
6. Read the installed Pi `docs/extensions.md` completely.
7. Read the relevant extension and TUI documentation.
8. Inspect examples for tool overrides, `createReadTool`, `renderShell`, empty components, shortcuts, and rerendering.
9. Confirm that a supported API can remove the complete tool row without leaving a spacer.

Required behavior:

- Add one focused global extension for read-row visibility.
- Keep `read` execution behavior identical to Pi's built-in `read` tool.
- Delegate execution to Pi's exported built-in implementation.
- Do not reimplement reads, image handling, offsets, limits, truncation, details, errors, or cancellation.
- Hide successful `read` calls and results when the extension is in hidden mode.
- Keep failed or blocked reads visible so errors are not concealed.
- Show all read rows in visible mode with Pi's normal built-in rendering.
- Add a global keyboard shortcut that toggles hidden and visible modes.
- Choose an unused shortcut after checking Pi's built-in bindings and this repository's managed bindings. Prefer a mnemonic binding that the terminal can report reliably.
- Make the shortcut affect existing transcript rows immediately, not only future reads.
- Show a brief notification after each toggle.
- Show persistent status only if it is useful and does not add comparable clutter.
- Default to hidden mode in each new Pi process unless repository conventions specify another default.
- Limit the behavior to interactive TUI presentation. Do not alter model context, session data, RPC results, print mode, or JSON mode.
- Do not add a new typed-link resource kind. This extension introduces a UI mechanism, not a durable navigable resource.

Design constraints:

- Keep one responsibility in the extension.
- Preserve the exact built-in read tool contract and result details.
- Avoid private Pi APIs when a documented public API works.
- Do not remove `read` from the active tool set.
- Do not hide `edit`, `write`, `bash`, search, browser, or custom tool rows.
- Do not bind over the workflow manager's `Shift+Tab` shortcut or the managed thinking shortcut `Ctrl+Shift+L`.
- If no supported API can rerender old rows, stop before implementation.
- Report the exact API limitation.

Repository integration:

- Put extension source under `modules/programs/pi/extensions/`.
- Add a generated Home Manager entry point under `~/.pi/agent/extensions/` through `modules/programs/pi/pi.nix`, following the existing extension pattern.
- Add focused automated tests before production code. Test the visibility decision separately from terminal rendering where practical.
- Add the extension test to the flake checks through the existing Pi check pattern.
- Update the Pi reference documentation with the shortcut, default state, error behavior, and scope.
- Update any documentation index only when the repository's documentation architecture requires it.

Validation:

1. Run the focused extension tests.
2. Run formatting and static checks that apply to changed files.
3. Run `pi-writing-lint` on every changed Markdown or plain-text file.
4. Run `nix flake check`.
5. Dry-build or evaluate every affected Pi home as required by `AGENTS.md`.
6. Do not run `hr`, `nr`, `nrr`, any switch command, or any command that commits or pushes.

After implementation, report:

- the selected shortcut
- the files changed
- how built-in read semantics remain preserved
- how errors remain visible
- whether existing transcript rows rerender immediately
- focused and repository-wide validation results
- any documentation gaps or unresolved Pi API limitations
