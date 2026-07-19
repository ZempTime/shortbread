# Ticket #2 Run

| Field | Value |
|---|---|
| Issue | `ZempTime/shortbread#2` / local ticket `T01` |
| Branch | `ticket-2-walking-skeleton` |
| Pinned baseline | `412be84d441325c5e61004da87ec6878e588d7b4` (`Start Shortbread v1 execution`) |
| Owner | `ZempTime` |
| Current phase | Dependency freeze review |
| State | Bootstrap, locks, compatibility adjustments, and supply-chain evidence complete; awaiting fixed-SHA review |

## Inputs

- root `AGENTS.md`, `CONTEXT.md`, and active initiative `RUN.md`
- canonical Shortbread v1 PRD and T01 ticket
- ADRs 0001–0007, especially 0005–0007
- `03_goal_handoff/output/dependency-baseline.md`
- repo-local `implement` and `tdd` skills

## Phase contract

Scaffold and audit the complete approved Ruby, browser, Go, and tool baseline. Prove the Rails boot, browser production build, Go tests/build, and real CLI help boundary through `mise run bootstrap-check`. Record compatibility and supply-chain evidence, then stop for the controller-owned dependency freeze.

This phase must not create product records, product routes, deployment resources, credentials, telemetry, or proprietary integrations. It must not commit, open a PR, or mutate GitHub.

## Evidence

- [`evidence/bootstrap-red.md`](evidence/bootstrap-red.md)
- [`evidence/bootstrap-green.md`](evidence/bootstrap-green.md)
- [`evidence/dependency-audit.md`](evidence/dependency-audit.md)

## Controller decisions for phase 2

- `shortbread invite create` delivers the one-time bearer link only through an explicit `--link-file <path>` sink. It creates a new mode-`0600` file, refuses overwrite and `-`, and prints only redacted non-secret status.
- The link uses `https://<apex>/invitations/<opaque-locator>#<secret>`. The locator cannot authorize acceptance; URI fragments do not reach previews or server request targets. Landing code removes the fragment before sending the secret only in the explicit acceptance POST body.
- The black-box harness owns a mode-`0700` temporary directory, reads and deletes the link internally, and never emits the URL, secret, current browser URL, request body, page dump, or browser log. Agent-facing evidence contains only redacted pass/fail output.
- This clarifies the trust promise: Invitation values remain forbidden in Git, logs, issues/PRs, chat/prompts, fixtures, screenshots, process arguments, stdout/stderr/JSON, and captured tool output. The transient Owner-selected private sink is the intentional product delivery boundary, not command output.

## Stop

Stop after the complete baseline and lockfiles are present, public bootstrap seams are green, and the supply-chain audit is recorded. The publish/invite/view tracer belongs to phase 2 after controller inspection and freeze.
