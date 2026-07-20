# Shortbread v1 Recovery and Delivery Plan

**Parent PRD:** [GitHub #1](https://github.com/ZempTime/shortbread/issues/1)  
**Product contract:** unchanged  
**Execution authority:** Chris accepted this replan on 2026-07-20  
**Unit contract:** [`UNIT-CONTRACT.md`](UNIT-CONTRACT.md)  
**Original graph:** retained as acceptance history under `02_ticket_map/`

## Delivery Shape

The initiative persists until Shortbread v1 is credential-ready or live-smoked. Execution proceeds through bounded campaigns, each launched in a fresh controller context and ending after at most four integrated leaf units, a genuine external stop, or an explicit pause capsule. The controller does not inherit a mandate to consume the entire initiative in one model goal.

The old GitHub issues #3–#17 remain acceptance umbrellas. The leaf units below are the only executable work. Issue #2 remains the completed bootstrap/private-view tracer.

## Recovery Before the Frontier

The controller preservation action is complete: `ticket-4-owner-cli-auth` was pushed from remote `4c7e807` to `8fcb22f`; `ticket-3-releases-rollback` was already remote-durable at `f5943d7`. Missing `/private/tmp` worktrees are not recreated during replanning.

The first campaign serializes the two branches. U01 reviews/integrates the Release branch. U02 then replays the auth branch semantically on the new main, omits the stale Ruby schema dump, regenerates SQL structure state, and completes the authenticated Owner landing journey.

## Common Fit and Split Rule

Every unit must fit one fresh implementation context and one fresh review context. Generated schema, lock, screenshot, and artifact files do not count toward the size heuristic, but their governing changes do. When a unit grows beyond the common contract, the controller stops at a remote green checkpoint and splits by actor-visible behavior—not backend/frontend/tests—while preserving the umbrella acceptance and graph edges.

## Campaigns

| Campaign | Units | Exit condition |
|---|---|---|
| C00 Recovery integration | U01–U02 | Both interrupted branches are represented by reviewed behavior on main; no stale worktree is required |
| C01 Production spine | U03–U04 | Production-shaped runtime and credential-free resource plan are executable before feature completion |
| C02 Owner/API | U05–U07 | Owner re-entry/recovery and scoped API behavior are usable and reviewed |
| C03 Producer/control UI | U08–U11 | Remote CLI auth, Release UI, Sites/People, and Grants are usable |
| C04 Invitations/access | U12–U14 | Invitation → Shelf → Site and optional Viewer re-entry are complete |
| C05 Private content | U15–U18 | Private R2 publishing and normal multi-page authenticated HTTP serving work |
| C06 Isolation/trust | U19–U20 | Injected controls and the implemented-system security baseline pass hostile review |
| C07 Offline/feedback | U21–U24 | Offline and authoritative/realtime feedback journeys are complete |
| C08 Receipts/deletion | U25–U27 | Receipts and retryable truthful deletion/reclamation are complete |
| C09 Artifacts/provision | U28–U31 | App/CLI artifacts and fake-provider apply/resume are release-candidate ready |
| C10 Deploy/public evidence | U32–U34 | Deploy/doctor contract, example tour, and screenshots are reproducible |
| C11 Docs/release | U35–U38 | Clean clone, holistic audit, stable release, and credential ceremony satisfy the PRD terminal condition |

## Dependency Graph

```text
U01 -> U02 -> {U03, U05}
U03 -> U04
U05 -> {U06, U09, U14}
U06 -> U07 -> {U08, U10, U16}
U08 -> {U10, U23, U25, U26, U29}
U10 -> U11 -> U12 -> U13 -> U14
U04 -> U15 -> U16 -> U17 -> U18 -> U19
{U08, U14, U16, U19} -> U20
{U13, U19, U20} -> U21 -> U22
{U08, U13, U19, U20} -> U23 -> U24
{U08, U13, U18, U20} -> U25
{U08, U11, U23, U25} -> U26
{U15, U26} -> U27
{U03, U19, U22, U24, U25, U27} -> U28
{U01, U08, U10, U11, U12, U23, U25, U26} -> U29
{U28, U29} -> U30
{U04, U28} -> U31
{U24, U30, U31} -> U32
{U01, U13, U22, U24, U25, U27} -> U33 -> U34
{U20, U27, U30, U32, U34} -> U35 -> U36
{U20, U27, U30, U32, U34, U36} -> U37 -> U38
```

Only U01 is initially executable. Campaign grouping never overrides a blocking edge or an edit-surface collision.

## Unit Index

| ID | Outcome-oriented title | Acceptance umbrella | Blocked by | Primary seam |
|---|---|---:|---|---|
| U01 | Recover immutable Release republish and rollback | #3 | #2 integrated | Black-box CLI/request/browser |
| U02 | Bootstrap the first Owner into an authenticated landing | #4 | U01 | Real browser/request |
| U03 | Boot the production-shaped Shortbread runtime locally | #12 | U02 | Container/process smoke |
| U04 | Plan the reference infrastructure without credentials | #13 | U03 | Provider command contract |
| U05 | Re-enter as Owner and manage passkeys/recovery | #4 | U02 | WebAuthn browser/request |
| U06 | Manage scoped automation tokens safely | #4 | U05 | Owner UI/request |
| U07 | Enforce the stable `/api/v1` contract | #4 | U06 | Request/black-box CLI |
| U08 | Log a remote CLI into a deployed-style instance | #4 | U05, U07 | Browser-assisted black-box CLI |
| U09 | Inspect and roll back Releases in Owner UI | #3 | U01, U05 | Owner browser |
| U10 | Manage Sites and the Person roster | #5 | U07, U08 | Owner UI/API/CLI |
| U11 | Grant and revoke Site access and offline permission | #5 | U10 | Owner UI/API/CLI |
| U12 | Manage and accept preview-safe Invitations | #5 | U11 | Owner/Viewer browser/request/CLI |
| U13 | Resume through the Shelf and isolated Site handoff | #5 | U12 | Viewer browser/request |
| U14 | Re-enter the Shelf with an optional Viewer passkey | #5 | U05, U13 | Viewer WebAuthn browser/request |
| U15 | Read private content-addressed Blobs through an R2 port | #6 | U01, U04 | S3 contract/request |
| U16 | Upload only missing private R2 Blobs and finalize atomically | #6 | U07, U15 | CLI/S3/request contract |
| U17 | Validate and resolve safe multi-page Bundles | #7 | U16 | CLI/request/unit |
| U18 | Serve authenticated Bundles with normal HTTP semantics | #7 | U13, U17 | Request/browser |
| U19 | Inject Shortbread controls without crossing origin/session boundaries | #7 | U13, U18 | Hostile browser/request |
| U20 | Publish the implemented-system threat model and hostile baseline | #14 | U08, U14, U16, U19 | Security/browser/CLI/R2 suite |
| U21 | Keep and remove one complete Release offline explicitly | #8 | U13, U19, U20 | Real offline browser |
| U22 | Update optional Offline Copies atomically and truthfully | #8 | U01, U21 | Real offline browser |
| U23 | Post and retrieve Release/path-anchored feedback | #9 | U08, U13, U19, U20 | Viewer/Owner/CLI |
| U24 | Reconnect live feedback without making realtime authoritative | #9 | U03, U23 | AnyCable/browser |
| U25 | Show minimal Owner-only View Receipts | #10 | U08, U13, U18, U20 | Request/browser/CLI |
| U26 | Stop access through a retryable Site-deletion state machine | #11 | U08, U11, U23, U25 | Job/request/CLI |
| U27 | Reclaim only unshared Blobs and explain recovery truthfully | #11 | U15, U26 | Job/R2 failure contract |
| U28 | Produce the final non-root application image | #12 | U03, U19, U22, U24, U25, U27 | Container/build smoke |
| U29 | Produce checksummed cross-platform CLI artifacts | #12 | U01, U08, U10, U11, U12, U23, U25, U26 | Artifact install/black-box CLI |
| U30 | Rehearse immutable app/CLI release artifacts | #12 | U28, U29 | CI/release/install smoke |
| U31 | Apply and resume provider changes against failure-injection fakes | #13 | U04, U28 | Provider command contract |
| U32 | Deploy, diagnose, and accept secrets only through the Operator boundary | #13 | U24, U30, U31 | Clean-room deploy/doctor contract |
| U33 | Publish the deterministic synthetic Shortbread tour | #15 | U01, U13, U22, U24, U25, U27 | Full browser tour |
| U34 | Capture and freshness-check real documentation screenshots | #15 | U33 | Browser capture/accessibility |
| U35 | Make product and operations documentation executable | #16 | U20, U27, U30, U32, U34 | Command/link/config checks |
| U36 | Repair every gap found by an independent clean clone | #16 | U35 | Fresh-checkout rehearsal |
| U37 | Repeat the holistic trust and terminal composition audit | #14, #17 | U20, U27, U30, U32, U34, U36 | Full composition/security suite |
| U38 | Promote the stable release and present one credential ceremony | #17 | U37 | Release plus optional live smoke |

## PRD Coverage

| PRD stories | Delivery ownership |
|---|---|
| 1 | U02 |
| 2–3 | U05 |
| 4, 6 | U10 |
| 5 | U09, U10, U23, U25 |
| 7 | U11 |
| 8–9, 18–19 | U12 |
| 10, 20–22, 30 | U13, U22 |
| 11 | U01, U09 |
| 12, 25, 42 | U23–U24 |
| 13 | U25 |
| 14 | U06 |
| 15–16 | U26–U27 |
| 17, 36 | U08–U12, U23, U25–U26, U29 |
| 23 | U14 |
| 24 | U17–U19 |
| 26–29 | U21–U22 |
| 31 | U29–U30 |
| 32–35 | U08 |
| 37–38 | U17, U21–U22 |
| 39 | U15–U16 |
| 40–41 | U01, U16 |
| 43–45 | U07–U08 |
| 46–49 | Integrated #2 plus U03 |
| 50–51 | U04, U32, U35 |
| 52 | U31–U32 |
| 53–54 | U32 |
| 55–56 | U27, U30, U35 |
| 57 | U32, U36, U38 |
| 58 | U28–U30 |
| 59 | U35 |
| 60 | U33 |
| 61 | U34 |
| 62–63 | Every unit's evidence/harvest; U35–U38 composition |
| 64 | U20, U37 |

The mapping covers all 64 stories. The original ticket bodies remain useful acceptance summaries; this graph owns executable granularity and ordering.

## Delivery Units

Each card inherits `UNIT-CONTRACT.md`. “Central surfaces” are reservations, not permission for parallel workers to edit them concurrently.

### U01 — Recover immutable Release republish and rollback

- **Acceptance umbrella / blockers:** GitHub #3; #2 is integrated. Existing candidate branch `ticket-3-releases-rollback` at remote-durable `f5943d7`.
- **Outcome:** A Producer republishes changed Bundles, sees deterministic added/changed/reused/removed results, lists immutable history, and rolls back the current pointer without rewriting a Release. The existing invited browser returns to the rolled-back content.
- **Failure/recovery:** Interrupted/finalize/rollback retries are exact and idempotent; inconsistent responses and half-visible Releases fail closed.
- **Evidence:** Fixed-SHA review of the existing branch; Rails request/concurrency and Go suites; real CLI/browser Release tracer; full relevant CI and clean-checkout replay.
- **Central surfaces / impact:** Migration and SQL schema format, `config/routes.rb`, Release/publishing services, CLI command registration, black-box tracer. Data-integrity specialist review is required. Do not add Owner UI; U09 owns it.
- **Safe split:** If review exposes a blocker outside the Release transaction/API/CLI journey, repair only that journey and create a follow-up under #3 rather than expanding this diff.

### U02 — Bootstrap the first Owner into an authenticated landing

- **Acceptance umbrella / blockers:** GitHub #4; blocked by U01. Preserve `ticket-4-owner-cli-auth` at `8fcb22f` as source evidence, not the merge branch.
- **Outcome:** An Operator mints one short-lived local/deployment-authority ceremony; a real browser registers the first Owner passkey exactly once, receives an authenticated apex session, and reaches a minimal private Owner landing page.
- **Failure/recovery:** Remote ceremony minting, replay, expired/wrong-origin ceremonies, malformed credentials, concurrent completion, and a second Owner fail closed without secrets in logs or durable URLs.
- **Evidence:** Semantically replay the preserved commits on current main, omit stale `db/schema.rb`, regenerate SQL structure state, add real WebAuthn/request/browser and bootstrap-command evidence, then run auth/security review.
- **Central surfaces / impact:** Auth migration/schema, apex session, root routes, WebAuthn configuration, logging filters. U05 owns later re-entry, credential management, and recovery.
- **Safe split:** Registration verification helpers may be isolated behind one service seam, but the unit does not integrate until bootstrap ends in an authenticated landing.

### U03 — Boot the production-shaped Shortbread runtime locally

- **Acceptance umbrella / blockers:** GitHub #12; blocked by U02.
- **Outcome:** An Operator builds one non-root candidate image and boots migrate, web, Solid Queue worker, AnyCable/WebSocket, PostgreSQL, and local private-Blob dependencies from a documented production-shaped configuration without provider credentials.
- **Failure/recovery:** Missing or contradictory configuration fails before serving; migration/health/process failures remain observable and restartable.
- **Evidence:** Container build and scan, non-root assertion, process-specific health checks, migration ordering, local production-shaped smoke, and exact environment inventory.
- **Central surfaces / impact:** Container/release configuration, process commands, environment contract, health routes, root operations docs. No stable artifact publication; U28 finalizes the image after features settle.
- **Safe split:** If process orchestration and image construction cannot fit together, first land a production-shaped process contract runnable from source, then the candidate image as a child with the same smoke.

### U04 — Plan the reference infrastructure without credentials

- **Acceptance umbrella / blockers:** GitHub #13; blocked by U03.
- **Outcome:** An Operator supplies only non-secret deployment choices and receives a deterministic plan for namespaced Northflank, PlanetScale Postgres, private R2, wildcard DNS/TLS, secrets, process roles, health checks, and expected plan/cost choices without mutation.
- **Failure/recovery:** Missing values, invalid names, unsupported plan choices, and unknown existing-resource/adoption scenarios fail explicitly; plan never requests or prints a secret.
- **Evidence:** Versioned resource manifest, command-contract fakes, golden/redacted plan output, configuration validation, and provider-feasibility notes sourced from current official documentation at implementation time.
- **Central surfaces / impact:** New provisioning namespace, deployment inventory, non-secret configuration schema, root ops docs. Provider credentials and live APIs remain out of scope until U31/U32.
- **Safe split:** Provider-specific plan renderers may become children only after one cross-provider manifest-to-plan tracer is green.

### U05 — Re-enter as Owner and manage passkeys/recovery

- **Acceptance umbrella / blockers:** GitHub #4; blocked by U02.
- **Outcome:** The Owner signs in again with a registered passkey, adds and removes credentials without stranding the installation, and an Operator can mint a short-lived deployment-authority recovery ceremony that is not remotely invocable.
- **Failure/recovery:** Wrong RP/origin, cloned/replayed assertions, counter anomalies, expired recovery, removal of the last usable credential, and concurrent ceremonies fail safely and redact secrets.
- **Evidence:** Real browser WebAuthn assertion/management/recovery journeys, request concurrency tests, deployed-origin configuration tests, and dedicated auth/security review.
- **Central surfaces / impact:** Owner session, credentials/ceremonies schema, auth routes, deployment-authority command. Keep API tokens and device authorization out; U06–U08 own them.
- **Safe split:** If recovery requires separate process authority code, checkpoint after passkey re-entry/management and create a recovery child that still ends in an authenticated Owner session.

### U06 — Manage scoped automation tokens safely

- **Acceptance umbrella / blockers:** GitHub #4; blocked by U05.
- **Outcome:** The Owner creates, lists, and revokes separately labeled/scoped automation tokens, sees creation/last-used/expiry metadata, and receives plaintext exactly once while the server stores only a digest.
- **Failure/recovery:** Expired, revoked, wrong-scope, malformed, and replayed token use fails with stable redacted errors; concurrent last-used updates do not authorize invalid work.
- **Evidence:** Owner browser/request tests, digest/scope/revocation/expiry tests, log/redaction assertions, and auth/security review.
- **Central surfaces / impact:** Token schema, Owner control UI, token authentication seam. U07 applies the common API contract; U08 owns interactive CLI credentials.
- **Safe split:** Token issuance and token enforcement may split only at a green one-time-display/digest checkpoint, with enforcement remaining a blocker for U07.

### U07 — Enforce the stable `/api/v1` contract

- **Acceptance umbrella / blockers:** GitHub #4; blocked by U06.
- **Outcome:** API clients negotiate compatibility before mutation and receive scoped authorization, request IDs, bounded pagination, rate limits, idempotency behavior, stable JSON success/error envelopes, deterministic exit categories, and redacted failures.
- **Failure/recovery:** Unsupported versions, reused conflicting idempotency keys, pagination abuse, redirect/body leakage, rate excess, and wrong scope fail before side effects.
- **Evidence:** Request contract suite plus built-CLI probes for compatibility, idempotency, pagination, scope, rate, timeout, JSON shape, and redaction.
- **Central surfaces / impact:** API base controller/policy, shared JSON envelope, CLI client transport—not every domain endpoint. Security review is required.
- **Safe split:** If one common policy cannot remain a deep seam, split compatibility/idempotency from pagination/rate limits, but do not fan domain tickets out until both are integrated.

### U08 — Log a remote CLI into a deployed-style instance

- **Acceptance umbrella / blockers:** GitHub #4; blocked by U05 and U07.
- **Outcome:** `shortbread login --server ... --profile ...` starts a proof-bound short-lived device authorization, opens a public verification URL/code, receives Owner passkey approval, stores the one-time token in the OS keyring, and supports profiles, `whoami`, logout, and separately scoped CI tokens.
- **Failure/recovery:** Stolen/replayed/expired device secrets, proof mismatch, redemption races, keyring failure, non-loopback HTTP, compatibility mismatch, and partial logout remain redacted and recoverable.
- **Evidence:** Built Go binary against Rails plus real/fake browser approval, keyring seam, race tests, stable JSON/human output, and dedicated auth/security review.
- **Central surfaces / impact:** Device schema/routes, Owner approval UI, CLI transport/root command registration/keyring. Freeze these public seams before later CLI units.
- **Safe split:** Server authorization and CLI client may use two checkpoints, but integration waits for the complete remote-style login/logout journey.

### U09 — Inspect and roll back Releases in Owner UI

- **Acceptance umbrella / blockers:** GitHub #3; blocked by U01 and U05.
- **Outcome:** An authenticated Owner sees immutable Release history/current state and rolls back with precise changed/no-op/replay feedback while browser content follows the selected Release.
- **Failure/recovery:** Cross-Site access, stale history cursors, conflicting idempotency, and rollback races fail without mutating historical Releases.
- **Evidence:** Owner browser/request tests stacked on U01 API behavior, authorization probes, and Release data-integrity review.
- **Central surfaces / impact:** Owner navigation, Release UI/routes, no Release schema changes unless U01 review requires them.
- **Safe split:** Read-only history UI may checkpoint before rollback only if both remain within the same campaign and history is independently useful.

### U10 — Manage Sites and the Person roster

- **Acceptance umbrella / blockers:** GitHub #5; blocked by U07 and U08.
- **Outcome:** The Owner and scoped CLI create/list/update Sites and maintain one Person roster with validated Site metadata, stable origins, SPA/offline policy, first name, and private disambiguating note.
- **Failure/recovery:** Slug/origin collisions, invalid metadata, cross-Site access, duplicate retries, and unauthorized scopes fail before mutation with stable UI/JSON results.
- **Evidence:** Owner UI/request and built-CLI black-box tests covering create/list/update, idempotency, validation, pagination, scope, and redaction.
- **Central surfaces / impact:** Existing Site/Person models and APIs, Owner navigation, CLI management commands. Reserve root routes and CLI registration through the controller.
- **Safe split:** If the combined UI/CLI diff exceeds the fit limit, split Sites and People as two actor-visible children; neither becomes a backend-only foundation.

### U11 — Grant and revoke Site access and offline permission

- **Acceptance umbrella / blockers:** GitHub #5; blocked by U10.
- **Outcome:** The Owner and scoped CLI grant/revoke a Person's access to a Site and set per-Grant offline permission within the Site policy, with current access visible from both UI and JSON.
- **Failure/recovery:** Duplicate/conflicting grants, cross-Site references, revoked credentials, concurrent revoke/access, and invalid offline-policy combinations fail deterministically.
- **Evidence:** Owner UI/request/CLI tests for grant, revoke, list, idempotency, authorization, concurrency, and offline-policy truth.
- **Central surfaces / impact:** Grant model/API/UI/CLI and authorization policy. Revocation's effect on Shelf/Site access is completed in U13; saved Offline Copy wording is completed in U22.
- **Safe split:** A read-only grant inventory may checkpoint before mutations, but the unit integrates only when grant and revoke are observable through one management seam.

### U12 — Manage and accept preview-safe Invitations

- **Acceptance umbrella / blockers:** GitHub #5; blocked by U11.
- **Outcome:** The Owner/CLI creates, inspects, rotates, and revokes a personal expiring Invitation; a Viewer preview GET is side-effect free and an explicit CSRF-protected acceptance consumes the secret exactly once.
- **Failure/recovery:** Link preview, expiry, revocation, rotation, replay, wrong audience, rate excess, malformed fragments, and concurrent acceptance fail closed without leaking Invitation values.
- **Evidence:** Owner/Viewer browser and request journeys, black-box CLI private-sink contract, concurrency/rate/redaction tests, and auth/security review.
- **Central surfaces / impact:** Existing Invitation/Grant flow, acceptance UI/routes, CLI invite commands, filters/logging. U13 owns the subsequent Shelf-to-Site journey.
- **Safe split:** Management and acceptance may checkpoint separately only if acceptance remains a direct blocker and the management half has complete rotation/revocation behavior.

### U13 — Resume through the Shelf and isolated Site handoff

- **Acceptance umbrella / blockers:** GitHub #5; blocked by U12.
- **Outcome:** An accepted Viewer bookmarks the apex Shelf, sees only currently granted Sites, and crosses through a one-use audience/host-bound handoff to a host-only Site session; revocation blocks future server access and updates.
- **Failure/recovery:** Cross-Person/Site enumeration, handoff replay/expiry, sibling-host cookie use, revoked Grant, and URL credential residue fail without leaks.
- **Evidence:** Real Viewer browser journey from Invitation/Shelf to Site, request/session/cookie isolation probes, revocation tests, and auth/security review.
- **Central surfaces / impact:** Shelf UI, apex session, handoff, Site session, host routes/cookies. U19 adds hostile injected-control/origin tests; U22 completes Offline Copy truth.
- **Safe split:** Shelf listing and handoff may use two green checkpoints, but they integrate together because neither proves the resume journey alone.

### U14 — Re-enter the Shelf with an optional Viewer passkey

- **Acceptance umbrella / blockers:** GitHub #5; blocked by U05 and U13.
- **Outcome:** A Viewer who first entered accountlessly may register a passkey and later re-enter the apex Shelf without weakening personal Grant isolation or requiring every invited Person to register.
- **Failure/recovery:** Wrong Person binding, RP/origin mismatch, replay, revoked Grant, removed credential, and first-invitation passkey coercion fail safely.
- **Evidence:** Real browser WebAuthn registration/assertion plus request authorization/revocation tests and auth/privacy review.
- **Central surfaces / impact:** Viewer credential schema/session and Shelf auth routes. Reuse the U05 WebAuthn seam; do not create a parallel authentication implementation.
- **Safe split:** Registration/assertion helpers can be internal checkpoints; the actor-visible unit remains register now, re-enter later.

### U15 — Read private content-addressed Blobs through an R2 port

- **Acceptance umbrella / blockers:** GitHub #6; blocked by U01 and U04.
- **Outcome:** One BlobStore port reads verified content-addressed bytes from the local adapter and an R2/S3-compatible contract while buckets remain private and provider behavior stays outside domain services.
- **Failure/recovery:** Missing/wrong-size/wrong-hash objects, unauthorized direct reads, timeouts, provider errors, and namespace confusion fail before a successful content response.
- **Evidence:** S3-compatible fake/contract suite, local-adapter parity, authenticated request read, direct anonymous denial, failure injection, and data/security review.
- **Central surfaces / impact:** BlobStore public seam, R2 configuration/namespace, publishing/serving adapters. No presigned upload yet; U16 owns it.
- **Safe split:** Local/R2 parity may checkpoint before application wiring, but the unit integrates only when one authenticated request reads verified private bytes through the port.

### U16 — Upload only missing private R2 Blobs and finalize atomically

- **Acceptance umbrella / blockers:** GitHub #6; blocked by U07 and U15.
- **Outcome:** Publish asks which content-addressed Blobs are missing, receives short-lived exact-key/size presigned PUTs, uploads only those bodies, and atomically/idempotently finalizes a Release that private serving can read.
- **Failure/recovery:** Expired/wrong-key/wrong-size uploads, partial interruption, contradictory Manifest data, concurrent finalize, retry, and provider error never expose a half-visible Release or read/list permission.
- **Evidence:** Built CLI → Rails → S3 fake tracer, presign-scope contract, finalize concurrency/idempotency, private denial, and data/security review.
- **Central surfaces / impact:** Publish API/services, CLI upload transport, R2 presigning, Release transaction. Orphan reclamation stays with deletion U27.
- **Safe split:** Presign/upload and finalize may be two checkpoints only if the first cannot promote a Release and the second completes the same black-box tracer.

### U17 — Validate and resolve safe multi-page Bundles

- **Acceptance umbrella / blockers:** GitHub #7; blocked by U16.
- **Outcome:** The CLI/server accepts a real multi-page Bundle with normal files, directory indexes, optional SPA fallback, offline classification, and deterministic content types while rejecting unsafe/ambiguous paths and manifests before upload or serve.
- **Failure/recovery:** Traversal, absolute paths, Unicode/case collisions, symlinks/special files, reserved paths, invalid sizes/hashes/types, and secret-like files fail before network mutation.
- **Evidence:** Built-CLI hostile Bundle suite, request/unit resolution tests, strict-mode/external-origin warnings, and stable JSON results.
- **Central surfaces / impact:** Bundle walker/Manifest schema/path resolver/content-type policy. Reserve service-worker path and `/_shortbread/*` namespace for later units.
- **Safe split:** Validation and resolver may split only if the validator produces the exact canonical Manifest consumed by the independently actor-visible serving child.

### U18 — Serve authenticated Bundles with normal HTTP semantics

- **Acceptance umbrella / blockers:** GitHub #7; blocked by U13 and U17.
- **Outcome:** An authenticated Viewer browses `/`, directory indexes, relative/root-relative assets, downloads, explicit SPA fallback, GET/HEAD, strong ETags/conditions, and single byte ranges from the selected Release.
- **Failure/recovery:** Unauthenticated/revoked access, absent/corrupt Blob, invalid/multi-range requests, stale conditions, missing paths, and provider failure return correct generic responses before leaking bytes or success headers.
- **Evidence:** Request/browser suites over local and fake-R2 adapters, range/ETag/type/content-length probes, large media, current/rollback behavior, and serving security review.
- **Central surfaces / impact:** Site content controller/middleware, Manifest resolver, Blob reads, host routing. U19 owns injection and state-changing reserved endpoints.
- **Safe split:** HTTP metadata and directory/SPA resolution may checkpoint separately, but both remain inside one authenticated multi-page browser outcome.

### U19 — Inject Shortbread controls without crossing origin/session boundaries

- **Acceptance umbrella / blockers:** GitHub #7; blocked by U13 and U18.
- **Outcome:** Eligible HTML receives deterministic/idempotent Shortbread controls while non-HTML bytes remain exact; hostile Bundle JavaScript cannot read apex/other-Site credentials or perform sibling-Site reserved-endpoint mutations.
- **Failure/recovery:** Malformed/streamed HTML, duplicate injection, Domain-cookie shadow/toss, CSRF, wrong Origin/Fetch Metadata, credentialed CORS, confused Host, and reserved-path collisions fail closed.
- **Evidence:** Hostile real-browser/request tests across production/development stacks, exact-Origin/session-bound CSRF/no-CORS probes, Rack/response lint, and dedicated security review.
- **Central surfaces / impact:** HTML injection seam, reserved routes, cookie/session policy, middleware/host routing, CSP/external-origin guidance.
- **Safe split:** Byte-preserving injection may checkpoint before hostile-origin controls, but the unit cannot integrate until the injected surface is security-reviewed.

### U20 — Publish the implemented-system threat model and hostile baseline

- **Acceptance umbrella / blockers:** GitHub #14; blocked by U08, U14, U16, and U19.
- **Outcome:** A public data-flow/threat model names current actors/assets/boundaries/abuse cases/mitigations/residuals and an executable hostile suite proves the implemented control plane, passkeys, tokens, Invitations, sessions, private R2 path, Bundle isolation, logging, and no-telemetry promise.
- **Failure/recovery:** Missing controls are blockers or explicitly assigned later acceptance; the document cannot claim final coverage for offline, feedback, receipts, deletion, provisioner, artifacts, examples, or screenshots.
- **Evidence:** Independent security/privacy reviewers replay browser/request/CLI/R2/log/dependency/secret hostile checks at a fixed head.
- **Central surfaces / impact:** Security docs and cross-cutting tests; minimal product repairs only through separate regression-first commits.
- **Safe split:** Model and executable audit may use two review checkpoints, but campaign promotion requires their claims to agree.

### U21 — Keep and remove one complete Release offline explicitly

- **Acceptance umbrella / blockers:** GitHub #8; blocked by U13, U19, and U20.
- **Outcome:** When Site and Grant policy permit, a Viewer explicitly sees total size, keeps one complete required Release offline, reopens it with the network disabled, and removes Shortbread caches/state/registration from the device as safely as the browser permits.
- **Failure/recovery:** No silent download; policy denial, missing/corrupt required entry, quota/network interruption, incomplete cache, and removal failure preserve the prior online/offline truth and report browser limits.
- **Evidence:** Real-browser keep/progress/network-off reopen/remove tests plus deterministic cache-state units only where browser isolation is impossible; offline/security review.
- **Central surfaces / impact:** Release offline manifest, injected UI, service worker reserved path, cache namespace/state. U22 owns optional entries and updates.
- **Safe split:** Keep and remove may checkpoint independently only if both operate on the same complete Release cache protocol and leave no competing service worker.

### U22 — Update optional Offline Copies atomically and truthfully

- **Acceptance umbrella / blockers:** GitHub #8; blocked by U01 and U21.
- **Outcome:** A Viewer chooses optional entries, keeps the prior complete Release when an update fails, atomically switches after a new complete Release verifies, and sees that browser eviction is possible and revocation cannot erase saved bytes.
- **Failure/recovery:** Required/optional mismatch, corrupt response, partial update, concurrent publish/rollback, eviction, revoked Grant, and remove/update races never silently select an incomplete Release.
- **Evidence:** Real-browser optional selection, failed/successful update, offline pinning, policy/revocation/eviction wording, and cache cleanup tests.
- **Central surfaces / impact:** Service worker/cache state, Release Manifest classification, offline UI/docs/screenshots. No background silent update.
- **Safe split:** Optional selection and atomic upgrade may split only if U21 behavior remains green and the intermediate state offers no automatic update.

### U23 — Post and retrieve Release/path-anchored feedback

- **Acceptance umbrella / blockers:** GitHub #9; blocked by U08, U13, U19, and U20.
- **Outcome:** An authenticated Viewer opens one flat injected Feedback Thread, posts append-only Comments attributed from the server-side Person and served Release/path, while Owner UI and `shortbread feedback --json` retrieve stable chronological context.
- **Failure/recovery:** Client-forged identity/anchor, revoked access, cross-Site reads, retry, pagination, rollback/republish, and malformed content fail safely; no workflow/replies/reactions/notifications appear.
- **Evidence:** Viewer/Owner browser, request, and built-CLI tests for anchoring/order/auth/revocation/pagination/JSON/redaction plus privacy review.
- **Central surfaces / impact:** Comment schema, injected reserved UI/routes, Owner UI, API/CLI registration. Realtime is optional correctness transport owned by U24.
- **Safe split:** Posting and retrieval may use two checkpoints, but integration requires one complete Viewer-to-Owner/Producer feedback journey.

### U24 — Reconnect live feedback without making realtime authoritative

- **Acceptance umbrella / blockers:** GitHub #9; blocked by U03 and U23.
- **Outcome:** Self-hosted AnyCable delivers new authorized Comments to connected Viewers, while disconnect/reconnect/fetch restores authoritative ordering and correctness never depends on WebSocket delivery.
- **Failure/recovery:** Wrong Site/Person subscriptions, revoked sessions, dropped/duplicate/out-of-order messages, unavailable AnyCable, and reconnect races recover from HTTP truth without leaking data.
- **Evidence:** Real-browser multi-session/reconnect tests, channel authorization, process health/failure smoke, and privacy/operations review.
- **Central surfaces / impact:** AnyCable process/config, channel/auth seam, injected client. Do not expand Comment semantics.
- **Safe split:** Process health/auth may checkpoint before live UI only when U23 remains fully usable without realtime.

### U25 — Show minimal Owner-only View Receipts

- **Acceptance umbrella / blockers:** GitHub #10; blocked by U08, U13, U18, and U20.
- **Outcome:** A successful authenticated content open creates a minimally deduplicated Person/Site/Release receipt visible only in Owner UI/API/`shortbread receipts --json`.
- **Failure/recovery:** Previews, health checks, failed auth, assets, ranges/background probes, offline cache reads, retries, and other Viewers cannot fabricate or infer receipts.
- **Evidence:** Request/browser/CLI classification, deduplication, authorization, cross-Site isolation, privacy, and eventual deletion tests.
- **Central surfaces / impact:** Receipt schema, successful-content boundary, Owner UI/API/CLI. No analytics/event stream or third party.
- **Safe split:** Recording and reporting may checkpoint separately, but the unit integrates only with Owner-visible verified classification.

### U26 — Stop access through a retryable Site-deletion state machine

- **Acceptance umbrella / blockers:** GitHub #11; blocked by U08, U11, U23, and U25.
- **Outcome:** Owner UI/CLI explicitly confirms a named Site deletion, commits a durable pending/complete/failed state, and immediately fails serving, Invitations, Grants, feedback, receipts, publishing, and current-pointer access closed.
- **Failure/recovery:** Retry after each interrupted record-cleanup stage, concurrent publish/access, duplicate requests, wrong Site confirmation, and worker failure remain idempotent and inspectable.
- **Evidence:** Request/job/CLI failure-injection and concurrency tests, UI confirmation, stable JSON, and destructive-data/security/operations review.
- **Central surfaces / impact:** Deletion state/schema/job, authorization/serving guards, related-record policy, CLI command registration. Object reclamation is U27.
- **Safe split:** Fail-closed boundary and record cleanup may be two checkpoints only if the first is durable/retryable and does not falsely report completion.

### U27 — Reclaim only unshared Blobs and explain recovery truthfully

- **Acceptance umbrella / blockers:** GitHub #11; blocked by U15 and U26.
- **Outcome:** Deletion transactionally identifies Blobs with no remaining Release references, retryably deletes only those private objects, and reports pending/failed/complete cleanup while operations guidance distinguishes source Bundles, provider durability/backups, and application deletion.
- **Failure/recovery:** Shared references, partial R2 failure, concurrent publish/delete, retry, already-missing objects, provider versioning, and operator-held source recovery never remove required content or overstate erasure.
- **Evidence:** Shared/unshared set tests, R2 failure injection, retry/idempotency, restore/deletion wording, and destructive-data/operations review.
- **Central surfaces / impact:** Blob GC set, cleanup job, provider adapter, deletion status and operations docs.
- **Safe split:** Reference calculation and provider deletion may checkpoint separately; completion remains false until the provider phase succeeds or reaches a documented terminal disposition.

### U28 — Produce the final non-root application image

- **Acceptance umbrella / blockers:** GitHub #12; blocked by U03, U19, U22, U24, U25, and U27.
- **Outcome:** CI/local tooling produces an immutable production application image that runs non-root with documented migrate/web/worker/WebSocket commands, health behavior, runtime configuration, and complete built assets.
- **Failure/recovery:** Missing config, migration failure, read-only filesystem assumptions, signal/shutdown, worker/WebSocket failure, architecture mismatch, and container vulnerabilities fail before release promotion.
- **Evidence:** Reproducible build, digest, container scan/SBOM-equivalent inventory, non-root/runtime health, production-shaped full journey smoke, and supply-chain/operations review.
- **Central surfaces / impact:** Container/release files, process commands, CI build, artifact naming. U30 publishes only after CLI artifacts also pass.
- **Safe split:** Image hardening and full product smoke may be two checkpoints, but one immutable digest must pass both before integration.

### U29 — Produce checksummed cross-platform CLI artifacts

- **Acceptance umbrella / blockers:** GitHub #12; blocked by U01, U08, U10, U11, U12, U23, U25, and U26.
- **Outcome:** Supported macOS/Linux users install a single `shortbread` binary, verify checksums, inspect version/commit/API range, and run the complete management command surface without a language runtime.
- **Failure/recovery:** Unsupported architecture, corrupt checksum, incompatible API, missing keyring, non-interactive misuse, and partial install fail with non-mutating instructions.
- **Evidence:** Cross-builds, checksums, dependency/SBOM inventory, clean-machine install probes, every black-box command/JSON contract, and supply-chain review.
- **Central surfaces / impact:** GoReleaser/build config, CLI version/command registry, artifact names/docs. No stable release tag yet.
- **Safe split:** Architecture builds may run as matrix jobs, but the unit promotes one consistent version/compatibility/checksum contract.

### U30 — Rehearse immutable app/CLI release artifacts

- **Acceptance umbrella / blockers:** GitHub #12; blocked by U28 and U29.
- **Outcome:** Least-privilege pinned CI produces draft/prerelease app and CLI artifacts, and a clean production-shaped checkout installs them and completes the Shortbread actor smoke without rebuilding from source.
- **Failure/recovery:** Missing provenance/checksum/SBOM, mutable tag/image reference, permission excess, incompatible app/CLI, failed migration/health, and artifact unavailability block promotion.
- **Evidence:** CI workflow review, artifact download/install/checksum, image digest, compatibility smoke, license/security scan, and release/operations review.
- **Central surfaces / impact:** GitHub workflows, package/release configuration, immutable references. Stable promotion remains U38.
- **Safe split:** CI publication and clean install may checkpoint separately, but the issue remains open until published candidates pass the smoke.

### U31 — Apply and resume provider changes against failure-injection fakes

- **Acceptance umbrella / blockers:** GitHub #13; blocked by U04 and U28.
- **Outcome:** The provisioner validates least-privilege capabilities and idempotently creates/updates only manifest-declared, namespaced Northflank, PlanetScale, R2, and DNS/TLS resources against provider command/API fakes, with resumable checkpoints.
- **Failure/recovery:** Unknown existing resources, partial creation, provider timeout/rate/error, stale plan, scope deficiency, plan-cost change, retry, and rollback never adopt/delete unknown resources, upgrade plans, buy/transfer domains, or accept terms.
- **Evidence:** Provider command-contract and failure-injection matrices, exact inventory/state transitions, idempotent apply/resume replay, redacted errors, and infrastructure/security review.
- **Central surfaces / impact:** Provider adapters, manifest state, resource naming, checkpoint store, deployment docs. Use current official provider APIs at implementation time; no live credentials.
- **Safe split:** One provider adapter may checkpoint after the shared manifest/apply protocol is green, but later providers must implement the same public state machine rather than fork it.

### U32 — Deploy, diagnose, and accept secrets only through the Operator boundary

- **Acceptance umbrella / blockers:** GitHub #13; blocked by U24, U30, and U31.
- **Outcome:** A direct Operator-run setup program accepts secrets only through no-echo stdin/provider-native auth/keychain/direct secret-store entry, orders secrets → database/R2/DNS/TLS → migrate → web/worker/WebSocket → health, and `doctor` verifies every dependency with redacted status.
- **Failure/recovery:** Secret leakage, partial deploy, unhealthy migration/process, DNS/TLS propagation, queue/WebSocket/API mismatch, invalid scope, interrupted resume, and smoke failure produce one exact safe continuation without false success.
- **Evidence:** Clean-room fake-provider deploy/resume/doctor, redaction and process-argument audit, production-shaped artifact smoke, setup inventory, and secrets/infrastructure/operations review. Optional live values remain outside model/tool logs.
- **Central surfaces / impact:** Setup command/program, secret ingress, deploy orchestrator, doctor, provider stores, operations docs. This freezes the final credential ceremony contract.
- **Safe split:** Deploy ordering and doctor may checkpoint separately only if the setup program retains one resumable state and never declares deployment complete before doctor passes.

### U33 — Publish the deterministic synthetic Shortbread tour

- **Acceptance umbrella / blockers:** GitHub #15; blocked by U01, U13, U22, U24, U25, and U27.
- **Outcome:** A small attractive invented-data multi-page Bundle and deterministic seed/publish/tour demonstrate Invitation, Shelf, private Site, republish/rollback, offline keeping/update, feedback, receipts, revocation, and deletion without real/private/proprietary data or anonymous hosting.
- **Failure/recovery:** Non-deterministic clock/data, stale state, external/private assets, license ambiguity, anonymous exposure, and failed reset make the tour fail explicitly.
- **Evidence:** Example validation/license scan, deterministic seed and full real-browser tour, repeatable cleanup, local docs usability, and privacy/license review.
- **Central surfaces / impact:** Example source/fixtures, tour harness, deterministic data/clock. Screenshot capture is U34.
- **Safe split:** Example Bundle and scripted tour may checkpoint separately, but the example is not accepted until the real app completes every named state.

### U34 — Capture and freshness-check real documentation screenshots

- **Acceptance umbrella / blockers:** GitHub #15; blocked by U33.
- **Outcome:** A repeatable browser harness captures current real-app desktop/mobile documentation screenshots with deterministic state, stable filenames, accessible captions/alt text, and a manifest that fails when required images are absent or stale.
- **Failure/recovery:** Wrong viewport/state, nondeterminism, stale flow, missing accessibility metadata, private data, and manual image drift fail the freshness check.
- **Evidence:** Screenshot regeneration, manifest/digest/freshness tests, visual/accessibility review, privacy scan, and clean rerun.
- **Central surfaces / impact:** Generated screenshots are controller-exclusive; harness, manifest, docs image references. No image is accepted from mockups or synthetic rendering outside the app.
- **Safe split:** Capture harness and final image set may checkpoint separately, but generation/freshness must be one command contract.

### U35 — Make product and operations documentation executable

- **Acceptance umbrella / blockers:** GitHub #16; blocked by U20, U27, U30, U32, and U34.
- **Outcome:** The public repository explains Shortbread, trust/no-build boundary, quickstart, CLI/API, Owner/Viewer/Producer flows, artifacts, setup, upgrades, migrations, health, logs/redaction, backup/restore, deletion, disaster recovery, architecture, contribution, testing, release, and the MWP experiment without private knowledge.
- **Failure/recovery:** Missing/stale commands, links, config keys, screenshots, compatibility guidance, recovery steps, secret handling, or provider assumptions fail mechanical checks.
- **Evidence:** Command/help/config/link/screenshot-manifest checks, docs build/readability, operations/security review, and exact credential/value inventory.
- **Central surfaces / impact:** Root README and all public docs are controller-coordinated; product behavior changes discovered here become separate regression-first repairs.
- **Safe split:** Product/CLI and setup/operations guides may be parallel drafts only after central terminology/config ownership is reserved; U36 validates them together.

### U36 — Repair every gap found by an independent clean clone

- **Acceptance umbrella / blockers:** GitHub #16; blocked by U35.
- **Outcome:** A fresh independent agent follows only public docs from clone through bootstrap, local example, tests, production-shaped artifact boot, credential-free plan/apply/resume/doctor, and complete actor tour, recording and repairing every undocumented step.
- **Failure/recovery:** Host-global assumptions, sibling repos, cached tools, hidden config, stale links, platform-specific gaps, dirty generated output, or irreproducible evidence block completion.
- **Evidence:** Clean clone transcript reduced to concise commands/results/gaps, repaired docs/code/tests, second independent green rehearsal, and no private source dependency.
- **Central surfaces / impact:** May touch any documented setup seam through controller-assigned repairs; all repairs return through affected unit review rules.
- **Safe split:** Local development and production-shaped/provider rehearsal may be two independent runs, but both must start from the same released tree and public docs.

### U37 — Repeat the holistic trust and terminal composition audit

- **Acceptance umbrella / blockers:** GitHub #14 and #17; blocked by U20, U27, U30, U32, U34, and U36.
- **Outcome:** Independent reviewers reconcile every PRD story/ADR/umbrella/leaf with merged behavior and repeat the complete trust/data-flow audit over offline, feedback, receipts, deletion, provider/provisioner, artifacts, fixtures, screenshots, runtime/browser network behavior, dependencies, logs, and private-content boundaries.
- **Failure/recovery:** Missing acceptance, unresolved review, secret/private/proprietary content, stale artifact/docs, unsafe network/log behavior, or unverified recovery is a blocker assigned to a bounded repair unit; it cannot be waived by vote.
- **Evidence:** Full browser/request/CLI/unit/provider-contract/static/security/license/secret/container/build/link/screenshot suites plus final Standards, Spec, security/operations, OSS/private-content, and clean-room verdicts.
- **Central surfaces / impact:** Final evidence/report only until a blocker creates a separate repair. Reviewers must be independent of the implementation under audit.
- **Safe split:** Review axes may run in parallel on the same fixed release candidate; U38 waits for one reconciled blocker-free verdict.

### U38 — Promote the stable release and present one credential ceremony

- **Acceptance umbrella / blockers:** GitHub #17; blocked by U37.
- **Outcome:** The controller promotes immutable app/CLI artifacts to the stable public release, closes all acceptance umbrellas, consolidates harvest results, and presents one exact Operator ceremony listing account/domain/plan values, safe credential ingress, apply, Owner bootstrap, doctor, and full live smoke.
- **Failure/recovery:** Artifact drift, missing checksums/compatibility, incomplete issue/evidence state, credentials absent, or unsafe live ingress cannot be called a live deployment. Credential absence truthfully leaves a credential-ready repository and one exact Operator-only command.
- **Evidence:** Release/tag/package checks, terminal report, redacted setup checklist, optional live provision → deploy → Owner bootstrap → CLI login → publish → invite → view → feedback smoke, and final factory evaluation.
- **Central surfaces / impact:** Stable release/tag, root RUN/tracker, release notes, credential boundary, factory harvest. Paid/legal/account/domain decisions remain Operator actions.
- **Safe split:** Stable artifact promotion and optional live smoke are distinct evidence states, but both share one ceremony; missing credentials do not invalidate credential-ready completion.

## Controller Review

The accepted graph was challenged against the original run and revised before publication:

- **Oversized recovery:** Release and auth branches are serialized; U02 replays auth semantically after U01 instead of attempting a conflict-heavy parallel merge.
- **Unbounded auth:** Owner bootstrap, re-entry/recovery, automation tokens, common API policy, and remote CLI login are separate actor-visible units.
- **Unbounded access:** Site/Person management, Grants, Invitations, Shelf/handoff, and Viewer passkeys are separate units with explicit session dependencies.
- **Hidden deployment cliff:** Production-shaped runtime and credential-free resource planning move to C01; provider apply/deploy remain later because they require stable artifacts and process roles.
- **False parallelism:** Schema, root routes, CLI registration, injected UI, service worker, screenshots, release, deployment, and root docs are called out as reservations. Campaign membership never overrides them.
- **Security timing:** U20 audits the implemented control/content boundaries before offline/feedback/receipts; U37 repeats the audit over the complete release candidate.
- **Final-bucket risk:** Artifacts, provider contracts, example evidence, and docs each have earlier executable units; U37/U38 are verification/promotion gates, not containers for missing product work.
- **Credential boundary:** U04/U31/U32 prove every credential-free behavior; U38 requests or references live values once and distinguishes credential-ready from live-smoked.
- **Coverage:** The PRD table assigns every story 1–64, and every original issue #3–#17 remains an acceptance umbrella.

**Controller verdict:** Approved for publication on 2026-07-20 under Chris's explicit acceptance and the initiative authority envelope. Only U01 is the executable frontier.

## Fresh-Context Start Packet for U01

A new controller begins with only:

1. `AGENTS.md` and `docs/agents/mwp.md`;
2. root initiative `RUN.md` and Stage 05 `tracker.md`;
3. [`UNIT-CONTRACT.md`](UNIT-CONTRACT.md) and the U01 card above;
4. original umbrella [ticket body](../../02_ticket_map/output/tickets/02-releases-and-rollback.md), ADR 0003, and relevant domain glossary entries;
5. fixed candidate branch/SHA `ticket-3-releases-rollback` / `f5943d7` and its GitHub issue/PR state.

The controller reconciles local/remote refs, creates a durable worktree and draft PR, fixes the review target, and invokes implementation only for evidence-backed U01 repairs. It does not re-read or relaunch the superseded whole-v1 goal.
