# Delivery Replan Addendum

**Date:** 2026-07-20
**Source:** Direct conversation with Chris after review of the interrupted Ultra/MWP execution
**Status:** Accepted delivery direction; does not change the Shortbread v1 product contract

## Accepted Outcome

Complete the accepted Shortbread v1 scope and leave a credential-ready public repository. Before live credentials are requested, the repository must have verified application and CLI artifacts, a production-shaped rehearsal, a credential-free infrastructure plan, provider command contracts, complete setup and operations documentation, and one exact deployment/smoke path.

Chris's remaining work at the live boundary should be limited to possessing the provider accounts and domain, choosing plans/region, accepting provider billing or legal terms, supplying least-privilege credentials through the direct safe ingress, running the documented apply command, and registering the first Owner passkey. The setup workflow—not undocumented dashboard construction—creates and configures the namespaced application resources, DNS/TLS, secrets, migrations, process roles, health checks, and deployment.

## Accepted Execution Corrections

- Preserve and repurpose the completed and partial implementation; do not restart the product.
- Keep the canonical PRD, ADRs, and original issues as product acceptance history.
- Replace the original oversized implementation graph with fresh-context, PR-sized delivery units grouped into bounded campaigns.
- A persistent controller owns one campaign, not the whole initiative.
- Bring the production runtime, provider inventory, and credential-free plan forward so deployment seams are exercised before feature completion.
- Serialize schema, routes, CLI registration, release state, deployment configuration, and other shared hotspots unless a concrete non-overlap check proves safe parallelism.
- Make pause/recovery, local-versus-remote durability, draft PRs, fixed review targets, and concise resume capsules explicit protocol state.
- Retain specialist review where risk warrants it, while avoiding repeated full-context/full-suite ceremony after every small repair.

## Recovery Facts Accepted as Inputs

- Main coordination head before this replan: `119c6c4`.
- Ticket #2 is integrated through PR #18 at `f2e0326`.
- Release/rollback branch `ticket-3-releases-rollback` is preserved locally and remotely at `f5943d7`.
- Owner-bootstrap branch `ticket-4-owner-cli-auth` is preserved locally and remotely at `8fcb22f` after pushing seven formerly local-only commits.
- Both old `/private/tmp` worktrees are missing and prunable; branch refs, not those paths, are the recovery source.
- The two branches overlap in `config/routes.rb`; the release branch removes `db/schema.rb` for SQL structure dumps while the auth branch edits `db/schema.rb`. They must not be merged in parallel.

## Non-Changes

This addendum does not reduce the accepted Owner, Viewer, Producer, Operator, offline, feedback, receipt, deletion, trust, documentation, artifact, or deployment scope. It changes work granularity, ordering, evidence, and recovery discipline only.
