# Claude Code declarative config

Source for the user's `~/.claude` extras, inlined by `../claude-code.nix`.

Each file here is read into a string and passed to the home-manager
`programs.claude-code` *content* options — **not** symlinked via the `*Dir`
options. Drop files in and rebuild; they land in `~/.claude/<subdir>/`.

| Folder        | Becomes                         | File convention                                   |
| ------------- | ------------------------------- | ------------------------------------------------- |
| `agents/`     | `~/.claude/agents/<name>.md`    | `<name>.md` with Claude agent frontmatter         |
| `commands/`   | `~/.claude/commands/<name>.md`  | `<name>.md` slash-command definition              |
| `rules/`      | `~/.claude/rules/<name>.md`     | `<name>.md`, auto-loaded as project memory        |
| `hooks/`      | `~/.claude/hooks/<name>`        | any filename; written verbatim, marked executable |
| `skills/`     | `~/.claude/skills/<name>/SKILL.md` | one folder per skill, each holding `SKILL.md`   |
| `CLAUDE.md`   | `~/.claude/CLAUDE.md`           | global context; empty file = nothing written      |

`.gitkeep` files keep the empty folders in git and are ignored by the importer.

Note on skills: only each skill's `SKILL.md` is inlined. A skill that ships
extra files next to `SKILL.md` cannot be expressed this way without symlinking,
which this setup deliberately avoids.
