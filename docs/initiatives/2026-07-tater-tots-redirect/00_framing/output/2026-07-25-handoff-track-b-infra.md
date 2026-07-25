# Handoff — Track B: R2 blob port and Northflank infra

**Type:** production implementation, test-first. Two sequential units. Independent of Track A —
neither blocks the other, and this work is needed under **any** product framing.

**Why this is safe to build during a product redirect:** blob storage and deployment packaging
are substrate. The plannotator redirect changes what documents *are*, not how bytes are stored
or how the app is deployed.

## Required reading first

1. `docs/initiatives/2026-07-tater-tots-redirect/00_framing/output/2026-07-25-deployment-findings.md`
   — verified Northflank/DNS/pricing facts and the brunch-club gotcha list. **Do not re-derive
   these.**
2. `AGENTS.md` → `docs/agents/mwp.md` for method; `docs/agents/issue-tracker.md` for coordination.
3. `OPERATIONS.md` — the existing production runtime contract.
4. The donor: `/Users/chris/code/chriszempel_apps/brunch-club`, specifically `infra/`,
   `docs/runbooks/deploy.md`, `docs/runbooks/photos-r2.md`.

Per the global rule: **before creating any new file, read 2–3 existing files of the same type
and match their conventions exactly.**

## Repo facts you need

- `config.active_record.schema_format = :sql` — migrations update `db/structure.sql`, not
  `schema.rb`.
- Tests: `mise run test` (Rails + Go). Agent variants exist: `mise run agent:rails -- test <path>`,
  `mise run agent:test`. Also `mise run lint`, `mise run typecheck`, `mise run security`.
- Ruby entry is via mise/Bundler with frozen lockfiles. **Do not add gems without checking the
  dependency-freeze policy** — the baseline is audited and frozen, and unauthorized dependency
  changes have caused rework before (see PR #58/#60 history).

---

## Unit B1 — R2 blob port

### Goal
Add an R2-backed blob store behind the existing interface, selectable by configuration, with
`LocalBlobStore` still the default for development and test.

### Current shape
`app/services/local_blob_store.rb` is already a clean content-addressed port. Public surface:

```ruby
put_verified(io:, sha256:, byte_size:)  # => storage_key
verified?(storage_key:, sha256:, byte_size:)
open(storage_key) { |io| ... }
open_verified(storage_key:, sha256:, byte_size:)  # => io, caller closes
each_chunk(storage_key)                  # => Enumerator
CHUNK_SIZE, ContentMismatch, StorageFailure
```

Five call sites, all in controllers:
- `app/controllers/site_contents_controller.rb:69` (plus error classes at `:17`, `CHUNK_SIZE` at `:59`)
- `app/controllers/api/v1/publish_plan_blobs_controller.rb:30` (errors at `:21`, `:23`, `:42`)
- `app/controllers/api/v1/publish_plan_finalizations_controller.rb:10`
- `app/controllers/api/v1/publish_plans_controller.rb:42`

### Approach
1. Extract the shared contract — error classes (`ContentMismatch`, `StorageFailure`) and
   `CHUNK_SIZE` — so callers no longer reference `LocalBlobStore::` by name. **Do this first,
   as its own green step**; it is a pure refactor and every existing test must stay green.
2. Add `R2BlobStore` implementing the same five methods against the S3-compatible API.
3. Select the implementation by configuration, defaulting to local. Wire it through
   `Shortbread::ProductionRuntime` fail-closed validation the way other production values are
   handled — production with R2 selected and credentials missing must exit 78 before serving.

### Requirements
- **Verification is not optional.** `put_verified` and `open_verified` must keep verifying
  sha256 and byte size. Content addressing is a correctness guarantee, not a nicety.
- Streaming, not buffering. Large blobs must not be read fully into memory — mirror the existing
  chunked approach.
- Private bucket only. No public ACLs, ever.
- Credentials come from env, never committed. Extend `.env.production.example` with redacted
  placeholders and keep them out of `bin/production config` output.
- Test against a fake/stubbed S3 — no live credentials in CI or in agent context.

### Acceptance
- All existing blob tests green against `LocalBlobStore`.
- New tests cover `R2BlobStore` for: round-trip, sha mismatch, size mismatch, missing key,
  storage failure, and streaming a blob larger than one chunk.
- `mise run test`, `mise run lint`, `mise run security` all green.

---

## Unit B2 — Northflank `infra/`

### Goal
Make deployment "create services, add secrets, connect repo" by putting the deployment knowledge
in the repo. Chris explicitly wants brunch-club's experience.

### Deliverables
Model directly on brunch-club, adapting rather than inventing:

- `infra/app.env` — all app-specific **non-secret** values in one file (app name, GitHub repo,
  Northflank team/region/plans, apex domain). Never secrets.
- `infra/northflank/secret-group.json` — placeholder values only, filled by a human in the
  dashboard.
- `infra/northflank/service-web.json` — built from the repo Dockerfile, push-to-deploy on the
  default branch.
- `infra/provision-northflank.sh` — creates the secret group and service via the Northflank API
  using a project-scoped token supplied at runtime. Never stores or echoes the token.
- `docs/runbooks/deploy.md` — phased, marking each step **HUMAN** (accounts, secret values,
  DNS records) or **AGENT** (scriptable plumbing). Secret values never appear in the runbook, in
  scripts, or in agent context.

### Shortbread-specific deltas from brunch-club
1. **One service, not three.** `app/jobs/` holds only the empty `ApplicationJob`; `app/channels/`
   does not exist. Drop `worker` and `cable`. Add a **pre-deploy migration job** running
   `bin/production migrate`, which must complete before web starts.
2. **Wildcard domain.** Add `sites.<apex>` as a Northflank domain with **both** `wildcard
   redirect` routing and `wildcard via DCV` certificates at add time, then a `*` subdomain bound
   to the web service port. The apex itself (`<apex>`) is a separate normal subdomain for the
   Owner UI. **The wildcard domain cannot also serve the apex** — this is why the `.sites.`
   infix stays. Document the three Netlify records (TXT ownership, CNAME routing, CNAME DCV).
3. **R2, not a volume** (B1 provides it). Do not configure persistent volumes.
4. `SHORTBREAD_BOOTSTRAP_TOKEN` fails closed in production and is redacted from `bin/production
   config` — that work exists on the `launch-single-host-62` branch at `d964e8b1` and is worth
   salvaging rather than rewriting.

### Boundaries — important
- **Do not deploy.** Do not create live Northflank resources, do not purchase anything, do not
  register domains. This unit produces a credential-ready repository, nothing more.
- **Never request, accept, or handle live credentials.** If a step needs a secret, the runbook
  marks it HUMAN and the Operator does it in their own terminal or the provider dashboard.
- Verify Northflank API shapes against current primary docs before writing manifests — the
  deployment-findings doc records what was verified on 2026-07-25 and what was not.

### Acceptance
- `infra/` exists and is self-consistent; the provisioning script is readable and idempotent-aware
  (brunch-club's is explicitly not idempotent — improve on that if cheap, or document it).
- The runbook is followable by someone who has never seen the repo, with every HUMAN step named.
- No secrets in Git. `mise run security` green.
- `OPERATIONS.md` and the initiative README updated to point at the new path, and the
  single-host Compose path marked as superseded for deployment purposes (keep it for local
  rehearsal — it still works and `bin/production-smoke` depends on it).

---

## Sequencing

B1 before B2 — the infra manifests should reflect R2 rather than being written for volumes and
then rewritten. Both are independent of Track A.

## Unverified items to close during this work

- Northflank **managed Postgres pricing** (never confirmed; do not quote the ~$3.91 figure).
- **Netlify DNS wildcard CNAME** support.
- Exact Northflank API shape for pre-deploy jobs and for attaching a wildcard subdomain to a
  service port.
