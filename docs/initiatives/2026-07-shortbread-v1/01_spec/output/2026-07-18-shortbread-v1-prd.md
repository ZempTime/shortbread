# PRD: Shortbread v1

**Status:** Accepted for autonomous implementation
**Repository:** `ZempTime/shortbread`
**License:** MIT
**Canonical framing:** [`docs/initiatives/2026-07-shortbread-v1/00_framing/output/2026-07-18-framing-contract.md`](https://github.com/ZempTime/shortbread/blob/main/docs/initiatives/2026-07-shortbread-v1/00_framing/output/2026-07-18-framing-contract.md)

## Problem Statement

Interactive HTML explainers, trip Sites, and prototypes are easy to build but awkward to share privately. Existing options tend to make the content public, trap it inside a producer-specific tool, require every Viewer to create an account, collapse a multi-page experience into screenshots, or demand bespoke hosting and authentication. Iteration then fragments feedback across texts and screenshots with no reliable Release or page context. Offline use adds another failure mode: ordinary web hosting does not give a Viewer a clear, atomic, user-controlled way to keep the whole Site available when connectivity disappears.

The Owner needs one small, trustworthy host for already-built Bundles. It must serve personal material only to named people, preserve a one-tap Viewer journey, support immutable iteration and rollback, let Viewers deliberately keep eligible Sites offline, and collect contextual feedback for any operator-controlled Producer to retrieve. It must remain a host and access layer—not a CMS, collaboration workflow, notification service, analytics product, or AI processor. As an open-source project, a new Operator must be able to understand, run, audit, and deploy it without private knowledge or proprietary application dependencies.

## Solution

Shortbread is a public MIT-licensed, single-Owner Rails application plus a Go CLI named `shortbread`. A Producer publishes an already-built directory as an immutable Release of a Site. Content-addressed Blobs live in private S3-compatible storage; a Release Manifest maps safe paths to those Blobs; an atomic current pointer selects what a stable Site origin serves. Shortbread never builds or rewrites the Bundle.

The apex origin contains Owner controls, personal Invitation acceptance, and a Viewer Shelf. Each Site runs at `<slug>.sites.<apex>`, which confines arbitrary Bundle JavaScript and gives relative/root-relative files plus offline caching a normal web origin. A preview-safe one-time Invitation activates a Person's Grant at the apex; a short-lived signed handoff establishes a host-only Site cookie. Passkeys support Owner authentication and optional Viewer re-entry without passwords.

Every Site may expose a Shortbread-owned, injected flat Feedback Thread. Comments automatically carry Release and page-path context and remain retrievable through the API/CLI. Owner-only View Receipts answer who opened which Release without social analytics. When allowed by the Owner, a Viewer explicitly keeps one complete Release offline: required and optional Manifest Entries download visibly into a new cache, and the service worker switches only after the new cache is complete.

The reference production path uses Northflank, PlanetScale Postgres, and private Cloudflare R2. Tested automation plans and creates only namespaced Shortbread resources from Operator-supplied credentials and deployment values, configures secrets/DNS/TLS/roles, deploys, migrates, and smoke-tests. Standard container, HTTP, PostgreSQL, S3, and DNS seams preserve open-source portability.

## User Stories

### Owner

1. As the Operator becoming the Owner, I can use a one-time local/deployment bootstrap command or URL to register the first passkey so no default password, public signup, or seeded credential exists.
2. As the Owner, I can register more than one passkey and remove an old passkey so a single lost device does not strand the installation.
3. As the Operator recovering the Owner, I can mint a short-lived recovery ceremony from deployment authority, while remote callers cannot invoke recovery and recovery values never enter logs or durable URLs.
4. As the Owner, I can create a Site with a unique validated slug, name, icon/metadata, explicit optional SPA fallback, and `allow offline` policy.
5. As the Owner, I can see every Site, its stable URL, current Release, Release count, Viewer count, recent feedback, and recent Owner-only receipts from the apex control plane.
6. As the Owner, I can maintain one roster of People by first name and optional disambiguating private note, independent of any one Site.
7. As the Owner, I can grant or revoke a Person's access to a Site and choose whether that Grant permits an Offline Copy within the Site policy.
8. As the Owner, I can create a personal Invitation for a Grant, copy its link, see whether it is pending/accepted/expired/revoked, and revoke it without Shortbread contacting the Person.
9. As the Owner, I can rotate an unaccepted Invitation without creating a second Person or Grant.
10. As the Owner, I can revoke future server access and updates immediately while the UI/docs state that an already saved Offline Copy cannot be remotely removed.
11. As the Owner, I can list immutable Releases, see which one is current, and atomically roll back the Site to an earlier Release without copying or rebuilding content.
12. As the Owner, I can see the single chronological Feedback Thread with each Comment's Person, Release, path, and timestamp, without replies, reactions, assignments, or workflow states.
13. As the Owner, I can see which Person opened which Release, while no Viewer can see another Viewer's receipt and no third-party analytics receives the event.
14. As the Owner, I can list and revoke CLI/automation credentials with label, creation time, last-used time, and scope but never recover their plaintext token.
15. As the Owner, I can delete a Site through an explicit confirmation that names the effects: revoke Grants, remove Site/Release/Comment/receipt records according to documented retention, and asynchronously delete only Blobs no other Release references.
16. As the Owner, I can retry an interrupted Site deletion safely and see whether cleanup is pending or complete.
17. As the Owner, I can use the same core management operations from the web UI and `shortbread` CLI/API, with authorization and audit behavior kept consistent.

### Viewer

18. As an invited Person, a messaging-app link preview or safe GET can inspect the Invitation landing page without consuming the Invitation, creating a session, or recording a View Receipt.
19. As an invited Person, I can explicitly accept a valid Invitation in one tap, confirm the displayed first name when needed, and reach the Site without creating an account or password.
20. As a Viewer, I can bookmark the apex Shelf and see every Site for which I currently have a Grant.
21. As a Viewer, opening a Shelf item or accepted Invitation transfers me to the correct Site origin through a short-lived one-use handoff without exposing a reusable credential to Bundle JavaScript or browser history.
22. As a Viewer, my Site session uses a `__Host-` cookie (Secure in production, HttpOnly, `Path=/`, no `Domain`), expires, and is useless on the apex or another Site host; a hostile sibling Site cannot shadow it or perform a cross-Site reserved-endpoint mutation.
23. As a Viewer, I can optionally register a passkey at the apex for later re-entry while a first-time Invitation remains accountless and passwordless.
24. As a Viewer, I can browse a multi-page Site with normal `/`, directory-index, relative, and root-relative paths, plus media range requests and ordinary file downloads.
25. As a Viewer, I can expand one consistent Feedback Thread from any HTML page, post a flat Comment under my first name, and receive Release/path context automatically.
26. As a Viewer, when offline keeping is allowed I can see required/optional size, choose to keep the Release, watch progress, and continue using the prior complete Release if the download fails.
27. As a Viewer with an Offline Copy, I can open the Site without a network, see which Release is saved, and choose when to download a visible newer Release.
28. As a Viewer, I can remove the Offline Copy from this device, unregister the Shortbread service worker for that Site as appropriate, and receive a clear success/failure result.
29. As a Viewer, I am told that browser storage may be evicted and that revocation prevents new access/updates but cannot erase content already saved on my device.
30. As a revoked Viewer, future online content, feedback, and update requests fail without leaking whether other People or Releases exist.

### Producer and CLI user

31. As a Producer, I can install one released `shortbread` binary for a supported macOS or Linux architecture, verify its checksum, and run `shortbread version` without a language runtime.
32. As a human Producer, I can run `shortbread login --server https://shortbread.example.com [--profile name]`, approve the request in that deployed instance with the Owner passkey, and store the returned token in the OS keyring.
33. As a human Producer, I can use `shortbread profiles`, `whoami`, and `logout` to inspect, select, and revoke local server/profile credentials without printing a token.
34. As a CI/agent Producer, I can use an explicitly created scoped `SHORTBREAD_TOKEN` plus `SHORTBREAD_URL` without a browser or OS keyring.
35. As a Producer using multiple installations, every networked command can resolve `--server`/`--profile` and the non-secret `SHORTBREAD_URL`/`SHORTBREAD_PROFILE` overrides predictably.
36. As a Producer, I can run `shortbread sites create/list/delete`, `people add/list`, `access grant/revoke`, `invite create/revoke`, `releases list/rollback`, `publish`, `feedback`, and `receipts` subject to token scope.
37. As a Producer, `shortbread publish <directory> --site <slug>` walks the directory without following symlinks, normalizes safe relative paths, and rejects traversal, absolute paths, case/Unicode collisions, reserved Shortbread paths, invalid file types, and configured secret-like files before network upload.
38. As a Producer, publish computes SHA-256, size, and content type for every Manifest Entry, identifies required/optional offline policy, warns about external origins that can break privacy/offline use, and can enforce a documented strict mode.
39. As a Producer, publish asks `/api/v1` which Blobs are missing, PUTs only those bodies through short-lived presigned R2 URLs, and never sends local paths or private bodies to GitHub, analytics, or AI.
40. As a Producer, retrying an interrupted upload or finalize is idempotent, hash/size mismatches fail closed, and a Release becomes visible only after complete atomic finalization.
41. As a Producer, successful publish returns the Release number, stable Site URL, changed/reused/uploaded counts, bytes, and machine-readable result.
42. As a Producer, `shortbread feedback --site <slug> [--since-release N] --json` returns stable ordered Comment records with Person first name, Release, path, timestamp, and content.
43. As an automation author, all commands support stable `--json` success/error envelopes, deterministic exit categories, non-interactive mode, timeouts, and redaction of tokens/private response bodies.
44. As a CLI user, a server/API compatibility mismatch produces a clear upgrade/downgrade instruction before mutating data.
45. As an API client, mutating `/api/v1` operations support idempotency keys, scoped bearer tokens, bounded pagination, explicit errors, and documented rate limits.

### Operator

46. As a new Operator, I can clone the public repository, run one documented tool/bootstrap command, and use `mise` pins for Ruby, Node, Go, Aube, fnox, hk, PostgreSQL, and AnyCable Go.
47. As a new Operator, I can run the application, worker, WebSocket process, PostgreSQL, browser tests, and black-box Go CLI flow locally without production provider accounts.
48. As an Operator reviewing supply chain, I can inspect one front-loaded Ruby/JavaScript/Go dependency baseline, committed lockfiles, build scripts, licenses, and security audit before feature work fans out.
49. As an Operator, later dependency changes are exceptional, isolated, controller-approved, and explain why the standard library/current baseline is insufficient; small shadcn component source additions use the existing package set.
50. As an Operator, a setup guide and `shortbread setup`/provisioning workflow enumerate the exact GitHub, Northflank, PlanetScale, Cloudflare/R2, apex-domain, account/project, region, and deployment values required without accepting secrets in process arguments or Git.
51. As an Operator, I can run a credential-free plan/command-contract mode that shows idempotently named resources, intended changes, roles, secrets, DNS records, health checks, and expected costs/plan choices without mutating a provider.
52. As an authorized Operator, supplying least-privilege credentials outside Git lets the provisioner validate scopes and create/update only manifest-declared Shortbread resources without adopting or deleting unknown existing resources.
53. As an Operator, deployment configures separate migrate, web, worker, and self-hosted WebSocket roles as justified, injects secrets directly into provider stores, applies database migrations safely, and waits for health before declaring success.
54. As an Operator, `doctor` verifies DNS/wildcard TLS, application health, database, private object access, queue/WebSocket health, API/CLI compatibility, and configuration without echoing secrets.
55. As an Operator, the operations guide distinguishes source-Bundle recovery, PlanetScale backup/restore, R2 durability/versioning choices, application rollback, database migrations, and destructive Site deletion instead of promising an untested “platform backup.”
56. As an Operator, upgrades and rollbacks have compatibility rules, preflight checks, database guidance, immutable container references, and a tested recovery route.
57. As an Operator, a clean-room rehearsal proves the repository is credential-ready; once credentials exist, one optional live smoke proves provision → deploy → Owner bootstrap → CLI login → publish → invite → view → feedback.
58. As an Operator, I can consume immutable app images and checksummed cross-platform CLI artifacts from GitHub releases and verify the documented version/compatibility matrix.

### Contributor and process evaluator

59. As a prospective contributor, the README explains Shortbread, self-hosting, the no-build product boundary, the trust contract, status, quickstart, MIT license, and Chris's experiment with AI processes for building software.
60. As a prospective Operator, I can publish a committed synthetic example Bundle and follow a public tour that demonstrates Invitation, Shelf, Site, offline keeping, feedback, receipt, republish, and deletion without real private data or anonymous hosted access.
61. As a reader, documentation screenshots come from the working application through a repeatable browser capture harness at named viewports, include accessible captions, and fail a freshness check when the flow changes.
62. As a process evaluator, I can inspect canonical PRD/tickets, per-slice MWP state/evidence, independent reviews and repairs, controller checkpoints, and factory harvest decisions without needing private conversation transcripts.
63. As a maintainer, every ticket either promotes a demonstrated reusable harness/process improvement into `agents/` or records `No reusable harvest`, while Shortbread-specific facts remain with product docs/code/tests.
64. As a privacy reviewer, I can inspect a public data-flow/threat model and executable checks proving the trust contract, origin/session isolation, private object access, token redaction, and absence of telemetry/optional processors.

## Implementation Decisions

### Application and repository shape

- One public monorepo contains the Rails application, `cli/` Go module, deployment/provisioning code, example Bundle, documentation, MWP workspaces, and reusable `agents/` factory.
- Rails 8.1 + PostgreSQL is the system of record. Inertia + React + TypeScript provides Owner, Shelf, Invitation, and injected Shortbread UI. Vite/Tailwind/shadcn source primitives provide the browser toolchain.
- Self-hosted AnyCable carries live Feedback Thread updates. Solid Queue runs durable cleanup and other asynchronous work. No external realtime, job, analytics, auth, or error-reporting SaaS is an application dependency.
- The dependency baseline and tool pins are defined in [`docs/initiatives/2026-07-shortbread-v1/03_goal_handoff/output/dependency-baseline.md`](https://github.com/ZempTime/shortbread/blob/main/docs/initiatives/2026-07-shortbread-v1/03_goal_handoff/output/dependency-baseline.md) and ADR 0007. The first tracer resolves lockfiles and audits licenses/security before other implementation branches start.

### Records and storage

- Core records follow the root glossary: Owner credential, Person, Site, Grant, Invitation, Release, Manifest Entry, Blob, Feedback Thread/Comment, View Receipt, CLI authorization/token, and cleanup state.
- Site slugs are globally unique within one installation. Release numbers are monotonic per Site. Releases and Manifest Entries are immutable after finalize.
- Blob identity is lowercase SHA-256 plus byte size verification. Private R2 keys are content-derived under an installation namespace; database references, not bucket listing, govern serving.
- Publish finalize validates ownership, upload presence, hash/size/Manifest consistency, idempotency, Site policy, and a complete transaction before advancing the current Release.
- Rollback changes only the current pointer and records the action. It never mutates historical Release content.

### Host routing and content isolation

- `SHORTBREAD_APEX_HOST` defines the exact apex. Sites use one-label `<slug>.sites.<apex>`; unknown/deeper/malformed hosts fail closed before application routing.
- The apex never serves Bundle bodies. Site hosts serve only their current Release plus Shortbread-reserved endpoints and injected controls.
- Bundle HTML injection is deterministic and idempotent, restricted to eligible HTML responses, and covered against malformed/streamed content. Non-HTML bytes remain exact.
- Bundle CSP/sandbox guidance, external-origin lint, and a documented strict mode reduce accidental processors, but Shortbread does not pretend it can make arbitrary third-party Bundle code offline/private. The Producer owns Bundle composition.

### Invitations, sessions, and passkeys

- Invitation secrets are high-entropy, stored only as digests, rate-limited, expiring, individually revocable, and consumed only by an explicit unsafe-method acceptance guarded against CSRF/replay.
- Acceptance binds the intended Person/Grant. Link preview GETs have no side effects. Successful acceptance mints a one-use, audience/host-bound, short-lived signed handoff; the Site exchanges it for a production `__Host-` HttpOnly cookie (`Secure`, `Path=/`, no `Domain`) and removes the handoff from the visible URL. Apex sessions use the same prefix constraints.
- Because sibling Site origins are same-site, SameSite cookies are not treated as CSRF isolation. Every state-changing `/_shortbread/*` endpoint requires a session-bound CSRF token, exact expected `Origin`, and appropriate Fetch Metadata; reserved endpoints expose no permissive credentialed CORS. Tests cover sibling Domain-cookie shadowing/tossing and cross-Site mutation attempts.
- Owner and Viewer passkeys use correct deployed RP ID/origin configuration and request-layer WebAuthn verification. Viewers never need a passkey for first acceptance.
- Owner bootstrap is single-use. Recovery is invoked from deployment authority, expires quickly, and is recorded without revealing its secret. Owners are encouraged to register multiple passkeys.

### Remote CLI authentication and API

- The CLI keeps named profiles keyed by normalized HTTPS server origin. Non-loopback HTTP is refused. Endpoint/profile selection precedence is documented and testable.
- Browser-assisted login creates a short-lived device authorization, opens the deployed apex verification page, lets the Owner approve after passkey authentication, then returns a token once through bounded polling. The high-entropy device code is still a bearer secret: it is one-use, short-lived, redacted, held only by the initiating CLI, and proof-key bound when possible; a public user code/verification URL is distinct from it.
- Interactive tokens live in the OS keyring through go-keyring; server records store digests. `logout` deletes the local token and attempts server revocation. Automation tokens are separately minted/scoped and enter via environment or stdin-safe secret mechanisms.
- `/api/v1` is JSON over HTTPS with explicit version/compatibility headers, scoped bearer auth, idempotency keys for mutations, bounded pagination, stable error codes, request IDs, and token-safe logs.
- Cobra defines the command/help surface. HTTP, JSON, filesystem, hashing, retry, browser launch, provider API, and test behavior use the Go standard library unless the controller approves a documented exception.

### Publishing and serving

- CLI validation completes before presigning: path normalization, no symlinks/special files, collision detection, reserved-path rejection, configurable secret-file rules, file/Bundle size accounting, content types, external-origin warnings, and offline classification.
- The API returns short-lived presigned PUTs only for missing Blobs. R2 remains private; presigned upload does not grant reads or arbitrary keys. Retries are safe.
- Serving authorizes the Site session/Grant before resolving Manifest entries and fetching private Blob bytes. It supports GET/HEAD, strong content hash ETags, conditional requests, single byte ranges, correct content length/type, directory indexes, and explicit Site-level SPA fallback.
- Site deletion is a durable state machine: stop serving, revoke Grants/Invitations, remove dependent records according to policy, compute unreferenced Blobs transactionally, and retry object deletion. Shared Blobs cannot be removed.

### Offline behavior

- The Release Manifest marks entries `required`, `optional`, or ordinary-download-only. HTML/CSS/JS and essential metadata default required; Producers may classify heavy media explicitly within validation rules.
- The injected UI requests a Release-specific offline manifest, shows byte/file counts and policy, and begins only after Viewer confirmation.
- The service worker populates a new Release-named cache, verifies every required response/hash/size, optionally downloads selected optional entries, and atomically changes its local current marker. Failure deletes the incomplete cache and preserves the prior cache.
- Navigation and asset fetches pin to the locally selected complete Release while offline. An online newer Release is offered, never silently installed. Removal clears Shortbread caches/state and communicates browser limitations.

### Feedback and receipts

- One Feedback Thread per Site is injected into eligible HTML pages under reserved endpoints. Comments are flat, append-only through ordinary product UI, attributed to the authenticated Person's first name, and anchored server-side to the served Release/path.
- AnyCable updates connected Viewers, but correctness never depends on a WebSocket; reconnect/fetch restores authoritative order.
- View Receipts are recorded only after an authenticated successful content open, deduplicated to a documented granularity, visible only to the Owner, and excluded from third-party telemetry. Preview and health requests never count.

### Deployment, configuration, and secrets

- Reference automation uses provider APIs/CLIs behind command-contract fakes. It has inventory, plan, apply, resume, and doctor semantics; names every Shortbread-managed resource; is idempotent; and never adopts/deletes unknown resources.
- Credentials never enter chat, agent prompts, Git, issue/PR text, process arguments, or captured tool output. The generated setup program accepts them only when the Operator runs it directly in an interactive terminal through no-echo stdin/provider-native browser authentication or configures them directly in provider/GitHub secret stores; it keeps secrets in process memory/OS keychain only long enough to write the provider store and emits redacted status. Agents may run plans and inspect redacted `doctor` results, but if the runtime cannot keep secret entry out of model/tool logs, live apply remains an exact Operator-run command. `mise.toml` contains only tool pins/non-secret tasks; production secrets never live in repo fnox files.
- Containers run non-root and use separate migrate/web/worker/WebSocket commands as needed. CI builds immutable images and Go binaries, emits checksums/SBOM or equivalent dependency inventory, and runs security/license checks.
- The provisioner may automatically run live only after credentials and deployment values exist. It cannot purchase/upgrade plans, transfer domains, or delete production resources under the v1 authority envelope.

### Trust, logs, and public evidence

> Shortbread itself never sends site content, feedback, invitation data, or viewer PII to AI, analytics, or optional third-party processors. Data is processed only by operator-configured Northflank, PlanetScale, and R2. Producers/agents outside Shortbread are operator-controlled.

- Application logs use request/resource identifiers and redacted structured metadata, never credentials, Invitation values, Comment bodies, Bundle paths/bodies that reveal private content, or Viewer PII beyond what an Operator intentionally sees in the product database.
- The public example uses invented data. Browser screenshots use deterministic synthetic People/Sites and are captured from the actual running app.
- README/setup/security/operations/contributing/API/CLI docs and the process demonstration are part of product completion, not post-release polish.

## Testing Decisions

### Browser system tests

- Owner: bootstrap/passkey, Site/Person/Grant/Invitation management, Release/rollback, feedback/receipts, offline policy, tokens, delete/retry.
- Viewer: preview-safe Invitation, acceptance, apex-to-Site handoff, Shelf, site-cookie isolation, optional passkey, Comment flow, revocation, downloads.
- Offline: explicit keep with size/progress, required/optional selection, real offline reopen, interrupted-update preservation, atomic successful update, policy denial, removal, and saved-copy wording.
- Documentation: deterministic example-tour and screenshot capture at named viewports from the real application.

### Rails request/integration tests

- WebAuthn creation/assertion and deployed origin/RP configuration.
- Invitation GET/POST/replay/expiry/revocation/preview behavior; signed host handoff and cookies.
- Strict Host routing, apex/Site isolation, `__Host-` cookie constraints, sibling cookie-shadow/toss attempts, exact-Origin/Fetch-Metadata/CSRF enforcement, no credentialed permissive CORS, session/Grant authorization, rate limits, and hostile host/path inputs.
- `/api/v1` token scopes, digests/revocation, device authorization, idempotency, pagination, compatibility, JSON/redaction.
- Publish plan/presign/finalize concurrency, hash/size failure, rollback, private R2 serving, HEAD/range/ETag/content type, injection, SPA/directory routing.

### Black-box Go CLI tests

- Build the real binary and run it against the Rails test application/fake R2 for `login`, profiles/whoami/logout, Site/Person/Grant/Invitation operations, publish/retry, Release rollback, feedback/receipts, delete, `--json`, compatibility, and redaction.
- Exercise browser-assisted deployed-instance login through a fake browser callback/approval seam, stolen/replayed/expired device codes and proof-key binding, and CI token mode separately.
- Provider command-contract tests prove plan/apply/resume/doctor without credentials or live mutations.

### Pure unit tests

- Ruby/Go units are reserved for deterministic algorithms: safe path and collision rules, Manifest canonicalization, hash/delta plans, content/range resolution, offline required/optional selection, cache state transitions, and shared-Blob garbage-collection sets.
- Avoid tests of private class structure or mock-heavy implementation choreography when a request/browser/CLI seam is available.

### Delivery verification

- Use red → green → refactor at the agreed public seam for one behavior at a time.
- Run relevant targeted checks regularly and the complete test/lint/type/security/build suite before integration.
- Every implementation receives independent Standards and Spec reviews in parallel. Auth/session/deletion/data/secrets/deployment changes also receive a security/operations review. Blocking findings are repaired and rereviewed.
- Clean-clone rehearsal verifies local setup, production-shaped boot, example flow, CLI artifact install, docs commands/links, screenshot freshness, and credential-free provider plan.
- Provider credentials are requested only once, after all credential-free v1 checks are green. The final setup ceremony may run a live provider smoke when values are supplied; otherwise credential absence is recorded as the sole remaining Operator input, never disguised as live verification.

## Out of Scope

- Building, compiling, editing, templating, or visually authoring Bundle content; Shortbread is never a CMS or static-site generator.
- More than one Owner, team publishing roles, organization tenancy, multi-tenant hosted SaaS, or billing.
- Anonymous public Sites, public-link Grants, search/indexing, discoverability, or a public historical-Release hostname.
- Passwords, email login, SMS, email/push delivery, Invitation delivery, notifications, reminders, or an inbox.
- Feedback replies, nesting, reactions, assignments, approvals, resolve states, moderation workflow, or Shortbread acting on feedback.
- Group-visible View Receipts, behavioral analytics, tracking pixels, ad tech, optional telemetry, or third-party error/event reporting containing product data.
- Shortbread-controlled AI processing. Operator-controlled Producers/agents remain outside the application trust boundary.
- Native mobile/desktop apps or an umbrella Shelf PWA. Each Site owns its optional installation/offline experience.
- Cryptographic erasure of Viewer devices or a promise that revocation removes an Offline Copy.
- Pulling/reconstructing source Bundles from a Release, round-trip export, branches, merge workflows, or Release mutation.
- Custom access tiers/roles, per-file Grants, expiring offline DRM, end-to-end/zero-knowledge content encryption, or a separate sensitive-content mode.
- Automated support for providers beyond the reference Northflank/PlanetScale/R2 recipe in v1; standard interfaces and contribution docs remain portable.
- Paid plan purchases, account creation, domain purchase/transfer, or destructive adoption/deletion of pre-existing external resources.

## Further Notes

### Product truth

- Domain language is defined in root `CONTEXT.md`; accepted hard-to-reverse decisions live under `docs/adr/`.
- The server-private trust contract and the statement that Offline Copies survive revocation must remain prominent in setup, security, Invitation/offline UI, and operations docs.
- Operator source Bundles are the v1 content recovery source. Provider durability/backup features and tested database/object restore steps are documented separately; R2 serving storage alone is not called a backup.

### Delivery truth

- Starting the persistent goal is the Operator's approval of this PRD, the initial ticket graph, the dependency baseline, and the authority envelope in the initiative `RUN.md`.
- The top-level controller owns decomposition, frontier scheduling, subordinate approval, repair, integration, and durable state. Independent agents may implement/review in parallel only on isolated worktrees with non-overlapping edit surfaces.
- GitHub issues/PRs coordinate across sessions. Initiative workspaces retain inputs, meaningful stage contracts, problem-specific harnesses, evidence, and handoffs. `RUN.md` owns live state.
- Each slice records a factory harvest or `No reusable harvest`. Only reusable, evidenced process/harness learning enters `agents/`; Shortbread facts stay with the product.

### v1 terminal condition

Shortbread v1 is complete only when all in-scope tickets are integrated; browser/request/black-box CLI/unit seams and full lint/type/security/build checks pass; independent reviews have no unresolved blockers; a clean clone completes the local example flow; release images and CLI binaries/checksums are produced; the real screenshot harness refreshes docs; the credential-free deployment plan and setup guide enumerate everything; the security/data-flow and backup/restore/deletion docs are verified; and every ticket has a harvest result. If live provider credentials are absent, the repository must still be demonstrably ready for the Operator to supply them and execute one documented deployment/smoke path.
