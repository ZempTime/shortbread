# Goal-setup Factory Harvest — 2026-07-18

## Result

This setup run produced reusable factory changes. They were promoted during the run and validated before handoff.

## Promoted learning

### A staged workspace still needs a controller

**Evidence:** the initial workspace described stage ownership but had no executor responsible for frontier computation, parallel assignment, review repair, integration, durable checkpoints, or terminal composition.
**General rule:** MWP holds bounded work/evidence; a multi-ticket goal needs an explicit top-level controller state machine.
**Promotion:** `docs/agents/mwp.md`, `agents/skills/ship-goal/`, and the controller-aware `implement`/`code-review` skills.

### Authority must be a data surface, not a conversational assumption

**Evidence:** default triage/ticket workflows expected repeated human gates, while the Operator explicitly wanted one bounded initial approval.
**General rule:** an authoritative `RUN.md` should name allowed external/local actions, invariants, prohibited actions, credential inputs, and true stops. Skills can treat controller sign-off as routine approval only inside that envelope.
**Promotion:** controller modes in `triage`/`to-tickets`, authority rules in MWP/ship-goal, and the run manifest contract.

### Dependency ownership is a concurrency boundary

**Evidence:** a greenfield Rails/React/Go build would otherwise let parallel slices discover and add overlapping libraries after work had fanned out.
**General rule:** when a trusted template already supplies most of a kit, front-load and audit dependencies in the walking-skeleton checkpoint; then make manifests/lockfiles controller-exclusive and require narrow exceptions.
**Promotion:** dependency bootstrap/freeze rules in `ship-goal` and `implement`. The exact Shortbread package list remains a product/run artifact.

### Review findings need a repair loop

**Evidence:** “run code review” alone does not guarantee findings are fixed, rereviewed, or integrated against a fixed diff.
**General rule:** run independent Standards and Spec reviews from pinned SHAs, add sensitive-domain review as needed, route blockers back through behavioral TDD, and rereview.
**Promotion:** `agents/skills/code-review/` plus integration rules in `ship-goal`.

### Tool discovery is part of a reusable factory

**Evidence:** canonical skills under `agents/skills` were not automatically visible to every client; a clean session could have been told to invoke an undiscoverable skill.
**General rule:** keep one canonical skill tree and check in deterministic client mounts. Validate both source skills and symlink targets during setup.
**Promotion:** `agents/scripts/link-codex.sh`, existing `link-claude.sh`, and documented layout in `agents/README.md`.

### Credentials are inputs, not permission shortcuts

**Evidence:** a credential-ready deployment outcome must continue without secrets, but “all approvals” could accidentally authorize charges or destructive provider actions.
**General rule:** complete fakes/contracts/dry runs/docs without credentials; allow least-privilege live application only to declared resources after values arrive; retain stops for paid/legal/destructive/invariant changes.
**Promotion:** MWP and ship-goal authority/terminal rules. Provider-specific inventory remains in Shortbread tickets/docs.

### A public first push needs a whole-tree and ancestry audit

**Evidence:** reviewing only the final setup edits missed stale vendor-specific, human-gated factory instructions and superseded private-template provenance inherited from the unpushed scaffold.
**General rule:** before a repository first becomes public, review the complete proposed tree and reachable public ancestry for secrets, private prior art, proprietary assumptions, upstream notices, unsafe generators, and contradictory workflow rules—not only the latest diff.
**Promotion:** the unpushed setup history was flattened onto the public initial commit; historical inputs were generalized; every mounted skill was refit/validated; and the upstream notice was preserved with a verifiable revision.

### Generated evidence is a code-execution boundary

**Evidence:** an architecture-report helper loaded live CDN JavaScript into a document containing codebase-derived labels and used a permissive renderer configuration.
**General rule:** generated reports that contain repository information are offline artifacts: escape derived text, embed inert CSS/static diagrams, set a restrictive CSP, and load no remote executable resources.
**Promotion:** the architecture-report factory now requires escaped static HTML/SVG and an offline CSP.

### Discovery mounts must fail closed

**Evidence:** idempotent skill-link helpers could replace an unexpected file, directory, or custom symlink at a managed path.
**General rule:** setup helpers may accept an absent target or the exact expected link; every other collision is evidence to stop and report rather than overwrite.
**Promotion:** both Codex and Claude mount scripts now enforce the exact-link contract.

## Validation

- All five new skills were created through the supported skill initializer and passed `quick_validate.py` with isolated PyYAML.
- Repo-local Codex and Claude mounts resolve to the canonical factory directories.
- The setup run's independent authority, ticket-graph, and controller/factory audits were reconciled into the local contracts; raw reports were not retained.

## Not promoted

Shortbread domain terms, Rails/Go package versions, provider choices, auth ceremony details, ticket graph, and product testing cases remain in the PRD, ADRs, dependency baseline, and initiative outputs because they are product/run facts rather than general factory doctrine.
