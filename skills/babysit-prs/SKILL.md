---
name: babysit-prs
description: Monitor all open PRs in a GitHub repository. Promotes draft automation PRs to ready-for-review, rebases PRs with merge conflicts, fixes failing CI, resolves review comments, and flags PRs that are ready to merge for human attention.
user-invocable: true
allowed-tools: Read Edit Write Glob Grep Bash Agent
---

# Babysit PRs

This skill monitors every open pull request in a GitHub repository and takes the appropriate automated action on each one, escalating to the user only what genuinely requires human judgment.

## Summary of Actions

| PR State | Action |
|---|---|
| Draft, opened by automation | Promote to Ready for Review |
| Has merge conflicts | Rebase on base branch and fix conflicts |
| Has failing CI checks | Analyze failure logs, fix code, push |
| Has unresolved review comments | Validate, fix, reply, and resolve each thread |
| CI green, no conflicts, no open comments | Flag for user — ready to merge |

---

## Step 1: Determine the Target Repository

If an `owner/repo` argument was provided (e.g., `/babysit-prs acme/myrepo`), use that.

Otherwise, detect from the current git remote:

```bash
git remote get-url origin
```

Parse `owner` and `repo` from the remote URL (handles both HTTPS `https://github.com/owner/repo.git` and SSH `git@github.com:owner/repo.git` formats).

If not in a git repository and no argument was given, inform the user and stop.

Verify the working directory matches the target repo. If the skill was invoked against a different repo than the current directory, ask the user to `cd` into it first rather than cloning silently.

---

## Step 2: Snapshot Current Branch State

Before switching branches to work on any PR, save the current branch name and stash any uncommitted changes so they can be restored at the end.

```bash
git branch --show-current
git status --porcelain
```

If `git status --porcelain` has output, stash:

```bash
git stash push -m "babysit-prs: auto-stash"
```

---

## Step 3: Fetch All Open PRs

Pull the full set of open PRs with the fields needed for triage in a single call:

```bash
gh pr list \
  --state open \
  --json number,title,isDraft,author,mergeable,reviewDecision,headRefName,baseRefName,statusCheckRollup \
  --limit 200
```

If there are more than 200 open PRs, warn the user that only the first 200 will be processed.

---

## Step 4: Categorize Each PR

**Before categorizing, skip any PR that is a release-please release PR.** A PR is a release-please PR if its `headRefName` matches the pattern `release-please--branches--*`. These PRs are managed entirely by release-please automation — do not promote, rebase, fix CI, or touch review comments on them. Record them in the final summary as "Skipped (release-please)" and move on.

Evaluate each remaining PR against the following categories **in order**. A PR can match multiple categories; apply every relevant action.

### A — Automation-authored draft PR

Criteria: `isDraft == true` **AND** the author is automation.

Automation authors include any login that:
- Ends in `[bot]` (e.g., `github-actions[bot]`, `dependabot[bot]`, `renovate[bot]`)
- Is exactly `amalgamated-bot`
- Contains `copilot` (case-insensitive, e.g., `copilot-swe-agent`)
- Is `renovate`

### B — Merge conflict

Criteria: `mergeable == "CONFLICTING"`.

### C — Failing CI

Criteria: any entry in `statusCheckRollup` has `conclusion` of `"FAILURE"` or `"TIMED_OUT"`.

Ignore entries with `status` of `"IN_PROGRESS"`, `"QUEUED"`, or `"PENDING"` — do not treat pending checks as failures.

### D — Unresolved review comments

Use the GraphQL API to check for unresolved threads (the REST JSON above does not expose thread resolution status):

```bash
gh api graphql -f query='
  query($owner: String!, $repo: String!, $pr: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 50) {
          nodes {
            isResolved
          }
        }
      }
    }
  }
' -F owner=OWNER -F repo=REPO -F pr=NUMBER
```

Criteria: any `isResolved == false`.

### E — Ready to merge

Criteria: ALL of the following are true:
- `isDraft == false`
- `mergeable == "MERGEABLE"`
- All `statusCheckRollup` entries have `conclusion == "SUCCESS"` (or no checks exist)
- No unresolved review threads (Category D check returns all resolved or no threads)
- `reviewDecision` is `"APPROVED"` or `null` (no required approvals configured)

---

## Step 5: Process Each PR

Announce each PR before working on it: `"Processing PR #<number>: <title>"`.

Process categories in order: A → B → C → D. Category E PRs are collected and reported at the end without automated action.

### 5A — Promote Automation Draft PRs

```bash
gh pr ready <number>
```

Log the action. No branch checkout is needed.

After promotion, re-check the PR's state to determine if it also falls into categories B, C, or D and process those as well.

---

### 5B — Rebase PRs with Merge Conflicts

1. Check out the PR branch:

```bash
git fetch origin
git checkout <headRefName>
git pull origin <headRefName>
```

2. Rebase onto the base branch:

```bash
git rebase origin/<baseRefName>
```

3. **If rebase succeeds cleanly**, push and comment:

```bash
git push origin <headRefName> --force-with-lease
gh pr comment <number> --body "Rebased on \`<baseRefName>\` to resolve merge conflicts."
```

4. **If rebase has conflicts**, resolve them file by file:
   - Read each conflicted file — look for `<<<<<<<`, `=======`, `>>>>>>>` markers
   - For each conflict: understand what the base branch changed vs. what the PR changed, then apply the correct resolution
   - General rule: prefer base-branch intent for infrastructure, config, and migration files; prefer PR intent for feature code — when uncertain, abort and add to the "needs attention" list
   - After resolving a file: `git add <file>`
   - Continue the rebase: `git rebase --continue`
   - Repeat until complete, then push with `--force-with-lease`

5. **If a conflict cannot be resolved safely**, abort and note it:

```bash
git rebase --abort
```

Add this PR to the needs-attention list: "conflicts in `<files>` — requires manual resolution."

---

### 5C — Fix Failing CI

1. Check out the branch:

```bash
git fetch origin
git checkout <headRefName>
git pull origin <headRefName>
```

2. Identify which checks failed:

```bash
gh pr checks <number> --json name,status,conclusion,detailsUrl
```

3. For each failing check, find the most recent run and fetch the failure logs:

```bash
gh run list --branch <headRefName> --json databaseId,name,status,conclusion --limit 10
gh run view <runId> --log-failed
```

4. Analyze the failure type and fix accordingly:

**Lint / format errors**
Read the lint output, identify the files and rules that failed, fix the code, and run the linter locally to confirm it passes before committing. Check the CI workflow file (`.github/workflows/`) to find the exact lint command used.

**Test failures**
Read the test output to identify the failing test name and assertion. Read the relevant source and test files. Fix the underlying code issue. Run the failing test locally to confirm it passes:
```bash
# Go: go test ./path/to/package -run TestFunctionName
# JS/TS: look at the workflow for the test command
```

**Build / compile errors**
Read the compiler output. Find the referenced file and line. Fix the type mismatch, missing import, or syntax error. Re-run the build command locally.

**Type errors (TypeScript)**
Read the type error, find the file, fix the type annotation or interface. Run `tsc --noEmit` (or the equivalent from the workflow) locally.

5. Group all fixes into as few commits as possible. Use conventional commit messages (`fix(scope): description`). Do not add Co-Authored-By trailers.

6. Push:

```bash
git push origin <headRefName>
```

7. **If the failure is infrastructure-related** (flaky external service, infra outage, network timeout) or the fix would require changes beyond the scope of the PR, skip fixing and add to the needs-attention list with the failure description and the failing check name.

---

### 5D — Resolve Review Comments

1. Check out the branch (if not already on it):

```bash
git fetch origin
git checkout <headRefName>
git pull origin <headRefName>
```

2. Fetch all unresolved review threads with full detail:

```bash
gh api graphql -f query='
  query($owner: String!, $repo: String!, $pr: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            comments(first: 50) {
              nodes {
                databaseId
                body
                author { login }
                path
                line
              }
            }
          }
        }
      }
    }
  }
' -F owner=OWNER -F repo=REPO -F pr=NUMBER
```

3. For each **unresolved** thread:

   a. **Read the comment** to understand what the reviewer is requesting.

   b. **Read the current state** of the referenced file at the referenced line.

   c. **Determine validity**:
      - If the issue described **still exists** in the current code → it is **valid**, fix it.
      - If the issue **has already been addressed** by a prior commit → it is **already resolved**, note it.

   d. **Fix valid issues**: make the change, run any relevant local checks to verify.

   e. **Reply to the thread** using the REST API:

   ```bash
   gh api repos/{owner}/{repo}/pulls/{pr}/comments/{comment_database_id}/replies \
     -f body="<reply text>"
   ```

   For fixed issues: explain concisely what was changed.
   For already-resolved issues: state that the issue was already addressed and why.

   f. **Resolve the thread** via GraphQL:

   ```bash
   gh api graphql -f query='
     mutation($threadId: ID!) {
       resolveReviewThread(input: {threadId: $threadId}) {
         thread { isResolved }
       }
     }
   ' -f threadId="<thread_id>"
   ```

4. Commit all code fixes together (group by PR, not by individual comment). Push once per PR after all threads are processed.

---

## Step 6: Restore Original Branch

After all PRs have been processed:

```bash
git checkout <original-branch>
```

If changes were stashed in Step 2:

```bash
git stash pop
```

---

## Step 7: Report Summary

Print a table covering every open PR processed:

```
PR #  | Title                  | Author              | Category           | Action              | Result
------|------------------------|---------------------|--------------------|---------------------|-------
#42   | bump deps              | dependabot[bot]     | Draft automation   | Promoted to ready   | ✓
#38   | fix login flow         | alice               | Merge conflict     | Rebased on main     | ✓
#35   | add upload feature     | bob                 | Failing CI (lint)  | Fixed & pushed      | ✓
#31   | refactor auth          | carol               | Review comments    | 3 threads resolved  | ✓
#28   | upgrade API client     | alice               | Ready to merge ⭐   | Needs your review   | —
```

Then list any items that need human attention:

**Ready to merge (no action needed from you except approval):**
- PR #28: "upgrade API client" by alice — CI green, approved, no conflicts

**Needs manual intervention:**
- PR #41: "big refactor" — conflicts in `db/schema.sql` too complex to auto-resolve
- PR #39: "add payment flow" — CI failing due to expired external API credentials (infrastructure issue)

---

## Important Notes

- Always use `git push --force-with-lease` after a rebase. Never use `--force` alone.
- Never merge a PR. Flag it and let the human decide.
- Check the `.github/workflows/` directory to understand what commands the CI runs before attempting local verification of fixes.
- A PR may fall into multiple categories. Process all applicable categories for each PR before moving on.
- When replying to review comments, be concise and specific. Reviewers appreciate brevity.
- For PRs owned by other humans (not bots), be conservative when fixing CI failures: only make changes that are clearly mechanical (lint, format, obvious type errors). For logic changes, add to the needs-attention list instead.
- Do not commit or push without first verifying the fix locally (run the same command the CI runs, as found in the workflow file).
