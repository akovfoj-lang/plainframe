# Areas

Your actual life and work: one folder per domain, each with a README saying what it is, what's true now, and where its stuff lives.

An area is a domain you're committed to — a project, a role, a part of life. Not a task
(too small), not "everything" (too big). If it has a goal and a current state, it's an
area.

Rules:

- One folder per area, named plainly: `areas/<name>/`.
- Every area has a README.md — start from _templates/area.md. Keep it short: goal,
  current state, next step, pointers.
- A fact lives in exactly one place (law 3). If two areas need the same fact, one owns
  it and the other links to it.
- Big, binary, or external assets stay out of git; each collection gets one tracked
  pointer page (law 4). areas/example-project/assets.md shows the shape.
- A finished or dead area moves to archive/ — it is never deleted in place.

This directory starts nearly empty on purpose. areas/example-project/ shows the shape;
replace it with your first real area.
