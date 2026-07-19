# Bootstrap green checkpoint

Observed on 2026-07-19 from the ticket worktree on macOS arm64. Product routes and records were still absent; this checkpoint exercises only the dependency/bootstrap seams. Review required runtime, package-manager, and development-transport repairs after commit `914ddd6`; fresh post-repair evidence is recorded first, followed by the explicitly historical pre-review baseline.

## Post-repair repository-only tool resolution

```text
$ MISE_GLOBAL_CONFIG_FILE=/dev/null mise install
mise all tools are installed
exit 0
```

The repaired inventory is mise 2026.7.7 (repository minimum 2026.7.1), Ruby 3.4.10, Node 24.18.0, Go 1.26.5, Aube 1.29.1, fnox 1.28.0, GoReleaser 2.17.0, hk 1.49.0, PostgreSQL 17.10, and AnyCable Go 1.6.15. Ruby reported zlib gem 3.2.3. The normalized `mise.lock` remained byte-identical after installation and contains 54 checksum records and 20 GitHub-attestation records.

## Post-repair frozen setup

```text
$ mise run setup
== Verifying approved dependency inventory ==
Dependency policy: approved frozen inventory exact; denylisted identifiers absent; AnyCable dev exception exact
Toolchain: Ruby 3.4.10; Bundler 2.6.9
Bundle complete! 19 Gemfile dependencies, 133 gems now installed.
aube 1.29.1 ... resolved 130 packages
PostgreSQL 17.10 server started; application databases prepared
exit 0
```

The exact-inventory gate ran before Bundler, Aube, or Go could install or execute dependency build hooks. Bundler used frozen mode, Aube used its frozen lock, and Go module download remained `-mod=readonly` with pre/post lock digests equal.

## Post-repair public verification seams

```text
$ mise run test
1 runs, 1 assertions, 0 failures, 0 errors, 0 skips
ok github.com/ZempTime/shortbread/cli
exit 0

$ mise run lint
27 files inspected, no offenses detected
node_modules symlink tree is consistent (checked 130 packages).
exit 0

$ mise run typecheck
exit 0

$ mise run build
vite v8.1.5 ... 547 modules transformed ... built
Go CLI build exit 0

$ mise run bootstrap-check
Rails boot: 8.1.3; Solid Queue: queue
AnyCable config: green
vite v8.1.5 ... 547 modules transformed ... built
ok github.com/ZempTime/shortbread/cli
Bootstrap seams: green
exit 0

$ mise run security
ruby-advisory-db: 1224 advisories at 22dbb971f836ca61dc91d58613be1938fde502c9
No vulnerabilities found
No known vulnerabilities found
No ignored builds.
License audit: 133 Ruby gems; 170 browser packages; 16 Go modules
Dependency policy: approved frozen inventory exact; denylisted identifiers absent; AnyCable dev exception exact
all modules verified
exit 0

$ mise run licenses
License audit: 133 Ruby gems; 170 browser packages; 16 Go modules
exit 0
```

The license command's full output additionally records 40 exact/pattern-bounded native/WASM metadata exceptions. The Vite builds reported the same non-fatal `@inertiajs/vite` source-map warning as the pre-review build.

Finally, `mise exec -- bin/ci` exercised the checked-in composition—Setup, Bootstrap, Lint, Typecheck, Security, Tests, and Build—and all seven steps passed in 15.53 seconds.

The URL-only Action Cable helper was rendered directly through Rails and produced `<meta name="action-cable-url" content="ws://localhost:8080/cable" />`; an assertion rejected `jid`, JWT, or token query parameters.

## Post-repair development stack smoke

`mise run dev` started Rails/Pitchfork, Vite, Solid Queue, and AnyCable together. The retained probes were:

```text
$ curl ... http://127.0.0.1:3000/up
Rails /up HTTP 200
$ curl ... http://localhost:3036/vite-dev/@vite/client
Vite client via localhost HTTP 200
$ curl ... http://127.0.0.1:8080/health
AnyCable /health HTTP 200

$ lsof -nP -a -iTCP:3000 -sTCP:LISTEN
Pitchfork monitor/workers: 127.0.0.1:3000 only
$ lsof -nP -a -iTCP:3036 -sTCP:LISTEN
Vite: [::1]:3036 only
$ lsof -nP -a -iTCP:8080 -sTCP:LISTEN
AnyCable: 127.0.0.1:8080 only
```

Process inspection showed the Solid Queue fork supervisor plus its dispatcher and worker alive alongside Pitchfork, Vite, and AnyCable. After an interrupt was sent only to the unified development session, every captured development PID was absent and listeners 3000, 3036, and 8080 had closed. Repository-local PostgreSQL was deliberately left running and `pg_isready` still reported that it accepted connections.

## Pre-review repository-only tool resolution

```text
$ MISE_GLOBAL_CONFIG_FILE=/dev/null mise install
mise all tools are installed
exit 0
```

The pre-review resolved inventory was Ruby 3.4.8, Node 24.7.0, Go 1.26.5, Aube 1.25.2, fnox 1.28.0, GoReleaser 2.17.0, hk 1.49.0, PostgreSQL 17.5, and AnyCable Go 1.6.15.

## Current repair pins

The repaired manifests now require mise `2026.7.1` or newer and pin Ruby `3.4.10`, Node `24.18.0`, Go `1.26.5`, Aube `1.29.1`, fnox `1.28.0`, GoReleaser `2.17.0`, hk `1.49.0`, PostgreSQL `17.10`, and AnyCable Go `1.6.15`. The controller host's installed and audited mise is `2026.7.7`.

These pins received the post-repair installation and checkpoint rerun above. Only macOS arm64 was exercised; lock entries for other targets are artifact inventory, not a portability or support claim.

## Pre-review frozen setup

```text
$ mise run setup
Toolchain: Ruby 3.4.8; Bundler 2.6.9
The Gemfile's dependencies are satisfied
aube 1.25.2 ... installed 130 packages
Created database 'shortbread_development'
Created database 'shortbread_development_queue'
Created database 'shortbread_test'
exit 0
```

`bin/setup` enforced the committed Bundler and Aube locks, downloaded Go modules with `-mod=readonly`, proved that `cli/go.mod` and `cli/go.sum` did not change, and prepared repository-local PostgreSQL. Aube emitted its documented global-virtual-store compatibility warning for Vite; it installed the frozen graph successfully.

## Pre-review public verification seams

```text
$ mise run test
1 runs, 1 assertions, 0 failures, 0 errors, 0 skips
ok github.com/ZempTime/shortbread/cli
exit 0

$ mise run lint
27 files inspected, no offenses detected
node_modules symlink tree is consistent (checked 130 packages).
exit 0

$ mise run typecheck
exit 0

$ mise run build
vite v8.1.5 ... 547 modules transformed ... built
Go CLI build exit 0

$ mise run bootstrap-check
Rails boot: 8.1.3; Solid Queue: queue
AnyCable config: green
vite v8.1.5 ... 547 modules transformed ... built
ok github.com/ZempTime/shortbread/cli
Bootstrap seams: green
exit 0
```

The Vite build reported a non-fatal source-map warning from `@inertiajs/vite`; production assets and their manifest were emitted successfully. The bootstrap check also proved the Solid Queue schema on its isolated database, parsed the checked-in AnyCable Go configuration, built the real Go binary, and invoked its help boundary.

## Pre-review development stack smoke

After removing Unicorn's unsupported `preload_app` directive from the Pitchfork configuration, the pre-review public development task brought up all four processes concurrently:

```text
$ ANYCABLE_DEBUG=false ANYCABLE_LOG_LEVEL=info mise run dev
Rails /up (127.0.0.1:3000): HTTP 200
Vite client ([::1]:3036): HTTP 200
AnyCable /health (127.0.0.1:8080): HTTP 200
Solid Queue supervisor/dispatcher/worker: alive
```

The smoke harness sent an interrupt to only that development session and confirmed that its listeners and child processes were gone afterward. Repository-local PostgreSQL remained running.

## Review repair disposition

- Ruby, Node, PostgreSQL, mise, and Aube moved to the repaired pins listed above. The version choices and advisory dispositions are recorded in [`dependency-audit.md`](dependency-audit.md).
- `bin/setup` now runs the exact dependency-policy gate before invoking Bundler, Aube, or Go dependency installation. The public CI sequence now invokes `mise run bootstrap-check` after setup.
- The Action Cable JWT meta helper was removed so the scaffold does not create a bearer-token query string. Browser authentication remains deferred until a non-query transport is implemented.
- AnyCable access logging is disabled and its checked-in configuration disables debug logging.
- Pitchfork now binds to `127.0.0.1` by default, with `PITCHFORK_HOST` as an explicit override.

The post-repair clean install, exact-version probes, lock counts, setup, public gates, security scan, license scan, URL-only cable-meta assertion, and development listener/process/teardown smoke all passed.

Security, vulnerability, license, install-script, and compatibility evidence is recorded separately in [`dependency-audit.md`](dependency-audit.md).
