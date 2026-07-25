# Deployment findings — Northflank, R2, DNS

Verified 2026-07-25 against Northflank primary documentation. **Unaffected by the plannotator
redirect** — this work is needed under any product framing and can proceed in parallel with the
product question.

Provider docs drift. Re-verify anything load-bearing if this document is more than a few
months old.

## Decisions

| Item | Decision |
|---|---|
| Platform | Northflank |
| Apex | `shortbread.chriszempel.com` (rename pending) |
| Site origins | `*.sites.<apex>` — **keep the `.sites.` infix**, see below |
| DNS | Netlify — works, no API integration needed |
| Blob storage | Implement the R2 port (U15/U16); do **not** use a persistent volume |
| Database | Northflank managed Postgres (recommended; not finally confirmed) |
| Services | **One**, not four |

## Wildcard domains: supported

Northflank accepts a literal `*` subdomain with a shared wildcard TLS certificate. New Sites
appear at runtime with **zero per-tenant work** — no API call, no DNS record, no redeploy.

Two switches must both be set **at domain-add time** (under "advanced options"):
- **Wildcard routing** — select `wildcard redirect` from the routing dropdown, plus a region.
- **Wildcard certificate generation** — select `wildcard via DCV`.

> "To add a wildcard subdomain you must add your domain with wildcard redirect and wildcard
> certificate generation. Once the domain has been verified, add a subdomain with `*` as the
> value and assign it to a service's port."

Cert is genuinely shared: "any new subdomains you create under the domain will use the same
wildcard certificate" — so no per-tenant issuance latency and no Let's Encrypt rate-limit
pressure.

Fallback if ever needed: `POST /v1/domains/{domain}/subdomains`, permission
`Account > Networking > Subdomains > Update`. The `subdomain` field regex begins `^\*`,
confirming `*` is API-settable for IaC.

### The apex restriction forces the `.sites.` layout

> "Wildcard routing will restrict the use of your domain to a single region, and **you will be
> unable to use the top-level domain (also called the apex or root domain) for services**."

This is decisive. A flat `*.shortbread.chriszempel.com` would require adding
`shortbread.chriszempel.com` as the wildcard domain — which would then **block the Owner UI
from being served there**, breaking the app (apex hosts Owner bootstrap, landing, health).

The existing `.sites.` layout sidesteps it exactly:

| Role | Host | Northflank setup |
|---|---|---|
| Owner UI / API | `shortbread.chriszempel.com` | normal subdomain → web service |
| Sites | `*.sites.shortbread.chriszempel.com` | wildcard domain `sites.shortbread.chriszempel.com`, `*` subdomain → same service |

**Set `SHORTBREAD_APEX_HOST=shortbread.chriszempel.com` and ship — zero code changes.**
`lib/shortbread/hosts.rb` hardcodes `SITE_HOST_INFIX = ".sites."`; keeping it is both
platform-required and better design (slugs can never collide with apex infrastructure, and the
wildcard cert covers only Sites).

## TLS/DNS: Netlify is fine

Northflank runs ACME itself. You never operate an ACME client and never need DNS-provider API
automation — only three static records, created once by hand:

1. **TXT** — root domain ownership verification.
2. **CNAME** — wildcard routing (`*.sites` → Northflank target).
3. **CNAME** — wildcard cert DCV verification.

The DCV CNAME is **delegation**, not a challenge you service: point it at a Northflank-owned
target once, and Northflank answers all subsequent ACME DNS-01 challenges, including renewals.

CA is Let's Encrypt, 2048-bit RSA, auto-renewed. Cautions: a cert is not issued for a subdomain
until it is **linked to a service port**; clear any stale `_acme-challenge` TXT records first
(a Nov 2025 release added a pre-flight conflict check); disable DNS proxying during initial
verification if applicable.

**Unconfirmed:** that Netlify DNS supports wildcard CNAME records. Not a Northflank question —
verify before committing.

## Pricing (read from northflank.com/pricing)

| Plan | vCPU | Memory | Monthly |
|---|---|---|---|
| nf-compute-10 | 0.1 shared | 256 MB | $2.70 |
| nf-compute-20 | 0.2 shared | 512 MB | $5.40 |
| nf-compute-50 | 0.5 shared | 1 GB | $12.00 |

Storage $0.15/GB/mo. Egress $0.06/GB. Billed per second, no monthly minimum. The free Sandbox
advertises 2 free services and **1 free database** (size limits unconfirmed).

**Estimate: ~$9–11/mo.** Budget `nf-compute-20` (512 MB) for web — 256 MB is tight for Rails 8
with Bootsnap and jemalloc, and brunch-club chose exactly that plan for a comparable app. With
R2 holding blobs, Postgres storage stays negligible.

**Unconfirmed:** managed Postgres addon pricing was not verified from a primary source before
the research was redirected. A search summary suggested ~$3.91/mo but did not reconcile with
published rates — **do not quote it.** Verify at `northflank.com/dbaas/managed-postgresql`.

## Why R2 instead of a persistent volume

Volumes exist and can be shared (**Multi Read/Write** access mode, not the default Single R/W),
but:

> "Ownership of persistent volumes will be given to the group specified in the Docker image,
> determined at build time."

No fsGroup/UID setting is exposed. Our image runs as `10001:10001` on a `read_only` rootfs, so
volume ownership would need empirical validation with a `chown`-in-entrypoint fallback.
Whether Northflank sets a Kubernetes `fsGroup` automatically is **unconfirmed**.

R2 avoids this entirely, is the designed v1 target, and survives replica scaling.
`app/services/local_blob_store.rb` is already a clean five-method content-addressed port
(`put_verified`, `verified?`, `open`, `open_verified`, `each_chunk`) with only **five call
sites**, all in controllers. An `R2BlobStore` implementing the same interface drops in.

## Only one service is needed

`app/jobs/` contains only the empty `ApplicationJob` base class, and `app/channels/` **does not
exist**. Nothing uses ActiveJob or ActionCable. This matches the finding recorded in PR #63.
Drop the `worker` and `cable` roles for the initial deploy — one web service plus a pre-deploy
migration job. (Revisit if the review product introduces realtime or background work.)

## The donor template: brunch-club

`/Users/chris/code/chriszempel_apps/brunch-club` is a working Northflank deployment of the same
stack (Rails 8, AnyCable, Postgres, Vite, mise, aube), same author, same conventions. Copy the
shape of:

- `infra/app.env` — all app-specific non-secret values in one file
- `infra/northflank/*.json` — declarative service + secret-group manifests
- `infra/provision-northflank.sh` — creates resources via API from those manifests
- `infra/provision-r2.sh` + `docs/runbooks/photos-r2.md` — **a working, scripted R2 setup path**
- `docs/runbooks/deploy.md` — phased runbook splitting **HUMAN** (accounts, secret values) from
  **AGENT** (scriptable plumbing)

Shortbread has none of this — only `compose.production.yml`, which targets a single
SSH-accessible machine. Building the `infra/` equivalent is what makes setup "create services,
add secrets, connect repo."

### Field gotchas already recorded by brunch-club

These bit once and are worth not repeating (they apply if PlanetScale is chosen; Northflank
managed Postgres avoids both):

- **PlanetScale TLS**: `ruby:*-slim` images lack `ca-certificates`; and PlanetScale URIs ship
  `sslrootcert=system`, which must be **deleted from `DATABASE_URL`**, letting
  `PGSSLROOTCERT=/etc/ssl/certs/ca-certificates.crt` do the job.
- **PlanetScale usernames are `user.branch`** (e.g. `myrole.main`).
- The app role must include the `postgres` inherited role, or migrations fail on `CREATE TABLE`.
- **Secret group edits do not restart services** — restart explicitly after entering values.
- Northflank service names must be ≥3 characters.
