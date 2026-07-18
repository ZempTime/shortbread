# Design Notes (Distilled 2026-07-18)

Consolidates the design conversation: Chris's requirements, the endorsed external critique, and Claude's proposals. Attribution of what is accepted vs. seed lives in [`request.md`](request.md). The framing stage may amend anything here.

## Product

Shortbread — private little websites for the people you choose. Hosts, gates, and collects; never builds, never acts on feedback. Single-owner (Chris), personal deployment.

## Domain Model

Site (slug, current-release pointer) → Releases (immutable, linear, content-addressed) → manifest rows (path → SHA-256, size, content type) → blobs in private R2. Grants (person × site × tier). Comments (append-only, anchored to release + page path). View log (read receipts per release).

## Serving

- Apex (`shortbread.<domain>`): dashboard, owner auth, invitations.
- Sites at `<slug>.sites.<domain>` — single-label wildcard DNS + wildcard cert (Northflank); Rails routes by Host header; bundle mounted at `/` so root-absolute and relative references work with no rewriting. `/` and `dir/` resolve to `index.html`.
- Auth: personal invite link hits apex → grant validated → short-lived signed ticket → site origin sets its own HttpOnly cookie. Blast radius of hostile bundle JS = that one site. Candidate viewer ceremony: tap link → in; soft identity confirm; optional passkey. Link-preview bots must not consume invitations or create receipts.
- Serve-time injection into HTML: comment thread + service-worker bootstrap. Reserved paths `/_shortbread/*` and `/service-worker.js`; bundles may not contain them.

## Versioning & Offline

- Publish = new immutable release; slug serves current; rollback = repoint. No branches.
- Content addressing dedupes across releases (vendor JS, photos, tile pyramids ~free to re-publish).
- Shortbread-owned service worker pins all page requests to one release manifest; downloads changed files into a new cache; swaps atomically — never a half-updated site. Each site is its own installable PWA (own home-screen icon).
- "Keep offline" shows size/progress; best-effort (browser eviction is real) — durable keeping = ordinary download buttons for .ics/PDF/ZIP.
- Comments and receipts record release + page path ("comments since release 12" is the iteration loop).
- Historical-review hostname (`slug--v12.sites...`) possible later; not the ordinary experience.

## CLI (Go, single binary)

`login`, `publish ./dist --site italy`, `invite`, `feedback`. Publish: walk dir (reject unsafe paths, symlinks, secret files, reserved paths) → hash manifest → server returns presigned R2 PUTs for missing hashes → upload deltas → finalize release atomically → repoint. Lints external origins (CDN fonts, tile servers) and warns; optional CSP privacy mode blocks them. No build step — bundles arrive already built; vendoring external deps is the producer's job.

## Trust Contract

Server-private (not zero-knowledge): private R2, TLS, app-level encryption where appropriate, logs never contain invite tokens or private values, no AI or external processor ever receives content. Sensitive values = private bundle files added locally pre-publish; the model never sees them. Stated plainly: offline copies survive revocation.

## Remaining PRD Decisions (seeds, unaccepted)

1. Revocation vs offline policy per trust tier (sensitive tier may disallow "keep offline").
2. Public-link grant tier in v1?
3. Owner dashboard minimum; viewers get no shelf (links only).
4. No delivery infrastructure (owner texts links; no email/SMS/notifications).
5. Single-tenant permanently.
6. Export (`pull` round-trip), deletion, backup/restore, key recovery.
7. Bundle routing details: clean-directory URLs, optional SPA fallback, byte ranges for large offline files.
8. Offline policy details: whole bundle vs subset, max size, update UX, "remove from this device".

## Stack (Chris's stated preference + reviewed generic template patterns)

Rails 8, Inertia + React + TypeScript, invite-link → passkey auth pattern, S3-compatible R2 integration, on Northflank / PlanetScale / R2. Real-time thread updates candidate: Action Cable/AnyCable. Testing: system tests at the viewer seam; pure-Ruby units for manifest/diff/weighting logic; WebAuthn fake-client at the request layer.
