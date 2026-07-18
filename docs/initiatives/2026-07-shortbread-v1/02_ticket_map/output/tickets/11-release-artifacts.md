# Produce release-candidate application and CLI artifacts

Parent: #1
Blocked by: #4, #6, #7
Local ticket ID: T11

## Outcome

CI produces immutable production Rails images and checksummed single-binary `shortbread` release candidates for supported macOS/Linux architectures, with version/API compatibility and clean-install smoke evidence. Stable public promotion waits for final readiness T16/#17.

## Acceptance

- Production image builds reproducibly, runs non-root, and exposes documented migrate/web/worker/WebSocket commands with health checks.
- CLI cross-builds supported Darwin/Linux architectures without a runtime, reports version/commit/API range, and ships checksums plus dependency/SBOM inventory.
- GitHub release workflow uses least permissions, pinned actions/tools, and no proprietary release dependency. This ticket may publish CI artifacts or a draft/prerelease only; it cannot create a stable public release/tag before T16/#17 passes.
- A clean checkout installs each artifact and runs the walking skeleton against a production-shaped local stack.
- Compatibility failures give clear non-mutating instructions.

## Evidence and review

- CI/local artifact build, container scan, license/vulnerability audit, checksum/install, non-root/health, and end-to-end smoke results.
- Standards + Spec + supply-chain/operations review, release docs and harvest.
