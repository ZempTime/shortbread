# Documentation

Code and executable tests are the source of truth for implemented behavior. Use the narrowest document that owns the question.

| Document | Use it for |
|---|---|
| [`../CONTEXT.md`](../CONTEXT.md) | Canonical product language |
| [`adr/`](adr/) | Accepted hard-to-reverse architectural/product decisions |
| [`agents/`](agents/) | Tracker, triage, domain, and repo-local MWP conventions |
| [`initiatives/`](initiatives/) | Active bounded workspaces, stage state, evidence, and handoffs |

## Active direction

**On 2026-07-25 the Operator redirected the product.** Shortbread v1 is superseded by a
plannotator-shaped annotation and review product. Start at
[`initiatives/2026-07-tater-tots-redirect/`](initiatives/2026-07-tater-tots-redirect/) — its
[open questions](initiatives/2026-07-tater-tots-redirect/00_framing/output/2026-07-25-open-questions.md)
document is the clean-session entry point and records exactly where work stopped.

Nothing in the redirect has been implemented. No PRD, no tickets, no controller.

## Superseded build

Shortbread v1 remains paused at [`initiatives/2026-07-shortbread-v1/RUN.md`](initiatives/2026-07-shortbread-v1/RUN.md). Its [PRD](initiatives/2026-07-shortbread-v1/01_spec/output/2026-07-18-shortbread-v1-prd.md), [ticket map](initiatives/2026-07-shortbread-v1/02_ticket_map/output/2026-07-18-ticket-map.md), and [persistent goal](initiatives/2026-07-shortbread-v1/03_goal_handoff/output/GOAL.md) describe the **previous** product and are acceptance history, not current truth. Do not resume that graph. What its build produced that remains valuable is inventoried in the redirect framing.

## Maintenance

- Keep current rules near code or behind pointers from `AGENTS.md`.
- Keep one document per live concern and link canonical artifacts instead of copying them.
- Delete working exhaust when a current result captures its value.
- Keep credentials, Invitation values, private Bundle content, and Viewer PII outside Git; commit only synthetic/redacted evidence.
