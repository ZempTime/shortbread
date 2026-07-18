# Collect Release- and path-anchored feedback

Parent: #1
Blocked by: #5, #7
Local ticket ID: T08

## Outcome

Every eligible Site page exposes one collapsed flat chronological Feedback Thread; authenticated Viewers post append-only Comments automatically anchored to the served Release/path, and the Owner/Producer retrieves stable contextual JSON.

## Acceptance

- The injected thread works across normal Bundle pages without changing non-HTML files and attributes identity from the authenticated Person, never client input.
- Comment anchors derive server-side from the actual Release/path; ordering/pagination is stable across republish/rollback.
- Self-hosted AnyCable pushes updates, while reconnect/fetch restores authoritative order and correctness never depends on WebSocket delivery.
- Owner UI and `shortbread feedback --site ... [--since-release N] --json` expose the agreed fields with scopes/redaction.
- No replies, nesting, reactions, states, assignments, approvals, notifications, email/SMS/push, or Shortbread action on feedback appear.

## Evidence and review

- Viewer/Owner system, request, and black-box CLI tests cover ordering, auth, anchoring across Releases/paths, reconnect, pagination, revocation, and stable JSON.
- Standards + Spec + privacy review, full suite, CLI/API/UI docs and harvest.
