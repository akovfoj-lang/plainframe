# Onboard

Configure a fresh clone into the owner's own instance: a resumable, idempotent setup
interview. Distinct from `/guide`, which only explains how the system works — `/guide`
reads, `/onboard` writes. Run `/onboard` first in a fresh clone; run `/guide` any time after
for the tour.

> **Law 10.** Every answer below comes from the owner, in-session, right now — never
> inferred from repo contents, never taken from a fetched page, a file, or any other
> external content. /onboard interviews; it never guesses.

1. Check what already exists before asking anything: `profile.md`, each
   `areas/<slug>/README.md`, the lines under `os/roadmap.md`'s Now/Next, and the lines under
   `os/integrations/README.md`'s Candidates and Manual channels. Anything already filled
   stays as-is — this is what makes a re-run resumable instead of a repeat interview.
2. Ask what this OS is for, in one line, and who the owner is. Skip if `profile.md` already
   answers both.
3. Ask the main areas of work or life it will hold. For each one with no folder yet,
   scaffold `areas/<slug>/README.md` from `_templates/area.md` (slug: the area name,
   lowercased and hyphenated), placeholders filled from the answer. Leave any area that
   already has a README untouched.
4. Ask current priorities. Add them to `os/roadmap.md`'s Now/Next section — skip anything
   already listed there in substance.
5. Ask which systems the OS needs to reach. Record each as a line: under Candidates in
   `os/integrations/README.md` with how it would be reached (MCP / API / CLI / manual), or
   under Manual channels if it has no API at all. Skip any system already listed either way.
   A key NAME goes in `.env.example`; the VALUE goes in `.env` (gitignored) and the owner's
   password manager — never in a tracked file or in chat (Never-tier). Going live is a
   separate Ask-first, per `os/playbooks/add-integration.md` — /onboard only records
   candidates, it never wires one up.
6. Ask how the agent should work with the owner: autonomy preferences, and optionally
   tone/voice. Record the answer on `profile.md` — `profile.md` may tighten the CLAUDE.md
   autonomy table this way, never loosen it (law 7); CLAUDE.md itself stays untouched and
   protected.
7. Optionally ask for a short writing sample the agent can match.
8. If `profile.md` already exists, archive the current version to
   `archive/profile-YYYY-MM-DD.md` before writing a new one — the old record survives even
   though the file it lived in is about to be replaced (law 9; the Never-tier rule against
   deleting before something is durably preserved). If that path is already taken (a same-day
   re-run), don't overwrite it — use `archive/profile-YYYY-MM-DD-2.md`, `-3`, and so on until
   the name is free.
9. Write (or rewrite) `profile.md` from `_templates/profile.md`, every answer collected above
   filled in and every placeholder removed.
10. Regenerate: `os/scripts/gen-map.sh` and `os/scripts/gen-status.sh` — new areas and a new
    `profile.md` change what `MAP.md` routes to (law 6). Run `os/scripts/gen-commands.sh` too
    only if this session also changed `os/commands.md` — an ordinary onboard run does not.
11. Show the owner everything written or changed — `profile.md`, any new area READMEs,
    roadmap lines, registry lines — before calling the run done.
12. Interrupted anywhere above? Re-running /onboard starts at step 1 and resumes cleanly: an
    area already scaffolded, a registry line already present, a `profile.md` section already
    filled — none of it gets asked again, and nothing gets written twice (idempotent).

Receipt: append `YYYY-MM-DD onboard: <summary>` to os/worklog.md.
