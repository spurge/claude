---
name: pr-digest
description: A read-only morning digest of a repository's open pull requests - CI state, mergeability, review state, age, and what each one needs from the maintainer. Use when asked "what's open", "PR status", "which PRs are ready", or for a PR digest. GitHub and Gitea. Changes nothing.
argument-hint: "[--all-authors]"
---

# Open PRs, at a glance

This skill is read-only: it posts nothing, pushes nothing and re-runs nothing.

1. Run `git remote get-url origin` to pick `gh` or `tea --login <name>`.
2. List the open PRs with number, title, author, head branch, draft state, mergeable and last update:
   - GitHub: `gh pr list --json number,title,author,headRefName,isDraft,mergeable,reviewDecision,updatedAt`
   - Gitea: `tea api --login <name> "repos/<owner>/<repo>/pulls?state=open&limit=50"`. Take `mergeable`,
     `draft` and `updated_at` from the JSON.

   Renovate and other bot PRs get one line each, and only when CI is red or there is a merge conflict.
3. For each PR, run `ci-status <n>` and keep the last line. For a red one, also run `ci-status <n> --logs`, but
   only to decide whether the failure is infrastructure or code. Don't fix anything.
4. Read each PR's latest comments, and note any review finding or question still waiting for an answer.

## Report

First line: how many are ready to merge, and how many need the maintainer.

Next, **Needs you**: one bullet for each decision, question or sign-off that is waiting on the maintainer.

Then a table with these columns:

| PR | Title | CI | Mergeable | Waiting on | Updated |
|----|-------|----|-----------|------------|---------|

For **CI**, write green, red-code, red-infra or running. For **Waiting on**, write maintainer, CI, author,
conflict or nothing (ready).
