# Keep a Site offline under Viewer control

Parent: #1
Blocked by: #5, #7
Local ticket ID: T07

## Outcome

When policy permits, a Viewer explicitly keeps one complete eligible Release offline with visible size/progress, required/optional entries, atomic updates, honest eviction/revocation language, and complete removal from the device.

## Acceptance

- Owner Site policy and per-Grant permission jointly govern offline eligibility; no silent download occurs.
- Release Manifest exposes required/optional/download-only entries and accurate counts/bytes; Viewer chooses optional content.
- Service worker builds a new Release cache, verifies required hash/size responses, swaps its local current marker only after completion, and deletes incomplete caches on failure.
- Offline navigation/assets pin to the selected complete Release; a newer Release is offered visibly and never silently applied.
- `remove from this device` clears Shortbread caches/state/registration as safely possible and reports browser limitations.
- UI/docs say browser eviction is possible and saved Offline Copies survive revocation.

## Evidence and review

- Real-browser system tests cover keep/progress, optional selection, network-off reopen, failed-update preservation, successful atomic update, policy denial, revocation semantics, and removal.
- Deterministic cache-state units only where browser tests cannot isolate algorithms.
- Standards + Spec + offline/security review, screenshot/docs and harvest.
