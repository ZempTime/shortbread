# Ticket #4 Run

| Field | Value |
|---|---|
| Issue | `ZempTime/shortbread#4` / local ticket `T03` |
| Branch | `ticket-4-owner-cli-auth` |
| Product baseline | `f2e03262a0da76e30ff105a51b775055dba5037e` (merged ticket #2) |
| Worktree | `/private/tmp/shortbread-ticket-4` |
| Owner | `ZempTime` |
| Current phase | Behavioral TDD implementation |
| State | Claimed; bounded workspace seeded; no implementation checkpoint yet |

## Inputs

- root `AGENTS.md`, `CONTEXT.md`, and active initiative `RUN.md`
- canonical PRD Owner stories 1, 2, 14; Producer stories 32–36, 43, 45; authentication/API testing decisions
- canonical T03 ticket and ADRs 0002, 0004, 0006, and 0007
- integrated T01 host isolation, bootstrap Producer API, CLI transport, redaction, and Invitation/session seams
- frozen `webauthn` Ruby and `go-keyring` Go dependencies already present in the approved baseline
- repo-local `implement` and `tdd` skills

## Owned outcome

One installation bootstraps one permanent Owner exactly once, supports multiple passkeys and deployment-authority recovery, authorizes a remote CLI through a proof-bound short-lived device flow, stores interactive tokens in the OS keyring, and manages separately scoped/digested automation tokens.

This ticket owns Owner/WebAuthn credential records and flows, device authorizations, API token digests/scopes/revocation/expiry/last-used metadata, API compatibility/request IDs/pagination/rate-limit/idempotency authorization policy, and CLI server/profile/login/whoami/logout/keyring behavior.

## Boundaries

- Dependency manifests, lockfiles, tool pins, and dependency-policy digests are controller-only and frozen; use the front-loaded WebAuthn/keyring libraries.
- Do not implement Release/rollback semantics owned by parallel ticket #3, People/Shelf management, Viewer optional passkeys, R2, offline copies, feedback, receipts, deletion, or deployment.
- Coordinate before editing shared publishing endpoints, API base-controller behavior, CLI client/command dispatch, or stable JSON envelopes used by ticket #3.
- No password, email/SMS flow, hosted identity, plaintext stored server token, recoverable token display, or off-loopback HTTP.
- Treat the high-entropy device code and recovery values as one-use bearer secrets; never place them in logs, fixtures, process arguments, JSON status, screenshots, or durable evidence.

## Behavioral loop

Start at request/browser/real-CLI boundaries: one-time bootstrap and multiple passkeys; deployed RP ID/origin; recovery expiry and remote-invocation denial; device proof/replay/expiry/redemption races; keyring seam; profiles/whoami/logout; automation scope/revocation; HTTPS, compatibility, CSRF/session separation, idempotency, pagination, request IDs, rate limits, and redaction. Pure units are reserved for deterministic token/profile precedence or cryptographic formatting helpers.

## Verification and promotion

- focused red/green evidence for every acceptance promise, including real browser WebAuthn seams and built CLI black boxes;
- full Rails and Go suites, Go race tests, lint/type/security/license/build gates, and the walking skeleton;
- independent Standards + Spec + dedicated auth/security review on a fixed SHA;
- detached clean-checkout verification, named findings/dispositions, threat/residual scope, and harvest decision;
- controller-owned PR integration only after all blockers and should-fixes are repaired.
