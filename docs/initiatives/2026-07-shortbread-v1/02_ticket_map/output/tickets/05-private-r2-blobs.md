# Store content-addressed Blobs in private R2

Parent: #1
Blocked by: #3
Local ticket ID: T05

## Outcome

Manifest publishing discovers missing content-addressed Blobs, uploads only those bytes directly through short-lived presigned requests, finalizes atomically, and serves reads only through authenticated Shortbread requests from private R2.

## Acceptance

- One BlobStore port supports local tests and R2's S3-compatible API without leaking provider behavior into domain code.
- Blob keys are installation-namespaced/content-derived; presigned PUTs cover only missing expected hashes/sizes, expire quickly, and do not grant reads/listing/arbitrary keys.
- Finalize verifies hash/size/upload presence and stays idempotent across retry/partial failure.
- Authenticated serving fetches private bytes; direct unauthenticated object access fails.
- Orphan cleanup is retryable and cannot remove a Blob referenced by any Release.

## Evidence and review

- S3-compatible fake/contract harness plus Rails/CLI tests cover missing-only upload, hash/size mismatch, expiry, retry, private denial, and orphan/shared-Blob behavior.
- Standards + Spec + data/security review, full suite, R2 config/ops docs and harvest.
