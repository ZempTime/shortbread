# Ticket #2 Run

| Field | Value |
|---|---|
| Issue | `ZempTime/shortbread#2` / local ticket `T01` |
| Branch | `ticket-2-walking-skeleton` |
| Pinned baseline | `412be84d441325c5e61004da87ec6878e588d7b4` (`Start Shortbread v1 execution`) |
| Owner | `ZempTime` |
| Current phase | Phase 2 approved promotion and PR integration |
| State | Fixed code `0fda8d4` is approved on Standards, Spec, and Security/Operations; merge-ready tree `055d448` is tree-identical and passed detached clean-checkout CI plus the real browser tracer |

## Inputs

- root `AGENTS.md`, `CONTEXT.md`, and active initiative `RUN.md`
- canonical Shortbread v1 PRD and T01 ticket
- ADRs 0001–0007, especially 0005–0007
- `03_goal_handoff/output/dependency-baseline.md`
- repo-local `implement` and `tdd` skills

## Phase 1 contract — complete

Scaffold and audit the complete approved Ruby, browser, Go, and tool baseline. Prove the Rails boot, browser production build, Go tests/build, and real CLI help boundary through `mise run bootstrap-check`. Record compatibility and supply-chain evidence, then stop for the controller-owned dependency freeze.

This phase must not create product records, product routes, deployment resources, credentials, telemetry, or proprietary integrations. The subordinate implementation worker must not commit, open a PR, or mutate GitHub. The controller may create and push checkpoint/freeze commits so independent reviewers receive a durable fixed SHA; PR creation remains a later integration action.

## Controller checkpoints

- `e3a41c8` reconstructed the dependency scaffold as a durable local checkpoint after the temporary worker workspace was lost.
- `914ddd6` froze the first audited bootstrap and was pushed as the fixed input for independent review.
- `214e1da`, `715e7d8`, and `13e69f4` repaired the initial security, trust-boundary, telemetry, and installer-source findings.
- `3c40a67` added the pre-mise installer preflight; Standards, Security/Operations, and Spec reviewers all approved the fixed phase-one tree with no remaining blocker or should-fix finding.

## Evidence

- [`evidence/bootstrap-red.md`](evidence/bootstrap-red.md)
- [`evidence/bootstrap-green.md`](evidence/bootstrap-green.md)
- [`evidence/dependency-audit.md`](evidence/dependency-audit.md)
- [`evidence/review-phase1.md`](evidence/review-phase1.md)
- [`evidence/phase2-verification.md`](evidence/phase2-verification.md)
- [`evidence/review-phase2.md`](evidence/review-phase2.md)

## Controller decisions for phase 2

- `shortbread invite create` delivers the one-time bearer link only through an explicit `--link-file <path>` sink. It creates a new mode-`0600` file, refuses overwrite and `-`, and prints only redacted non-secret status.
- The link uses `https://<apex>/invitations/<opaque-locator>#<secret>`. The locator cannot authorize acceptance; URI fragments do not reach previews or server request targets. Landing code removes the fragment before sending the secret only in the explicit acceptance POST body.
- The black-box harness owns a mode-`0700` temporary directory, reads and deletes the link internally, and never emits the URL, secret, current browser URL, request body, page dump, or browser log. Agent-facing evidence contains only redacted pass/fail output.
- This clarifies the trust promise: Invitation values remain forbidden in Git, logs, issues/PRs, chat/prompts, fixtures, screenshots, process arguments, stdout/stderr/JSON, and captured tool output. The transient Owner-selected private sink is the intentional product delivery boundary, not command output.

## Phase 2 contract

Implement the thinnest durable domain, API, local Blob storage, CLI, Invitation acceptance, host-session, and private-serving seams required by T01. Work test-first at request, CLI black-box, and browser boundaries. Dependency manifests and locks remain frozen.

Stop for review only after a built Go CLI creates the minimum records, safely publishes one HTML Bundle, writes the one-time Invitation link only to the approved private sink, and the browser proves preview-safe GET → explicit POST → private Site view. Unauthenticated Site reads, Invitation replay, unsafe Bundle paths, symlinks, reserved paths, and representative secret-like files must fail closed.

## Phase 2 checkpoint

`0fda8d4` is the fixed reviewed code checkpoint relative to promotion baseline `606a94f`. It contains the durable Site/Person/Grant/Invitation/Release/Blob model, bootstrap-token Producer API, safe one-file CLI publish path, preview-safe explicit Invitation acceptance, one-use host-bound handoff and Site session, private HTML serving, exact host isolation, Rack-conformant denial boundaries, strict redaction/security checks, and the built-CLI-to-real-Chrome black-box tracer. Merge commit `055d448` incorporates current `main` without changing that tree.

The dependency freeze remains intact: no dependency/tool version, source, inventory, lock entry, or governed manifest digest changed in Phase 2. The frozen `mise.toml` therefore retains its historical “currently pending” walking-skeleton description even though the task is now implemented; this RUN file, not that governed setup label, owns live execution status.

Independent Standards, Spec, and Security/Operations reviews approve `0fda8d4` with no remaining blocker or should-fix. Controller CI, detached clean-checkout CI, focused host/Rack probes, and the real browser tracer are green. The named verdicts, every blocking repair, exact gate counts, clean-tree comparison, and harvest disposition are recorded in [`evidence/review-phase2.md`](evidence/review-phase2.md). The remaining action is reviewed PR integration.
