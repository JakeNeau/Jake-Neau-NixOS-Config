export interface PreviewOption {
  label: string;
  preview?: string;
}

export type DialogMode = "menu" | "free-form" | "clarification";

export interface DialogState {
  optionCount: number;
  selectedIndex: number;
  mode: DialogMode;
  input: string;
}

export type DialogAction =
  | { type: "up" }
  | { type: "down" }
  | { type: "enter" }
  | { type: "escape" }
  | { type: "input"; value: string };

export type DialogEvent =
  | { type: "selected"; index: number }
  | { type: "free-form"; value: string }
  | { type: "clarification"; value: string }
  | { type: "cancelled" };

export interface DialogTransition {
  state: DialogState;
  event?: DialogEvent;
}

export function createDialogState(optionCount: number): DialogState {
  return { optionCount, selectedIndex: 0, mode: "menu", input: "" };
}

export function activePreview(
  options: PreviewOption[],
  state: DialogState,
): string | undefined {
  if (state.mode !== "menu" || state.selectedIndex >= state.optionCount) return undefined;
  return options[state.selectedIndex]?.preview;
}

export function reduceDialogState(
  state: DialogState,
  action: DialogAction,
): DialogTransition {
  if (state.mode !== "menu") {
    if (action.type === "input") return { state: { ...state, input: action.value } };
    if (action.type === "escape") {
      return { state: { ...state, mode: "menu", input: "" } };
    }
    if (action.type !== "enter") return { state };

    const value = state.input.trim();
    if (!value) return { state: { ...state, mode: "menu", input: "" } };
    return {
      state,
      event: { type: state.mode, value },
    };
  }

  const rowCount = state.optionCount + 2;
  if (action.type === "up") {
    return { state: { ...state, selectedIndex: Math.max(0, state.selectedIndex - 1) } };
  }
  if (action.type === "down") {
    return {
      state: { ...state, selectedIndex: Math.min(rowCount - 1, state.selectedIndex + 1) },
    };
  }
  if (action.type === "escape") return { state, event: { type: "cancelled" } };
  if (action.type !== "enter") return { state };

  if (state.selectedIndex < state.optionCount) {
    return { state, event: { type: "selected", index: state.selectedIndex } };
  }

  return {
    state: {
      ...state,
      mode: state.selectedIndex === state.optionCount ? "free-form" : "clarification",
      input: "",
    },
  };
}
