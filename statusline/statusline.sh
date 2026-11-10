#!/bin/sh
# Claude Code's `statusLine` command, and the only way to get live rate-limit
# numbers out of Claude Code without inventing a second credential.
#
# ── Why this exists ───────────────────────────────────────────────────
# Claude Code pipes a JSON blob to this script on every status line render.
# For Claude.ai subscribers that blob carries `rate_limits.five_hour` and
# `rate_limits.seven_day` — the same percentages `/usage` shows, using the
# session's own auth. Nothing else on the machine publishes them live: the
# transcripts under ~/.claude/projects record token counts but no limits,
# and there is no `claude usage` subcommand.
#
# So: tee the blob to a state file that Neovim polls (lua/core/claude.lua
# in ~/src/vim), and print a short line for Claude Code's own status bar
# while we're here. That state file's path is the contract between the two
# repositories: change it in both or neither.
#
# The line ends with the branch's pull request when the remote is a Gitea
# host with a tea login. Claude Code shows GitHub's itself, through gh.
#
# Registered by install.sh. jq is optional. Without it the tee — the part
# Neovim needs — still happens, and only the printed line is skipped.

set -u

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude-code"
cache="$state_dir/statusline.json"

input=$(cat)
[ -n "$input" ] || exit 0

# Write-then-rename, so a poll that lands mid-write reads the previous
# complete document rather than half of this one.
if mkdir -p "$state_dir" 2>/dev/null; then
  tmp="$cache.$$"
  if printf '%s' "$input" >"$tmp" 2>/dev/null; then
    mv -f "$tmp" "$cache" 2>/dev/null || rm -f "$tmp" 2>/dev/null
  else
    rm -f "$tmp" 2>/dev/null
  fi
fi

command -v jq >/dev/null 2>&1 || exit 0

# ── The tea pull request ──────────────────────────────────────────────
# tea asks the server, far too slow for every render. So the answer is
# cached per checkout and branch, refreshed in the background once it is a
# minute old: a render never waits on the network, only on two local git
# calls. An empty cache file means "no PR", and is retried a minute later.

# refresh_pr <toplevel> <branch> <cache file>
refresh_pr() {
  url=$(git -C "$1" remote get-url origin 2>/dev/null) \
    || url=$(git -C "$1" remote get-url "$(git -C "$1" remote | head -n 1)" 2>/dev/null) \
    || return 0
  case $url in # ssh://git@host:22/o/r, https://host/o/r.git, git@host:o/r.git
    *://*) rest=${url#*://}; rest=${rest#*@}; host=${rest%%[:/]*}; slug=${rest#*/} ;;
    *@*:*) rest=${url#*@}; host=${rest%%:*}; slug=${rest#*:} ;;
    *) return 0 ;;
  esac
  host=$(printf '%s' "$host" | tr '[:upper:]' '[:lower:]')
  slug=${slug%/}; slug=${slug%.git}; slug=${slug#/}
  login=$(tea logins list -o json 2>/dev/null | jq -r --arg host "$host" '
    map(select((.url | sub("^[a-z]+://"; "") | sub("[:/].*$"; "") | ascii_downcase) == $host
               or ((.ssh_host // "") | ascii_downcase) == $host)) | .[0].name // empty')
  [ -n "$login" ] || return 0
  tea pulls list --login "$login" --repo "$slug" --state open --limit 100 \
    --fields index,head,url,ci -o json 2>/dev/null | jq -r --arg branch "$2" '
    map(select(.head == $branch)) | .[0] // empty
    | ({success: "\u001b[32m✓\u001b[0m ", failure: "\u001b[31m✗\u001b[0m ", error: "\u001b[31m✗\u001b[0m ",
        pending: "\u001b[33m•\u001b[0m "}[.ci] // "")
      + "\u001b]8;;\(.url)\u001b\\PR #\(.index)\u001b]8;;\u001b\\"'
}

pr_segment() {
  command -v tea >/dev/null 2>&1 || return 0
  cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // empty')
  [ -n "$cwd" ] || return 0
  top=$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel 2>/dev/null) || return 0
  branch=$(git -C "$top" --no-optional-locks symbolic-ref --short -q HEAD 2>/dev/null) || return 0
  mkdir -p "$state_dir/pr" 2>/dev/null || return 0
  file="$state_dir/pr/$(printf '%s\n%s' "$top" "$branch" | cksum | cut -d ' ' -f 1)"
  if [ -z "$(find "$file" -mmin -1 2>/dev/null)" ]; then
    # A lock older than two minutes belongs to a refresh that was killed.
    [ -n "$(find "$file.lock" -maxdepth 0 -mmin +2 2>/dev/null)" ] && rmdir "$file.lock" 2>/dev/null
    if mkdir "$file.lock" 2>/dev/null; then
      ( refresh_pr "$top" "$branch" >"$file.$$"; mv -f "$file.$$" "$file"; rmdir "$file.lock" ) \
        </dev/null >/dev/null 2>&1 &
    fi
  fi
  [ -f "$file" ] && cat "$file"
}

line=$(printf '%s' "$input" | jq -r '
  [ (.model.display_name // empty),
    (.workspace.current_dir // "" | split("/") | last | select(. != "")),
    ((.context_window.used_percentage // empty) | "ctx \(round)%"),
    ((.rate_limits.five_hour.used_percentage // empty) | "5h \(round)%"),
    ((.rate_limits.seven_day.used_percentage // empty) | "7d \(round)%")
  ] | join("  ")
' 2>/dev/null)
pr=$(pr_segment)
printf '%s' "$line"
[ -n "$pr" ] && printf '%s%s' "${line:+  }" "$pr"
exit 0
