# Run Manifest

| Field | Value |
|---|---|
| Run | `2026-07-18-shortbread-v1` |
| Work item | [ZempTime/shortbread](https://github.com/ZempTime/shortbread); direct design and authority conversation |
| Initializer | Claude Code on Claude Fable 5 (`claude-fable-5`) |
| Current controller | Codex (`ship-goal`); C00/U02 resumed on 2026-07-21 |
| Accepted doctrine baseline | Repo-local MWP with bounded campaigns, fresh-context leaf units, TDD, proportionate independent review, durable pause/recovery, and explicit credential boundary |
| Repository authority | Implement, review, repair, document, package, and prepare deployment of the accepted Shortbread v1 scope |
| External authority | Configure the GitHub issue tracker; create/update issues, branches, commits, pull requests, releases, packages, and deployment configuration inside `ZempTime/shortbread` as required by the goal |
| Initialized | 2026-07-18 |
| State token | `execution-active` |
| Current state | U01/#19 is integrated; U02/#20 is implemented in draft PR #59 at approved head `0ff26c8` and is frozen pending a controller-owned repair of the inherited dependency-policy digest mismatch introduced by merged PR #58 |

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
| 05 Delivery replan | Complete; C00 resumed with U01 integrated and U02 at its integration gate | [Bounded campaign/unit graph](05_delivery_replan/output/2026-07-20-delivery-plan.md), [unit contract](05_delivery_replan/output/UNIT-CONTRACT.md), [published tracker](05_delivery_replan/output/tracker.md), [integrated U01/#19](https://github.com/ZempTime/shortbread/issues/19), [U02/#20](https://github.com/ZempTime/shortbread/issues/20), and draft [PR #59](https://github.com/ZempTime/shortbread/pull/59) |
| 99 Harvest | Complete for setup and #2; interrupted-run learning promoted into MWP | [Setup harvest](99_harvest/output/2026-07-18-goal-setup-harvest.md) plus Stage 05 process corrections |

## Recovery Capsule

| Field | State |
|---|---|
| Reconciled | 2026-07-21, against GitHub, local/remote refs, clean worktrees, merged PR #58, issue #20, and draft PR #59 |
| Integration branch/head | `main@ab6e30e` locally and on `origin`; this capsule is the next coordination-only main commit before the isolated dependency-policy repair |
| Release candidate | U02 draft [PR #59](https://github.com/ZempTime/shortbread/pull/59) is fixed at local/remote `u02-owner-bootstrap@0ff26c8`; do not amend or rewrite that reviewed history |
| Auth source evidence | `ticket-4-owner-cli-auth` local and remote at `8fcb22f`; no PR; replay semantically only after U01 |
| Worktrees | Clean U02 implementation worktree `/private/tmp/shortbread-u02` at `0ff26c8`; inactive clean U01 implementation and detached replay worktrees remain durable evidence |
| Dirty state | Main and all registered worktrees were clean at reconciliation; U02 remains frozen while the controller works in a separate policy-repair branch/worktree |
| Collision | Merged PR #58 changed governed `mise.toml`; frozen `script/check_dependency_policy.rb` still records the prior digest, so `mise run security` fails on clean main and U02 without either branch having changed dependency versions or lockfiles |
| Dependency state | Frozen/audited dependency and tool versions remain unchanged; the controller must confirm PR #58's governed task-only change is authorized under ADR 0007 before updating only its approved digest |
| Review state | Independent auth re-review approved exact U02 head `0ff26c8` with no remaining blocker, should-fix, or note findings; its full relevant evidence is green except the inherited mainline dependency-policy mismatch |
| Reserved surfaces | Controller exclusively owns `script/check_dependency_policy.rb`, the isolated policy-repair branch/worktree, root run/tracker state, and GitHub integration; U02 owns its existing auth/schema/routes/tests and remains frozen until main is merged into it |
| True stop | Product-scope/trust/authority change, preservation failure, or unreconcilable tracker mutation—not ordinary graph edits |
| Next action | Audit merged [PR #58](https://github.com/ZempTime/shortbread/pull/58) against the active authority and frozen dependency contract; if authorized, update only the governed `mise.toml` digest in an isolated controller branch/worktree, run complete security/dependency/license evidence, obtain exact-head review, and integrate that repair into `main` before updating PR #59 |

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
