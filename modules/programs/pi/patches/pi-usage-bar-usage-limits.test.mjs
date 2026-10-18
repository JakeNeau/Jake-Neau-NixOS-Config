import assert from "node:assert/strict";
import { test } from "node:test";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const source = process.env.PI_USAGE_BAR_SOURCE;
if (!source) throw new Error("PI_USAGE_BAR_SOURCE is required");

const { footerStatuses } = await import(
  pathToFileURL(join(source, "src/footer-statuses.ts")).href
);

const limits = "\u001b[2m5h: 73% ↻2h10m 14:30, 7d: 12% ↻1d4h Mon 20:00\u001b[22m";
const statuses = new Map([
  ["pi-usage-bar", "ignored"],
  ["model-usage", limits],
  ["other", "x".repeat(40)],
  ["blank", "  "],
]);

test("the second line carries the full plain limits status", () => {
  assert.deepEqual(footerStatuses(statuses, true), {
    lineOne: `${"x".repeat(27)}…`,
    lineTwo: "5h: 73% ↻2h10m 14:30, 7d: 12% ↻1d4h Mon 20:00",
  });
});

test("without a second line the limits status stays on line one", () => {
  assert.deepEqual(footerStatuses(statuses, false), {
    lineOne: `5h: 73% ↻2h10m 14:30, 7d: 1… ❯ ${"x".repeat(27)}…`,
    lineTwo: null,
  });
});

test("no visible statuses yield no segments", () => {
  assert.deepEqual(footerStatuses(new Map([["blank", " "]]), true), {
    lineOne: null,
    lineTwo: null,
  });
});
