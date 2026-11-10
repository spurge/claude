#!/bin/sh
# Link this repository into ~/.claude and ~/.local/bin, and register its status line and hooks.
# Safe to run again after a pull: links are replaced, and every settings entry pointing into this
# repository is rewritten from the list below. Settings of your own are left alone.
set -eu
repo=$(cd "$(dirname "$0")" && pwd)
claude="$HOME/.claude"
mkdir -p "$claude/skills" "$HOME/.local/bin"

link() { # link <target> <link path>
  if [ -e "$2" ] && [ ! -L "$2" ]; then
    mv "$2" "$2.before-claude"
    echo "moved existing $2 to $2.before-claude"
  fi
  ln -sfn "$1" "$2"
  echo "linked $2"
}

for dir in "$repo"/skills/*/; do
  name=$(basename "$dir")
  link "${dir%/}" "$claude/skills/$name"
done
# Skills removed from the repo, or links left by its old name (claude-config), dangle.
for l in "$claude"/skills/* "$HOME"/.local/bin/*; do
  if [ -L "$l" ] && [ ! -e "$l" ]; then
    case "$(readlink "$l")" in "$repo"/* | */claude-config/*) rm "$l"; echo "removed stale $l" ;; esac
  fi
done

for f in "$repo"/bin/*; do
  link "$f" "$HOME/.local/bin/$(basename "$f")"
done

# Settings. A hook is ours when its script is in this repo, or in one of its earlier homes:
# ~/src/claude-config, and ~/src/vim/claude (put there by Neovim's old :ClaudeSetup).
settings="$claude/settings.json"
[ -f "$settings" ] || echo '{}' > "$settings"
tmp=$(mktemp)
jq --arg repo "$repo" '
  def ours: (split(" ")[0]) as $script
    | ($script | startswith($repo + "/"))
      or ($script | test("/claude-config/(hooks|statusline)/[^/]+$"))
      or ($script | test("/vim/claude/(notify|progress|statusline)\\.sh$"));
  def entry($matcher; $commands): {matcher: $matcher, hooks: [$commands[] | {type: "command", command: ($repo + "/" + .)}]};
  def add($event; $entry): .[$event] = ((.[$event] // []) + [$entry]);

  .hooks = ((.hooks // {})
    | with_entries(.value |= (map(.hooks |= map(select((.command // "") | ours | not)))
                              | map(select((.hooks | length) > 0))))
    | with_entries(select((.value | length) > 0))
    | add("UserPromptSubmit"; entry(""; ["hooks/progress.sh running"]))
    | add("PostToolUse"; entry(""; ["hooks/progress.sh running"]))
    | add("PostToolUse"; entry("Edit|Write|MultiEdit"; ["hooks/format.sh"]))
    | add("PostToolUseFailure"; entry(""; ["hooks/progress.sh running"]))
    | add("Notification"; entry(""; ["hooks/notify.sh attention", "hooks/progress.sh attention"]))
    | add("Stop"; entry(""; ["hooks/notify.sh done", "hooks/progress.sh stop"]))
    | add("StopFailure"; entry(""; ["hooks/progress.sh stop"]))
    | add("SessionEnd"; entry(""; ["hooks/progress.sh stop"])))
  | if (.statusLine.command // "") == "" or (.statusLine.command | ours)
    then .statusLine = {type: "command", command: ($repo + "/statusline/statusline.sh")} else . end
  | .permissions.allow = ((.permissions.allow // [])
    | if index("Bash(ci-status *)") then . else . + ["Bash(ci-status *)"] end)
' "$settings" > "$tmp"
if cmp -s "$tmp" "$settings"; then
  rm "$tmp"
else
  cp "$settings" "$settings.before-claude"
  mv "$tmp" "$settings"
  echo "updated $settings (previous copy: $settings.before-claude)"
fi
case "$(jq -r '.statusLine.command // ""' "$settings")" in
  "$repo"/*) ;;
  *) echo "left your own statusLine in place; ours is $repo/statusline/statusline.sh" ;;
esac
