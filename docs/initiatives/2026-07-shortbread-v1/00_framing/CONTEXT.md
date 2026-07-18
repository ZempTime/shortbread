# Stage 00 — Framing Synthesis

## Inputs

- `../inputs/request.md` — source request and attribution
- `../inputs/design-notes.md` — initial architecture synthesis and unresolved seeds
- `../inputs/chris-framing.md` — human-owned outcomes, decisions, and constraints
- `../inputs/2026-07-18-goal-addendum.md` — subsequent open-source, workflow, deployment, evidence, and autonomy decisions

## Process

Preserve the inputs unchanged and reconcile them into one traceable framing contract. Distinguish Chris's statements, accepted external critique, and seed proposals. Surface contradictions, record their resolution only when later user instruction settles them, and keep implementation detail out unless it constrains the product contract.

Create the root glossary and accepted ADRs for stable terminology and hard-to-reverse decisions. Create a PRD draft in the agreed structure: problem statement, solution, numbered user stories, implementation decisions, testing decisions, out of scope, and further notes.

## Outputs

- `output/2026-07-18-framing-contract.md`
- `output/2026-07-18-prd-draft.md`
- `/CONTEXT.md`
- accepted records under `/docs/adr/`

## Verify

- Every accepted outcome and constraint traces to an input or explicit conversation instruction.
- The exact accepted trust contract is used consistently.
- The public example is not silently converted into anonymous public access.
- The reference deployment, CLI, setup guide, screenshots, open-source posture, and mandatory factory harvest are represented.
- Remaining uncertainty is assigned to an implementation ticket or named as out of scope; it is not disguised as a decision.

## Stop

The human framing gate was explicitly released in conversation on 2026-07-18. Stop only if synthesis reveals a genuine contradiction that would change the permanent trust or product boundary and no later instruction resolves it.

## Promote

Promote the glossary and accepted ADRs to repository-wide domain artifacts. Pass the framing contract and PRD draft to Stage 01; do not publish child tickets from this stage.
