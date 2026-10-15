---
name: deepen
description: Turns a task into the deeper version a top professional would do, before any work starts. Names what that professional would do that wasn't asked for, the rawest source material they would start from, the named methods and tools of the field, and an outside check that would prove the result right; then rewrites the user's prompt to ask for exactly that, and stops. Deeper, not bigger. Use when the user types /deepen before or after a request, or says "deepen this", "deeper version", "go deeper" or "how would a pro do this".
---

<!-- This playbook is also a portable skill: the header above is what claude.ai and
Claude Code read. Link it into ~/.claude/skills/deepen/SKILL.md, or zip it as
deepen/SKILL.md and upload it at claude.ai > Customize > Skills. Keep the header to
name and description — claude.ai rejects other header fields. -->

# Deepen

Make the task deeper, not bigger: the same outcome, done to the standard of the best
person in that field. Hand back a better prompt. Do not do the task itself.

## Find the task

- The task is everything the user wrote around /deepen, before it or after it. In Claude
  Code, text typed after `/deepen` arrives as `ARGUMENTS:`.
- If /deepen came alone, take the user's most recent request in this conversation. If
  there is none, ask for the task in one line and stop.
- Keep the user's goal, deliverable and limits exactly. You are raising the standard, not
  changing the job.

## Name the field

One line: the specific professional whose job this is ("a skip-trace analyst for an
outbound real-estate call team", not "an expert"). If the task spans two fields, name the
one whose standard decides whether the result is good.

## The four answers

Two to four bullets each, concrete, in plain words. Explain any term a non-specialist
would not know, in a few words.

1. **What they would do that wasn't asked.** Moves that change the result, not polish:
   the question they ask first, the failure they guard against, the step amateurs skip.
   One clause each on why it matters.
2. **The rawest material.** What they would start from instead of what has already been
   summarised, filtered or interpreted: the original record, the full export, the primary
   source, the actual transcript, the measurements. For each, say where it lives and
   whether it can be reached from here. Check cheaply when you can (a named file exists,
   a connector is attached); do not go searching for it.
3. **Methods and tools, by name.** The field's actual named methods, standards,
   checklists and software, never "analyse carefully". Name only what you are confident
   exists; mark anything uncertain "(check)".
4. **The outside check.** Something other than Claude or the user that would show the
   result is right: a test that passes or fails, a published standard, a measurement
   against reality, an independent source, a third party's verdict, an outcome in the
   world. Say how to run it and what passing looks like. "Looks right to me" does not
   count, from either of us.

## Rewrite the prompt

Then write the new prompt in the user's own voice, ready to paste, in one fenced block:

- It asks for the same deliverable, with the four answers turned into instructions: do
  these unasked things, start from this material, use these methods, prove it with this
  check.
- It names concrete things (files, sources, tools), not categories.
- It says what "done" looks like, including the outside check passing.
- It stays deeper, not bigger. Cut any line that adds a new deliverable instead of
  raising the standard of the existing one. Aim for at most about twice the original's
  length.

## Stop

End with one line after the prompt: "Say **go** to run it, or edit it first." Do not
start the work until the user says so.

If a top professional would do nothing different, say so in one line, hand the prompt
back unchanged, and stop.

Deepening changes no files, so in a Plainframe repo it leaves no receipt (law 9 covers
state-changing work only). Running the rewritten prompt afterwards is ordinary work and
leaves its own.

## Example

Task: "mark the repeated phone numbers in this cold-call sheet light blue".

- Field: a data-hygiene analyst for an outbound call team.
- Unasked: put every number in one format before comparing (+1, dashes, call notes typed
  after the number), or real repeats slip through; decide which copy stays black (the
  one with the most data, not just the first).
- Rawest material: the original skip-trace export, not the tab someone already cleaned.
- Methods: E.164 phone formatting (the +1XXXXXXXXXX standard); a count reconciliation,
  where rows before = black rows + blue rows.
- Outside check: a second, independent script counts the repeats from the raw export
  and must arrive at the same number; then read back every cell's colour against the
  plan, with zero mismatches.
