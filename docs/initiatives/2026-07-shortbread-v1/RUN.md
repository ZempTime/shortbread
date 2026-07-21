# Run Manifest

| Field | Value |
|---|---|
| Run | `2026-07-18-shortbread-v1` |
| Work item | [ZempTime/shortbread](https://github.com/ZempTime/shortbread); direct design and authority conversation |
| Initializer | Claude Code on Claude Fable 5 (`claude-fable-5`) |
| Current controller | None; U03 is integrated and no campaign or product implementation is active |
| Accepted doctrine baseline | Repo-local MWP with bounded campaigns, fresh-context leaf units, TDD, proportionate independent review, durable pause/recovery, and explicit credential boundary |
| Repository authority | Implement, review, repair, document, package, and prepare deployment of the accepted Shortbread v1 scope |
| External authority | Configure the GitHub issue tracker; create/update issues, branches, commits, pull requests, releases, packages, and deployment configuration inside `ZempTime/shortbread` as required by the goal |
| Initialized | 2026-07-18 |
| State token | `campaign-paused` |
| Current state | U03/#21 is integrated by PR #61. U04/#22 closed as not planned without implementation because the Operator selected the launch-today self-hosted path; U05 and the remaining unbuilt v1 backlog stay open, unassigned, and paused |

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
| 05 Delivery replan | Paused after reviewed U03 integration; no controller active | [Bounded campaign/unit graph](05_delivery_replan/output/2026-07-20-delivery-plan.md), [unit contract](05_delivery_replan/output/UNIT-CONTRACT.md), [published tracker](05_delivery_replan/output/tracker.md), integrated [U01/#19](https://github.com/ZempTime/shortbread/issues/19), [U02/#20](https://github.com/ZempTime/shortbread/issues/20), and [U03/#21](https://github.com/ZempTime/shortbread/issues/21); U04/#22 was not delivered |
| 99 Harvest | Complete through U03; no U02 or U03 factory promotion | [Setup harvest](99_harvest/output/2026-07-18-goal-setup-harvest.md), Stage 05 process corrections, and the unit decisions in the [delivery tracker](05_delivery_replan/output/tracker.md) |

## Recovery Capsule

| Field | State |
|---|---|
| Reconciled | 2026-07-21 by integration controller `/root`; reviewed U03 head `4b76c83cd2cc04f253157e97e8f235c8d1590fcb` is integrated by [PR #61](https://github.com/ZempTime/shortbread/pull/61) at merge `d30be56043cac9f20f8eec1aed2f51f9e2d03225`; #21 is closed and #22 is closed as not planned |
| Integration branch/head | `main` contains U03 merge `d30be56043cac9f20f8eec1aed2f51f9e2d03225` plus this pause-state coordination update; the pinned U03 baseline remains `173f09644c140599a706fabfffee0ae0e1289437` |
| Release candidate | No active U03 release candidate or draft PR remains. PR #61 merged exact reviewed head `4b76c83cd2cc04f253157e97e8f235c8d1590fcb`; it remains a production-shaped candidate, not a vulnerability-clean final image |
| Auth source evidence | Historical `ticket-4-owner-cli-auth` remains local and remote at `8fcb22f`; its accepted U02 behavior is represented on main by PR #59, and the source branch is no longer merge material |
| Worktrees | The clean U03 worktree and integrated local/remote branch were removed after ancestry proof. Unrelated U02, policy-repair, U01 implementation, and detached U01 replay evidence worktrees remain untouched |
| Dirty state | Root `main` is clean and synchronized with `origin/main`; there is no U03 worktree, branch, or uncommitted evidence |
| Collision | No product implementation is active. U04 was not started; U05 and all subsequent unbuilt v1 work remain unclaimed and paused |
| Dependency state | Frozen dependency/tool versions, installer pins, telemetry controls, and lockfiles remain unchanged. Authorized PR #58 task-only changes are reconciled to the exact frozen `mise.toml` digest by reviewed [PR #60](https://github.com/ZempTime/shortbread/pull/60) at merge `1a65ae3` |
| Review state | Independent Standards + Spec and operations/container/security reviewers approved exact pushed head `4b76c83cd2cc04f253157e97e8f235c8d1590fcb` with no remaining findings after test-first repairs; the [final PR review record](https://github.com/ZempTime/shortbread/pull/61#issuecomment-5037707914) owns the evidence and residual boundaries. The Operator-approved U28 scan disposition remains accepted |
| Reserved surfaces | None. U03 reservations are released; no later unit has been claimed |
| True stop | Product-scope/trust/authority change, preservation failure, or unreconcilable tracker mutation—not ordinary graph edits |
| Next action | None authorized. Do not start U04 or any later v1 unit: the Operator selected the launch-today self-hosted path, and deployment preparation is outside this integration session. Any future work begins from explicit new Operator direction and a fresh reconciliation |

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

Stage 05 promotes only after local graph review, full PRD coverage, GitHub leaf publication, umbrella reconciliation, one accurate frontier, and agreement between this file and the tracker. C00 is complete; C01 ended after U03 integration when the Operator selected the launch-today self-hosted path. No frontier is active, and execution must not silently continue into U04, C02/U05, or later v1 work.

## Limitations

- The reference-provider plan in U04/#22 was not delivered. Any future Northflank, PlanetScale, R2, or provider-automation work requires a new plan and current primary-source verification.
- Only macOS arm64 has exercised the frozen dependency/tool bootstrap so far; artifact/platform claims remain unverified until U28–U30.
- Live Northflank, PlanetScale, Cloudflare R2, DNS, and GitHub credentials are deliberately absent from all current evidence.
- The public demonstration remains a synthetic invite-only Site; anonymous public Sites stay outside v1.
