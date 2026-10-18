import assert from "node:assert/strict";
import { test } from "node:test";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const source = process.env.PI_USAGE_LIMITS_SOURCE;
if (!source) throw new Error("PI_USAGE_LIMITS_SOURCE is required");
if (process.env.TZ !== "UTC") throw new Error("TZ=UTC is required");

const { formatReset } = await import(
  pathToFileURL(join(source, "resets.ts")).href
);

// Saturday 2026-10-17 12:00 UTC.
const now = Date.UTC(2026, 9, 17, 12, 0);
const later = (minutes) => now + minutes * 60_000;

test("a same-day reset shows the countdown and the time", () => {
  assert.equal(formatReset(later(130), now), " ↻2h10m 14:10");
  assert.equal(formatReset(later(45), now), " ↻45m 12:45");
});

test("a reset on another day adds the weekday", () => {
  assert.equal(formatReset(later(13 * 60), now), " ↻13h0m Sun 01:00");
  assert.equal(formatReset(later(3 * 1440 + 250), now), " ↻3d4h Tue 16:10");
});

test("the countdown counts clock minutes and stops at zero", () => {
  assert.equal(formatReset(later(130), now + 59_000), " ↻2h10m 14:10");
  assert.equal(formatReset(now + 1_000, now), " ↻0m 12:00");
  assert.equal(formatReset(later(-5), now), " ↻0m 11:55");
});

test("ISO timestamps and epoch milliseconds are both accepted", () => {
  assert.equal(
    formatReset("2026-10-17T14:10:00.031004+00:00", now),
    " ↻2h10m 14:10",
  );
  assert.equal(formatReset(later(130), now), formatReset(new Date(later(130)).toISOString(), now));
});

test("a reset time rounds to the nearest minute", () => {
  assert.equal(
    formatReset("2026-10-17T14:09:59.579199+00:00", now),
    " \u21bb2h10m 14:10",
  );
  assert.equal(formatReset(later(130) + 29_000, now), " \u21bb2h10m 14:10");
});

test("a missing or invalid reset time adds nothing", () => {
  assert.equal(formatReset(null, now), "");
  assert.equal(formatReset(undefined, now), "");
  assert.equal(formatReset("not a date", now), "");
});
