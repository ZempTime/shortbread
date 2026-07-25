# Redirect framing — Shortbread to a plannotator-shaped product

Date: 2026-07-25. Source: direct conversation with Chris (Operator). Status: framing only,
nothing implemented.

## What Chris asked for

Verbatim intent, across several messages:

- "basically plannotate but on a rails server with cli support and all the passkey link
  management etc bells and whistles"
- "we want this to be plannotator based. this is a major scope redirect previous approach is
  no longer relevant unless useful here."
- "yes I want to flip this to fully support plannotator experience. lets target full infra."
- Primary reviewers: "other people me and my agents" — both remote humans and his own agents.
- "I love md to html feature of plannotator"
- Possible rename to **Tater Tots** — from anno-**tate**, not the potato.

## Authority note

`docs/initiatives/2026-07-shortbread-v1/RUN.md` lists product-scope change as a **true stop**
requiring explicit Operator direction. Chris gave that direction. The v1 initiative stays
paused and frozen as history; this workspace owns the new direction. The v1 PRD is now
partially wrong and must not be treated as current product truth.

## What survives from the Shortbread v1 build

This is the reason to redirect rather than start a new repo. All of the following is
integrated on `main` and directly serves the new product:

| Asset | Why it still matters |
|---|---|
| Immutable content-addressed Releases + rollback | plannotator has **no** durable versioning. An annotation against Release N points at an exact, unchanging document. This is a genuine advantage. |
| Passkey Owner bootstrap, People, Grants, Invitations, revocation | plannotator has **no identity at all** — its sharing is anonymous, AES-GCM in a URL fragment, 7-day expiry. This is the single biggest thing Shortbread adds. |
| Publish pipeline (Blobs, PublishPlan, finalize, manifest) | Unchanged — documents still need uploading and addressing. |
| Go CLI + `/api/v1` contract | The Producer/agent retrieval path. `shortbread feedback --json` is already specified. |
| Production container, health contract, `bin/production` | Deployment substrate, unaffected. |
| Isolated `<slug>.sites.<apex>` origins | Still the right isolation model for served documents. |

## What is now questionable

- **Offline Copies + service workers (U21/U22).** Heavy machinery. Annotation review does not
  obviously need offline. Candidate for cutting.
- **View Receipts (U25).** Possibly still useful ("did they actually read it") — undecided.
- **The single-file-HTML compromise.** Dead. Chris accepted it earlier on 2026-07-25 when the
  product was private-site sharing; a review tool needs real multi-page documents, so
  U17/U18 (multi-page Bundle serving) moves from deferred to load-bearing.

## What is genuinely new work

1. **Range-anchored annotations.** Today a Comment anchors to Release + page path,
   server-side. Annotation review needs anchoring to a text range *within* a document.
2. **Resolve states.** Currently an explicit PRD non-goal. An iteration loop needs them.
3. **A review UI.** `app/frontend/pages/` is empty — there is no frontend at all yet.
4. **Diff between Releases.** plannotator's continuity mechanism; Shortbread has the
   immutable versions but no diff view.
5. **Markdown as a document type**, with server-side rendering for review.

## The md-to-HTML question, resolved

Chris wants plannotator's markdown rendering. The v1 PRD says Shortbread is "never a CMS or
static-site generator" and never builds Bundle content.

**These are compatible if the line is drawn at authoring, not rendering:**

- **Rendering for review** — markdown → HTML so a reviewer can read and annotate. Ephemeral
  presentation. Not authoring. plannotator does exactly this and is not a CMS.
- **Rendering as publishing** — rendered HTML becomes the served Release content. This *would*
  break the model, because the served bytes would depend on renderer version rather than on
  what was uploaded, defeating content-addressing.

**Decision: accept markdown as a reviewable document type, render server-side for the review
UI, keep the Release content-addressed to the markdown source.** The no-CMS boundary holds and
Releases stay honest — the same bytes always produce the same hash.

## The unresolved tension

Chris wants both a **local agent-feedback loop** and **durable multi-person review**. These
pull in opposite directions:

- plannotator's local loop works *because* it is ephemeral and identity-free — random port,
  hook fires, browser opens, feedback returns to the agent, nothing persists.
- Shortbread's value is the opposite — a persistent server, named people, durable records.

Building both well means one annotation model serving two access paths that share little
operationally. This was flagged as the main scope risk. The recommendation on record is
**remote-first**: build the durable multi-person surface Shortbread is uniquely positioned for,
and keep using plannotator itself for the local agent loop until the annotation model is proven.
Chris has not accepted or rejected this; see the open-questions document.

## Naming

**Tater Tots**, from anno-**tate**. Availability checked 2026-07-25: `tatertots.com` and
`tater.sh` appear available (whois, indicative only — confirm at a registrar); all candidate
repo names are free under the ZempTime account. No domain purchase is needed to proceed —
`tatertots.chriszempel.com` works with the same Northflank wildcard setup.

Two cautions recorded:
1. The rename touches **168 files / 868 occurrences** (`Shortbread::` namespace, `SHORTBREAD_*`
   env vars, CLI binary, docs, repo name). Mechanical but wide — do it **once**, after the spec
   settles, not mid-flight.
2. plannotator's own source contains `author?: string; // Tater identity for collaborative
   sharing` — "Tater" appears to be their internal codename. Worth knowing before committing.
