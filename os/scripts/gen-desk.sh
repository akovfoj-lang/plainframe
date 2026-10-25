#!/usr/bin/env bash
# gen-desk.sh — write DESK.md, the one page to open when you sit down.
#
# Usage: os/scripts/gen-desk.sh          regenerate DESK.md in place
#        os/scripts/gen-desk.sh --check  exit 1 (writing nothing) if DESK.md is stale
#
# MAP.md answers "where does a fact live". STATUS.md answers "what happened".
# DESK.md answers "what do I do next, and where was I" — the question neither
# of the other two is shaped to answer.
#
# It reports, never infers (law 6). Everything here is lifted verbatim from a
# source file that already owns it (law 3): build pages own their own Next line,
# workspace notes own their status and blocker, handoffs own their titles, the
# ledger owns its drafts. DESK copies none of it into a second home — it is an
# index with pointers, regenerated from the tree.
#
# Handoff chains: this repo's own os/handoffs/, plus every satellite in
# os/satellites.txt that keeps a chain (docs/handoffs/ or os/handoffs/). Chains
# are ordered by filename, which is why the naming rule is date-first. A
# satellite's chain counts only its committed handoffs (PF-032): a page that
# exists on one disk only is not a place another machine can pick up from, and
# a draft another session just wrote must not change this repo's DESK.
# A satellite that is not on this machine is listed as unavailable, never
# silently dropped.
#
# Waiting on you also names a satellite whose uncommitted work is more than a
# day old (PF-041): sync.sh skips a dirty satellite until the owner has looked,
# so without this line it could sit unsynced, on one disk, for weeks.
#
# --check compares everything except the lines that describe other repos'
# live state — satellite chains and satellite uncommitted work — the same
# split gen-status.sh makes for its own satellite lines: they move with no
# change to this repo, and the pre-commit hook must never block a commit here
# because a sibling repo wrote a file (PF-032).
# Output is deterministic (LC_ALL=C, stable glob order).
# DESK.md is only ever written by this script (law 6).

set -eu
if (set -o pipefail) 2>/dev/null; then set -o pipefail; fi
LC_ALL=C
export LC_ALL

case "${1:-}" in
  ""|--check) ;;
  *) echo "usage: os/scripts/gen-desk.sh [--check]" >&2; exit 2 ;;
esac

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

TMP=$(mktemp -d "${TMPDIR:-/tmp}/gen-desk.XXXXXX")
trap 'rm -rf "$TMP" ".DESK.md.$$"' EXIT

# shellcheck source=lib/fs.sh
. "$ROOT/os/scripts/lib/fs.sh"

# First H1 of a file, with the leading "# " stripped. Empty if there is none.
file_h1() {
  awk '/^# / { sub(/^# /, ""); sub(/\r$/, ""); print; exit }' "$1" 2>/dev/null || true
}

# The value of a bold label, unwrapped onto one line. Source pages wrap at ~90
# columns, so a value routinely spans several physical lines; taking only the
# first silently truncates it mid-sentence. Accumulate until a blank line, a new
# bold label, or a list/heading starts.
field() {
  awk -v lbl="$2" '
    BEGIN { on = 0 }
    on {
      if ($0 ~ /^[[:space:]]*$/ || $0 ~ /^\*\*[A-Za-z]/ || $0 ~ /^[-*#|] / || $0 ~ /^[0-9]+\. /) exit
      sub(/^[[:space:]]+/, ""); buf = buf " " $0; next
    }
    $0 ~ "^\\*\\*" lbl ":\\*\\*" {
      sub("^\\*\\*" lbl ":\\*\\*[[:space:]]*", "")
      buf = $0; on = 1
    }
    END { gsub(/^_|_$/, "", buf); gsub(/[[:space:]]+/, " ", buf)
          sub(/^[[:space:]]+/, "", buf); print buf }' "$1" 2>/dev/null || true
}

# Trim a long value to a readable length for the desk, on a word boundary.
trim() {
  awk -v n="${2:-160}" '{ if (length($0) <= n) { print; exit }
    s = substr($0, 1, n); sub(/[^ ]*$/, "", s); sub(/[[:space:],.;:—-]+$/, "", s)
    print s " …" }' <<EOF
$1
EOF
}

# A note's status: line, or empty.
status_of() {
  awk 'sub(/^status:[[:space:]]*/, "") { sub(/[[:space:]]+$/, ""); print; exit }' "$1"
}

# Handoff files in a directory, one per line, sorted (dates lead, so the last
# line is the newest). This repo's own chain reads the tree as it stands — the
# pre-commit hook validates an export with no .git, and a new handoff is in
# the tree before it is committed. A satellite's chain is its committed
# handoffs only (PF-032); outside git it falls back to the files.
handoffs_in() {
  if [ "${2:-}" = tracked ] && git -C "$1" rev-parse --git-dir >/dev/null 2>&1; then
    # -z: git quotes and escapes a name it prints plain (non-ASCII, a quote,
    # a backslash), and the quoted form would never match the folder.
    git -C "$1" ls-files -z -- "$3" 2>/dev/null | tr '\0' '\n' \
      | awk -v d="$3/" 'index($0, d) == 1 { r = substr($0, length(d) + 1)
          if (r !~ /\// && r ~ /\.md$/ && r != "README.md") print $0 }' | sort
  else
    find "$1/$3" -maxdepth 1 -type f -name '*.md' ! -name 'README.md' 2>/dev/null \
      | sed "s|^$1/||" | sort
  fi
}

satellites() { satellite_list; }

generate() {
  printf '<!-- GENERATED — do not hand-edit. Regenerate: os/scripts/gen-desk.sh -->\n\n'
  printf '# DESK\n\n'
  printf 'What to do next, and where you left off. MAP says where things live; STATUS says\n'
  printf 'what happened; this says what is in front of you.\n'

  # -- Waiting on you --------------------------------------------------------
  printf '\n## Waiting on you\n\n'
  : > "$TMP/wait"
  if [ -d workspace ]; then
    for f in workspace/*.md; do
      [ -f "$f" ] || continue
      case "$f" in workspace/README.md) continue ;; esac
      [ "$(status_of "$f")" = "open" ] || continue
      bl=$(field "$f" "Blocked on")
      # The note template's convention: "owner" as the first word. A free-text
      # mention ("the property owner", "the owner already approved") is not.
      case $(printf '%s' "$bl" | tr '[:upper:]' '[:lower:]') in
        owner|owner[!a-z]*) printf -- '- **%s** — [%s](%s)\n' "$(file_h1 "$f")" "$f" "$f" >> "$TMP/wait" ;;
      esac
    done
  fi
  if [ -f os/decisions.md ]; then
    draft_decisions os/decisions.md | while IFS= read -r h; do
      printf -- '- **Draft decision, void until you confirm** — %s — [os/decisions.md](os/decisions.md)\n' "$h"
    done >> "$TMP/wait"
  fi
  now=$(date +%s)
  satellites > "$TMP/sats"
  while IFS= read -r p; do
    git -C "$p" rev-parse --git-dir >/dev/null 2>&1 || continue
    od=$(oldest_dirty "$p") || od=""
    [ -n "$od" ] || continue
    e=${od#* }
    [ "$e" -gt 0 ] && [ $((now - e)) -gt 86400 ] || continue
    printf -- '- **%s: %s uncommitted file(s) since %s** — nothing syncs them until you look: commit them (sync with SATELLITE-CONFIRMED) or move them — `git -C %s status`\n' \
      "$(basename "$p")" "${od%% *}" "$(epoch_date "$e")" "$p" >> "$TMP/wait"
  done < "$TMP/sats"
  if [ -s "$TMP/wait" ]; then
    cat "$TMP/wait"
  else
    printf -- '- nothing — no open question is blocked on you\n'
  fi

  # -- Projects --------------------------------------------------------------
  printf '\n## Projects\n\n'
  found=0
  if [ -d areas/builds ]; then
    for f in areas/builds/*.md; do
      [ -f "$f" ] || continue
      case "$f" in areas/builds/README.md) continue ;; esac
      found=1
      printf -- '### %s\n\n' "$(file_h1 "$f")"
      printf -- '- page — [%s](%s)\n' "$f" "$f"
      goal=$(field "$f" "Goal")
      case "$goal" in
        ""|*"not set"*) printf -- '- goal — **not set**\n' ;;
        *) printf -- '- goal — %s\n' "$(trim "$goal" 140)" ;;
      esac
      nx=$(field "$f" "Next")
      [ -n "$nx" ] && printf -- '- next — %s\n' "$(trim "$nx" 200)"
      printf '\n'
    done
  fi
  [ "$found" -eq 1 ] || printf -- '(no build pages yet — add one in areas/builds/)\n'

  # -- Handoff chains --------------------------------------------------------
  printf '\n## Where you left off\n\n'
  printf 'The newest handoff in each chain, by its own title — not its filename.\n\n'
  : > "$TMP/chains"
  if [ -d os/handoffs ]; then
    handoffs_in . files os/handoffs > "$TMP/h"
    n=$(wc -l < "$TMP/h" | tr -d ' ')
    h=$(tail -n 1 "$TMP/h")
    if [ -n "$h" ]; then
      printf -- '- **this repo** (%s in chain) — %s\n  [%s](%s)\n' \
        "$n" "$(file_h1 "$h")" "$h" "$h" >> "$TMP/chains"
    fi
  fi
  while IFS= read -r p; do
    name=$(basename "$p")
    if [ ! -d "$p" ]; then
      # Say so: a chain that silently disappears reads as "no chain", which
      # is a different fact (law 6 — report, never infer).
      printf -- '- **%s** — unavailable here: `%s` is not on this machine\n' \
        "$name" "$p" >> "$TMP/chains"
      continue
    fi
    for sub in docs/handoffs os/handoffs; do
      [ -d "$p/$sub" ] || continue
      handoffs_in "$p" tracked "$sub" > "$TMP/h"
      n=$(wc -l < "$TMP/h" | tr -d ' ')
      [ "$n" -gt 0 ] || continue
      h=$(tail -n 1 "$TMP/h")
      printf -- '- **%s** (%s in chain) — %s\n  `%s`\n' \
        "$name" "$n" "$(file_h1 "$p/$h")" "$p/$h" >> "$TMP/chains"
    done
  done < "$TMP/sats"
  if [ -s "$TMP/chains" ]; then
    cat "$TMP/chains"
  else
    printf -- '- no handoff chains yet\n'
  fi

  # -- Open questions --------------------------------------------------------
  # Open ones only: a settled note's call already lives in os/decisions.md, so
  # listing it here as blocked on anyone was a fact that had stopped being true.
  printf '\n## Open questions\n\n'
  : > "$TMP/q"
  if [ -d workspace ]; then
    for f in workspace/*.md; do
      [ -f "$f" ] || continue
      case "$f" in workspace/README.md) continue ;; esac
      st=$(status_of "$f")
      [ -n "$st" ] || st="(no status)"
      [ "$st" != settled ] || continue
      bl=$(field "$f" "Blocked on")
      [ -n "$bl" ] || bl="—"
      printf -- '- [%s] **%s** — blocked on %s — [%s](%s)\n' \
        "$st" "$(file_h1 "$f")" "$bl" "$f" "$f" >> "$TMP/q"
    done
  fi
  if [ -s "$TMP/q" ]; then cat "$TMP/q"; else printf -- '- none open\n'; fi

  # -- Flags -----------------------------------------------------------------
  printf '\n## Flags\n\n'
  if [ -f os/roadmap.md ] && [ -n "$(open_flags os/roadmap.md)" ]; then
    open_flags os/roadmap.md | sed 's/^/- /'
  else
    printf -- '- none\n'
  fi

  printf '\n---\n\n'
  printf 'Sources: `areas/builds/`, `workspace/`, `os/handoffs/`, satellite handoff chains\n'
  printf 'listed in `os/satellites.txt`, `os/decisions.md` drafts, and `FLAG:` lines in\n'
  printf '`os/roadmap.md`. Each fact lives in the file linked beside it (law 3).\n'
}

generate > "$TMP/DESK.md"

# Basenames of every satellite, "/"-separated (a basename cannot contain "/",
# and a raw newline in `awk -v` is a syntax error in BSD awk).
sat_names() {
  satellites | while IFS= read -r p; do printf '%s/' "$(basename "$p")"; done
}

# Drop what describes other repos' live state: each satellite's chain entry
# (its bullet and the indented line under it), each satellite's uncommitted-
# work line, and the "no chains" / "nothing waiting" placeholders that can
# stand in for them. Everything about this repo is compared strictly.
strip_live() {
  awk -v names="$2" '
    BEGIN { n = split(names, a, "/")
            for (i = 1; i <= n; i++) if (a[i] != "") {
              key["- **" a[i] "** "] = 1; key["- **" a[i] "** —"] = 1; key["- **" a[i] ": "] = 1 } }
    skip && /^  / { next }
    { skip = 0 }
    /^- \*\*/ { for (k in key) if (index($0, k) == 1) { skip = 1; next } }
    n > 0 && ($0 == "- no handoff chains yet" || $0 == "- nothing — no open question is blocked on you") { next }
    { print }' "$1"
}

if [ "${1:-}" = "--check" ]; then
  if [ ! -f DESK.md ]; then
    echo "STALE: DESK.md is missing. Run os/scripts/gen-desk.sh."
    exit 1
  fi
  names=$(sat_names)
  strip_live DESK.md "$names" > "$TMP/cur"
  strip_live "$TMP/DESK.md" "$names" > "$TMP/new"
  if diff -u "$TMP/cur" "$TMP/new" > "$TMP/diff"; then
    echo "OK: DESK.md is current"
  else
    echo "STALE: DESK.md is out of date (current vs regenerated, other repos' live lines ignored):"
    cat "$TMP/diff"
    echo "Run os/scripts/gen-desk.sh to regenerate."
    exit 1
  fi
else
  NEW=".DESK.md.$$"
  cp "$TMP/DESK.md" "$NEW"
  mv "$NEW" DESK.md
  echo "OK: DESK.md written"
fi
