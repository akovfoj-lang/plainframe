#!/usr/bin/env bash
# markers.sh — list EDIT: / Q: / IDEA: markers in the working tree.
#
# Usage: os/scripts/markers.sh
#
# Scans git-tracked files AND untracked-but-not-ignored ones, excluding MAP.md,
# STATUS.md, and os/scripts/ (.git is never tracked). Used by /sweep beat 1.
#
# Patterns — kept simple on purpose:
#   A marker counts at line start, after a list bullet, after a blockquote
#   mark, after a numbered-list marker, or after "<!--". Leading whitespace is
#   allowed. Obsidian auto-continues a list when you press Enter, so the most
#   ordinary way to type a marker — under an existing bullet — put it at an
#   indent, where a column-0-only pattern could not see it and the owner got
#   silence instead of an answer (PF-022). Anchoring to those openers still
#   avoids false hits like "FAQ:" and prose that merely MENTIONS a marker.
#
# Prints file:line:text grouped by marker type, then a summary count.
#
# Hits are prefixed "[untrusted origin]" when the marker sits in unverified
# external material (law 10): anything under inbox/, plus any routed block
# still carrying the ingest/sweep provenance envelope (a "trust: data" line —
# see os/playbooks/ingest.md). /sweep never acts on a tagged marker; it only
# reports it. Two properties that gate matters:
#
#   Taint is BLOCK-scoped, not file-scoped (PF-023). A "trust: data" line
#   taints the lines below it until the next Markdown heading or the next
#   "source:" line — the two things that end a routed block. Tainting the
#   whole file instead meant one routed fact landing in an area page
#   permanently disabled the marker track for that page, so the feature
#   quietly stopped working on exactly the pages that receive routed facts.
#   Files under inbox/ are still tainted whole: nothing in there is the
#   owner's own writing.
#
#   The tag is decided per file, while the path is still a variable, and
#   baked in at emit time (PF-024). It used to be re-derived from the emitted
#   "path:line:text" record by cutting at the first ":" — but a path may
#   legally contain a colon ("inbox/2026-07-31 10:15 clipped.md"), which
#   yielded a truncated key that matched nothing and silently dropped the
#   tag. A dropped tag reads as "the owner wrote this", which is the exact
#   law-10 breach the tag exists to prevent.

set -eu
if (set -o pipefail) 2>/dev/null; then set -o pipefail; fi
LC_ALL=C
export LC_ALL

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: not a git repo — markers.sh enumerates files through git" >&2
  exit 1
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/markers.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

# NUL-delimited: a filename with a newline in it must not split into two paths.
#
# Two enumerations, one list. --cached is every committed file, as before.
# --others --exclude-standard adds files that exist but have never been
# committed: a note typed into Obsidian this morning is untracked until the
# next /sync, so tracked-only enumeration made the most ordinary marker
# invisible (PF-021). The two sets are disjoint, so no dedup is needed.
#
# --exclude-standard keeps .gitignore'd paths unscanned, so .env* and friends
# are never read and .obsidian/ never becomes noise. It is NOT a scope
# boundary, though: --others recurses into any untracked directory .gitignore
# does not happen to name — a vault-local .trash/, a venv/, a vendored copy of
# someone else's docs. The template ignores .trash/ for that reason, because
# resurfacing a marker out of a deliberately deleted note is worse than
# missing it. Everything else is still *reported*; what gates *acting* on a
# marker is sweep.md's M1, which requires a repo-owned location, not this list.
{
  git ls-files -z --cached
  git ls-files -z --others --exclude-standard
} > "$TMP/files0"

# Apply the exclusions, then hand the survivors to ONE awk. Doing the taint
# tracking and the tagging per file in separate processes cost two forks per
# file — 25s on a 2000-note vault, for a command meant to run at the top of
# every /sweep (PF-025). The loop below forks nothing: `case` and `printf` are
# both shell builtins, and the redirect is opened once for the whole loop.
#
# Every path is emitted with a "./" prefix. awk reads an operand of the form
# name=value as a variable assignment rather than a filename, so a note called
# "a=b.md" would silently never be scanned; "./" makes the operand start with a
# character that cannot begin an identifier, and as a bonus stops a file named
# "-x.md" from being read as a flag.
{
  while IFS= read -r -d '' f; do
    case $f in MAP.md|STATUS.md|os/scripts/*) continue ;; esac
    [ -f "$f" ] || continue
    printf './%s\0' "$f"
  done < "$TMP/files0"
} > "$TMP/scan0"

# Tracks provenance-block taint as it goes and bakes the tag into each hit, so
# nothing downstream has to re-parse a path. State resets on FNR==1, so one awk
# can walk every file; xargs may still split the list into several batches on a
# very large vault, which is harmless for exactly that reason.
MARKER_AWK='
# Hits are buffered per file and only flushed once the whole file has been read
# without a non-text byte turning up. That reproduces grep -I, which suppressed
# every match in a file it judged binary rather than deciding line by line: a
# plain-ASCII line sitting inside a .bin is still not prose.
#
# "Non-text" means a control character other than tab or CR — NOT "outside
# [[:print:]]". This script runs under LC_ALL=C, where [[:print:]] is
# single-byte ASCII only, so a printability test condemns every note
# containing an em dash, a curly quote, an accent or an emoji — which is most
# real notes. Testing for control characters instead leaves UTF-8 alone: its
# continuation bytes are all >= 0x80, well clear of the C0 range. Tab and CR
# are excluded because both occur in ordinary text (CR from CRLF files), and
# they are stripped only on the rare line that trips the cheap outer test.
function flush(  i) {
  if (!binary) for (i = 1; i <= nbuf; i++) print buf[i]
  nbuf = 0
  binary = 0
}
BEGIN {
  # A marker opener: any run of bullets/quotes/numbers, then an optional
  # HTML-comment start. Kept as one string so all three patterns share it.
  pfx = "^[[:space:]]*([-*+>][[:space:]]*|[0-9]+[.)][[:space:]]+)*(<!--[[:space:]]*)?"
  reEDIT = pfx "EDIT:"
  reIDEA = pfx "IDEA:"
  reQ    = pfx "Q:"
  nbuf = 0
  binary = 0
}
FNR == 1 {
  flush()
  path = FILENAME
  sub(/^\.\//, "", path)
  # A filename with an embedded newline would split one hit across two physical
  # lines and double-count it downstream (wc -l counts newlines, not hits)
  # (PF-020). Sanitize for display only; awk opened the real path itself.
  disp = path
  gsub(/\n/, " ", disp)
  wholen = (path ~ /^inbox\//) ? 1 : 0
  tainted = wholen
}
{
  if (!binary && $0 ~ /[[:cntrl:]]/) {
    probe = $0
    gsub(/[\t\r]/, "", probe)
    if (probe ~ /[[:cntrl:]]/) binary = 1
  }
  if (!wholen) {
    # A new provenance block starts at its source: line, so taint resets
    # there; a heading ends whatever block was open.
    if ($0 ~ /^[[:space:]]*(<!--[[:space:]]*)?source:/) tainted = 0
    else if ($0 ~ /^[[:space:]]*#+[[:space:]]/) tainted = 0
    if ($0 ~ /^[[:space:]]*(<!--[[:space:]]*)?trust:[[:space:]]*data([[:space:]]*-->)?[[:space:]]*$/) {
      tainted = 1
      next
    }
  }
  if ($0 !~ reEDIT && $0 !~ reIDEA && $0 !~ reQ) next
  p = tainted ? "[untrusted origin] " : ""
  if ($0 ~ reEDIT)      buf[++nbuf] = sprintf("EDIT:\t%s%s:%d:%s", p, disp, FNR, $0)
  else if ($0 ~ reIDEA) buf[++nbuf] = sprintf("IDEA:\t%s%s:%d:%s", p, disp, FNR, $0)
  else                  buf[++nbuf] = sprintf("Q:\t%s%s:%d:%s", p, disp, FNR, $0)
}
END { flush() }
'

: > "$TMP/hits"
if [ -s "$TMP/scan0" ]; then
  xargs -0 awk "$MARKER_AWK" < "$TMP/scan0" >> "$TMP/hits" || true
fi

TOTAL=0

emit() {
  em_label=$1
  awk -v lbl="$em_label" -F '\t' '$1 == lbl { print substr($0, length(lbl) + 2) }' \
    "$TMP/hits" > "$TMP/group"
  cnt=$(wc -l < "$TMP/group"); cnt=$((cnt))
  echo "## $em_label ($cnt)"
  if [ "$cnt" -gt 0 ]; then
    # The tag is part of the sorted record, so untrusted hits group together
    # rather than interleaving by path. Deterministic either way, and the
    # grouping is the more useful reading order.
    sort "$TMP/group"
  fi
  echo ""
  TOTAL=$((TOTAL + cnt))
}

emit "EDIT:"
emit "Q:"
emit "IDEA:"

echo "OK: $TOTAL marker(s) found"
