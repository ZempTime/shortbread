# Runbook: first deploy (Northflank + Cloudflare R2 + Netlify DNS)

App-specific values live in `infra/app.env`. Steps are marked **HUMAN** (accounts, tokens,
secret values, DNS) or **AGENT** (scriptable plumbing).

**Secret values never appear in this runbook, in `infra/`, or in agent context.** Every step that
handles a real credential is HUMAN and happens in the Operator's own terminal or a provider
dashboard.

> **Blocker before this runbook can complete — read first.**
> `Shortbread::ProductionRuntime` requires `ANYCABLE_SECRET`, `ANYCABLE_RPC_HOST`,
> `ANYCABLE_HTTP_BROADCAST_URL`, and `ANYCABLE_WEBSOCKET_URL`, and exits 78 without them — but
> this deploy has **no cable service** to point them at. Nothing in `app/` or `lib/` uses
> ActionCable or AnyCable (`app/channels/` does not exist). Until that contract is changed, a
> one-service deploy cannot boot. See "Known blockers" at the end.

## Naming convention (all providers)

| Thing | Value |
|---|---|
| Northflank project | `shortbread` |
| Web service | `web` (port `p01`, internal 3000) |
| Migration job | `migrate` |
| Secret group | `shortbread-secrets` |
| Owner UI / API domain | `tater.chriszempel.com` |
| Site domain (wildcard) | `sites.tater.chriszempel.com` |
| R2 bucket | `shortbread-blobs` |

## Phase 0 — accounts (HUMAN, one-time per provider)

1. Northflank account with a team; note the team slug into `NF_TEAM` in `infra/app.env`.
2. Cloudflare account with R2 enabled; note the account ID (needed for the R2 endpoint).
3. Netlify account holding the DNS zone for `chriszempel.com`.
4. `tater.chriszempel.com` delegated to Netlify DNS.

## Phase 1 — Northflank wiring (HUMAN, ~5 min)

1. Create the project `shortbread` in region `us-central`.
2. Connect the GitHub account and grant access to `ZempTime/shortbread-share`.
3. Create a **project-scoped API token** with at least:
   - `Project > Services > Create/Update`
   - `Project > Jobs > Create/Update`
   - `Project > Secrets > Create/Update`
   - `Account > Networking > Subdomains > Update` (wildcard assignment, Phase 6)
4. Export it in your own shell — never write it to a file:
   ```sh
   export NORTHFLANK_TOKEN=...
   ```

## Phase 2 — Postgres addon (HUMAN, ~3 min)

1. Add a **PostgreSQL addon** to the project. `nf-compute-10` is the documented floor; with blobs
   in R2, storage stays small.
2. Create two databases (or two roles) so the app and the queue are distinct — `ProductionRuntime`
   rejects a shared `DATABASE_URL`/`QUEUE_DATABASE_URL`.
3. Copy both connection URIs somewhere safe for Phase 4. **Do not paste them into a file in the
   repo, into chat, or into an agent session.**

> Managed Postgres pricing is not published as a table; the DBaaS page states only "plans starting
> at $2.70 per month." Treat cost as an estimate. See
> `docs/initiatives/2026-07-tater-tots-redirect/00_framing/output/2026-07-25-deployment-verification.md`.

## Phase 3 — R2 bucket (HUMAN, ~3 min)

1. Create a **private** bucket named `shortbread-blobs`. Never enable public access.
2. Create an R2 API token scoped to that bucket with object read/write.
3. Note the Access Key ID, Secret Access Key, and the S3 endpoint
   `https://<ACCOUNT_ID>.r2.cloudflarestorage.com` for Phase 4.

## Phase 4 — plumbing (AGENT)

```sh
infra/provision-northflank.sh
```

Creates the secret group (placeholder values), the `migrate` job, and the `web` service. Skips
anything that already exists, so a partial run can be resumed. It does not reconcile drift, and it
never sees a real secret.

## Phase 5 — secret values (HUMAN, ~5 min)

In the Northflank dashboard, open the `shortbread-secrets` group and replace every
`PLACEHOLDER_SET_BY_HUMAN`:

| Variable | Source |
|---|---|
| `DATABASE_URL` | Phase 2 |
| `QUEUE_DATABASE_URL` | Phase 2 (must differ from `DATABASE_URL`) |
| `SECRET_KEY_BASE` | `openssl rand -hex 64` in your own terminal |
| `ANYCABLE_SECRET` | `openssl rand -hex 64` (see the blocker note) |
| `ANYCABLE_RPC_HOST` | see the blocker note |
| `ANYCABLE_HTTP_BROADCAST_URL` | see the blocker note |
| `ANYCABLE_WEBSOCKET_URL` | see the blocker note |
| `SHORTBREAD_BOOTSTRAP_TOKEN` | `openssl rand -hex 32`; rotate after Owner bootstrap |
| `SHORTBREAD_R2_ACCESS_KEY_ID` | Phase 3 |
| `SHORTBREAD_R2_SECRET_ACCESS_KEY` | Phase 3 |
| `SHORTBREAD_R2_BUCKET` | `shortbread-blobs` |
| `SHORTBREAD_R2_ENDPOINT` | `https://<ACCOUNT_ID>.r2.cloudflarestorage.com` |

**Secret group edits do not restart services.** Restart `web` explicitly afterwards.

Verify without revealing values — this prints `[configured secret]`, never the secret:

```sh
# in a Northflank shell on the web service
bin/production config
```

## Phase 6 — domains and DNS (HUMAN, ~10 min + propagation)

### 6a. Apex — Owner UI

1. Add `tater.chriszempel.com` as a Northflank domain (normal, **no** wildcard options).
2. Add the ownership **TXT** record in Netlify DNS as shown by Northflank.
3. Once verified, add it as a subdomain assigned to `web` port `p01`.

### 6b. Sites — wildcard

1. Add `sites.tater.chriszempel.com` as a **separate** Northflank domain. Under advanced options,
   set **both** at add time — they cannot be changed later:
   - routing: **wildcard redirect** (plus region `us-central`)
   - certificates: **wildcard via DCV**
2. Add the three Netlify DNS records Northflank shows:
   - **TXT** — ownership verification
   - **CNAME** — `*.sites` → the Northflank target
   - **CNAME** — DCV delegation (Northflank answers ACME challenges, including renewals)
3. After verification, add a subdomain with the literal value `*` and assign it to `web` port
   `p01`. A certificate is not issued until a subdomain is linked to a port.

> **Unverified: Netlify wildcard CNAME support.** Netlify's docs neither confirm nor deny literal
> `*` records; its API imposes no hostname restriction. Confirm before relying on it:
> ```sh
> dig +short '*.sites.tater.chriszempel.com' CNAME
> ```
> If Netlify rejects the record, move the zone to a provider that documents wildcard CNAMEs
> (Cloudflare DNS is free and already in use for R2). **This is a DNS-provider swap only** — no
> code, no manifest, and no redeploy changes. The apex/Owner UI is unaffected either way.
>
> Clear any stale `_acme-challenge` TXT records first, and disable DNS proxying during initial
> verification.

## Phase 7 — release workflow (HUMAN, ~5 min)

Northflank has **no pre-deploy field on a service**. Migrations run as a job inside a workflow:

1. Create a workflow in the project.
2. Add nodes in order: **build** → **run job** (`migrate`, "wait for completion" enabled) →
   **deploy** (`web`).
3. Trigger the workflow on push to `main`.

The deploy node runs only after `migrate` exits successfully, so a failed migration never
promotes a new web deployment.

## Phase 8 — verify (AGENT drives, HUMAN watches)

```sh
curl -fsS https://tater.chriszempel.com/up            # readiness
curl -fsS -o /dev/null -w '%{http_code}\n' https://tater.chriszempel.com/
```

Then publish a Site with the CLI and confirm it serves from
`https://<slug>.sites.tater.chriszempel.com`.

> Under R2 the readiness endpoint reports the `private_blob` dependency satisfied **without
> probing the bucket** — weaker than the local-disk path, which genuinely exercises storage. A
> green `/up` does not prove R2 is reachable. Confirm with a real publish.

## Phase 9 — rotation (HUMAN, immediately after)

1. Rotate `SHORTBREAD_BOOTSTRAP_TOKEN` once the Owner account exists.
2. Revoke the Phase 1 Northflank token if it was broader than needed.

## Known blockers

1. **AnyCable is required but not deployed.** `ProductionRuntime::BASE_REQUIRED_KEYS` demands four
   `ANYCABLE_*` values and exits 78 without them, yet no cable service exists in this topology and
   nothing in the app uses ActionCable. Options, in preference order:
   - make the AnyCable keys conditional the way the blob-store keys now are (small, mirrors the
     existing pattern, and matches "one service, not three"); or
   - deploy a cable service after all, reverting the one-service decision; or
   - set the four values to syntactically valid but unused placeholders — **works, but lies in the
     config**, and a future reader cannot tell it is deliberate.

   This is a production-runtime contract change and was left outside B2's scope deliberately.
2. **Netlify wildcard CNAME** — unverified, Phase 6b, with a documented fallback.
3. **`mise run security` fails** on an unclassified `@anycable/core 1.1.6` browser license,
   pre-existing and unrelated to deployment.

## Superseded

`compose.production.yml` and the single-host Compose path are **superseded for deployment**. Keep
them for local production-shaped rehearsal — `bin/production-smoke` depends on them.
