# Phase-two review record

## Promotion target

- Ticket: GitHub #2 / T01
- Promotion baseline: `606a94f`
- Fixed reviewed code: `0fda8d4f9ff2bcbc7919a39b142860796d792be8`
- Merge-ready tree: `055d448fad5f93dc41de0af930aadbac5870e56c`
- Tree comparison: `git diff --exit-code 0fda8d4..055d448` passed
- Dependency comparison: all governed manifests and locks are unchanged from `606a94f`

## Final independent verdicts

| Axis | Reviewer | Verdict | Independent replay |
|---|---|---|---|
| Standards | `/root/phase2_standards_review` | **Approved** for `0fda8d4`; no blocker or should-fix | 30 host/Rack tests / 376 assertions, lint, dependency policy, diff/status |
| Spec | `/root/phase2_standards_review` | **Approved** for `0fda8d4`; no blocker or should-fix | T01 mapping plus development/production stack and valid/invalid host probes |
| Security/Operations | `/root/phase2_standards_review/fresh_security_review` | **Approved** for `0fda8d4`; no blocker or should-fix; one operations note | Focused Rails 92 / 1,104, full Rails 106 / 1,151, black-box 5 / 19, real tracer, dependency/secret gates; delegated CLI/Blob 31 / 383 plus Go internal race |

`/root/phase2_spec_review` independently approved the pre-security candidate `c77cf19`, then switched roles at the controller's direction to author the subsequent test-first host/Rack repairs. Its earlier verdict is not counted as independent approval of its own repair. Final Spec approval therefore belongs to `/root/phase2_standards_review`.

`/root/repair_phase2_rails` found and replayed the production host/Rack blockers, including a 25 / 368 focused security run, but it authored an earlier pre-`5635586` Vite repair. Its later audit is retained as adversarial supporting evidence, not represented as the final independent Security verdict.

## Blocking findings and dispositions

| Candidate | Finding | Disposition | Regression |
|---|---|---|---|
| `061de47` | A description-only `mise.toml` edit broke the governed dependency digest; public status pages were stale | Restored `mise.toml` byte-for-byte to the approved freeze, kept live status in RUN docs, and reconciled both public status pages | Exact dependency policy plus full CI |
| `c77cf19` | Production raw Site Host plus forwarded apex could cross the host boundary | Added always-on `HostIdentityGuard` before production routing/static | Production subprocess probes for health, Invitation, static, and Producer API |
| `df3b5bf` | Valid Site 404s returned a frozen header Hash through SSL; Vite and Guard duplicated/diverged on forwarded-host parsing | Added one shared `HostIdentity` resolver, mutable static denials, matching Site/Site production coverage, and actual development Vite coverage | Production SSL and development Vite subprocess tests |
| `af0a0c4` | Five custom 404 boundaries violated Rack 3 header mutability and/or lowercase-name requirements | Added `RackResponses.not_found`; routed Guard, Vite, static, HostAuthorization, and Site health fallback through it | Rack::Lint for all five boundaries plus independent mutable-response test |
| final docs | Evidence named the pre-repair SHA and middleware order | Reconciled verification, RUN, README, review identities, final gates, and merge-ready tree in the post-review evidence commit | Docs lint, dependency policy, diff/status; final code tree already reviewed and clean-rehearsed |

Earlier implementation findings—HostAuthorization, locator-path redaction, Site-host health/static/Vite isolation, Blob verification timing, Manifest consistency, stable identities, strict CLI output, secret scanning, and harness cleanup—were repaired before the final fixed-SHA sequence and remain covered by the full suite.

## Controller verification

Against exact code candidate `0fda8d4`:

- `mise exec -- bin/ci` passed in 15.93 seconds;
- Rails passed 106 tests / 1,151 assertions;
- `mise run walking-skeleton` passed;
- governed dependency diff, worktree status, and `git diff --check` were clean.

Against detached clean merge-ready tree `055d448`:

- `mise exec -- bin/ci` passed in 23.52 seconds with the same Rails count and all Go packages;
- `mise run walking-skeleton` passed;
- status, diff, and temporary-residue checks were clean;
- the disposable database/worktree was stopped and removed.

## Scope disposition

R2 storage, full multi-file Bundle serving, Release history/rollback, Owner passkeys and remote CLI authorization, Shelf management, production Invitation lifecycle/rate limits, offline copies, feedback, receipts, deletion, deployment, release artifacts, and terminal security/readiness remain assigned to later tickets. They are not T01 promotion blockers.

The fresh Security reviewer recorded one nonblocking harness note: the fixed synthetic tracer appends redacted Site/Blob/path metadata to ignored `log/test.log` outside its private temporary workspace. It observed no bearer, Invitation locator/secret, handoff, or Bundle body. Later cleanup hardening should route tracer logging to `File::NULL` or its mode-`0700` workspace and assert no external log delta.

## Harvest result

No shared-factory file changes are made for ticket #2. Four candidates are retained in [`phase2-verification.md`](phase2-verification.md): reserved multi-label `.localhost` browser tracing, exact secret-bearing CLI output protocols, real production/development host-identity probes, and Rack::Lint for custom Rack tuples. The post-integration controller decision is to wait for a second demonstrated use or terminal harvest before changing `agents/`.
