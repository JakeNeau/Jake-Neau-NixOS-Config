import assert from "node:assert/strict";
import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import {
  expandPromptTemplate,
  formatOutgoingLinks,
  formatReadLinkFooter,
  loadLinkedResource,
} from "../adapters.ts";

test("expands every documented prompt placeholder", () => {
  const cases = [
    ["Build $1 with $@", 'Button "click handler"', "Build Button with Button click handler"],
    ["All: $ARGUMENTS", "one two", "All: one two"],
    ["Use ${1:-seven}", "", "Use seven"],
    ["Use ${@:-seven words}", "", "Use seven words"],
    ["Use ${ARGUMENTS:-seven words}", "", "Use seven words"],
    ["Rest: ${@:2}", "one two three", "Rest: two three"],
    ["Slice: ${@:2:1}", "one two three", "Slice: two"],
    ["Missing: $3", "one two", "Missing: "],
    ["Past: ${@:5}", "one two", "Past: "],
    ["Keep $NAME", "one", "Keep $NAME"],
  ];
  for (const [template, args, expected] of cases) {
    assert.equal(expandPromptTemplate(template, args), expected);
  }
});

test("rejects malformed argument strings", () => {
  assert.throws(() => expandPromptTemplate("$1", '"unterminated'), /unterminated/i);
  assert.throws(() => expandPromptTemplate("$1", "trailing\\"), /escape/i);
});

test("loads each resource type with the correct transformation", async () => {
  const root = await mkdtemp(join(tmpdir(), "pi-link-adapters-"));
  const skillPath = join(root, "SKILL.md");
  const commandPath = join(root, "review.md");
  const docPath = join(root, "doc.md");
  await writeFile(skillPath, "---\nname: sample\ndescription: Sample\n---\n# Skill\n", "utf8");
  await writeFile(commandPath, "---\ndescription: Review\n---\nReview $1 with $@.\n", "utf8");
  await writeFile(docPath, "# Document\n", "utf8");

  const base = { layer: "global", metadata: {}, links: [], mtimeMs: null };
  assert.equal(
    (await loadLinkedResource({ ...base, id: "global:skill:sample", type: "skill", name: "sample", path: skillPath, description: "Sample", adapter: "skill" }, "carefully")).text,
    "---\nname: sample\ndescription: Sample\n---\n# Skill\n\nUser: carefully",
  );
  assert.equal(
    (await loadLinkedResource({ ...base, id: "global:command:review", type: "command", name: "review", path: commandPath, description: "Review", adapter: "command" }, "file.ts")).text,
    "Review file.ts with file.ts.\n",
  );
  assert.equal(
    (await loadLinkedResource({ ...base, id: "project:doc:doc", type: "doc", name: "doc", path: docPath, description: "Document", adapter: "doc" })).text,
    "# Document\n",
  );
});

test("formats outgoing links and idempotent read footers", () => {
  const entry = {
    id: "global:skill:comments",
    type: "skill",
    name: "comments",
    layer: "global",
    path: "/tmp/comments/SKILL.md",
    description: "Comments",
    metadata: {},
    adapter: "skill",
    mtimeMs: null,
    links: [
      { raw: "[[skill:diataxis]]", type: "skill", name: "diataxis", status: "resolved", targetId: "global:skill:diataxis" },
      { raw: "[[doc:missing]]", type: "doc", name: "missing", status: "missing-target", targetId: undefined },
    ],
  };
  assert.equal(
    formatOutgoingLinks(entry),
    "Linked resources:\n- [[skill:diataxis]] → global:skill:diataxis\n- [[doc:missing]] → missing-target",
  );

  const links = [entry.links[0]];
  const once = formatReadLinkFooter("Body", links);
  const twice = formatReadLinkFooter(once, links);
  assert.equal(once, "Body\n\n[pi-typed-links]\nLinked resources:\n- [[skill:diataxis]] → global:skill:diataxis");
  assert.equal(twice, once);
  assert.equal(formatReadLinkFooter("Body", []), undefined);
});
