---
name: ci-green
description: Own a pull request's CI until it is green, or blocked by something outside the PR, then report a verified verdict. Sorts each failure into code, flaky test or infrastructure (registry 429/5xx, DNS, OOM, disk), fixes code, re-runs infrastructure failures with backoff. Use when asked to "get CI green", "watch CI", "fix CI", or after pushing to a PR. GitHub and Gitea. Args - the PR number (defaults to the current branch's PR).
argument-hint: "[pr]"
---

# Get a PR's CI green

PR: `$ARGUMENTS`, or the current branch's PR if that is empty. Every step reads CI through `ci-status`
(see `ci-status --help`). It fetches the head and the check ids afresh on every call, so never reuse an id or
a status from an earlier call.

## Loop

1. **Status.** Run `ci-status <pr>`.
   - Exit 0, green: go to **Finish**.
   - Exit 2 or 3, running or not started: run `ci-status <pr> --wait` with Bash `run_in_background: true`. You
     are notified when it exits, so don't poll it, and don't write a watcher of your own.
   - Exit 1, red: go to step 2.
   - Exit 4: read the error, which is usually auth, a wrong directory, or a number that isn't a PR.
2. **Read the failure.** Run `ci-status <pr> --logs` and sort each failed job:

   | Class | How it shows | What to do |
   |-------|--------------|------------|
   | **Infrastructure** | Infra-suspect lines (429 or 5xx from a registry, DNS, a lost runner, OOM, disk) and no failing test | Re-run, with growing gaps (step 3) |
   | **Flaky** | A test that passed on the same code: on `main`, or in an earlier run of this head | Reproduce locally, five runs. Fix the cause if you find it; if you don't, one re-run, and record it |
   | **Code** | Anything else | Reproduce with the narrowest local command, fix it, run the suite, commit, push, back to step 1 |

   If a log is too short to judge, read the whole job log. `ci-status --logs` names the run and the job.
3. **Re-run infrastructure failures** with growing gaps of about 2, 5, 10 and 20 minutes, and at most five
   re-runs per job. Wait in the background:
   `sleep 300; ci-status <pr> --rerun-failed && ci-status <pr> --wait`, with `run_in_background: true`.
   After the fifth, stop. Report the log lines, and propose the lasting fix: a mirror, a dependency cache, a
   pinned download.
4. **Queued for a long time?** Before suspecting the PR, check whether the runner is busy with other work. On
   Gitea that is `tea actions runs list --login <name>`; on GitHub, `gh run list`. Runs may be serialised.

A push while you wait is fine: `ci-status --wait` follows the head when it moves.

## Finish

Run `ci-status <pr>` fresh. The first line of the report is one of:

- `green`, followed by `ci-status`'s last line.
- `red, infrastructure`, followed by the log lines and how many re-runs were made.
- `red, code`, followed by the failing test or step and what is left.
- `still running`, with how long it has run and what it is waiting for.

Then list what you changed, with the commits, and whatever the maintainer has to decide.
