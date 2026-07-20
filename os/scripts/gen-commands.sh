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
# README.md's command table is stamped between COMMANDS:BEGIN/END markers from
# the same records (skipped when the markers are absent) — no copy can drift.
# The manifest is validated first: every block complete, names unique,
# playbooks real — a half-written block is an error, never a silent skip.
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
trap 'rm -rf "$TMP" .claude/commands.new .agents/skills.new ".README.md.$$"' EXIT

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

# Validate before touching anything: a malformed block must fail loudly, not
# silently drop that command's adapters.
H=$(grep -cE '^## ' "$MANIFEST" || true)
R=$(wc -l < "$TMP/records"); R=$((R))
if [ "$R" -ne "$H" ]; then
  echo "ERROR: $MANIFEST has $H '## <name>' block(s) but only $R complete — each needs '- desc:' and '- playbook:'" >&2
  exit 1
fi
if cut -f1 "$TMP/records" | sort | uniq -d | grep -q .; then
  echo "ERROR: duplicate command names in $MANIFEST:" >&2
  cut -f1 "$TMP/records" | sort | uniq -d >&2
  exit 1
fi

mkdir -p "$TMP/claude" "$TMP/skills"

TAB=$(printf '\t')
N=0
while IFS="$TAB" read -r name desc pb; do
  case $name in
    ""|*[!a-z0-9-]*)
      echo "ERROR: bad command name '$name' in $MANIFEST (want [a-z0-9-])" >&2
      exit 1 ;;
  esac
  if [ ! -f "$pb" ]; then
    echo "ERROR: command '$name' references missing playbook '$pb'" >&2
    exit 1
  fi
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

# README table: regenerate between the COMMANDS markers from the same records.
have_markers=0
if [ -f README.md ] && grep -qF 'COMMANDS:BEGIN' README.md && grep -qF 'COMMANDS:END' README.md; then
  have_markers=1
  {
    printf '| Command | Playbook | What it does |\n'
    printf '|---------|----------|--------------|\n'
    while IFS="$TAB" read -r name desc pb; do
      printf '| `/%s` | `%s` | %s |\n' "$name" "$pb" "$desc"
    done < "$TMP/records"
  } > "$TMP/table"
  awk -v tf="$TMP/table" '
    /COMMANDS:BEGIN/ { print; while ((getline line < tf) > 0) print line; inside = 1; next }
    /COMMANDS:END/   { inside = 0 }
    !inside { print }
  ' README.md > "$TMP/README.new"
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
  if [ "$have_markers" -eq 1 ] && ! diff -u README.md "$TMP/README.new" > "$TMP/rdiff"; then
    echo "DRIFT: README.md command table does not match $MANIFEST:"
    cat "$TMP/rdiff"
    DRIFT=1
  fi
  if [ "$DRIFT" -ne 0 ]; then
    echo "Run os/scripts/gen-commands.sh to regenerate."
    exit 1
  fi
  echo "OK: adapters are current ($N command(s))"
else
  # Build both new trees fully, then swap — a failure mid-copy must never
  # leave either toolchain missing its adapters.
  rm -rf .claude/commands.new .agents/skills.new
  mkdir -p .claude .agents
  cp -R "$TMP/claude" .claude/commands.new
  cp -R "$TMP/skills" .agents/skills.new
  rm -rf .claude/commands .agents/skills
  mv .claude/commands.new .claude/commands
  mv .agents/skills.new .agents/skills
  if [ "$have_markers" -eq 1 ]; then
    NEWR=".README.md.$$"
    cp "$TMP/README.new" "$NEWR"
    mv "$NEWR" README.md
  fi
  echo "OK: $N command adapter(s) generated (.claude/commands, .agents/skills)"
fi
