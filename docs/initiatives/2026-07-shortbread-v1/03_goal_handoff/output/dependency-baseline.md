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

Development/test starting resolutions: `debug 1.11.1`, `bundler-audit 0.9.3`, `brakeman 8.0.5`, `rubocop-rails-omakase 1.1.0`, `web-console 4.3.0`, `capybara 3.40.0`, `minitest-mock 5.27.0`, `selenium-webdriver 4.45.0`, and test-only `puma 8.0.2`. Their manifest constraints and all transitive/platform resolutions are written and reviewed in the bootstrap commit rather than silently inherited.

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
| Go toolchain | `1.26.2` | Reproducible CLI build |
| `github.com/spf13/cobra` | `v1.10.2` | Stable command tree and help contract |
| `github.com/zalando/go-keyring` | `v0.2.8` | OS credential-store integration for interactive login |

HTTP, JSON, hashing, file walking, retries, browser launch, setup prompts, provider APIs, and tests use the Go standard library unless implementation evidence justifies an exception. Release tooling starts at GoReleaser `v2.17.0` without linking it into the CLI.

## Toolchain

The root `mise.toml` now pins Ruby `3.4.8`, Node `24.7.0`, Go `1.26.2`, Aube `1.25.2`, fnox `1.28.0`, hk `1.49.0`, PostgreSQL `17.5`, and AnyCable Go `1.6.15`. It is the cross-platform tool inventory; executable tasks are added with the first tracer so they never point at nonexistent app files.

A read-only GitHub license audit on 2026-07-18 verified the direct tool/Go sources below. The bootstrap still runs a complete resolved dependency/license audit because transitive packages matter too.

| Source | License observed |
|---|---|
| [`jdx/mise`](https://github.com/jdx/mise), [`jdx/aube`](https://github.com/jdx/aube), [`jdx/fnox`](https://github.com/jdx/fnox), [`jdx/hk`](https://github.com/jdx/hk) | MIT |
| [`goreleaser/goreleaser`](https://github.com/goreleaser/goreleaser) | MIT |
| [`zalando/go-keyring`](https://github.com/zalando/go-keyring) | MIT |
| [`spf13/cobra`](https://github.com/spf13/cobra) | Apache-2.0 |

## Remote CLI profile and authentication contract

The CLI is a client of a deployed Shortbread apex, not a localhost-only administration script.

- `shortbread login --server https://shortbread.example.com [--profile name]` requests a short-lived CLI authorization from that instance and opens its verification URL/user code in the system browser. Its high-entropy device code is a one-use, short-lived bearer secret held only by the initiating CLI, never shown in the URL/output/log, and bound to a CLI-generated proof key when the protocol permits.
- The Owner authenticates to the deployed apex with the normal passkey and explicitly approves that CLI. The resulting API token is returned once, stored under the normalized server/profile in the operating-system keyring, and stored only as a one-way digest by the server.
- `shortbread whoami`, `shortbread logout`, `shortbread profiles`, and a server-side token list/revoke surface make the relationship inspectable and revocable.
- Every networked command accepts `--server`/`--profile`; non-secret `SHORTBREAD_URL` and `SHORTBREAD_PROFILE` overrides support scripts. Headless CI uses a separately minted, scoped `SHORTBREAD_TOKEN` environment value and never triggers browser login.
- HTTPS is mandatory for non-loopback servers. Tokens, device codes/proof verifiers, authorization codes, Invitation values, and private Bundle content never appear in URLs, process arguments, command output, or logs. `--json` errors remain stable and redact sensitive response bodies.
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
