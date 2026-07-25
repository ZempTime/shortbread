# Deployment verification — closing the B2 unverified items

Verified 2026-07-25 against primary sources. Supplements `2026-07-25-deployment-findings.md`;
where the two disagree, this document is newer.

## 1. Northflank pre-deploy migrations — CLOSED, and the handoff's shape was wrong

The Track B handoff calls for "a **pre-deploy migration job** running `bin/production migrate`,
which must complete before web starts," implying a field on the service manifest. **There is no
such field.** Northflank's mechanism is two resources plus an ordering:

1. A **Job** resource (separate from the service) running the migration command, built from the
   same build as the service.
2. A **workflow** (release flow) whose nodes execute sequentially: build → run job → deploy.
   Each node must complete successfully before the next runs; "wait for completion" gates the
   deploy node on the job.

Source: <https://northflank.com/docs/v1/application/release/run-migrations>

**Consequence for `infra/`:** we need `job-migrate.json` and a workflow definition alongside
`service-web.json` — not one manifest with a pre-deploy stanza. brunch-club has no equivalent
to copy; this part is new.

## 2. Wildcard subdomain → service port API — CLOSED

```
POST /v1/domains/{domain}/subdomains/{subdomain}/assign
Authorization: Bearer $NORTHFLANK_API_TOKEN
{ "serviceId": "...", "projectId": "...", "portName": "p01" }
```

- `portName`: 1–8 chars, must start with a letter.
- Permission: `Account > Networking > Subdomains > Update`.
- The subdomain value may be literally `*`; requests to any subdomain at that level forward to
  the assigned port.

Sources: <https://northflank.com/docs/v1/api/domains/assign-service-to-subdomain>,
<https://northflank.com/docs/v1/application/domains/wildcard-domains-and-certificates>

Unchanged from the findings doc: wildcard routing and wildcard-via-DCV certificates must both be
selected **at domain-add time**, and the apex cannot be served from a wildcard domain — which is
why `.sites.` stays.

## 3. Netlify wildcard CNAME — NOT CLOSED, and not closeable from documentation

Status after checking the DNS records doc, the OpenAPI spec, and the support forum: **unresolved
in both directions.** Do not record this as verified.

What is actually established:

- Netlify's DNS records documentation lists supported types (A, AAAA, CAA, CNAME, MX, NS, SPF,
  SRV, TXT) and **says nothing about wildcards either way**.
  <https://docs.netlify.com/manage/domains/configure-domains/dns-records/>
- The public OpenAPI spec's `dnsRecordCreate.hostname` is an **unconstrained string** with no
  pattern or validation. The API does not itself reject `*`. (Permissive, but not proof of
  behavior.)
- **A conflation worth flagging:** search results claiming "wildcard needs Netlify Pro" are about
  Netlify *hosting* wildcard subdomains for sites Netlify serves. That is a different feature and
  **does not apply here** — Northflank serves the traffic; Netlify is only authoritative DNS. A
  Netlify staff reply in the forum thread addresses hosting and explicitly does not answer whether
  a literal `*` record can be created in the DNS panel.

### How to close it

It is a five-minute empirical check the Operator can do, and no amount of further reading will
substitute:

1. In Netlify DNS for the apex zone, add a CNAME with host `*.sites` pointing at any placeholder
   target.
2. If the panel accepts it: `dig +short '*.sites.<apex>' CNAME` — resolution confirms support.
3. Delete the placeholder record.

If Netlify rejects it, the fallback is moving the zone to a provider that clearly supports
wildcard CNAMEs (Cloudflare DNS is free and documented for this). That is a DNS-provider swap,
not an application change — no code, no manifests, no redeploy.

**Blast radius if wrong:** wildcard Site serving fails. The Owner UI at the apex is unaffected.

## 4. Managed Postgres pricing — STILL NOT CONFIRMED

`northflank.com/pricing` does not publish an addon pricing table; it defers to an interactive
calculator. `northflank.com/dbaas/managed-postgresql` states only "plans starting at $2.70 per
month" (equal to `nf-compute-10`) and advertises a free tier.

The `~$3.91/mo` figure from the earlier research is **still unsourced — continue not quoting it.**

Best current read: an addon consumes a compute plan plus storage at the published rates, making
`nf-compute-10` + a few GB the realistic floor. Treat as an estimate, not a verified price.
This gates no engineering decision and does not block `infra/`; it only affects the cost estimate.
