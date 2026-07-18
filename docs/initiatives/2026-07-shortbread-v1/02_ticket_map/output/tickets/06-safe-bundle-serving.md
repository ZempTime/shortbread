# Serve real static Bundles safely

Parent: #1
Blocked by: #5, #6
Local ticket ID: T06

## Outcome

Authenticated Site hosts serve real multi-page HTML/CSS/JS/media Bundles with normal paths and HTTP semantics while rejecting unsafe manifests, isolating apex credentials, and reserving Shortbread endpoints.

## Acceptance

- Exact paths, `/` and directory `index.html`, explicit per-Site SPA fallback, correct content types, GET/HEAD, strong ETags/conditions, and single byte ranges work.
- CLI/server validation rejects traversal, absolute/ambiguous/colliding paths, symlinks/special files, invalid hashes/sizes/types, `/_shortbread/*`, and `/service-worker.js`.
- HTML injection is deterministic/idempotent and limited to eligible HTML; non-HTML bytes remain exact.
- Strict Host parsing permits only apex or one-label Site hosts and fails unknown/deeper/confused hosts closed.
- Production apex/Site sessions use `__Host-` cookies (`Secure`, HttpOnly, `Path=/`, no `Domain`). Every state-changing reserved endpoint requires session-bound CSRF plus exact `Origin`/Fetch Metadata and exposes no permissive credentialed CORS; sibling Domain-cookie shadowing/tossing and cross-Site mutations fail.
- Arbitrary hostile Bundle JavaScript cannot read apex or another Site credentials/content; external-origin lint and documented strict mode make privacy/offline limits visible.

## Evidence and review

- Request/CLI/system suites cover routing/ranges/ETags/types, malformed/hostile paths/manifests/HTML, root-relative assets, large media, strict Host/origin isolation, sibling cookie tossing/shadowing, cross-Site CSRF/Fetch-Metadata/CORS attempts, and direct private-object denial.
- Standards + Spec + security review, full suite, serving/Bundle-author docs and harvest.
