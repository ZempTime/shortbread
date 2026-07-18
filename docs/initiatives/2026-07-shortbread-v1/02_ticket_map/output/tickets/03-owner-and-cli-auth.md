# Secure the Owner and remote Producer control plane

Parent: #1
Blocked by: #2
Local ticket ID: T03

## Outcome

One-time Owner bootstrap, passkey re-entry/recovery, browser-assisted CLI login against any deployed Shortbread apex, named server profiles, revocable scoped automation tokens, stable `/api/v1`, and `--json` work without passwords, email, or hosted identity.

## Acceptance

- Bootstrap is single-use; the Owner can register multiple passkeys; deployment-authority recovery is short-lived, remote-invocation resistant, and redacted.
- `shortbread login --server ... --profile ...` creates a short-lived device authorization, opens the deployed apex, requires Owner passkey approval, and stores the one-time token in the OS keyring. The high-entropy device code is treated as a redacted one-use bearer secret distinct from the public user code/URL and is bound to a CLI proof key when possible.
- `profiles`, `whoami`, and `logout` are inspectable; logout removes local state and revokes remotely when possible.
- Headless CI uses separately minted/scoped `SHORTBREAD_TOKEN`; server stores only token digests and supports list/revoke/expiry/last-used metadata.
- Every network command resolves server/profile/env precedence, requires HTTPS off-loopback, negotiates API/CLI compatibility, and redacts stable JSON/errors/logs.
- `/api/v1` enforces scopes, CSRF/session separation, idempotency, bounded pagination, rate limits, and request IDs.

## Evidence and review

- WebAuthn browser/request tests plus black-box Go tests cover deployed-origin login, stolen/replayed/expired device codes, proof-key mismatch, token redemption races, keyring seam, CI mode, scope/revocation, compatibility, and redaction.
- Standards + Spec + dedicated auth/security review; clean full suite and CLI docs/harvest.
