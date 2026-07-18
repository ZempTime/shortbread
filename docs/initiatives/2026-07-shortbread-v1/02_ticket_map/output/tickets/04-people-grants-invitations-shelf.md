# Manage People, Grants, Invitations, and the Shelf

Parent: #1
Blocked by: #4
Local ticket ID: T04

## Outcome

The Owner manages a reusable Person roster and per-Site Grants; Viewers accept preview-safe personal Invitations, use the apex Shelf, cross to isolated Site sessions, optionally register a passkey, and lose future server access when revoked.

## Acceptance

- Owner UI/CLI/API create/list/update People, grant/revoke Site access, manage offline permission, and create/rotate/revoke/inspect Invitations.
- Invitation secrets are high-entropy/digested/expiring/rate-limited; GET/link previews are side-effect free; explicit CSRF-protected acceptance consumes exactly once.
- The Shelf lists only currently granted Sites without leaking other People/Sites.
- Apex acceptance/Shelf creates a one-use, host/audience-bound, short-lived handoff; exchange sets a Secure HttpOnly host-only Site cookie and removes credentials from visible URLs.
- Optional Viewer passkey supports apex re-entry; first Invitation use remains passwordless/accountless.
- Revocation invalidates future online Site/feedback/update access while wording preserves Offline Copy truth.

## Evidence and review

- Owner/Viewer browser journeys and request tests cover preview POST semantics, replay/expiry/rotation, host confusion/cookie isolation, Shelf authorization, passkey, and revocation.
- Standards + Spec + auth/security review, full suite, UI/CLI docs and harvest.
