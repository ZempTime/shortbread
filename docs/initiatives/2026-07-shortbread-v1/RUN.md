# Run Manifest

| Field | Value |
|---|---|
| Run | `2026-07-18-shortbread-v1` |
| Work item | [ZempTime/shortbread](https://github.com/ZempTime/shortbread); direct design and authority conversation |
| Initializer | Claude Code on Claude Fable 5 (`claude-fable-5`) |
| Current controller | Codex persistent `ship-goal` controller (`ZempTime`) |
| Accepted doctrine baseline | The repo-local MWP staged-workspace method, combined with `to-spec` → `to-tickets` → per-ticket implementation, TDD, and review |
| Repository authority | Implement, review, repair, document, package, and prepare deployment of the accepted Shortbread v1 scope |
| External authority | Configure the GitHub issue tracker; create and update PRD/ticket issues; use branches, commits, pull requests, and releases inside `ZempTime/shortbread` as required by the goal |
| Initialized | 2026-07-18 |
| State token | `execution-active` |
| Current state | #2 remains the only unblocked frontier ticket; its dependency phase is frozen at `3c40a67` and its publish/invite/view tracer is in implementation |

## Input Snapshot

- [`inputs/request.md`](inputs/request.md) preserves the original request and attribution.
- [`inputs/design-notes.md`](inputs/design-notes.md) preserves the initial architecture synthesis.
- [`inputs/chris-framing.md`](inputs/chris-framing.md) is Chris's detailed framing contribution.
- [`inputs/2026-07-18-goal-addendum.md`](inputs/2026-07-18-goal-addendum.md) records the later decisions about open source, the CLI, deployment, the agent factory, evidence, and autonomous execution.

## Stage Status

| Stage | Status | Evidence |
|---|---|---|
| 00 Framing | Complete | [Framing contract](00_framing/output/2026-07-18-framing-contract.md), draft PRD, glossary, and ADRs verified |
| 01 Spec | Complete | [Canonical PRD](01_spec/output/2026-07-18-shortbread-v1-prd.md) published as [GitHub #1](https://github.com/ZempTime/shortbread/issues/1) |
| 02 Ticket map | Complete | [Reviewed graph](02_ticket_map/output/2026-07-18-ticket-map.md) published as [GitHub #2–#17](02_ticket_map/output/tracker.md); #2 is the initial frontier |
| 03 Goal handoff | Complete | [Persistent goal](03_goal_handoff/output/GOAL.md), controller runbook, dependency baseline, and [temporary-handoff lifecycle](03_goal_handoff/output/handoff.md) exist |
| 04 Execution | In progress | #2 phase-one dependency freeze approved at `3c40a67`; phase-two behavioral tracer active |
| 99 Harvest | Complete for setup | [Setup harvest](99_harvest/output/2026-07-18-goal-setup-harvest.md); implementation tickets repeat the decision |

## Execution State

- **Reconciled 2026-07-18:** `main`, `origin/main`, and the only local worktree all point to `3c1fc1b655a407d369a6f258af5e3cec33b7be0d`; the worktree is clean; no implementation branch or pull request exists.
- **Tracker:** #1–#17 are open, #2 alone has `ready-for-agent`, and no issue is assigned. The published #2 body matches the canonical T01 ticket.
- **Frontier:** #2, “Publish, invite, and view one private page locally.”
- **Dependency state:** the approved baseline is scaffolded, audited, frozen, and independently approved at `3c40a67`; manifests and lockfiles are now controller-only exception surfaces.
- **External input:** no credential or deployment value is requested during implementation; the consolidated credential ceremony remains owned by #17.

## Authority Envelope

Chris has authorized a top-level controller to continue without routine approval through specification, decomposition, implementation, review, repair, documentation, GitHub coordination, packaging, and deployment preparation. The controller may delegate and run independent work in parallel when dependency edges permit. It may approve subordinate-agent plans and outputs, create problem-specific harnesses, and revise tickets when evidence requires it.

Starting the persistent goal is Chris's single approval of the canonical PRD, published initial graph, dependency baseline, and this authority envelope. Skills and subordinate agents treat controller sign-off as satisfying routine gates inside this envelope and report uncertainty to the controller rather than asking Chris again.

Within this repository and its GitHub project, the controller is pre-authorized to:

- create, edit, move, or remove project files when the change is recoverable through Git and advances the accepted PRD;
- install project dependencies, run local services, tests, browsers, build tools, and security checks;
- create and update issues, labels, branches, commits, pull requests, releases, packages, and deployment configuration;
- merge reviewed project pull requests when required checks pass and the change satisfies its ticket;
- provision or update the reference deployment using credentials Chris supplies, provided the action matches the documented plan and does not delete an existing production resource;
- choose reversible implementation details inside accepted ADR and ticket boundaries;
- fix review findings and continue to the next unblocked slice without asking Chris.

The controller must stop only when:

1. a required credential, account grant, DNS delegation, provider confirmation, or billing authorization is unavailable;
2. an action would destroy or irreversibly migrate existing external data or infrastructure and no tested recovery path exists;
3. evidence requires changing a trust promise, accepted ADR, permanent product boundary, license, repository visibility, or scope beyond Shortbread v1;
4. a third-party decision or outage prevents meaningful progress after safe alternatives are exhausted;
5. the goal's terminal criteria are met.

Missing credentials are an input boundary, not a design approval gate: prepare everything else, produce the exact setup step and requested value, and continue any independent work. Never print, commit, transmit to agents, or place credentials in issue/PR text. The controller may not modify unrelated repositories, charge for new services, weaken security to pass a check, publish private fixture content, or delete production resources merely because those actions would be expedient.

## Promotion Rule

Each stage must satisfy its `Verify` section and update this file before promotion. A folder, branch, issue label, or merged pull request does not prove that a stage ran. The setup run ends only when the copy-paste goal and temporary handoff both reference the same canonical PRD, ticket graph, controller contract, and credential boundary.

Implementation begins under the persistent goal, not by silently extending this setup run. During implementation, each ticket receives the smallest workspace and harness justified by its uncertainty; ceremonial empty stages are forbidden.

## Limitations

- A local private template was reviewed during setup only. Its generic Rails/Inertia, authentication, testing, container, and deployment patterns informed the checked-in baseline; the clean implementation run cannot depend on access to that template or copy its product behavior or manual infrastructure steps as requirements.
- Live provider verification needs operator-supplied Northflank, PlanetScale, Cloudflare R2, DNS, and GitHub credentials. Clean-room and command-contract verification must run without them.
- The public demonstration is a committed example bundle, repeatable screenshot evidence, and explanatory documentation. Anonymous public sites remain outside v1 unless the PRD is explicitly reopened.
- Renaming the local checkout directory is outside repository version control and is not required for the goal; the product, repository, package, and CLI names are `shortbread`.
