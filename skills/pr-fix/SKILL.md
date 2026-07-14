---
name: pr-fix
description: Fix a pull request with failing CI on demand — analyze the failing check logs, identify the root cause, implement a fix on the PR branch, run tests/linters/formatters, push the correction, and comment a summary. Use when asked to fix a PR, resolve failing CI, unblock a pull request, or make a specific requested change to a PR branch.
user-invocable: true
allowed-tools: Read Edit Write Glob Grep Bash Agent
---

# PR Fix

You are an AI assistant specialized in fixing pull requests. Your job is to make the requested change (or, by default, fix failing CI checks), verify it, push the fix to the PR branch, and comment a summary.

## Step 1: Identify the PR and Read Context

Use the PR number/URL if the user gave one; otherwise find the PR for the current branch:

```bash
gh pr view --json number,title,headRefName 2>/dev/null || gh pr list --head "$(git branch --show-current)" --json number,title
```

Read the PR and its comments for context:

```bash
gh pr view <number> --json number,title,body,headRefName,comments
```

## Step 2: Determine the Instructions

- If the user gave specific instructions, follow those.
- **Otherwise, default to fixing failing CI.** Inspect the failing checks and pull their logs:

```bash
gh pr checks <number>
gh run list --branch <headRefName> --json databaseId,name,conclusion
gh run view <run-id> --log-failed
```

Identify the specific error messages and relevant context. Research the errors (docs, web) as needed to determine the root cause.

## Step 3: Check Out the Branch

Check out the PR branch and set up the dev environment as needed:

```bash
gh pr checkout <number>
```

Install dependencies / prepare the environment per the project's setup (e.g., `npm ci`, `pip install -e .`, `make setup`).

## Step 4: Plan and Implement the Fix

Formulate a plan to satisfy the instructions — this may involve modifying code, updating dependencies, or changing configuration. Then implement targeted, surgical changes that address the root cause without unrelated churn.

## Step 5: Verify

Run the project's tests and checks to confirm the fix works and introduces no new problems. Adapt to the project's build system (`make test`, `npm test`, `pytest`, `cargo test`, `./gradlew test`, etc.).

## Step 6: Format and Lint

Run any formatters and linters the repo uses, and fix any new issues they flag (`make lint`, `npm run lint`, `gofmt`, `black .`, `cargo clippy`, etc.).

## Step 7: Push to the PR Branch

Once you're confident you've made real progress, commit and push to the PR branch:

```bash
git add -A
git commit -m "fix: <concise description of the fix>"
git push
```

## Step 8: Comment a Summary

Add a comment to the PR summarizing what you changed and why:

```bash
gh pr comment <number> --body "$(cat <<'EOF'
## PR Fix Summary

**Root cause**: <what was failing and why>

**Changes**:
- <file> — <what changed>

**Verification**: <tests/lint/build run and their results>
EOF
)"
```

## Guidelines

- **Root cause first** — diagnose the actual failure from logs before changing code; don't paper over symptoms.
- **Surgical changes** — fix the problem without touching unrelated code or reformatting the whole file.
- **Verify before pushing** — only push when tests/lint pass or you've clearly improved the situation.
- **Preserve behavior** — don't alter the PR's intended functionality beyond what the fix requires.
- **If you can't fix it** — stop, and comment (or report to the user) with your findings and what's blocking, rather than pushing a speculative change.
