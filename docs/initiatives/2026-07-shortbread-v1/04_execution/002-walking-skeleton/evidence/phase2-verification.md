# Phase-two walking-skeleton verification

## Fixed implementation target

- Issue: `ZempTime/shortbread#2` / local T01
- Promotion baseline: `606a94f` (`Freeze bootstrap and promote walking skeleton`)
- Fixed reviewed code SHA: `0fda8d4f9ff2bcbc7919a39b142860796d792be8`
- Merge-ready tree: `055d448fad5f93dc41de0af930aadbac5870e56c`, tree-identical to `0fda8d4` and containing current `main`
- Dependency phase: independently approved at `3c40a67`
- Dependency disposition: no dependency/tool version, source, inventory, lock entry, or governed manifest digest changed in Phase 2

The candidate delivers the thinnest durable publish → Invitation → explicit acceptance → private Site path. A built Go CLI creates the Site, Person, Grant, publish plan, Blob, immutable Release, and Invitation; a real Chrome session previews without consuming, explicitly accepts, exchanges a one-use host-bound handoff, and reads the private page through a host-only Site session.

## Acceptance mapping

| Ticket promise | Evidence at `0fda8d4` |
|---|---|
| Durable minimum domain and storage | PostgreSQL-backed Site, Person, Grant, Invitation, Blob, Release, Manifest Entry, Publish Plan, and one-use Site Handoff records; verified mode-`0600` local Blob adapter |
| Safe Producer API | Exact apex host plus fixed Bearer authentication; generic/redacted failures; idempotent plan/finalize; contradictory digest/size, stale plan, missing Blob, and finalize races fail closed |
| Safe real CLI | Built Go binary creates records and publishes one Bundle; traversal, symlink, reserved, case/Unicode collision, `.env`, and key-like files are rejected before network access |
| Preview-safe Invitation | GET/HEAD do not mutate; fragment secret stays client-side; only an explicit POST can consume; expiry, revocation, replay, wrong audience, and concurrency are covered |
| Private Site | Exact `<slug>.sites.<apex>` routing, encrypted host-bound session cookie, active-Grant recheck, authenticated verified Blob open before 200 headers, and generic 404 denial |
| Host isolation | One shared resolver independently validates raw and effective forwarded host identity; unknown, deeper, malformed, confused, empty, and trailing-comma authorities fail before Vite/routing/static; Producer mutations are apex-only |
| Rack boundary | Every custom blank-404 boundary uses one Rack 3-conformant response seam with fresh mutable lowercase headers; Rack::Lint covers Guard, Vite, static, HostAuthorization, and Site health fallback |
| Redacted evidence boundary | Invitation link exists only in a new mode-`0600` private sink, is read once and deleted by the harness, and never appears in stdout, stderr, JSON, logs, screenshots, browser diagnostics, or agent-facing output |
| Real end-to-end proof | `mise run walking-skeleton` drives built CLI → Rails API → isolated PostgreSQL → real Chrome preview/click/session → private marker, with unauthenticated HEAD and fresh-browser denial |

## Final gate evidence

The controller ran the following against exact reviewed code candidate `0fda8d4` after all blocking repairs:

- `mise exec -- bin/ci` — passed Setup, Bootstrap, Lint, Typecheck, Security, Tests, and Build in 15.93 seconds.
- Rails — 106 tests, 1,151 assertions, zero failures/errors/skips.
- Lint — 91 Ruby files plus the 130-package browser symlink tree passed.
- Security — Ruby and browser advisory audits, dependency policy, secret scan, license audit, Go module verification, and vet passed.
- License audit — 133 Ruby gems, 170 browser packages with 40 exact/pattern-bounded native/WASM metadata exceptions, and 16 Go modules passed the frozen policy.
- Typecheck and production browser/CLI builds passed. The known Inertia transform sourcemap warning remains a non-failing upstream build warning; generated artifacts are valid.
- Focused host/Rack replay — 17 tests / 172 assertions passed before commit; independent Standards/Spec replay later passed 30 / 376. Fresh Security/Operations replay passed focused Rails 92 / 1,104, full Rails 106 / 1,151, black-box contract 5 / 19, and a delegated CLI/Blob slice of 31 / 383 plus Go internal race tests.
- `mise run walking-skeleton` — returned only `Walking skeleton passed.`.
- Earlier Go-specific final implementation verification ran all packages plus `go test -race ./...`; no Go file changed during the later Ruby middleware repairs.
- `git diff --check`, governed-dependency comparison, worktree status, and temporary tracer-residue checks were clean.

Final middleware order is:

- development: `HostScopedViteProxy` → `HostIdentityGuard` → `HostAuthorization` → `HostScopedStatic`; both outer host modules call the same `HostIdentity` resolver, so malformed/confused forwarded authorities fail before Vite forwards;
- production: `HostIdentityGuard` → `HostAuthorization` → `AssumeSSL` → `SSL` → `HostScopedStatic`.

The controller then created a detached worktree of merge-ready tree `055d448` at `/private/tmp/sb2f`, trusted its byte-identical mise config, and ran:

- `mise exec -- bin/ci` — passed every stage in 23.52 seconds with 106 Rails tests / 1,151 assertions and all Go packages;
- `mise run walking-skeleton` — passed;
- `git status --short`, `git diff --check`, and platform `sb-ws-*` residue scan — clean.

The controller stopped and removed the detached worktree's PostgreSQL cluster/worktree, then restored the ticket worktree's local cluster. No disposable `sb2f` worktree remains.

## Independent review and repair history

The durable final verdicts and finding dispositions are in [`review-phase2.md`](review-phase2.md). Independent reviewer identities are:

- Standards + final Spec: `/root/phase2_standards_review`;
- Security/Operations: `/root/phase2_standards_review/fresh_security_review`.

Both final reviewers approved exact code candidate `0fda8d4` with no remaining blocker or should-fix. The merge-ready `055d448` tree is byte-identical to that reviewed code candidate. `/root/repair_phase2_rails` found and replayed important host/Rack defects but authored an earlier pre-`5635586` Vite repair, so its later 25 / 368 security replay remains supporting evidence rather than the final independent verdict.

Material findings repaired across Phase 2 include:

- Site-host exposure of `/up`, public files, and the development Vite proxy;
- missing production HostAuthorization, incomplete Invitation-locator path redaction, and production raw/effective-forwarded host confusion;
- parser divergence that let malformed forwarded hosts reach the outer Vite proxy;
- frozen/uppercase custom Rack headers that failed through production SSL or violated Rack 3;
- contradictory SHA-256/size Manifest entries and success headers sent before verified Blob access;
- mutable Site/Grant host identities and impossible long-apex Site origins;
- black-box acceptance of stderr or extra/secret-bearing JSON fields;
- PostgreSQL cleanup that could forget a live process, platform-specific temp roots, and non-retryable private-file cleanup;
- line-wide secret-scan test exceptions, zero-file clean scans, and missing direct Site-host Producer denial coverage.

Invitation expiry/revocation/replay/races, maximum-origin bounds, matching proxy-port translation, valid Site denials through production SSL, and all five custom Rack response boundaries now have direct regression coverage.

The fresh Security reviewer recorded one nonblocking operations note: the fixed synthetic tracer can append redacted Site/Blob/path request and SQL metadata to ignored `log/test.log`, outside its mode-`0700` workspace. It observed no bearer, Invitation locator/secret, handoff, or Bundle body. A later harness cleanup should route that logger to `File::NULL` or the private workspace and assert no external log delta.

## Harvest proposal

Four reusable factory improvements are proposed; none changes `agents/` before ticket integration:

1. Multi-origin local browser tracers should use a multi-label reserved `.localhost` apex, explicit browser host mapping, and a CLI transport that maps only syntactically valid `.localhost` subdomains to loopback.
2. Secret-bearing CLI black-box tests should treat successful output as an exact protocol: empty stderr, exact envelope/result keys and types, fixed status/resource values, explicit arithmetic invariants, and immediate in-memory scrubbing.
3. Host-bound applications need actual production- and development-stack raw/effective-forwarded-host regressions; a development-only proxy guard can mask the production boundary.
4. Every custom Rack middleware or endpoint tuple should be exercised through `Rack::Lint`, including header mutability and lowercase-name requirements.

Post-integration decision: retain these candidates in ticket evidence without changing `agents/` yet. A second demonstrated use or the terminal harvest can promote them into the shared factory with stronger evidence than one tracer.
