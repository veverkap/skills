# Agent Skills

A collection of reusable [Agent skills](https://docs.github.com/en/copilot) authored by [@veverkap](https://github.com/veverkap).

Each skill is a self-contained folder under [`skills/`](./skills) that packages
instructions (and optional scripts or assets) an AI agent can load on demand to
perform a specific task.

## Skills

| Skill | Description |
|-------|-------------|
| [`babysit-prs`](./skills/babysit-prs) | Monitors every open PR in a repo — promotes automation drafts, rebases conflicts, fixes failing CI, resolves review comments, and flags PRs ready to merge. |
| [`graphify`](./skills/graphify) | Turns any input (code, docs, papers, images) into a clustered knowledge graph with HTML + JSON output and an audit report. |
| [`principal-engineer-review`](./skills/principal-engineer-review) | Reviews PRs and local diffs from a principal engineer standpoint — high-signal, MVP scope control, maintainability, security-aware, reuse of existing primitives. ([source](https://github.com/jonmagic/skills)) |
| [`resolve-pr-comments`](./skills/resolve-pr-comments) | Reviews all comments on the current branch's PR, fixes valid issues, replies to each, and resolves the review threads. |

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

Clone to a stable path, then run the install script — it symlinks every
`skills/*` folder into your agent skill dirs (`~/.claude/skills` and
`~/.copilot/skills`, whichever exist):

```bash
git clone git@github.com:veverkap/skills.git ~/Code/personal/skills
cd ~/Code/personal/skills && ./install.sh
```

Because they're symlinks, `git pull` updates every installed skill instantly,
and edits made through the linked paths write straight back to the repo.

Options:

```bash
./install.sh --dry-run   # preview without changing anything
./install.sh --force     # replace existing entries (real dirs or other links)
./install.sh --copy      # copy instead of symlink (for tools that don't
                         # follow symlinks; repo no longer stays the live source)
./install.sh --target ~/some/other/skills   # custom target(s), repeatable

./uninstall.sh           # remove only the symlinks this repo created
./uninstall.sh --copy    # also remove copies made with install --copy
```

Manual single-skill install (symlink or copy one folder):

```bash
ln -s "$PWD/skills/my-skill" ~/.claude/skills/my-skill
```

## License

[MIT](./LICENSE)
