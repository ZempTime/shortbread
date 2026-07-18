# Request Snapshot

**Date:** 2026-07-17 → 2026-07-18
**Source:** Direct conversation with Chris (Claude Code, Claude Fable 5), including an external AI critique Chris endorsed

## Chris's Requests

The originating idea:

> I often need to share interactive HTML explainers and other sorts of things. Often it'd be convenient if these could include sensitive data like booking at dinner areas real names or record numbers … this would need to be server side. That way all of these content isn't present in the front end, only from the server once we figured out it's the right people. … Maybe feedback stays out of this, or stays minimal. All that it does is collect, doesn't act. Whatever other system put it there can then go get the feedback. The feedback would need to be visible, sort of like a shared text amongst the people looking at it.

Core constraints, stated later:

> key to this experience is a seamless sharing and auth experience + downloads offline. i need this to work across not just claude and be trusted with personal content that shouldnt go into ai

> also how should we think about versioning key piece of this is iteration. for ex with italy i have several pages where they are a mini website even with leaflet

Work style:

> i think github as issue tracker and matt pocock prd adjacent is fine tho for artifactory idea. the mwp approach seems a lot better for start -> finish tho

Name and go signal:

> nvm lets go with shortbread. please proceed with scaffold.

## Requirements Established by the Request

- Seamless viewer experience: accountless personal links, no passwords, works for people outside claude.ai.
- Offline: save-to-phone for whole mini-sites plus ordinary downloads (.ics, PDFs).
- Feedback: one visible shared thread; Shortbread collects only; producing systems pull it.
- Producer-agnostic: CLIs, work packets, agents, and humans all publish over the same API; Claude is just another client.
- Trusted with personal content that must not pass through an AI.
- Versioning built for iteration over multi-page bundles (Italy mini-sites with Leaflet are the reference case).
- Tracking: GitHub issues + Matt Pocock-adjacent PRD with reviewed generic template patterns. Execution: repo-local MWP staged workspaces, start → finish.

## Endorsed External Critique (Chris: "thoughts from different ai critique i liked")

Chris adopted these revisions; treat them as accepted design, not seeds:

- One stable origin per site at `<slug>.sites.<apex>`; **no per-version subdomains**. Service worker pins releases inside the stable origin.
- CLI in **Go** (single binary; humans, agents, CI all use it).
- Presigned R2 PUTs against a private bucket; viewer reads stay on the site origin through Rails.
- `/_foyer/*`-style reserved paths (now `/_shortbread/*`) and reserved `/service-worker.js`.
- Drop `{{slot}}` template substitution; sensitive data enters as private bundle files (e.g. `private.json`) added locally before publish.
- Trust contract worded "server-private", not zero-knowledge; state plainly that revocation cannot remove saved offline copies.
- Name vocabulary uncute: sites, bundles, releases.

## Seed Material — Not Chris's Decision

Claude proposals awaiting the framing gate: the remaining-PRD-decisions list in [`design-notes.md`](design-notes.md) (revocation-vs-offline policy, public-link tier, owner surface, no delivery infrastructure, single-tenant permanence, export/backup, bundle routing details, offline policy details); reuse of a generic invite-link → passkey ceremony; Northflank/PlanetScale/R2 specifics beyond Chris's stated preference; the working repository naming.
