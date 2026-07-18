# Goal Addendum — 2026-07-18

This input records decisions Chris made after the original framing file. It is a decision source, not a polished specification.

## Outcome

- Finish this setup session with a copy-paste persistent goal that can return to a site ready to deploy and configure.
- The finished product includes the web application and the `shortbread` CLI.
- The operator's remaining deployment work should be limited to supplying credentials and deployment-specific values through a guided procedure.
- The top-level controller owns routine approvals, decomposition, direction, review, repair, and progress monitoring. It may run independent subagents in parallel when useful.

## Project and Reference Boundaries

- The public project and CLI are named **Shortbread** / `shortbread`.
- The public repository is `https://github.com/ZempTime/shortbread` and is MIT licensed.
- An unrelated local application gives up the Shortbread name; no compatibility work is required here.
- A local private template application was reviewed for generic Rails/Inertia, passkey/invite, testing, container, and deployment patterns. The public project must not require access to it or import its product behavior.
- The MWP process is defined and owned by this repository. It carries no product, infrastructure, severity, or repository-specific facts from reference projects.
- Adapt the Matt Pocock flow as `to-spec` → `to-tickets` → implement with TDD and independent standards/spec review.

## Reference Stack

- Rails 8.1 with Inertia, React, and TypeScript for the web application.
- PostgreSQL, with PlanetScale Postgres as the reference production database.
- Private Cloudflare R2 for bundle blobs through its S3-compatible interface.
- Northflank for the reference application deployment.
- Go for a distributable, single-binary CLI.
- Keep provider seams standard enough that self-hosters can substitute compatible services.

## Work Ownership

- `agents/` contains the reusable factory for shipping features.
- `docs/initiatives/` contains bounded feature and investigation workspaces: inputs, stage contracts, edit surfaces, problem-specific harnesses, evidence, reviews, and handoffs.
- GitHub issues and pull requests coordinate work across sessions; the repository workspace contains the durable work. A workspace `RUN.md` owns its state.
- Agents may create the smallest appropriate harness for each problem. Do not pre-scaffold ceremonial empty stages.
- Recurring, reusable learning must be harvested back into `agents/`. One-off product knowledge belongs in Shortbread docs, ADRs, code, tests, or runbooks. Explicitly record when there is nothing reusable to harvest.

## Public Project Evidence

- The README explains the product, the open-source/self-hosted posture, and Chris's experiment with AI processes for building software.
- A setup guide takes a new operator from a clean clone to local use and the reference deployment.
- A public-source example bundle demonstrates publishing, invitation, viewing, offline behavior, feedback, and iteration without exposing real private data.
- Real screenshots come from the working application through a repeatable capture harness; do not substitute mockups.
- Release the app/container and cross-platform CLI artifacts with reproducible instructions.

## Testing Seams

- Browser system tests cover owner and viewer journeys, apex-to-site authentication, feedback, install/update/offline behavior, and the screenshot path.
- Rails request tests cover WebAuthn, invitations, host routing, API authentication, publish finalization, range requests, and private serving.
- A black-box Go CLI suite runs against the Rails test application for login, publish, invite, and feedback.
- Pure Ruby and Go unit tests are reserved for deterministic algorithms such as path validation, manifests, deltas, offline cache selection, and blob garbage collection.
- Provisioner command-contract tests plus a clean-clone rehearsal prove the setup path without credentials. Run a live provider smoke test after credentials are supplied.

## Accepted Trust Contract

> Shortbread itself never sends site content, feedback, invitation data, or viewer PII to AI, analytics, or optional third-party processors. Data is processed only by operator-configured Northflank, PlanetScale, and R2. Producers/agents outside Shortbread are operator-controlled.

Private R2, database, and application providers are therefore part of the operator-selected processing boundary. Offline copies survive revocation. Logs, screenshots, fixtures, issues, PRs, and agent handoffs must not contain invite tokens, credentials, private bundle contents, or viewer PII.

## Autonomous Authority

- The controller may approve its own subordinate plans and ticket decomposition inside the accepted contract.
- It may use GitHub issues, branches, commits, pull requests, checks, reviews, releases, and packages as coordination and delivery mechanisms.
- It may install dependencies, run local services and browsers, create test data, and use parallel agents within the repository.
- It may provision the documented reference stack once Chris provides the required credentials and values.
- Routine implementation uncertainty is not an approval gate. Only missing authority/credentials, destructive changes to existing external state, or a required change to an accepted permanent boundary should stop the run.
