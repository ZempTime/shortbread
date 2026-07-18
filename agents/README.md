# Shortbread Agent Factory

This directory is the vendor-neutral, repo-local factory for moving Shortbread work from a settled need to reviewed, evidenced delivery. Tool-specific directories may mount these files; they do not own them.

## Delivery pipeline

`to-spec` → `to-tickets` → `implement` (TDD) → `code-review` → repair → integrate → harvest

- `to-spec` turns settled decisions into a canonical local PRD and a coordinating parent issue.
- `to-tickets` creates a dependency-aware graph of vertical tracer bullets.
- `implement` creates the smallest justified MWP workspace and harness, drives one ticket through red/green evidence, and prepares integration.
- `code-review` runs independent Standards and Spec reviews; the controller repairs or redelegates findings.
- every run makes an explicit harvest decision: promote demonstrated reusable improvements here, or record `No reusable harvest`.

The top-level controller owns frontier selection, delegation, routine approvals, integration, durable state, and recovery. When an initiative `RUN.md` grants autonomous authority, controller sign-off satisfies routine workflow gates; a subagent reports uncertainty to the controller rather than interrupting the operator.

## MWP ownership

[`docs/agents/mwp.md`](../docs/agents/mwp.md) is Shortbread's complete process definition. In brief:

- GitHub issues and pull requests coordinate across sessions.
- `docs/initiatives/` holds the actual work: bounded inputs, decisions, edit surfaces, harnesses, evidence, and handoffs.
- Each workspace has an authoritative `RUN.md`; branches, merges, labels, and folder presence do not prove state.
- Stages exist only when they have one real cognitive job. Do not pre-create ceremony.
- Product facts stay in product artifacts. Only reusable, evidenced execution knowledge belongs in this factory.

## Layout

- `skills/<name>/SKILL.md` — source of truth, plain Markdown, with optional reference docs and vendor adapters
- `scripts/` — deterministic mechanics such as label setup and skill mounting
- `.agents/skills/<name>` — Codex repo-skill symlinks; run `scripts/link-codex.sh` after adding a skill
- `.claude/skills/<name>` — optional symlinks into `skills/`; run `scripts/link-claude.sh` after adding a skill

## Issue roles

The canonical state labels are `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, and `wontfix`; `bug` and `enhancement` are categories. `scripts/setup-labels.sh` creates them idempotently. The active goal's authority envelope—not a copied severity system—decides whether the controller or operator must approve sensitive work.

## Safety and evidence

- Never put credentials, invitation tokens, private bundle content, or viewer PII in prompts, logs, issues, PRs, screenshots, or fixtures.
- Independent implementation work uses isolated branches/worktrees; serialize migrations, lockfiles, and shared hotspots.
- Merge only after targeted and full checks pass, Standards and Spec reviews are resolved, and evidence is durable.
- Reversible choices inside accepted PRDs/ADRs belong to the controller. Trust changes, scope expansion, paid commitments, and destructive external actions do not.

## Provenance

The engineering vocabulary and several skills are adapted from [mattpocock/skills](https://github.com/mattpocock/skills) under its MIT license. [`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md) preserves the upstream notice, revisions, and affected paths. Shortbread owns the local workflow, adaptations, and future improvements.

Recurring edits to a skill's output indicate a factory problem: repair the factory rather than teaching each product slice the same lesson again.
