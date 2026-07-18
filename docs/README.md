# Documentation

Code and executable tests are the source of truth for implemented behavior. Use the narrowest document that owns the question.

| Document | Use it for |
|---|---|
| [`../CONTEXT.md`](../CONTEXT.md) | Canonical product language |
| [`adr/`](adr/) | Accepted hard-to-reverse architectural/product decisions |
| [`agents/`](agents/) | Tracker, triage, domain, and repo-local MWP conventions |
| [`initiatives/`](initiatives/) | Active bounded workspaces, stage state, evidence, and handoffs |

## Active build

Shortbread v1 is controlled from [`initiatives/2026-07-shortbread-v1/RUN.md`](initiatives/2026-07-shortbread-v1/RUN.md). Its [PRD](initiatives/2026-07-shortbread-v1/01_spec/output/2026-07-18-shortbread-v1-prd.md), [ticket map](initiatives/2026-07-shortbread-v1/02_ticket_map/output/2026-07-18-ticket-map.md), and [persistent goal](initiatives/2026-07-shortbread-v1/03_goal_handoff/output/GOAL.md) are the clean-session entry points.

## Maintenance

- Keep current rules near code or behind pointers from `AGENTS.md`.
- Keep one document per live concern and link canonical artifacts instead of copying them.
- Delete working exhaust when a current result captures its value.
- Keep credentials, Invitation values, private Bundle content, and Viewer PII outside Git; commit only synthetic/redacted evidence.
