# Show Owner-only View Receipts

Parent: #1
Blocked by: #5, #7
Local ticket ID: T09

## Outcome

The Owner can answer which Person opened which Release through minimal receipts that are invisible to Viewers and never become third-party analytics.

## Acceptance

- Record only a successful authenticated content open, anchored to Person/Site/Release and deduplicated at a documented useful granularity.
- Invitation previews, health checks, failed auth, asset floods, offline cache reads, and background probes do not fabricate receipts.
- Only Owner UI/API/`shortbread receipts --json` can read them; no Viewer can infer another Viewer's activity.
- No tracking pixel, fingerprinting, behavioral event stream, optional telemetry, or external analytics dependency exists.
- Retention/deletion behavior is documented and follows Site deletion semantics.

## Evidence and review

- Request/system/CLI tests prove classification, deduplication, authorization, cross-Site isolation, privacy, and deletion.
- Standards + Spec + privacy/security review, full suite, UI/docs and harvest.
