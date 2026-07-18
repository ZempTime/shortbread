# Establish core security and trust controls

Parent: #1
Blocked by: #4, #5, #6, #7
Local ticket ID: T13

## Outcome

A public threat/data-flow model plus executable hostile tests establish the security baseline for the implemented control plane, Invitations/sessions, private R2 publish/serve path, and arbitrary Bundle isolation. The model also gives every later ticket a named security checklist; final whole-product trust proof remains T16/#17.

## Acceptance

- Map all anticipated actors, assets, trust boundaries, operator-selected providers, Producer boundary, entry points, abuse cases, mitigations, residual risks, and Offline Copy limitations, clearly marking later controls not yet implemented.
- Prove the existing Invitation/token replay controls, passkey origin/RP configuration, `__Host-` cookies, exact-Origin/Fetch-Metadata/CSRF/no-credentialed-CORS policy, host confusion, cross-Site/apex isolation, authorization scoping, and rate limits.
- Prove existing unsafe path/Manifest/content type/range/injection, R2 direct access, presign scope, SSRF/redirect/log/error/body leakage, and dependency/build-script controls fail safely.
- Audit current runtime/browser network behavior and logs against the exact trust contract; scan the current dependency/container/secret/license surface and resolve blockers.
- Publish explicit security acceptance/evidence requirements for offline, feedback, receipts, deletion, artifacts, provisioning, docs, example data, and screenshots so later slices cannot claim this baseline covered them.

## Evidence and review

- Hostile request/browser/CLI/R2-contract suites, captured current data-flow assertions, scans, and redacted log inspection.
- Independent Standards + Spec plus dedicated security/privacy review by agents that did not implement the controls; public baseline/threat docs and harvest.
- T16/#17 repeats the audit holistically over every later feature, provider adapter, artifact, fixture, screenshot, and runtime path before stable release.
