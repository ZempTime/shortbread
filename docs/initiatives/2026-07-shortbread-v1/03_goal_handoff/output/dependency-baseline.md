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

The root `mise.toml` requires mise `2026.6.14` or newer and pins Ruby `3.4.8`, Node `24.7.0`, Go `1.26.5`, Aube `1.25.2`, fnox `1.28.0`, GoReleaser `2.17.0`, hk `1.49.0`, PostgreSQL `17.5`, and AnyCable Go `1.6.15`. It is the multi-platform artifact inventory and now exposes executable setup, database, development, test, lint, typecheck, build, security, license, and checkpoint tasks. Those tasks support POSIX systems and Windows through WSL; Windows lock entries are download coverage, not a claim of native `cmd.exe` task compatibility.

The generated `mise.lock` records 53 platform-specific download URL/checksum entries across seven target platforms. Core, Aqua, and GitHub backends are artifact-locked where upstream publishes and mise retains a compatible artifact. The asdf PostgreSQL backend cannot emit an artifact URL/checksum, Aube/hk do not publish macOS x64 artifacts at these versions, and mise's Ruby core backend does not retain its separately resolved Windows RubyInstaller entry after a normal install. Those cases remain exact version pins rather than a falsely claimed full artifact lock. Repository tasks therefore consume the lock opportunistically instead of enabling mise's all-or-nothing locked mode. AnyCable uses mise's supported GitHub backend rather than the deprecated UBI backend.

A read-only GitHub license audit on 2026-07-18 verified the direct tool/Go sources below. The bootstrap still runs a complete resolved dependency/license audit because transitive packages matter too.

| Source | License observed |
|---|---|
| [`jdx/mise`](https://github.com/jdx/mise), [`jdx/aube`](https://github.com/jdx/aube), [`jdx/fnox`](https://github.com/jdx/fnox), [`jdx/hk`](https://github.com/jdx/hk) | MIT |
| [`goreleaser/goreleaser`](https://github.com/goreleaser/goreleaser) | MIT |
| [`zalando/go-keyring`](https://github.com/zalando/go-keyring) | MIT |
| [`spf13/cobra`](https://github.com/spf13/cobra) | Apache-2.0 |

## Bootstrap compatibility adjustments

- **Brakeman omitted:** the reviewed `8.0.5` candidate declares the non-permissive [Brakeman Public Use License](https://rubygems.org/gems/brakeman/versions/8.0.5), which conflicts with Shortbread's public open-source dependency policy. An obsolete permissive-era release would not provide a current Rails 8.1 security gate, and adding a different source-available scanner would expand the approved baseline. The checkpoint security task instead combines `bundler-audit`, executable secret/proprietary/telemetry checks, and the ticket's behavioral auth/path/request tests; T13/#14 owns the later holistic hostile security audit.
- **Aube browser scaffold:** the Inertia/Vite Ruby generators do not recognize Aube as a package manager. The first tracer therefore writes the reviewed browser manifest directly, resolves `aube-lock.yaml`, and configures Vite Ruby to execute `node_modules/.bin/vite`; it does not introduce an npm, Yarn, pnpm, or Bun lockfile.
- **Tool artifact locking:** GoReleaser is pinned now, before T11 adds release configuration. AnyCable moved from mise's deprecated UBI backend to its GitHub backend so all seven target artifacts have lockfile URLs and checksums; unlike the Aqua-backed tools and fnox, this backend did not record a provenance-attestation field. PostgreSQL retains the registry's asdf backend and its documented artifact-lock limitation.
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
