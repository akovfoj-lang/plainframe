#!/usr/bin/env bash
# gen-commands.sh — emit native command adapters from os/commands.md.
#
# Usage: os/scripts/gen-commands.sh          regenerate both adapter sets
#        os/scripts/gen-commands.sh --check  exit 1 (writing nothing) if adapters drift
#
# os/commands.md is the single source. Per "## <name>" block it emits:
#   .claude/commands/<name>.md        Claude Code slash command
#   .agents/skills/<name>/SKILL.md    portable agent skill
# Both directories are wholly generated: stale adapters are removed.
# Parsing uses awk/sed only. Never edit the adapters by hand — edit the
# manifest and rerun this script.

set -eu
if (set -o pipefail) 2>/dev/null; then set -o pipefail; fi
LC_ALL=C
export LC_ALL

case "${1:-}" in
  ""|--check) ;;
  *) echo "usage: os/scripts/gen-commands.sh [--check]" >&2; exit 2 ;;
esac

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

MANIFEST=os/commands.md
if [ ! -f "$MANIFEST" ]; then
  echo "ERROR: $MANIFEST not found" >&2
  exit 1
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/gen-commands.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

# Manifest -> TAB-separated records: name<TAB>desc<TAB>playbook.
# Prefix widths: "## " = 3, "- desc: " = 8, "- playbook: " = 12.
awk '
  /^## /          { name = substr($0, 4);  sub(/[[:space:]]+$/, "", name); desc = "" }
  /^- desc: /     { desc = substr($0, 9);  sub(/[[:space:]]+$/, "", desc) }
  /^- playbook: / { pb   = substr($0, 13); sub(/[[:space:]]+$/, "", pb)
                    if (name != "" && desc != "" && pb != "") {
                      printf "%s\t%s\t%s\n", name, desc, pb
                    }
                    name = "" }
' "$MANIFEST" > "$TMP/records"

mkdir -p "$TMP/claude" "$TMP/skills"

TAB=$(printf '\t')
N=0
while IFS="$TAB" read -r name desc pb; do
  case $name in
    ""|*[!a-z0-9-]*)
      echo "ERROR: bad command name '$name' in $MANIFEST (want [a-z0-9-])" >&2
      exit 1 ;;
  esac
  {
    printf -- '---\ndescription: %s\n---\n\n' "$desc"
    printf 'Follow the playbook at %s. It is the single source of truth for this procedure.\n' "$pb"
  } > "$TMP/claude/$name.md"
  mkdir "$TMP/skills/$name"
  {
    printf -- '---\nname: %s\ndescription: %s\n---\n\n' "$name" "$desc"
    printf 'Follow the playbook at %s. It is the single source of truth for this procedure.\n' "$pb"
  } > "$TMP/skills/$name/SKILL.md"
  N=$((N + 1))
done < "$TMP/records"

if [ "$N" -eq 0 ]; then
  echo "ERROR: no complete command blocks parsed from $MANIFEST" >&2
  exit 1
fi

if [ "${1:-}" = "--check" ]; then
  DRIFT=0
  for pair in ".claude/commands|$TMP/claude" ".agents/skills|$TMP/skills"; do
    target=${pair%%|*}
    fresh=${pair##*|}
    if [ ! -d "$target" ]; then
      echo "DRIFT: $target is missing"
      DRIFT=1
    elif ! diff -ru "$target" "$fresh" > "$TMP/diff" 2>&1; then
      echo "DRIFT: $target does not match $MANIFEST:"
      sed "s|$TMP/claude|<regenerated>|; s|$TMP/skills|<regenerated>|" "$TMP/diff"
      DRIFT=1
    fi
  done
  if [ "$DRIFT" -ne 0 ]; then
    echo "Run os/scripts/gen-commands.sh to regenerate."
    exit 1
  fi
  echo "OK: adapters are current ($N command(s))"
else
  rm -rf .claude/commands .agents/skills
  mkdir -p .claude/commands .agents/skills
  cp -R "$TMP/claude/." .claude/commands/
  cp -R "$TMP/skills/." .agents/skills/
  echo "OK: $N command adapter(s) generated (.claude/commands, .agents/skills)"
fi
