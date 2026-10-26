#!/usr/bin/env bash
# new-handoff.sh — start a handoff from the template, chained to the last one.
#
# Usage: os/scripts/new-handoff.sh <topic-slug>
#
# Writes os/handoffs/YYYY-MM-DD-HHMMSS-<topic-slug>.md from _templates/handoff.md,
# with its title, "Saved as" and "Continues from" (the newest handoff before it)
# filled in, and prints the new file's path as its last line. The path is the
# deliverable: the next session needs nothing else, so the reply to the owner
# starts with it (os/playbooks/handoff.md). Never overwrites a file.
#
# Exit: 0 written · 1 that file already exists · 2 usage, or no template

set -eu
LC_ALL=C
export LC_ALL

usage() { echo 'usage: os/scripts/new-handoff.sh <topic-slug>' >&2; exit 2; }
[ $# -eq 1 ] || usage
slug=$1
case $slug in
  ''|-*|*-|*--*|*[!a-z0-9-]*)
    echo "new-handoff.sh: the topic is a slug — lowercase letters, digits and single hyphens, like 'sync-fix'; got: $slug" >&2
    exit 2 ;;
esac

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"
[ -f _templates/handoff.md ] || { echo "new-handoff.sh: _templates/handoff.md is missing" >&2; exit 2; }
mkdir -p os/handoffs

prev=$(find os/handoffs -maxdepth 1 -type f -name '[0-9][0-9][0-9][0-9]-*.md' 2>/dev/null | sort | tail -n 1)
new="os/handoffs/$(date +%Y-%m-%d-%H%M%S)-$slug.md"
if [ -e "$new" ]; then
  echo "new-handoff.sh: $new already exists — never overwritten; wait a second or pick another topic" >&2
  exit 1
fi
if [ -n "$prev" ]; then
  p=$(basename "$prev")
  cont="[$p]($p)"
else
  cont="none — chain start"
fi

awk -v new="$new" -v cont="$cont" -v title="$(printf '%s' "$slug" | tr '-' ' ')" '
  !t && /^# Handoff: / { print "# Handoff: " title; t = 1; next }
  !s && /^\*\*Saved as:\*\*/ { print "**Saved as:** `" new "`"; s = 1; next }
  !c && /^\*\*Continues from:\*\*/ { print "**Continues from:** " cont; c = 1; next }
  { print }' _templates/handoff.md > "$new"
echo "$new"
