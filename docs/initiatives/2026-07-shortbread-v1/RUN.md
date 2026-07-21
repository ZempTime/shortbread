# Run Manifest

| Field | Value |
|---|---|
| Run | `2026-07-18-shortbread-v1` |
| Work item | [ZempTime/shortbread](https://github.com/ZempTime/shortbread); direct design and authority conversation |
| Initializer | Claude Code on Claude Fable 5 (`claude-fable-5`) |
| Current controller | None; launch-alpha packaging issue #62 is durably paused in one isolated worktree pending four non-secret deployment-shape inputs |
| Accepted doctrine baseline | Repo-local MWP with bounded campaigns, fresh-context leaf units, TDD, proportionate independent review, durable pause/recovery, and explicit credential boundary |
| Repository authority | Implement, review, repair, document, package, and prepare deployment of the accepted Shortbread v1 scope |
| External authority | Configure the GitHub issue tracker; create/update issues, branches, commits, pull requests, releases, packages, and deployment configuration inside `ZempTime/shortbread` as required by the goal |
| Initialized | 2026-07-18 |
| State token | `campaign-paused` |
| Current state | U03/#21 is integrated by PR #61. Launch-alpha packaging #62 is paused at draft PR #63 after all host-independent runtime work, verification, and credential rereview; the Operator's SSH/access method, apex hostname, DNS provider, and existing proxy/TLS manager are required before the exact host package can continue. U04/#22 remains closed as not planned, and U05 plus the remaining unbuilt v1 backlog stay open, unassigned, and paused |

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
| Reconciled | 2026-07-21 by launch controller `/root`; clean synchronized `main` is `abb256c560fe2944ffa4e9d4b9cb374618549f88`, reviewed host-independent implementation checkpoint is `4d04766825116024ee107c9ba0e60ba9ec670e14`, bounded launch issue [#62](https://github.com/ZempTime/shortbread/issues/62) is open, and [draft PR #63](https://github.com/ZempTime/shortbread/pull/63) is open |
| Integration branch/head | Pinned launch baseline is `abb256c560fe2944ffa4e9d4b9cb374618549f88`; reviewed implementation head is `4d04766825116024ee107c9ba0e60ba9ec670e14`; this coordination-only pause capsule is its descendant, and no launch commit is integrated into `main` |
| Release candidate | `4d04766825116024ee107c9ba0e60ba9ec670e14` is a host-independent credential/runtime checkpoint, not a deployable or final-review candidate. The exact proxy/host contract and HTTPS proxy/API Site-creation smoke remain red pending deployment-shape inputs |
| Auth source evidence | Historical `ticket-4-owner-cli-auth` remains local and remote at `8fcb22f`; its accepted U02 behavior is represented on main by PR #59, and the source branch is no longer merge material |
| Worktrees | Launch worktree `/private/tmp/shortbread-launch-62` is retained clean on `launch-single-host-62`. Unrelated U02, policy-repair, U01 implementation, and detached U01 replay evidence worktrees remain untouched |
| Dirty state | Root `main` is clean at `abb256c560fe2944ffa4e9d4b9cb374618549f88` and matches `origin/main`; launch local/remote head is clean and synchronized at `4d04766825116024ee107c9ba0e60ba9ec670e14` before this pause-capsule commit |
| Collision | No implementation agent or controller is active. Issue #62 remains the only claimed launch package; U04 was not started, and U05 plus all subsequent unbuilt v1 work remain unclaimed and paused |
| Dependency state | Frozen dependency/tool versions, installer pins, telemetry controls, and lockfiles remain unchanged. Authorized PR #58 task-only changes are reconciled to the exact frozen `mise.toml` digest by reviewed [PR #60](https://github.com/ZempTime/shortbread/pull/60) at merge `1a65ae3` |
| Review state | Credential security/operations preflight found two blockers, one should-fix, and one note at `e356d277`; all were repaired test-first. A fixed-head rereview approved the credential checkpoint at `4d04766825116024ee107c9ba0e60ba9ec670e14` with no remaining findings. Final Standards + Spec and operations/security reviews have not run because the host-specific package is incomplete; [PR #63's review record](https://github.com/ZempTime/shortbread/pull/63#issuecomment-5038302142) owns this evidence |
| Reserved surfaces | Issue #62 exclusively reserves production deployment/runtime configuration, production smoke coverage, operations documentation, and this root run state. Dependency manifests, lockfiles, schema, product routes, and deferred feature surfaces are forbidden |
| True stop | Missing deployment-shape input: SSH target/access method, intended apex hostname, DNS provider, and whether the host already has a reverse proxy/TLS manager. These are non-secret identifiers/choices; credentials remain forbidden from chat, Git, issues, PRs, process arguments, and captured output |
| Next action | Operator supplies only the four non-secret deployment-shape inputs; resume issue #62 at the clean pushed pause head, implement the retained HTTPS proxy/API smoke and exact host contract, then run final review/integration. Do not deploy |

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
