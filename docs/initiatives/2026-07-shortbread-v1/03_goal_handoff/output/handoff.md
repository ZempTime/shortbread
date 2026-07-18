# Temporary Handoff Lifecycle

The handoff skill writes one redacted convenience summary to the operating system's temporary directory after final validation. Its path is returned directly at session close and is intentionally not committed: OS cleanup and a different machine can remove it.

The durable, sufficient handoff is [`GOAL.md`](GOAL.md), [`controller-runbook.md`](controller-runbook.md), the dependency baseline, and the active [`../../RUN.md`](../../RUN.md). A fresh controller must be able to start from those files and GitHub state without the temporary summary.
