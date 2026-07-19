# Dependency Baseline for Controller Approval

Starting the persistent goal approves this baseline. The first tracer must scaffold it, resolve and commit lockfiles, run license/security checks, and record any compatibility adjustment before feature work fans out. Dependency manifests, lockfiles, and central tool pins are exclusive controller edit surfaces.

Versions below are the reviewed starting constraints/resolutions from the generic template snapshot on 2026-07-18. The controller may make a compatibility adjustment only inside the dependency-bootstrap checkpoint, with the resolved lockfile diff and audit recorded; after that, lockfiles are authoritative and frozen.

## Ruby application

| Package | Manifest constraint → reviewed start | Purpose |
|---|---|---|
| `rails` | `~> 8.1.3` → `8.1.3` | Web application and HTTP API |
| `pg` | `~> 1.1` → `1.6.3` | PostgreSQL adapter |
| `pitchfork` | `~> 0.18` → `0.18.2` | Production HTTP server |
| `anycable-rails-core` | `~> 1.6` → `1.6.2` | Self-hosted real-time Feedback Thread transport |
| `webauthn` | `~> 3.4` → `3.4.3` | Owner and optional Viewer passkeys |
| `bootsnap` | `~> 1.24` → `1.24.6` | Boot caching |
| `aws-sdk-s3` | `~> 1.226` → `1.226.0` | Private R2/S3 Blob operations and presigning |
| `solid_queue` | `~> 1.2` → `1.4.0` | Background cleanup and durable jobs |
| `inertia_rails` | `~> 3.21` → `3.21.2` | Rails/Inertia adapter |
| `vite_rails` | `~> 3.11` → `3.11.0` | Frontend build integration |
| `tzinfo-data` | platform-scoped; resolve/lock at bootstrap | Windows/JRuby timezone data for contributors |

Development/test starting resolutions: `debug 1.11.1`, `bundler-audit 0.9.3`, `rubocop-rails-omakase 1.1.0`, `web-console 4.3.0`, `capybara 3.40.0`, `minitest-mock 5.27.0`, `selenium-webdriver 4.45.0`, and test-only `puma 8.0.2`. Their manifest constraints and all transitive/platform resolutions are written and reviewed in the bootstrap commit rather than silently inherited.

## Browser application

| Package group | Starting constraints | Purpose |
|---|---|---|
| React | `react` / `react-dom` `^19.2.7` | Inertia UI |
| Inertia | `@inertiajs/core`, `@inertiajs/react`, `@inertiajs/vite` `^3.6.0` | Server-driven React navigation |
| AnyCable | `@anycable/core ^1.1.6`, `@anycable/web ^1.1.1` | Live Feedback Thread updates |
| Tailwind/shadcn foundation | `tailwindcss ^4.3.2`, `@tailwindcss/vite ^4.3.2`, `radix-ui ^1.6.1`, `class-variance-authority ^0.7.1`, `clsx ^2.1.1`, `tailwind-merge ^3.6.0`, `tw-animate-css ^1.4.0`, `lucide-react ^1.23.0` | UI primitives and component source |
| Vite | `vite ^8.1.3`, `@vitejs/plugin-react ^6.0.3`, `vite-plugin-ruby ^5.2.2` | Asset build and development server |
| TypeScript | `typescript ^6.0.3`, `@types/node ^26.1.0`, `@types/react ^19.2.17`, `@types/react-dom ^19.2.3` | Static checking |

The custom service worker uses browser Cache and Fetch APIs rather than adding a PWA framework. Rails system tests with Selenium cover browser behavior, so no separate JavaScript test runner is part of the baseline.

## Go CLI

| Package | Starting constraint | Purpose |
|---|---:|---|
| Go toolchain | `1.26.5` | Reproducible CLI build; patched from the reviewed `1.26.2` start during bootstrap audit |
| `github.com/spf13/cobra` | `v1.10.2` | Stable command tree and help contract |
| `github.com/zalando/go-keyring` | `v0.2.8` | OS credential-store integration for interactive login |

HTTP, JSON, hashing, file walking, retries, browser launch, setup prompts, provider APIs, and tests use the Go standard library unless implementation evidence justifies an exception. Release tooling starts at GoReleaser `v2.17.0` without linking it into the CLI.

## Toolchain

The root `mise.toml` requires mise `2026.7.1` or newer; the controller host currently has the audited `2026.7.7` release installed. It pins Ruby `3.4.10`, Node `24.18.0`, Go `1.26.5`, Aube `1.29.1`, fnox `1.28.0`, GoReleaser `2.17.0`, hk `1.49.0`, PostgreSQL `17.10`, and AnyCable Go `1.6.15`. It is the multi-platform artifact inventory and exposes executable setup, database, development, test, lint, typecheck, build, security, license, and checkpoint tasks.

Only macOS arm64 has been exercised by this checkpoint. Records for Linux, macOS x64, and Windows in `mise.lock` are an artifact inventory, not verified support for those targets; in particular, native Windows `cmd.exe` execution has not been tested. The asdf PostgreSQL backend cannot emit an artifact URL/checksum, some upstream releases omit some target artifacts, and mise's Ruby core backend may not retain a separately resolved Windows RubyInstaller entry after a normal install. Those cases remain exact version pins rather than a falsely claimed full artifact lock. Repository tasks therefore consume the lock opportunistically instead of enabling mise's all-or-nothing locked mode. AnyCable uses mise's supported GitHub backend rather than the deprecated UBI backend.

The repaired lock contains 54 checksum-bearing platform records and 20 GitHub-attestation records. The extra checksum record relative to the pre-review lock is the retained Windows RubyInstaller artifact for Ruby 3.4.10. Aube 1.29.1 still has no macOS x64 artifact, while hk 1.49.0 likewise has no macOS x64 artifact.

A read-only GitHub license audit on 2026-07-18 verified the direct tool/Go sources below. The bootstrap still runs a complete resolved dependency/license audit because transitive packages matter too.

| Source | License observed |
|---|---|
| [`jdx/mise`](https://github.com/jdx/mise), [`jdx/aube`](https://github.com/jdx/aube), [`jdx/fnox`](https://github.com/jdx/fnox), [`jdx/hk`](https://github.com/jdx/hk) | MIT |
| [`goreleaser/goreleaser`](https://github.com/goreleaser/goreleaser) | MIT |
| [`zalando/go-keyring`](https://github.com/zalando/go-keyring) | MIT |
| [`spf13/cobra`](https://github.com/spf13/cobra) | Apache-2.0 |

## Bootstrap compatibility adjustments

- **Security patch alignment:** review rejected Ruby `3.4.8`, Node `24.7.0`, PostgreSQL `17.5`, and mise `2026.6.14`. The repair pins Ruby `3.4.10` after the official [Ruby zlib CVE-2026-27820 advisory](https://www.ruby-lang.org/en/news/2026/03/05/buffer-overflow-zlib-cve-2026-27820/) and confirms the selected patch against the [Ruby releases index](https://www.ruby-lang.org/en/downloads/releases/); Node `24.18.0` is the reviewed current LTS [release](https://nodejs.org/en/blog/release/v24.18.0) and follows the [June 2026 security release](https://nodejs.org/en/blog/vulnerability/june-2026-security-releases); PostgreSQL `17.10` incorporates the 17.x fixes listed by the official [security page](https://www.postgresql.org/support/security/17/) and [17.10 release notes](https://www.postgresql.org/docs/17/release-17-10.html); and mise now requires at least `2026.7.1`, the fixed release for [GHSA-9mm4-fgvc-x7rp](https://github.com/advisories/GHSA-9mm4-fgvc-x7rp). The audited controller installation is mise `2026.7.7`.
- **Tool security and telemetry fixes:** Aube is pinned to `1.29.1`, whose [release](https://github.com/jdx/aube/releases/tag/v1.29.1) fixes the security-relevant `minimumReleaseAge` behavior. AnyCable Go remains at `1.6.15`, which is outside the affected range for [GHSA-w72w-9qmj-c9qm](https://github.com/advisories/GHSA-w72w-9qmj-c9qm) and [GHSA-5p54-whvp-x327](https://github.com/advisories/GHSA-5p54-whvp-x327). The checked-in mise settings also set `use_versions_host_track = false`; mise documents that its default would [send anonymous tool-install statistics](https://mise.jdx.dev/configuration/settings.html#use-versions-host-track), which this initiative's no-telemetry contract forbids.
- **mise residual advisory:** mise `2026.7.7` still carries `quick-xml` versions below `0.41.0`, covered by [RUSTSEC-2026-0194](https://rustsec.org/advisories/RUSTSEC-2026-0194.html) and [RUSTSEC-2026-0195](https://rustsec.org/advisories/RUSTSEC-2026-0195.html); mise's [2026.7.0 release notes](https://github.com/jdx/mise/releases/tag/v2026.7.0) record those advisories as pending upstream, and no clean mise release existed at this checkpoint. The accepted reachability exception is limited to the repository's public tasks: they do not invoke mise self-update or Conda/rattler paths and do not supply untrusted XML to mise. This is a known bootstrap-tool residual, not a claim that the installed mise binary is advisory-free.
- **Development transport hardening:** the scaffold replaces the Action Cable JWT meta tag—which would put a bearer token in a query string—with the ordinary URL-only Action Cable meta tag. AnyCable access logging is disabled, debug logging is disabled, and Pitchfork binds to `127.0.0.1` by default with an explicit host override. Browser-ready non-query authentication is deferred to the authentication tracer rather than freezing a query-token seam in the skeleton.
- **Brakeman omitted:** the reviewed `8.0.5` candidate declares the non-permissive [Brakeman Public Use License](https://rubygems.org/gems/brakeman/versions/8.0.5), which conflicts with Shortbread's public open-source dependency policy. An obsolete permissive-era release would not provide a current Rails 8.1 security gate, and adding a different source-available scanner would expand the approved baseline. The checkpoint security task instead combines `bundler-audit`, executable secret/proprietary/telemetry checks, and the ticket's behavioral auth/path/request tests; T13/#14 owns the later holistic hostile security audit.
- **Aube browser scaffold:** the Inertia/Vite Ruby generators do not recognize Aube as a package manager. The first tracer therefore writes the reviewed browser manifest directly, resolves `aube-lock.yaml`, and configures Vite Ruby to execute `node_modules/.bin/vite`; it does not introduce an npm, Yarn, pnpm, or Bun lockfile.
- **Tool artifact locking:** GoReleaser is pinned now, before T11 adds release configuration. AnyCable moved from mise's deprecated UBI backend to its GitHub backend; the repaired lock records seven target checksums over five distinct release assets and no provenance-attestation field. PostgreSQL retains the registry's asdf backend and its documented artifact-lock limitation.
- **Go patch update:** the reviewed Go `1.26.2` start had 13 module-level standard-library advisories in the 2026-07-08 Go vulnerability database, with fixes spread across `1.26.3`–`1.26.5`. The bootstrap therefore pins `1.26.5`; the controller rescans the rebuilt graph before dependency freeze.
- **Go vulnerability audit:** current `govulncheck v1.6.0` imports Go telemetry and starts local crash/counter collection, so it is not a committed tool or recurring task under this initiative's literal no-telemetry rule. The controller runs the exact pinned scanner once from an ephemeral directory with telemetry startup disabled, records the reachable and module-level results in checkpoint evidence, and repeats that external audit at T13 and T16. `go vet` remains static analysis and is not represented as vulnerability scanning.

## Remote CLI profile and authentication contract

The CLI is a client of a deployed Shortbread apex, not a localhost-only administration script.

- `shortbread login --server https://shortbread.example.com [--profile name]` requests a short-lived CLI authorization from that instance and opens its verification URL/user code in the system browser. Its high-entropy device code is a one-use, short-lived bearer secret held only by the initiating CLI, never shown in the URL/output/log, and bound to a CLI-generated proof key when the protocol permits.
- The Owner authenticates to the deployed apex with the normal passkey and explicitly approves that CLI. The resulting API token is returned once, stored under the normalized server/profile in the operating-system keyring, and stored only as a one-way digest by the server.
- `shortbread whoami`, `shortbread logout`, `shortbread profiles`, and a server-side token list/revoke surface make the relationship inspectable and revocable.
- Every networked command accepts `--server`/`--profile`; non-secret `SHORTBREAD_URL` and `SHORTBREAD_PROFILE` overrides support scripts. Headless CI uses a separately minted, scoped `SHORTBREAD_TOKEN` environment value and never triggers browser login.
- HTTPS is mandatory for non-loopback servers. Tokens, device codes/proof verifiers, authorization codes, and raw Invitation secrets never appear in HTTP request paths or queries, process arguments, stdout/stderr/JSON, application or proxy logs, or captured evidence. A newly created Invitation may be delivered once as an Owner-selected bearer link: its non-authorizing locator is in the path, its secret is only in the URI fragment, and the CLI writes the complete link only to an explicitly requested owner-only secret sink. The landing page removes the fragment before submitting the secret in a redacted explicit-acceptance POST. `--json` errors remain stable and redact sensitive response bodies.
- The CLI sends its version and requested API version, rejects unsupported server compatibility clearly, and uses `/api/v1` for the v1 contract.

This flow uses Cobra, go-keyring, and the Go standard library; it does not add an OAuth SDK or hosted identity provider.

## Intentionally excluded from the template

- Sentry gems, browser SDK, and Vite plugin: the accepted trust contract forbids optional third-party product-data processing and telemetry.
- Active Storage browser packages and image processing: Shortbread has a purpose-built content-addressed Blob/Manifest flow and no v1 image-variant feature.
- Password, email, SMS, analytics, CMS, native-app, or hosted proprietary SDKs.
- A generic PWA/service-worker package: release-pinned atomic offline behavior is a product invariant and receives its own small implementation and browser harness.

## Exception rule after bootstrap

A worker may propose but may not edit a dependency manifest. The controller may approve an exception only when accepted behavior cannot be implemented safely with the standard library or baseline. The isolated dependency change must record:

1. the missing capability and alternatives considered;
2. license and proprietary-service audit;
3. maintenance, security, transitive dependency, and install/build-script review;
4. compatibility and lockfile diff;
5. targeted and full verification.

Small shadcn components are committed source. They bypass this exception only when they use existing packages; otherwise their package requirement follows the same rule.
