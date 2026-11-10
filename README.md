# claude

My Claude Code setup for every machine: skills, a CI script, the status line and hooks. `~/.claude/CLAUDE.md`
is not here: each machine keeps its own. Project rules stay in each project's own CLAUDE.md.

```sh
git clone git@github.com:spurge/claude.git ~/src/claude
~/src/claude/install.sh
```

The installer links things into place, so an edit here is live at once. Run it again after a pull that adds
or removes a skill, or changes a hook.

| Path | Installed as | What it is |
|------|--------------|------------|
| `skills/review-pr/` | `~/.claude/skills/` | `/review-pr <n>`: subagent review, comment, fix, CI green |
| `skills/ci-green/` | `~/.claude/skills/` | `/ci-green <n>`: own a PR's CI until it is green or blocked |
| `skills/pr-digest/` | `~/.claude/skills/` | `/pr-digest`: read-only overview of open PRs |
| `bin/ci-status` | `~/.local/bin/` | One line per CI check, for GitHub (`gh`) and Gitea (`tea`) |
| `statusline/statusline.sh` | `statusLine` | Model, folder, context and rate limits, and the branch's Gitea PR |
| `hooks/notify.sh` | `Stop`, `Notification` | A desktop notification when a turn ends or Claude needs you |
| `hooks/progress.sh` | prompt, tool and stop hooks | Ghostty's progress bar for a session inside Neovim |
| `hooks/format.sh` | `PostToolUse` (edits) | Runs `gofmt` on each Go file Claude edits |

The installer writes `~/.claude/settings.json` (saving the previous copy as `settings.json.before-claude`):
the `statusLine`, the hooks, and `Bash(ci-status *)` in the allow list. It rewrites only entries whose script is
in this repository or in an earlier home of these scripts (`~/src/claude-config`, `~/src/vim/claude`). A
`statusLine` of your own is left in place.

## The status line

```
Opus 5.5  herdr  ctx 12%  5h 24%  7d 41%  ✓ PR #506
```

Claude Code pipes a JSON document to the status line on every render. `statusline.sh` prints the line and tees
the document to `~/.local/state/claude-code/statusline.json`, which Neovim (`~/src/vim`, `lua/core/claude.lua`)
reads for its rate-limit segment. That path is shared by the two repositories.

Claude Code shows the branch's GitHub pull request itself, through `gh`. For a remote whose host has a `tea`
login, the line ends with that branch's open Gitea pull request, linked, with its CI state (✓ green, ✗ red,
• running). It is cached per checkout and branch under `~/.local/state/claude-code/pr/` and refreshed in the
background once a minute old, so a render never waits on the network.

## Neovim

Inside a Neovim terminal, `notify.sh` and `progress.sh` hand their events to Neovim (`nvim --server $NVIM`,
`core.hostterm` in `~/src/vim`), which passes them to Ghostty. Elsewhere `progress.sh` does nothing and
`notify.sh` posts the notification itself (`terminal-notifier`, `osascript` or `notify-send`).

## ci-status

```sh
ci-status 506                 # status now; exit 0 green, 1 red, 2 running, 3 none yet, 4 error
ci-status 506 --wait          # poll until nothing runs (follows the head if it moves)
ci-status 506 --logs          # failed jobs: error lines, failing tests, infra-suspect lines
ci-status 506 --rerun-failed  # re-run failed jobs, with ids fetched just now
```

It reads the PR's head and checks afresh on every call, so it never polls a stale job. On Gitea it reads the
commit status API and finds the tea login from the remote's host.

The herdr PR panel (`~/.config/herdr-app/mods/prs`) has buttons that start `/review-pr` and `/ci-green`.
