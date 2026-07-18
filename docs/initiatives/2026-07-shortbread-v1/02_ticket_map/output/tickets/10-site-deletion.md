# Delete Sites and reclaim unshared Blobs truthfully

Parent: #1
Blocked by: #5, #6, #9, #10
Local ticket ID: T10

## Outcome

Owner-confirmed UI/CLI Site deletion stops future access, revokes related authorization, removes Site-owned records under a documented policy, and retryably reclaims only Blobs no remaining Release references.

## Acceptance

- Confirmation names the Site and consequences; CLI requires explicit non-interactive confirmation and stable JSON.
- Deletion is an idempotent durable state machine visible as pending/complete/failed and safe to resume after any partial failure.
- Serving, Invitations, Grants, comments, receipts, and current pointers fail closed as soon as the deletion boundary commits.
- Shared-Blob reference calculation is transactional; object deletion never removes content used elsewhere.
- Backup/restore/retention wording distinguishes application deletion, provider backups/versioning, and operator-held source Bundles.

## Evidence and review

- Request/job/CLI tests cover retries at each stage, concurrent publish/access, partial R2 failure, shared/unshared Blobs, revoked URLs, and recovery wording.
- Standards + Spec + destructive-data/security/operations review, full suite, runbook and harvest.
