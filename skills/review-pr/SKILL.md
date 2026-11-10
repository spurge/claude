---
name: review-pr
description: Review a pull request with parallel reviewer subagents, post the verified findings on the PR, fix them, and drive CI green. Use when asked to "review PR #N", "review and fix", "get it reviewed by subagents", or from the herdr PR panel. Works with GitHub (gh) and Gitea (tea). Args - the PR number, then optionally --no-fix (post findings only) or --no-post (fix without commenting on the PR).
argument-hint: <pr> [--no-fix] [--no-post]
---

# Review a PR, fix it, get it green

**A project's own review skill comes first.** If the repository has its own review or sweep skill under
`.claude/skills/` (Gardener's Almanac has `work-review` and `pr-sweep`), follow that skill instead of this one.
Only the CI step and the report shape below still apply.

Arguments: `$ARGUMENTS`. The first is the PR number. `--no-fix` stops after posting the findings, and
`--no-post` fixes the findings without commenting on the PR. Invoking this skill is the go-ahead to comment on
the PR and push follow-up commits to its branch, never to force-push, merge, approve or close it.

## 1. Get the PR and its branch

1. Run `git remote get-url origin` to pick the tool: `gh` for GitHub, `tea --login <name>` for Gitea.
2. Read the PR: title, description, base, head branch and existing review comments.
   - GitHub: `gh pr view <n> --comments` and `gh api repos/{owner}/{repo}/pulls/<n>/comments`.
   - Gitea: `tea pr <n>`, `tea comment list <n>` and `tea pr review-comments <n>`.
3. Put the PR's head branch in a checkout, up to date with the remote: `git fetch origin`, then switch or
   `git pull --ff-only`. Use this checkout unless it is dirty or busy with other work. In that case make a
   worktree and give its full path in the report.
4. Collect the diff: `git diff origin/<base>...HEAD --stat`, then the full diff.
5. Read the project's CLAUDE.md, plus the docs it names for this kind of change. They hold the rules the
   review checks against, such as release notes, API parity, translations and installed clients.

## 2. Review in parallel

Launch the reviewers in **one message** so they run at the same time. Choose them by what the diff touches:

| Reviewer | When |
|----------|------|
| Correctness and tests: bugs, edge cases, missing tests, error handling | Always |
| Project rules: what the project's CLAUDE.md requires for this kind of change | Always |
| UI, UX and copy | When screens, components or user-facing text changed |
| Security: auth, ownership, input handling, secrets | When any of those changed |

If the project has its own review skill for a part of the change, run that skill for it instead of a reviewer
here. For example, a `copy-review` skill covers Swedish or German copy.

Give each reviewer the PR number, the base, how to get the diff, the files that matter most and the CLAUDE.md
sections that apply. Give them the code, not your own conclusions. Ask each one for findings with
`file:line`, a severity (**bug**, **should fix**, **nit**), a concrete failure scenario and a suggested fix.
They are read-only: no edits and no comments.

## 3. Verify, then ask

1. Check every finding against the code yourself. Drop any that don't hold up, and give the reason in the
   report. Where reviewers disagree, settle it with one more targeted subagent or by testing it.
2. **Decisions first.** Some findings need the maintainer's call: a name, a design trade-off, scope, or
   rewording text they wrote. Ask all of these at once with AskUserQuestion, **before fixing anything**. Fix
   everything else while you wait for the answer.

## 4. Post the findings

Skip this step with `--no-post`. Otherwise write one comment to a file in the scratchpad, following the
project's writing rules. It has three parts:

- **In short**: how many findings, how serious, and whether you are fixing them.
- Numbered findings: severity, `file:line`, what goes wrong, and the fix.
- **Left for you**: what needs the maintainer, and why.

Post it with `gh pr comment <n> --body-file <file>` or `tea comment <n> -d "$(cat <file>)" --login <name>`.

## 5. Fix

Stop here with `--no-fix`. Otherwise:

1. Fix every finding the maintainer doesn't have to decide on. Make one commit per coherent group, and name
   the finding numbers in the commit message.
2. Regenerate whatever the change makes stale: snapshots, goldens, locale syncs and generated clients.
3. Run the tests the project's CLAUDE.md names for the code you touched, narrowest first.
4. Push. Never force-push.
5. Post a short follow-up comment that lists each finding as fixed (with its commit), or left and why.

## 6. CI

Follow the `ci-green` skill for this PR until CI is green, or blocked by infrastructure with the evidence.

## 7. Report

The first line gives the state: `#<n>: <k> findings, <f> fixed, <l> left for you. CI green at <sha>`, or what
is red and why. Under it come:

- **Left for you**, if anything is: the decisions and actions the maintainer owns.
- A table with one row per finding, giving its outcome: fixed (commit), left (reason) or dropped (why it did
  not hold).
- The last line of a fresh `ci-status <n>` run.
- The worktree path, if the work was not done in the launch checkout.
