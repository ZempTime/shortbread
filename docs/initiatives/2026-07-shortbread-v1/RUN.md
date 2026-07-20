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
| Current state | #2 fixed code `0fda8d4` is independently approved on Standards, Spec, and Security/Operations; merge-ready tree `055d448` passed detached clean-checkout CI and the real browser tracer; PR integration is active |

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
| 04 Execution | In progress | #2 dependency freeze approved at `3c40a67`; fixed code `0fda8d4` has approved [verification](04_execution/002-walking-skeleton/evidence/phase2-verification.md) and [review evidence](04_execution/002-walking-skeleton/evidence/review-phase2.md); PR integration active |
| 99 Harvest | Complete for setup | [Setup harvest](99_harvest/output/2026-07-18-goal-setup-harvest.md); implementation tickets repeat the decision |

## Execution State

- **Implementation checkpoint:** branch `ticket-2-walking-skeleton` contains independently approved code checkpoint `0fda8d4`, relative to promotion baseline `606a94f`; merge-ready tree `055d448` includes current `main` without a tree change and passed detached clean-checkout CI plus the real browser tracer.
- **Tracker:** #2 is the claimed T01 ticket. Its implementation and final evidence are promotion-ready; #3 and #4 become the parallel frontier only after #2 integrates.
- **Frontier:** #2, “Publish, invite, and view one private page locally,” remains the sole active integration unit until its reviewed PR merges.
- **Dependency state:** the approved baseline is scaffolded, audited, frozen, and independently approved at `3c40a67`; manifests and lockfiles are now controller-only exception surfaces.
- **Deployment apex:** Chris selected `shortbread.chriszempel.com`; provisioning later sets `SHORTBREAD_APEX_HOST` to that value and configures `<slug>.sites.shortbread.chriszempel.com` DNS/TLS. This is recorded on GitHub #13 and needs no credential during local implementation.
- **External input:** no credential is requested during the current implementation/review work; the consolidated credential ceremony remains owned by #17.

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
