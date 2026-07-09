# Agent Skills

A collection of reusable [Agent skills](https://docs.github.com/en/copilot) authored by [@veverkap](https://github.com/veverkap).

Each skill is a self-contained folder under [`skills/`](./skills) that packages
instructions (and optional scripts or assets) an AI agent can load on demand to
perform a specific task.

## Layout

```
skills/
  <skill-name>/
    SKILL.md        # required: frontmatter + instructions
    ...             # optional supporting scripts, templates, assets
```

## Anatomy of a skill

Every skill has a `SKILL.md` with YAML frontmatter followed by Markdown instructions:

```markdown
---
name: my-skill
description: One or two sentences describing exactly what the skill does and when to use it.
user-invocable: true
allowed-tools: Read Edit Write Glob Grep Bash Agent
---

# My Skill

Step-by-step instructions the agent should follow...
```

| Field | Purpose |
|-------|---------|
| `name` | Unique identifier, matches the folder name (kebab-case). |
| `description` | Used by agents to decide when the skill applies. Be specific about triggers. |
| `user-invocable` | Whether the user can invoke it directly (e.g. `/my-skill`). |
| `allowed-tools` | Space-separated tools the skill is permitted to use. |

## Adding a new skill

1. Create a folder: `skills/<skill-name>/`
2. Add a `SKILL.md` with the frontmatter above.
3. Keep the `description` precise — it drives when agents pick the skill up.
4. Add any supporting files (scripts, templates) alongside `SKILL.md`.

## Installing

Symlink or copy a skill into your agent's skills directory, e.g.:

```bash
ln -s "$PWD/skills/my-skill" ~/.claude/skills/my-skill
# or
ln -s "$PWD/skills/my-skill" ~/.copilot/skills/my-skill
```

## License

[MIT](./LICENSE)
