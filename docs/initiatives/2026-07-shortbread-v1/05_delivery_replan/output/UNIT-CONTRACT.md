# Fresh-Context Delivery Unit Contract

Every Stage 05 delivery unit inherits this contract. Its GitHub issue plus the specific unit card in the delivery plan are the complete task packet; a worker reads deeper PRD/ADR material only when linked or when evidence contradicts the packet.

## Claim

- The controller records the issue, campaign, baseline SHA, branch/worktree, worker, blockers, and reserved edit surfaces.
- The worker confirms blockers are integrated and checks for dirty or overlapping work before editing.
- Dependency manifests, lockfiles, schema format, central routes, root run state, release workflow, generated screenshots, deployment inventory, and `agents/` remain controller-owned unless explicitly assigned.

## Implement

- Begin at the named browser, request, black-box CLI, provider-contract, or deterministic unit seam with a meaningful red result.
- Deliver the smallest coherent actor-visible behavior and its failure/recovery behavior.
- Open a draft PR at the first green checkpoint and push every meaningful green checkpoint. Local and remote heads are distinct recorded states.
- If the unit exceeds one fresh implementation context, crosses an undeclared shared hotspot, or approaches roughly 20 hand-written files/1,500 hand-written changed lines without a coherent review target, stop at a green checkpoint and apply the card's safe split rule.
- Do not add dependencies without the ADR 0007 exception process.

## Verify and Review

- Run focused checks during implementation and the full relevant suite once at the fixed review candidate and again only when a repair affects full-suite risk or before integration.
- One reviewer independent of the author may cover Standards and Spec for an ordinary bounded diff. Auth, authorization, secrets, destructive data, provider, deployment, release, and final-composition units add the named specialist review.
- A reviewer who authors a repair loses approval eligibility for that repaired head. Rereview only affected axes unless the repair changes the whole risk surface.
- Record the fixed baseline/head, acceptance mapping, CI/evidence links, findings/dispositions, residual risks, and harvest decision in one evidence record or PR summary; other surfaces link rather than copy it.

## Integrate or Pause

- The controller reruns proportionate integration evidence, merges only a reviewed green head, closes the leaf issue, updates its acceptance umbrella, recomputes the frontier, and emits a compact resume capsule.
- A pause is not failure or completion. It records initiative/campaign/unit, state, baseline, local and remote heads, dirty state, review target/verdict, reserved surfaces, authority/stop, next action, evidence links, and reconciliation timestamp.
- Each unit records one demonstrated factory candidate or `No reusable harvest`. One-off product facts stay with Shortbread.
