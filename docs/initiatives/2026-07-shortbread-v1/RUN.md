# Run Manifest

| Field | Value |
|---|---|
| Run | `2026-07-18-shortbread-v1` |
| Work item | [ZempTime/shortbread](https://github.com/ZempTime/shortbread); direct design and authority conversation |
| Initializer | Claude Code on Claude Fable 5 (`claude-fable-5`) |
| Current controller | Codex `/root`; bounded campaign C01, with `/root/u03_implementation` assigned only to U03/#21 |
| Accepted doctrine baseline | Repo-local MWP with bounded campaigns, fresh-context leaf units, TDD, proportionate independent review, durable pause/recovery, and explicit credential boundary |
| Repository authority | Implement, review, repair, document, package, and prepare deployment of the accepted Shortbread v1 scope |
| External authority | Configure the GitHub issue tracker; create/update issues, branches, commits, pull requests, releases, packages, and deployment configuration inside `ZempTime/shortbread` as required by the goal |
| Initialized | 2026-07-18 |
| State token | `execution-active` |
| Current state | C01 is active at its sole frontier U03/#21 from `main@173f096`; U04/#22 remains blocked by U03, and U05/#23 remains campaign-gated for C02 |

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
| 05 Delivery replan | C01 execution active at U03/#21 | [Bounded campaign/unit graph](05_delivery_replan/output/2026-07-20-delivery-plan.md), [unit contract](05_delivery_replan/output/UNIT-CONTRACT.md), [published tracker](05_delivery_replan/output/tracker.md), integrated [U01/#19](https://github.com/ZempTime/shortbread/issues/19), integrated [U02/#20](https://github.com/ZempTime/shortbread/issues/20), and claimed [U03/#21](https://github.com/ZempTime/shortbread/issues/21) |
| 99 Harvest | Complete for setup, #2, U01, and U02; no U02 factory promotion | [Setup harvest](99_harvest/output/2026-07-18-goal-setup-harvest.md), Stage 05 process corrections, and the U02 decision in the [delivery tracker](05_delivery_replan/output/tracker.md) |

## Recovery Capsule

| Field | State |
|---|---|
| Reconciled | 2026-07-21 by C01 controller `/root`; local `main`, `origin/main`, and GitHub `main` equal `173f09644c140599a706fabfffee0ae0e1289437`; issue #21 is open and unassigned with no open PR before claim |
| Integration branch/head | `main@173f09644c140599a706fabfffee0ae0e1289437` is the pinned U03 baseline; controller coordination advances separately on `main` |
| Release candidate | U03 fixed review head is clean local/remote `u03-production-runtime@d4d058a37cdac284a305c4e0cfe529fce2a36e3f` in draft [PR #61](https://github.com/ZempTime/shortbread/pull/61), from pinned product baseline `173f09644c140599a706fabfffee0ae0e1289437` |
| Auth source evidence | Historical `ticket-4-owner-cli-auth` remains local and remote at `8fcb22f`; its accepted U02 behavior is represented on main by PR #59, and the source branch is no longer merge material |
| Worktrees | Active U03 worktree `/private/tmp/shortbread-u03` on `u03-production-runtime`; clean U02, policy-repair, U01 implementation, and detached U01 replay worktrees remain inactive durable evidence |
| Dirty state | Root and new U03 worktree were clean at claim; no overlapping implementation or open PR exists |
| Collision | U03 is the only active product implementation. U04 stays blocked and U05 auth/session work stays unscheduled until C02 |
| Dependency state | Frozen dependency/tool versions, installer pins, telemetry controls, and lockfiles remain unchanged. Authorized PR #58 task-only changes are reconciled to the exact frozen `mise.toml` digest by reviewed [PR #60](https://github.com/ZempTime/shortbread/pull/60) at merge `1a65ae3` |
| Review state | Independent review blocked fixed head `d4d058a`. General review found Docker context could include Git-ignored local secrets. Operations/container/security review found database identity normalization, AnyCable URL redaction, and worker-instance health defects; it also requested a real writable-Blob probe. The Operator-approved U28 scan disposition remains accepted. All blocking/should-fix findings return through the U03 TDD repair loop before affected-axis rereview |
| Reserved surfaces | U03 exclusively owns container/release configuration, process commands, production environment validation, process-specific health routes/probes, production-shaped smoke harnesses, and root operations documentation. Dependency manifests/lockfiles, schema, unrelated routes, screenshots, and `agents/` remain forbidden without controller exception. General Standards + Spec review and an independent operations/container/security specialist review target the same fixed pushed head |
| True stop | Product-scope/trust/authority change, preservation failure, or unreconcilable tracker mutation—not ordinary graph edits |
| Next action | `/root/u03_implementation` repairs the fixed-head review findings test-first: exclude every documented local secret path from Docker context, normalize/require distinct PostgreSQL database identities, reject secret-bearing AnyCable URLs, bind worker health to the current role instance, and prove writable private-Blob operations; then push a new fixed head for affected-axis rereview |

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

Stage 05 promotes only after local graph review, full PRD coverage, GitHub leaf publication, umbrella reconciliation, one accurate frontier, and agreement between this file and the tracker. C00 is complete; C01 product execution resumes in a fresh controller context at U03 and does not silently continue into C02/U05.

## Limitations

- Current provider APIs, capabilities, plan choices, and official deployment guidance must be reverified from primary provider documentation inside U04/U31/U32.
- Only macOS arm64 has exercised the frozen dependency/tool bootstrap so far; artifact/platform claims remain unverified until U28–U30.
- Live Northflank, PlanetScale, Cloudflare R2, DNS, and GitHub credentials are deliberately absent from all current evidence.
- The public demonstration remains a synthetic invite-only Site; anonymous public Sites stay outside v1.
