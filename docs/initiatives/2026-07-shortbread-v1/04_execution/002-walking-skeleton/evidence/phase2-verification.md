# Phase-two walking-skeleton verification

## Fixed implementation target

- Issue: `ZempTime/shortbread#2` / local T01
- Promotion baseline: `606a94f` (`Freeze bootstrap and promote walking skeleton`)
- Fixed implementation SHA: `5635586` (`Complete private publish invitation tracer`)
- Dependency phase: independently approved at `3c40a67`
- Dependency disposition: no dependency/tool version, source, inventory, or lock entry changed in Phase 2

The implementation checkpoint delivers the thinnest durable publish → Invitation → explicit acceptance → private Site path. A built Go CLI creates the Site, Person, Grant, publish plan, Blob, immutable Release, and Invitation; a real Chrome session previews without consuming, explicitly accepts, exchanges a one-use host-bound handoff, and reads the private page through a host-only Site session.

## Acceptance mapping

| Ticket promise | Evidence at `5635586` |
|---|---|
| Durable minimum domain and storage | PostgreSQL-backed Site, Person, Grant, Invitation, Blob, Release, Manifest Entry, Publish Plan, and one-use Site Handoff records; verified mode-0600 local Blob adapter |
| Safe Producer API | Exact apex host plus fixed Bearer authentication; generic/redacted failures; idempotent plan/finalize; contradictory digest/size, stale plan, missing Blob, and finalize races fail closed |
| Safe real CLI | Built Go binary creates records and publishes one Bundle; traversal, symlink, reserved, case/Unicode collision, `.env`, and key-like files are rejected before network access |
| Preview-safe Invitation | GET/HEAD do not mutate; fragment secret stays client-side; only an explicit POST can consume; expiry, revocation, replay, wrong audience, and concurrency are covered |
| Private Site | Exact `<slug>.sites.<apex>` routing, encrypted host-bound session cookie, active-Grant recheck, authenticated verified Blob open before 200 headers, and generic 404 denial |
| Host isolation | Unknown/deeper/malformed hosts fail before routing; apex health/static/Vite are unavailable from Site hosts; Producer mutations are apex-only; raw/forwarded-host mismatches fail closed |
| Redacted evidence boundary | Invitation link exists only in a new mode-0600 private sink, is read once and deleted by the harness, and never appears in stdout, stderr, JSON, logs, screenshots, browser diagnostics, or agent-facing output |
| Real end-to-end proof | `mise run walking-skeleton` drives built CLI → Rails API → isolated PostgreSQL → real Chrome preview/click/session → private marker, with unauthenticated HEAD and fresh-browser denial |

## Fixed gate evidence

The controller ran the following against the implementation worktree after all review repairs:

- `mise exec -- bin/ci` — passed Setup, Bootstrap, Lint, Typecheck, Security, Tests, and Build in 23.92 seconds.
- Rails — 96 tests, 1,038 assertions, zero failures/errors/skips.
- Go — all packages passed; `go test -race ./...` also passed.
- Lint — 84 Ruby files plus the 130-package browser symlink tree passed.
- Security — Bundler and browser audits found no known vulnerabilities; no ignored browser builds; strict fnox wrapper passed; Go modules verified and vetted.
- License audit — 133 Ruby gems, 170 browser packages with 40 exact/pattern-bounded native/WASM metadata exceptions, and 16 Go modules passed the frozen policy.
- Typecheck and production browser/CLI builds passed. The known Inertia transform sourcemap warning remains a non-failing upstream build warning; generated artifacts are valid.
- `mise run walking-skeleton` — returned only `Walking skeleton passed.`; repeated runs passed and left zero `sb-ws-*` workspaces.
- Development middleware order is `HostScopedViteProxy` → `HostAuthorization` → `HostScopedStatic`; production omits the Vite proxy and starts with `HostAuthorization`, SSL middleware, then `HostScopedStatic`.
- `git diff --check` passed; the ticket worktree was clean after commit.

The controller then created a detached worktree of exactly `5635586` at the deliberately short path `/private/tmp/sb2c`, trusted that byte-identical mise config, and reran:

- `mise exec -- bin/ci` — passed every stage in 27.19 seconds with the same 96 Rails tests / 1,038 assertions and all Go packages.
- `mise run walking-skeleton` — passed.
- `git status --short` and `git diff --check` — clean.
- platform temp-root residue count — zero.

An initial detached rehearsal collided with the already-running implementation-worktree PostgreSQL on the default local port. The controller stopped that known local cluster, recreated the detached worktree from the same SHA, completed the green rehearsal, removed the disposable worktree, and restored the original local cluster. No product or dependency repair was required.

## Independent review and repairs

Independent Standards reviewer `/root/phase2_standards_review` reviewed the live candidate, required repairs, then reviewed fixed code SHA `5635586`. Its code verdict is **approved with no remaining implementation blocker or should-fix finding**. The only remaining blocker was the stale/missing promotion record; this evidence and the accompanying RUN/README updates are its documentation repair.

Material findings repaired before `5635586` include:

- Site-host exposure of `/up`, `public/` files, and the pre-authorization Vite development proxy;
- contradictory SHA-256/size Manifest entries and success headers sent before verified Blob access;
- mutable Site/Grant host identities and impossible long-apex Site origins;
- black-box acceptance of stderr or extra/secret-bearing JSON fields;
- PostgreSQL cleanup that could forget a live process, platform-specific temp roots, and non-retryable private-file cleanup;
- line-wide secret-scan test exceptions and zero-file clean scans;
- missing direct coverage for valid Site-host Producer mutation denial.

An earlier independent authentication/security pass found missing production HostAuthorization and incomplete Invitation-locator path redaction. Both were repaired and covered, along with Invitation expiry/revocation/replay/races and maximum-origin bounds. A new fixed-SHA Security/Operations reviewer will re-evaluate the final documented target before integration.

Fixed-SHA Spec review and final Security/Operations review are still pending at the time of this verification record. Their named verdicts and dispositions must be added to the ticket review record before the PR merges.

## Harvest proposal

Two reusable factory improvements are proposed; neither changes `agents/` during this ticket:

1. Multi-origin local browser tracers should use a multi-label reserved `.localhost` apex, explicit browser host mapping, and a CLI transport that maps only syntactically valid `.localhost` subdomains to loopback. Bare `localhost` does not exercise real schemeful same-site behavior, and host OS resolution is inconsistent.
2. Secret-bearing CLI black-box tests should treat successful output as an exact protocol: empty stderr, exact envelope/result keys and types, fixed status/resource values, explicit arithmetic invariants, and immediate in-memory scrubbing. “JSON parsed successfully” is not sufficient redaction evidence.

The controller will decide whether to apply these to the shared factory after ticket integration, when the implementation workspace is no longer moving.
