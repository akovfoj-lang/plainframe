# <Area name>

<One sharp line: what this area covers and what belongs in it.>

**Goal:** <what healthy or done looks like for this area>

**Current state:** <what's true right now — keep this line honest; update it as things
change>

**Next:** <the next concrete step, or "nothing pending">

**Pointers:**

- <fact that lives elsewhere> — <path to its one home> (law 3: link, don't copy)
- <external or gitignored asset collection> — <path to its pointer page> (law 4)

**Fact provenance (optional).** A fact on this page may cite where it came from and how
solid it is — useful for anything `/ingest` or `/sweep` routed here, or just for
future-you. Attach a small block directly above the fact, HTML-comment-wrapped so it
renders invisibly:

    <!-- source: <where this came from> -->
    <!-- captured-at: YYYY-MM-DD -->
    <!-- confidence: low | medium | high -->

All three fields are optional, independently — a plain fact with no block is still valid.
When a fact arrived via `/ingest` or `/sweep`, its block also carries `<!-- trust: data -->`
(see `os/playbooks/ingest.md`) — that line means "unverified external material" (law 10),
not a confidence rating, so it sits alongside `confidence:` rather than replacing it.

<!-- Delete the angle-bracket placeholders as you fill them. Keep the page short:
if it grows past a screen, the detail probably wants its own file in this folder,
linked from here. -->
