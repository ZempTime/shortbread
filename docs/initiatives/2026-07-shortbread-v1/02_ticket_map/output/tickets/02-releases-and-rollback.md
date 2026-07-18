# Republish immutable Releases and roll back safely

Parent: #1
Blocked by: #2
Local ticket ID: T02

## Outcome

Repeated `shortbread publish` calls create immutable numbered Releases, atomically advance the Site's current pointer, reuse unchanged Blobs, expose Release history, and roll back by repointing without rewriting content.

## Acceptance

- Canonical Manifest hashing/delta logic identifies added, changed, reused, and removed paths deterministically.
- Finalize is transactional/idempotent, fails closed for incomplete or inconsistent uploads, and handles concurrent publishes without a half-visible Release.
- `shortbread releases list` and `rollback` plus Owner UI expose history/current state with stable JSON.
- Conditional serving uses content-hash ETags and preserves historical Release immutability.
- Interrupted/retried publish and rollback have precise observable results.

## Evidence and review

- Black-box CLI/request tests cover unchanged files, changed/removed paths, retry, incomplete finalize, concurrency, history, rollback, and current-pointer atomicity.
- Pure units only for canonical Manifest/delta algorithms.
- Standards + Spec review, data-integrity review, full suite, docs/harvest evidence.
