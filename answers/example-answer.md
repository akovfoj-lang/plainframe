# Does a git pre-commit hook run on `git commit --no-verify`?

**Short answer:** No. `--no-verify` skips `pre-commit` and `commit-msg` entirely, and
leaves no record in the commit that it was used. Hooks are a guardrail, not a security
boundary.

**The longer version:** this is why `CLAUDE.md` describes the protected-path hooks as
break-glass-able and says so out loud rather than claiming they enforce law 7 absolutely.
Anything that must not be bypassed has to be checked somewhere the committer does not
control — a server-side hook or CI. For a single-operator repo, the honest position is
that the hook stops accidents, not intent.

**What I checked:** `git help hooks` on the local install; the behaviour reproduced
directly by committing a staged stale generated file with and without the flag.

**Checked:** 2026-07-24

**Confidence:** high — reproduced locally, and it matches the documented behaviour.

**Re-check when:** never for the core behaviour; it has been stable for the life of git.
Re-check the *list* of hooks `--no-verify` covers if you start relying on a hook other than
`pre-commit` or `commit-msg`.

<!-- A placeholder showing the shape of an answer — replace it with a real one. Note what
makes it an answer and not a decision: it records what is true about git, not what this
repo chose to do about it. The choice lives in os/decisions.md. -->
