# Delegate

How to hand work to a helper — a subagent, a workflow, another session, another model
(Gemini, Codex) — without spending the owner's usage for nothing or losing the result.
Read it before starting one. The main session directs and judges; helpers on a smaller
model do the bulk.

Why it is strict: a fan-out launched without a stated cost can run into the usage limit and
return nothing, and a helper whose session closes dies with it.

## Before

1. Say what it will cost — tokens, and the share of the usage window — and get a yes, even
   when a skill or a mode favours fan-out. Estimate from the budgets below; until a kind of
   helper has a row there, say the estimate is a guess.
2. One helper at a time, with a narrow brief. Parallel only when the owner asks; then size
   each wave to the room left in the window, say so, and save as you go.
3. Launch a big helper right after a usage window resets, never late in one: a helper that
   hits the limit returns nothing until it is resumed.
4. Bulk work goes to a helper on a smaller model: reading many files or images, content
   packs, long mechanical runs. This session keeps whatever needs exact bytes or a
   judgement: protected-path edits, wording the owner approves, what ships. Separate
   sessions share the same limit, so splitting work across them saves nothing.

## The brief must require

5. No return until the results are complete and verified — an "in progress" reply holds
   nothing. Name what a full report holds: per-item results, totals, the verbatim text of
   any failure. If its own background run dies, it reruns in the foreground, in chunks.
6. Working files in a lasting folder, never /tmp, and each finished part saved where it
   belongs as it goes.
7. Short replies, and no single write over about 400 lines or 25k characters.
8. One unit finished before the next starts.
9. A workflow subagent cannot write report files: its report goes in a structured-output
   field (for example `report_markdown`); its scripts and data files still save.

## While it runs, and after

10. Keep this session open and uncleared. A helper dies with the session that started it,
    and only that session can resume it.
11. If it stops at the usage limit, wake after the reset with a loop on the wall clock
    (`date`), never a bare `sleep N`, which runs late when the machine sleeps. Resume it
    with the same requirements restated; never assume it remembers them.
12. A helper's report is a claim: check its files and results before telling the owner the
    work is done.

## Budgets (tokens)

Add each helper you measure here: what it did, what it took, and the budget to plan the
next one with. Estimate a new kind of helper from the nearest row.

| Helper | Measured | Budget |
|---|---|---|

Receipt: none for the delegating itself — the helper's work leaves its own receipt when it
is synced.
