## Spec

Make long `ask_user` option previews scrollable in Pi's interactive TUI.
Keep the preview panel at 16 content lines. Render the complete Markdown preview
inside Pi's public `ScrollView` component. Show a right-edge scrollbar only when
the rendered content exceeds the viewport. Remove the truncation marker because
every rendered line must remain reachable.

Use `Ctrl+Alt+J` to scroll the active preview down by one line. Use
`Ctrl+Alt+K` to scroll it up by one line. Users may hold either key to move
faster.
Keep `↑/↓` dedicated to option selection. Show the preview controls in the
dialog help row when the selected preview can scroll.

Store the preview offset as dialog state so normal rerenders preserve the
visible position. Reset the offset to the first line when the selected option
changes. Clamp the offset when terminal resizing or Markdown reflow changes the
rendered line count. Reserve scrollbar width before Markdown layout when the
scrollbar is present. Consume preview-scroll keys only in menu mode when the
selected preview overflows. Preserve existing key handling in every other
state.

Limit the change to the `ask-user` extension's TUI dialog and its focused tests.
Continue using Pi's Markdown renderer and active Markdown theme. Preserve option
selection, free-form answers, clarification, cancellation, and pending-question
behavior. Preserve the 4,000-character preview input limit.

RPC selection dialogs continue to accept the same option objects without
rendering previews. Print and JSON modes continue to direct the agent to normal
text. The change must not alter transcript scrolling, global keybindings, tool
results, session state, or model context. Mouse-wheel support and a separate
preview focus mode are outside this change. The change adds no typed-link
resource kind.

Verification must cover preview scrolling, offset bounds, and reset after
option changes. It must cover key routing, Markdown overflow, scrollbar
visibility, terminal resizing, and narrow widths. Existing dialog, core, and
pending-question tests must remain valid.
Update `docs/reference/pi.md` with the new controls, reset behavior, and TUI-only
scope.

Run the focused `pi-ask-user` tests and check, applicable formatting and static
checks, `pi-writing-lint` for changed prose, and `nix flake check`. Dry-build
each platform-compatible Pi home without activating it. Evaluate the activation
package derivation for each Pi home that the current platform cannot build.

Acceptance requires these results:

- Every rendered preview line is reachable through `Ctrl+Alt+J/K`.
- The preview never exceeds the 16-line content viewport.
- The scrollbar accurately represents overflow and the current offset.
- Changing the selected option starts its preview at the first line.
- Existing answer and clarification flows behave as before.
- Non-TUI modes behave as before.
- All focused and repository-required checks pass.

## Plan

**Goal:** Replace truncated `ask_user` previews with a bounded, scrollable Markdown viewport in the interactive TUI. Preserve every non-TUI and answer-flow contract.

**Architecture:** Keep selection and preview offset in the pure dialog reducer. Recreate Pi's public `ScrollView` from the current Markdown layout on each render. Restore the reducer offset into the viewport, then copy its clamped offset back into dialog state. This keeps rerenders stable while allowing width changes to reflow and clamp the preview.

**Files and symbols:**

- Modify `modules/programs/pi/extensions/ask-user/dialog-state.ts`.
  - Add `previewOffset: number` to `DialogState` and initialize it to zero in `createDialogState`.
  - Add a `scroll-preview` `DialogAction` carrying a signed line delta.
  - Extend `reduceDialogState` to floor preview offsets at zero.
  - Reset `previewOffset` only when `up` or `down` changes `selectedIndex`.
  - Keep edit-mode actions and every existing `DialogEvent` unchanged.
- Modify `modules/programs/pi/extensions/ask-user/dialog.ts`.
  - Import `ScrollView` and `Ellipsis` from `@earendil-works/pi-tui`.
  - Route `Key.ctrlAlt("j")` and `Key.ctrlAlt("k")` before menu navigation.
  - Apply one-line preview deltas only in menu mode and only when the latest layout overflows.
  - Keep `Key.up` and `Key.down` dedicated to option rows.
  - Replace the truncating `renderPreview` branch with a `ScrollView` viewport and remove `… preview truncated`.
  - Track whether the current rendered preview overflows so input routing and the help row use the same layout result.
  - Export the dialog or a focused preview-layout helper only as needed for black-box tests. Do not expose a new extension API.
- Modify `modules/programs/pi/extensions/ask-user/tests/dialog-state.test.ts` for offset movement, lower-bound clamping, and selection-reset behavior.
- Create `modules/programs/pi/extensions/ask-user/tests/dialog.test.ts` for rendering and keyboard integration.
- Modify `modules/programs/pi/pi.nix` so `mkPiPackage` runs the complete `ask-user` test suite while the pinned Pi source and its TUI dependencies are present. Make `mkPiAskUserCheck` depend on that package and retain its RPC loading smoke test. Avoid a second dependency-free run of the dialog test.
- Modify `docs/reference/pi.md` in **Selectable questions**. Document the 16-line viewport, overflow-only scrollbar, `Ctrl+Alt+J/K`, offset reset after selection changes, and TUI-only scope. Remove the truncation statement.

**Preview data flow:**

1. `AskUserDialog.render(width)` resolves the selected option through `activePreview`.
2. The preview renderer subtracts the existing panel borders and padding from `width`.
3. It first renders Markdown at the full inner width to determine whether more than 16 rows exist.
4. On overflow, it renders Markdown again with one fewer column. This reserves the scrollbar before Markdown wrapping.
5. It creates `ScrollView` with `height = min(16, renderedLineCount)`, automatic scrollbar mode, and `Ellipsis.Omit` because Markdown already wrapped the rows.
6. It restores `state.previewOffset` with `setScrollOffset`, renders the viewport, and writes `getScrollOffset()` back to state after ScrollView clamps it.
7. It styles the track with the muted border color and the thumb with the accent color, then places the viewport inside the existing preview border.
8. It appends `ctrl+alt+j/k scroll preview` to the menu help only when the selected preview overflows.

**Input and edge behavior:**

- Each accepted key repeat applies another one-line delta and requests a rerender.
- A preview-scroll key at the first or last row remains bounded by `ScrollView`.
- A preview-scroll key does nothing when the preview fits, no option preview exists, an action row is selected, or the dialog is editing text.
- A resize or Markdown reflow rebuilds the line list and clamps the saved offset to the new maximum.
- Widths below the existing preview minimum keep the title-only fallback, report no scrollable viewport, and remain within terminal width.
- No new user-facing error path is required. Cancellation, abort handling, pending-question state, RPC selection, print mode, JSON mode, and the 4,000-character schema limit remain unchanged.

## Tasks

### Task 1: Add preview offset state

- [ ] Extend `DialogState`, `DialogAction`, `createDialogState`, and `reduceDialogState` with the preview offset contract.
- [ ] Add reducer tests for one-line movement, zero clamping, preserved offsets on ordinary rerenders, and reset after an actual row change.
- [ ] Confirm existing free-form, clarification, selection, and cancellation transitions remain unchanged.

### Task 2: Render and control the scrollable viewport

- [ ] Replace preview slicing in `AskUserDialog.renderPreview` with the two-pass Markdown layout and `ScrollView` flow.
- [ ] Synchronize ScrollView's clamped offset back into dialog state after every preview render.
- [ ] Route `Ctrl+Alt+J/K` only for an overflowing menu preview and show the conditional help text.
- [ ] Preserve the existing panel border, active Markdown theme, focus propagation, and render invalidation behavior.

### Task 3: Add focused TUI coverage

- [ ] Test short Markdown without a scrollbar, help controls, or a truncation marker.
- [ ] Test long Markdown scrolling down and up one row, held-key repeat handling, top and bottom bounds, complete line reachability, and scrollbar-thumb movement.
- [ ] Test that changing options resets the viewport to the new preview's first row.
- [ ] Test overflow changes and offset clamping after wide-to-narrow and narrow-to-wide renders.
- [ ] Test that scrollbar width is reserved before Markdown wrapping and that every output row fits narrow widths.
- [ ] Test that preview keys request rendering only for overflowing menu previews, while arrows and text-entry modes retain their current routing.
- [ ] Run these tests inside the pinned Pi package dependency environment through `mkPiPackage`; keep the focused RPC extension-load smoke test in `mkPiAskUserCheck`.

### Task 4: Update durable documentation

- [ ] Revise `docs/reference/pi.md` with the controls, overflow behavior, selection reset, and mode boundary.
- [ ] Remove the obsolete truncation description and verify the reference still matches RPC, print, JSON, clarification, and pending-question behavior.
- [ ] Keep this specification until the implementation and durable documentation satisfy its acceptance criteria.
