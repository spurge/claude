#!/bin/sh
# PostToolUse hook for Edit|Write|MultiEdit: format the file Claude just wrote.
# Fast, single-file formatters only: anything slow (go vet, detekt) belongs in the
# project's own test targets. Never blocks: a file that doesn't parse is left as is.
f=$(jq -r '.tool_input.file_path // empty')
[ -f "$f" ] || exit 0
case "$f" in
  *.go) command -v gofmt >/dev/null && gofmt -w "$f" 2>/dev/null ;;
esac
exit 0
