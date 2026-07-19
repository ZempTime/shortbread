# Bootstrap green checkpoint

Observed on 2026-07-19 from the ticket worktree on macOS arm64. Product routes and records were still absent; this checkpoint exercises only the dependency/bootstrap seams.

## Repository-only tool resolution

```text
$ MISE_GLOBAL_CONFIG_FILE=/dev/null mise install
mise all tools are installed
exit 0
```

The resolved project inventory was Ruby 3.4.8, Node 24.7.0, Go 1.26.5, Aube 1.25.2, fnox 1.28.0, GoReleaser 2.17.0, hk 1.49.0, PostgreSQL 17.5, and AnyCable Go 1.6.15.

## Frozen setup

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

## Public verification seams

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

## Development stack smoke

After removing Unicorn's unsupported `preload_app` directive from the Pitchfork configuration, the public development task brought up all four processes concurrently:

```text
$ ANYCABLE_DEBUG=false ANYCABLE_LOG_LEVEL=info mise run dev
Rails /up (127.0.0.1:3000): HTTP 200
Vite client ([::1]:3036): HTTP 200
AnyCable /health (127.0.0.1:8080): HTTP 200
Solid Queue supervisor/dispatcher/worker: alive
```

The smoke harness sent an interrupt to only that development session and confirmed that its listeners and child processes were gone afterward. Repository-local PostgreSQL remained running.

Security, vulnerability, license, install-script, and compatibility evidence is recorded separately in [`dependency-audit.md`](dependency-audit.md).
