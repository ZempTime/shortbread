# Shortbread v1 Framing Contract

**Accepted:** 2026-07-18 through Chris's explicit continuation and autonomous-handoff instructions
**Purpose:** Bind the v1 PRD and controller without erasing the provenance or uncertainty of the source conversation.

## Source order

When sources differ, later direct instructions from Chris control:

1. `inputs/2026-07-18-goal-addendum.md` and subsequent direct instructions in this run;
2. `inputs/chris-framing.md`;
3. accepted external-critique items recorded in `inputs/request.md`;
4. architecture synthesis in `inputs/design-notes.md`;
5. seed proposals, which remain unaccepted unless a later source resolves them.

The product contract is Shortbread's own. A local private template supplied generic implementation prior art; it is not a product, runtime, or build input. The MWP workflow is defined locally in `docs/agents/mwp.md`.

## Desired outcomes

1. An Owner can publish an already-built directory as a private Site with one fire-and-forget CLI command.
2. A named Viewer can open a texted personal link in one tap without creating an account, choosing a password, or installing an app-store app.
3. Real names, booking references, prototypes, and similar personal material never become anonymously public merely because they are in a Bundle.
4. A Viewer can deliberately keep an eligible Site available offline, see update size/progress, and recover cleanly from an interrupted update.
5. The Owner can iterate through immutable Releases and understand which Viewer Comments and View Receipts belong to which Release and page.
6. Any operator-controlled Producer—a human CLI session, CI job, or agent—uses the same documented API and can retrieve place-agnostic feedback.
7. A new Operator can clone the public MIT repository, run it locally, and prepare the reference production deployment without hidden knowledge or proprietary application dependencies.
8. Once credentials and deployment values are supplied, documented automation creates/configures Northflank, PlanetScale Postgres, private Cloudflare R2, DNS/TLS, secrets, and the deployed application idempotently.
9. The public repository demonstrates both the product and a inspectable experiment in agent-driven software delivery through its MWP workspaces, issue coordination, evidence, and factory harvests.

## Reference journeys

### Italy trip

The Owner publishes a multi-page Bundle containing text, images, ordinary downloads, and locally vendored map assets. Named travelers accept personal Invitations, find the Site on their Shelf, explicitly keep the eligible Release offline, and open it in a dead zone. A later Release updates atomically when each Viewer chooses; an interrupted update leaves the prior Release usable.

### Prototype iteration

An operator-controlled Producer publishes ten or more Releases of an interactive HTML prototype. Friends open the stable Site URL and use one injected flat Feedback Thread. Comments acquire Release and path anchors automatically. The Producer retrieves stable JSON with `shortbread feedback` and uses it wherever the next iteration happens.

### Personal record share

The Owner includes real names or booking references in local Bundle files and publishes to a private Site. Only named Viewers with live Grants can fetch content from the Site host. Private Blobs remain in R2 and are served through authenticated Shortbread responses; logs, screenshots, public fixtures, issues, and PRs reveal none of the content.

### New operator

A contributor follows the clean-clone guide, runs the example flow locally, installs a released CLI binary, and understands every dependency and credential. For production, the setup command explains and validates the required provider values, plans named resources, and is ready to run live when the Operator supplies credentials.

## Accepted product decisions

### Ownership and access

- One permanent Owner per installation; no other publisher/owner role.
- A reusable roster of People spans Sites; Grants connect People to Sites.
- v1 access is invite-only. Anonymous public links do not exist.
- Invitations are personal, one-time, and preview-safe: a GET or link preview cannot consume one.
- The apex owns identity, the Owner control plane, Invitation acceptance, and the Viewer Shelf.
- Each Site host has its own host-only session established through a short-lived signed apex handoff.
- Owner passkeys and optional Viewer passkeys provide re-entry. Passwords do not exist.
- Shortbread never delivers Invitations or notifications; the Owner copies a link and uses an outside channel.

### Publishing and serving

- The CLI binary and command are named `shortbread`.
- Shortbread hosts already-built Bundles and never adds a content editor, build step, or source transformation.
- A Site uses one stable `<slug>.sites.<apex>` origin; `/` mounts Bundle paths without rewriting.
- Releases are immutable and content-addressed. Publish atomically changes the current pointer; rollback repoints it.
- Private R2 stores Blobs. Manifest entries map safe paths to hashes, content types, sizes, and offline policy.
- Exact paths, directory `index.html`, HEAD, byte ranges, ETags, and an explicitly enabled SPA fallback are supported.
- `/_shortbread/*` and `/service-worker.js` are reserved. Unsafe paths, symlinks, collisions, and known secret-like files are rejected before upload.
- Arbitrary Bundle JavaScript is confined to the Site origin and cannot receive apex credentials.

### Iteration, feedback, and offline use

- One flat chronological Feedback Thread belongs to each Site. Comments are append-only, show first-name identity, and automatically record Release and path.
- There are no replies, reactions, assignments, resolve/approve states, inbox, email, SMS, push, or other notification machinery.
- View Receipts answer only who opened which Release and are visible only to the Owner.
- Each Site has an Owner-controlled `allow offline` toggle, default on.
- Offline keeping is Viewer-initiated and visible, with total size, progress, required/optional Manifest Entries, atomic cache replacement, update choice, and `remove from this device`.
- Browser eviction remains possible. Ordinary downloadable files remain ordinary downloads. Saved Offline Copies survive Grant revocation; revocation prevents future server access and updates.

### Operations and openness

- The reference app stack is Rails 8.1, Inertia, React, TypeScript, PostgreSQL, private S3-compatible object storage, and self-hosted real-time delivery; the CLI is Go.
- The supported production recipe is Northflank + PlanetScale Postgres + Cloudflare R2 with standard boundaries that permit compatible self-hosted substitutions.
- The dependency baseline is front-loaded, audited, locked, and then frozen under controller ownership; small shadcn source additions using existing packages remain allowed.
- Site deletion revokes Grants, removes Site records, and reclaims only unreferenced Blobs through retryable work.
- v1 does not pull/export Bundle sources. Operator-held sources are the primary content recovery path; provider database/object recovery is documented honestly.
- Setup, upgrades, backup/restore, rollback, deletion, security, and troubleshooting are public docs.
- Screenshots are captured from the real application by a repeatable harness. A synthetic public-source example Bundle demonstrates the product without changing invite-only access.
- The README explains the product, self-hosting, and Chris's experiment with AI processes for building software.

## Trust and authority constraints

> Shortbread itself never sends site content, feedback, invitation data, or viewer PII to AI, analytics, or optional third-party processors. Data is processed only by operator-configured Northflank, PlanetScale, and R2. Producers/agents outside Shortbread are operator-controlled.

This is a server-private promise, not zero knowledge. TLS, private object storage, access control, token redaction, origin isolation, and safe logs enforce it. Credentials, Invitation values, private Bundle contents, and Viewer PII never enter GitHub coordination or agent evidence.

For delivery, starting the persistent goal is Chris's approval of the canonical PRD, initial ticket graph, dependency baseline, and `RUN.md` authority envelope. The controller may approve routine subordinate work, reversible implementation details, reviews, repairs, GitHub coordination, and namespaced deployment preparation. Only the stops named in `RUN.md` return to Chris.

## Resolved tensions

| Earlier tension | Resolution |
|---|---|
| “Never touches AI” versus operator-controlled Producers | The exact trust contract governs Shortbread itself; Producers and agents outside it are controlled by the Operator. |
| “Public bundle” could imply public access | The public artifact is source, fixtures, docs, and screenshots. Hosted v1 Sites remain invite-only. |
| Viewer links only versus an apex Viewer surface | Per-Site origins remain, and the apex adds a bookmarkable Shelf. There is no umbrella PWA. |
| Revocation versus Offline Copies | Revocation stops server access and updates; an existing Offline Copy can survive. The UI/docs say so plainly. |
| Private R2 versus “backup” | R2 is durable serving storage, not automatically an independent backup. Recovery docs distinguish operator source Bundles, PlanetScale restore, R2 protection/versioning when configured, and tested restore procedures. |
| Full user management versus single ownership | The Owner manages People and Grants across Sites; no second Owner/Producer person role is introduced. |
| Dependency flexibility versus predictable autonomous work | The full baseline is reviewed and locked in the first tracer, then only the controller may approve a documented exception. |
| Ticket approval versus no routine human interruptions | The top-level controller reviews and approves the graph under the initial goal authorization; subordinate agents do not ask Chris for routine approvals. |

## Reversible implementation choices

The controller may choose these from evidence without reopening framing: class/module boundaries, exact screen composition, copy refinements that preserve meaning, polling/backoff constants, default warning thresholds, job batching, cache chunking, provider API adapters, test helper organization, and ticket splitting. New hard-to-reverse choices receive concise ADRs before integration.

## Evidence of success

- The clean-clone walking skeleton proves CLI publish → personal Invitation → private Viewer page.
- The Italy example works offline in a real browser harness and updates without partial state.
- Ten sequential Release publishes preserve correct feedback anchors and delta behavior.
- Hostile-host/path/session tests prove isolation and private serving.
- CLI binaries authenticate to a deployed-compatible Shortbread instance and complete the black-box flow.
- The setup rehearsal enumerates every credential/value and reaches an idempotent deployment plan without hidden dashboard steps.
- Real screenshots and the public-source example stay reproducible.
- The final report links all reviews, repairs, security checks, clean-room evidence, release artifacts, and per-ticket harvest decisions.

## Framing boundary

Anything in the canonical PRD is approved for autonomous delivery. Anonymous public Sites, multi-owner/team tenancy, content building/editing, notification delivery, feedback workflow states, native apps, server-side AI/analytics, source export/pull, and destructive adoption of existing provider resources remain outside v1.
