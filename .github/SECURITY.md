# Security

Plainframe is plain text and shell scripts; its guardrails (the git hooks, the protected
paths, the secret check) are tripwires, not a security boundary — see CLAUDE.md.

If you find a way past a guard, or anything in the template that could expose a secret,
please report it privately through GitHub's **Report a vulnerability** button on this
repository's Security tab rather than in a public issue.

Never paste a real key, token or password into an issue, a pull request or a commit. If one
has landed in a clone's history, rotate it first: git history here is never rewritten.
