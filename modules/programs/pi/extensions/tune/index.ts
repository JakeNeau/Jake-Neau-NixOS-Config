import { readFile } from "node:fs/promises";

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

import { registerTune, type TuneApi } from "./core.ts";

const ProposePromptParameters = Type.Object(
  {
    prompt: Type.String({
      description: "The complete tuned prompt that replaces the draft",
      minLength: 1,
    }),
  },
  { additionalProperties: false },
);

export default function tune(pi: ExtensionAPI): void {
  registerTune(pi as unknown as TuneApi, {
    loadInstructions: () => readFile(new URL("./instructions.md", import.meta.url), "utf8"),
    parameters: ProposePromptParameters,
  });
}
