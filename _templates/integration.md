# Integration: <tool name>

<One line: what this tool does for the system.>

**Scope:** <exactly what an agent may do with it — start read-only. Widening scope later
is a fresh Ask-first (law 7), never a silent upgrade.>

**Autonomy:** <which tier its actions sit in: Free / Ask-first / Never. This page may
tighten a tier from the CLAUDE.md table, never loosen one.>

**Key location:** name goes in `.env.example` as `<KEY_NAME>=`, value goes in `.env`
(gitignored) and in the owner's password manager. Printing the value into a file or chat
is Never-tier.

**Went live:** <YYYY-MM-DD> — listed under Live in os/integrations/README.md the same day.

**Notes:**

- <quirks, limits, gotchas — one line each>

<!-- Create this page only when the integration goes live (os/playbooks/add-integration.md).
Candidates stay as a list line in os/integrations/README.md until then. -->
