# Run Manifest

| Field | Value |
|---|---|
| Run | `2026-07-18-shortbread-v1` |
| Work item | [ZempTime/shortbread](https://github.com/ZempTime/shortbread); direct design and authority conversation |
| Initializer | Claude Code on Claude Fable 5 (`claude-fable-5`) |
| Current controller | None; the next fresh controller claims C00/U02 |
| Accepted doctrine baseline | Repo-local MWP with bounded campaigns, fresh-context leaf units, TDD, proportionate independent review, durable pause/recovery, and explicit credential boundary |
| Repository authority | Implement, review, repair, document, package, and prepare deployment of the accepted Shortbread v1 scope |
| External authority | Configure the GitHub issue tracker; create/update issues, branches, commits, pull requests, releases, packages, and deployment configuration inside `ZempTime/shortbread` as required by the goal |
| Initialized | 2026-07-18 |
| State token | `campaign-ready` |
| Current state | U01/#19 is integrated through PR #57; U02/#20 is the sole executable frontier and no product implementation is active |

## Input Snapshot

- [`inputs/request.md`](inputs/request.md) preserves the original request and attribution.
- [`inputs/design-notes.md`](inputs/design-notes.md) preserves the initial architecture synthesis.
- [`inputs/chris-framing.md`](inputs/chris-framing.md) is Chris's detailed framing contribution.
- [`inputs/2026-07-18-goal-addendum.md`](inputs/2026-07-18-goal-addendum.md) records the open-source, CLI, deployment, evidence, and autonomy decisions.
- [`inputs/2026-07-20-delivery-replan-addendum.md`](inputs/2026-07-20-delivery-replan-addendum.md) records Chris's acceptance of the recovery, bounded-campaign, and credential-ready corrections without changing product scope.

## Stage Status

| Stage | Status | Evidence |
|---|---|---|
| 00 Framing | Complete | [Framing contract](00_framing/output/2026-07-18-framing-contract.md), draft PRD, glossary, and ADRs |
| 01 Spec | Complete | [Canonical PRD](01_spec/output/2026-07-18-shortbread-v1-prd.md) / [GitHub #1](https://github.com/ZempTime/shortbread/issues/1) |
| 02 Original ticket map | Complete; superseded for execution only | [Original graph](02_ticket_map/output/2026-07-18-ticket-map.md) / GitHub #2–#17 remain acceptance history |
| 03 Whole-goal handoff | Historical; superseded | [`GOAL.md`](03_goal_handoff/output/GOAL.md) is retained but must not be relaunched |
| 04 Original execution | Paused after interrupted attempt | #2 integrated; #3/#4 partial branch evidence preserved under [`04_execution/`](04_execution/) |
| 05 Delivery replan | Complete; U01 integrated and U02 campaign-ready | [Bounded campaign/unit graph](05_delivery_replan/output/2026-07-20-delivery-plan.md), [unit contract](05_delivery_replan/output/UNIT-CONTRACT.md), [published tracker](05_delivery_replan/output/tracker.md), [integrated U01/#19](https://github.com/ZempTime/shortbread/issues/19), and [frontier U02/#20](https://github.com/ZempTime/shortbread/issues/20) |
| 99 Harvest | Complete for setup and #2; interrupted-run learning promoted into MWP | [Setup harvest](99_harvest/output/2026-07-18-goal-setup-harvest.md) plus Stage 05 process corrections |

## Recovery Capsule

| Field | State |
|---|---|
| Reconciled | 2026-07-20, after reviewed U01 integration and U02 frontier promotion |
| Integration branch/head | `main`; product code includes merged #2 at `f2e0326` and U01 [#57](https://github.com/ZempTime/shortbread/pull/57) at merge `45db8bd`; the commit containing this capsule is the coordination head |
| Release candidate | U01 fixed candidate `21a08c9` is integrated as merge `45db8bd`; preserved `ticket-3-releases-rollback@f5943d7` remains fixed source/review evidence only |
| Auth source evidence | `ticket-4-owner-cli-auth` local and remote at `8fcb22f`; no PR; replay semantically only after U01 |
| Worktrees | No active execution worktree; inactive U01 implementation and detached clean-replay worktrees remain durable evidence; old ticket 3/4 registrations were pruned after their remote heads were verified |
| Dirty state | Clean after this coordination-only frontier handoff; no product implementation is active |
| Collision | Both preserved branches edit `config/routes.rb`; Release branch removes `db/schema.rb` for SQL structure dumps while auth branch edits it |
| Dependency state | Frozen/audited at `3c40a67`; manifest/lock/tool changes require ADR 0007 exception |
| Review state | Preserved source `f5943d7` was rejected as merge material; independent Standards + Spec and data-integrity reviews both approved exact U01 candidate `21a08c9` with no blockers or should-fix findings |
| Reserved surfaces | None until a fresh C00 controller claims U02 and records its branch, worktree, baseline, review target, and auth-specific edit surfaces |
| True stop | Product-scope/trust/authority change, preservation failure, or unreconcilable tracker mutation—not ordinary graph edits |
| Next action | A fresh C00 controller claims [U02/#20](https://github.com/ZempTime/shortbread/issues/20), reads its unit card and current packet, and semantically replays only accepted auth behavior from `ticket-4-owner-cli-auth@8fcb22f` onto current `main`; do not relaunch U01 or reuse stale schema output |

## Campaign Model

- The initiative persists through v1; one `ship-goal` controller owns one campaign of at most four leaf integrations.
- The [Stage 05 delivery plan](05_delivery_replan/output/2026-07-20-delivery-plan.md) is canonical for executable units and edges.
- The original issues #3–#17 own acceptance history; Stage 05 leaves own execution. Closing a leaf does not close its umbrella until every mapped acceptance is integrated.
- A leaf starts from its GitHub issue, [`UNIT-CONTRACT.md`](05_delivery_replan/output/UNIT-CONTRACT.md), relevant card, linked PRD/ADRs, and current resume capsule—not the superseded whole-v1 goal.
- Schema, root routes, CLI registration, injected UI/service worker, dependency files, generated screenshots, release/deployment state, root docs, and `agents/` are serialized unless the controller records concrete non-overlap.
- Every campaign ends with integration evidence or an MWP pause capsule. `execution-active` is forbidden when no controller is running.

## Credential-Ready Terminal Boundary

Before live credentials are requested, the repository must have reviewed app/CLI artifacts, production-shaped local rehearsal, credential-free plan, fake-provider apply/resume/deploy/doctor evidence, complete example/screenshots/docs, clean-clone proof, holistic trust audit, and one exact Operator-run ceremony.

The Operator supplies provider accounts/domain, region/plan choices, billing/legal acceptance, and least-privilege credentials only through the direct safe ingress. The setup program creates/updates namespaced manifest resources, configures secrets/DNS/TLS/processes, migrates, waits for health, and emits redacted doctor/smoke status. Credential absence may leave a truthful credential-ready repository; it cannot be represented as a live smoke.

## Authority Envelope

Chris has authorized a top-level controller to continue without routine approval through decomposition, GitHub coordination, implementation, review, repair, documentation, packaging, and deployment preparation of the accepted PRD. The controller may choose reversible implementation details and fix ordinary failures inside the declared campaign.

Within this repository and GitHub project, the controller may create/edit/move/remove recoverable project files; install/run project dependencies/services/tests/browsers/build/security tools; manage issues/labels/branches/commits/PRs/releases/packages/deployment configuration; merge reviewed green leaf PRs; and prepare or apply the documented reference deployment using safely supplied credentials when the runtime can keep values out of model/tool logs.

The controller stops for missing external authority/input at the live boundary; irreversible/destructive existing-resource action without proven recovery; paid/legal/account/domain commitment; a required change to the trust promise, accepted ADR, MIT/public/single-Owner/invite-only/reference-provider scope; or a persistent third-party blocker after safe alternatives. It may not weaken security, expose credentials/private content/Viewer PII, add proprietary product dependencies, contact real Viewers, charge for services, or delete existing production resources merely for expedience.

## Promotion Rule

Stage 05 promotes only after local graph review, full PRD coverage, GitHub leaf publication, umbrella reconciliation, one accurate frontier, and agreement between this file and the tracker. Product execution resumes in a fresh context; this replan controller does not silently continue into U01 implementation.

## Limitations

- Current provider APIs, capabilities, plan choices, and official deployment guidance must be reverified from primary provider documentation inside U04/U31/U32.
- Only macOS arm64 has exercised the frozen dependency/tool bootstrap so far; artifact/platform claims remain unverified until U28–U30.
- Live Northflank, PlanetScale, Cloudflare R2, DNS, and GitHub credentials are deliberately absent from all current evidence.
- The public demonstration remains a synthetic invite-only Site; anonymous public Sites stay outside v1.
