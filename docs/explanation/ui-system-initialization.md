# UI system initialization before feature design

Feature design needs a stable visual vocabulary. Without one, each screen can
introduce unrelated colors, spacing, typography, and interaction patterns. The
initializer therefore establishes the vocabulary before it creates feature UI.

The workflow separates visual foundations from application features. Product
direction constrains the overall character. Hierarchy and composition define
how the interface communicates importance. Finite scales remove arbitrary
values. Reusable patterns capture decisions that several features need.

Readiness requires inspected OpenPencil state because documentation alone can
drift from the design artifact. A documented variable or component is usable
only when its recorded identifier resolves in the authoritative `.fig` file.
The headless CLI verifies the saved file independently from the MCP mutation
path.

OpenPencil keeps the design artifact local and project-owned. Git can version
the binary `.fig` file, while the CLI and MCP server provide structured access.
Because binary storage limits line-level review, validators inspect node trees,
variables, component inventories, analysis output, and rendered evidence.

The generated project-local `ui-system` skill is a locator and enforcement
contract. It points to the durable documentation and design file rather than
copying them. Feature work must extend the system first when it needs a missing
value, state, or pattern.
