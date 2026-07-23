# Add integration

Take a tool from candidate to live. Read-only first.

1. The registry is the list in `os/integrations/README.md` — a tool that is not there does not exist. Add it as a one-line candidate first.
2. Going live — and every widening of scope later — is Ask-first (law 7): draft everything, then get an explicit yes in-session before it takes effect.
3. Create the integration page from `_templates/integration.md` only when the tool actually goes live. Candidates get a line, not a page.
4. Keys: the NAME goes in `.env.example` with a one-line comment; the VALUE goes in `.env` (gitignored) and the owner's password manager. If `.env` doesn't exist yet, the owner creates it once with `cp .env.example .env` — never ask the agent to run that copy or to type a real value into `.env`; the owner types values in by hand. Secret values never appear in tracked files or chat — that is Never-tier.
5. Start with read-only scope. Prove the tool useful before asking for write access.
6. Widening scope is a fresh Ask-first — a yes to read is not a yes to write.
7. The integration page may tighten the autonomy table for its tool, never loosen it (law 7).
8. Move the tool's line from Candidates to Live in the registry, linking its page.

Receipt: append `YYYY-MM-DD add-integration: <summary>` to os/worklog.md.
