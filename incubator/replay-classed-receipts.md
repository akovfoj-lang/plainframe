# replay-classed-receipts

status: seed

**Pitch:** class each receipt by replay safety (safe to repeat / not) so a crash-recovery
repeat never re-sends a message or re-runs a payment. Only earns its place once an outward
integration (messaging, payments) exists — nothing in the kernel needs it yet.
