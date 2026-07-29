---
name: diataxis
description: >
  Defines the four Diátaxis documentation types and their placement rules. It
  separates tutorials, how-to guides, reference, and explanation by reader
  need. Use when no existing project architecture determines documentation
  placement.
---

# Diátaxis documentation architecture

Diátaxis organizes documentation by the reader's need. Preserve an existing
project architecture. When no architecture exists, use Diátaxis as the default.

## The four types

- **Tutorial:** Teach a beginner through a complete lesson. The author chooses
  the path so the reader gains skill and confidence.
- **How-to guide:** Give a competent reader the steps for one practical goal.
  Include necessary conditions, actions, and expected results.
- **Reference:** Describe interfaces, options, commands, and behavior. Keep the
  description accurate, complete, and free from rationale.
- **Explanation:** Explain design reasons, alternatives, relationships, and
  trade-offs. Help the reader understand the system. Do not add task steps.

## The two axes

|                              | **Action** | **Knowledge** |
| ---------------------------- | ---------- | ------------- |
| **Learning**                  | Tutorial   | Explanation   |
| **Working**                   | How-to     | Reference     |

Use these questions to classify content:

1. Is the reader learning or applying existing knowledge?
2. Does the reader need actions or understanding?

The answers identify one documentation type.

## Keep the types separate

A tutorial serves a learner who does not yet know which questions to ask. A
how-to guide serves a reader who already has a specific goal.

Reference states what the system does. Explanation states why the system works
that way. Do not place rationale in reference content.

Use one type for each page. When a topic needs several types, create separate
pages and cross-link them.

## Apply Diátaxis

1. Read the project's documentation root and local conventions.
2. Preserve any established architecture and naming system.
3. Identify the reader's immediate need.
4. Choose the matching Diátaxis type when no existing placement applies.
5. Split content that serves a different need.
6. Update indexes and cross-links after adding or moving pages.

Treat Diátaxis as a placement guide, not a reason for a broad migration. Create
only the folders and pages that current documentation requires.

Within a type, create a subfolder only when several pages share a clear theme.
Do not create a single-page folder or an empty speculative folder.

## Define the documentation root

When creating a Diátaxis tree, its root page must contain two kinds of
information:

1. Define the four types and link each type to its location.
2. Describe the project's tooling, structure, naming, and local exceptions.

Link to <https://diataxis.fr> for the complete Diátaxis theory. Create only the
quadrant folders that contain current pages.

## Related skills

- [[skill:documentation]]: documentation-first navigation, defect handling,
  and post-code updates
