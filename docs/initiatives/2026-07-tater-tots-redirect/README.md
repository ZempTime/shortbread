# Initiative: Tater Tots redirect

**Goal:** Redirect Shortbread from private-site hosting to a plannotator-shaped annotation and review product, keeping the parts of the existing build that still serve that goal.

**Status:** Spec published, not yet decomposed. No implementation, no controller, no child tickets. Nothing in this workspace has been implemented.

**Current stage:** `01_spec` complete — [PRD #64: Range-anchored Comments](https://github.com/ZempTime/shortbread/issues/64). Track A (anchoring prototype) is answered; Track B (infra) is independent and unaffected. Next is `to-tickets`.

**Why a new workspace:** This is a product-direction change, not an amendment. `docs/initiatives/2026-07-shortbread-v1/RUN.md` names product-scope change as a "true stop" requiring explicit operator direction. Chris gave that direction on 2026-07-25. The v1 workspace stays frozen as history; this workspace owns the new direction.

## Entry points for a clean session

Read in this order:

1. [`00_framing/output/2026-07-25-redirect-framing.md`](00_framing/output/2026-07-25-redirect-framing.md) — what changed, what survives, what it costs
2. [`00_framing/output/2026-07-25-plannotator-analysis.md`](00_framing/output/2026-07-25-plannotator-analysis.md) — verified source analysis of plannotator, incl. the anchoring model
3. [`00_framing/output/2026-07-25-deployment-findings.md`](00_framing/output/2026-07-25-deployment-findings.md) — Northflank/R2/DNS facts, unaffected by the redirect
4. [`00_framing/output/2026-07-25-open-questions.md`](00_framing/output/2026-07-25-open-questions.md) — what is undecided and what to do next

## Ready-to-start work

Two independent tracks; neither blocks the other.

- ~~[Track A — prototype the anchoring model](00_framing/output/2026-07-25-handoff-track-a-anchoring.md)~~
  — **done.** Findings: [`2026-07-25-anchoring-prototype-findings.md`](00_framing/output/2026-07-25-anchoring-prototype-findings.md).
  Prototype code on branch `prototype/anchoring-2026-07-25`. The PRD it gated is now published.
- [Track B — R2 blob port and Northflank infra](00_framing/output/2026-07-25-handoff-track-b-infra.md)
  — **B1 done, B2 credential-ready.** B1 landed the Blob store contract, `R2BlobStore`, and
  config selection with fail-closed production validation. B2 added `infra/` and
  [`docs/runbooks/deploy.md`](../../runbooks/deploy.md); nothing is deployed and no live
  resource exists. Verified provider facts (and what stayed unverified):
  [`2026-07-25-deployment-verification.md`](00_framing/output/2026-07-25-deployment-verification.md).
  **Blocked from booting** until the four required `ANYCABLE_*` production keys are made
  conditional — the one-service topology has no cable service to point them at.

## Relationship to Shortbread v1

The v1 initiative is paused with U03 integrated and no controller active. Its PRD, ticket
graph, and the ~34 open backlog issues describe the *previous* product. Do not resume it,
and do not treat its ticket graph as the plan for this work.

What v1 built that remains valuable is inventoried in the framing document. In short: the
publish pipeline, immutable content-addressed Releases, passkey/People/Grant identity, the
Go CLI, and the production container all survive. The offline-copy and service-worker
machinery probably does not.

## Method

Follow the repo-local MWP in [`docs/agents/mwp.md`](../../agents/mwp.md), same stage shape as
the v1 workspace: `00_framing` reconciles the human direction into a traceable contract
before any spec work begins.
