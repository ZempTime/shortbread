---
name: to-spec
description: Synthesize settled conversation, framing, or a plan into the canonical local PRD and coordinating parent issue. Use after product decisions are sufficiently settled and before tracer-ticket decomposition.
---

# To Spec

Turn accepted decisions into one implementable product contract. Do not reopen settled choices merely to conduct an interview.

## Preflight

1. Read `AGENTS.md`, `docs/agents/issue-tracker.md`, the root domain glossary, relevant ADRs, and the active initiative `RUN.md`.
2. Read only the inputs named by the current stage contract. Preserve source attribution and apply the recorded precedence when inputs conflict.
3. Confirm the `RUN.md` authorizes synthesis and tracker publication. In controller mode, the controller's sign-off satisfies routine acceptance; stop only for a material contradiction outside its envelope.

## Write locally first

Use the stage's named output path. The PRD contains exactly these top-level sections:

1. `Problem Statement`
2. `Solution`
3. `User Stories`
4. `Implementation Decisions`
5. `Testing Decisions`
6. `Out of Scope`
7. `Further Notes`

Write numbered, observable stories by actor. Include permanent no-s, trust/authority boundaries, CLI/API/operations/documentation behavior, and the agreed behavioral test seams. Separate hard product constraints from reversible implementation choices. Use canonical domain terms; resolve missing language before inventing synonyms.

Do not turn uncertain code organization into a product requirement. Do not omit setup, recovery, deletion, security, public documentation, or evidence when the accepted outcome includes them.

## Verify

- Trace every accepted outcome and invariant to a named input or ADR.
- Search for contradictions, missing actors, unowned failure/recovery journeys, and requirements that cannot be tested at the declared seam.
- Confirm the exact trust statement and all explicit out-of-scope boundaries.
- Check that a fresh implementer could derive vertical tickets without reconstructing the conversation.
- Remove credentials, tokens, private content, PII, and transcript exhaust.

## Publish

Publish the exact local Markdown as one parent issue through the configured tracker. Add `ready-for-agent` only when the PRD is settled and safe under the active authority. Record issue number/URL in the stage tracker output and update `RUN.md` with evidence.

Do not create child tickets; that is `to-tickets`' one job.
