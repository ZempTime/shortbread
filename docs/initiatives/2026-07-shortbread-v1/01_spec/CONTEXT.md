# Stage 01 — Canonical Specification

## Inputs

- `../00_framing/output/2026-07-18-framing-contract.md`
- `../00_framing/output/2026-07-18-prd-draft.md`
- `/CONTEXT.md`
- accepted records under `/docs/adr/`
- the `to-spec` factory skill

## Process

Use `to-spec` to turn the settled framing into the canonical PRD. Keep product behavior and acceptance criteria explicit while leaving reversible code organization to implementation. Publish the exact local PRD as one parent GitHub issue and record its URL; the local file remains the canonical workspace artifact.

## Outputs

- `output/2026-07-18-shortbread-v1-prd.md`
- `output/tracker.md` containing the parent issue number and URL

## Verify

- The PRD uses the agreed sections and numbered user stories.
- Web, CLI, API, authentication, bundle serving, offline behavior, feedback, operations, open-source documentation, screenshots, and setup are all covered.
- The accepted testing seams and trust contract are verbatim.
- Hard product boundaries appear in Out of Scope.
- The published issue body matches the local artifact and is labeled `ready-for-agent`.

## Stop

Do not create child tickets here. Stop if publishing would expose credentials, tokens, viewer PII, or private bundle content.

## Promote

Pass the canonical PRD and parent issue reference to Stage 02.
