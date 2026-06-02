#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  printf 'usage: %s TEXT [DELAY_SECONDS]\n' "$0" >&2
  exit 2
fi

text="$1"
delay="${2:-0.12}"

osascript - "$text" "$delay" <<'APPLESCRIPT'
on run argv
  set inputText to item 1 of argv
  set delaySeconds to (item 2 of argv) as real
  tell application "System Events"
    repeat with c in characters of inputText
      keystroke (c as text)
      delay delaySeconds
    end repeat
  end tell
end run
APPLESCRIPT
