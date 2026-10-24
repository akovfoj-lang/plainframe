# shellcheck shell=bash
# json.sh — just enough JSON reading for the Claude Code hooks in
# os/scripts/claude-hooks/, without jq: Plainframe needs git and a POSIX
# shell, nothing else.
#
# Sourced, not executed. Provides:
#
#   json_str KEY      prints the first string value of "KEY" in the JSON on
#                     stdin, unescaped (\" \\ \/ \n \t; \uXXXX is left as
#                     written). Exit 1 when there is no such string. Inside a
#                     JSON string every quote is escaped, so a key spelled out
#                     in some file's content can never be mistaken for one.
#
#   json_after KEY    prints the raw JSON text after the first "KEY": — the
#                     hooks use it to look at a tool's response and not at
#                     the request that asked for it.

json_str() {
  LC_ALL=C awk -v key="$1" '
    { buf = buf $0 "\n" }
    END {
      if (!match(buf, "\"" key "\"[ \t\r\n]*:[ \t\r\n]*\"")) exit 1
      s = substr(buf, RSTART + RLENGTH); n = length(s); out = ""
      for (i = 1; i <= n; i++) {
        c = substr(s, i, 1)
        if (c == "\\") {
          i++; d = substr(s, i, 1)
          if (d == "n") out = out "\n"; else if (d == "t") out = out "\t"
          else if (d == "u") out = out "\\u"; else out = out d
          continue
        }
        if (c == "\"") { printf "%s", out; exit 0 }
        out = out c
      }
      exit 1
    }'
}

json_after() {
  LC_ALL=C awk -v key="$1" '
    { buf = buf $0 "\n" }
    END {
      if (!match(buf, "\"" key "\"[ \t\r\n]*:")) exit 1
      printf "%s", substr(buf, RSTART + RLENGTH)
    }'
}
