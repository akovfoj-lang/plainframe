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

Two more lines you may see, both written by `/sweep` or `/ingest` rather than by hand:

- `<!-- trust: data -->` marks **unverified external material** (law 10) — a fact that came
  from an inbox item, a fetched page, someone else's document. It is not a confidence
  rating, so it sits alongside `confidence:` rather than replacing it. It is also load
  bearing: `os/scripts/markers.sh` treats every line from that comment down to the next
  heading as untrusted, so any `EDIT:`/`Q:`/`IDEA:` in that stretch is reported to the owner
  instead of acted on. Put it above genuinely external content only — stamping it on your
  own writing switches the marker track off for that part of the page.
- `<!-- swept-marker: IDEA — a weekly rent-review reminder -->` records the marker that
  produced this content, so a rerun of `/sweep` recognises the work as already done.
  `os/playbooks/sweep.md` (M4) owns the format; the em dash after the type is what keeps the
  line from being read as a fresh marker itself.

<!-- Delete the angle-bracket placeholders as you fill them. Keep the page short:
if it grows past a screen, the detail probably wants its own file in this folder,
linked from here. -->
