# Dependency freeze audit

Observed 2026-07-19 before product behavior. This is the controller's supply-chain checkpoint for the Ruby, browser, Go, and mise-resolved tool graphs.

## Frozen resolutions

- Bundler 2.6.9 resolved 133 Ruby gems with a `CHECKSUMS` entry for every locked spec. The reviewed direct starting resolutions were preserved. The lock covers 12 Ruby platforms and is authoritative for all compatible transitive selections.
- Aube 1.25.2 resolved 170 all-platform browser packages and materialized 130 host packages. `aube-lock.yaml` is the only browser lockfile; no npm, Yarn, pnpm, or Bun lock was introduced.
- The Go 1.26.5 graph contains 16 non-main modules. `go mod tidy -diff`, `go mod verify`, tests, builds, vet, setup downloads, and license enumeration all ran read-only against `cli/go.mod` and `cli/go.sum`.
- `mise.lock` contains 53 checksum-bearing platform records. The PostgreSQL asdf backend emits no artifact record, the selected Aube/hk releases omit macOS x64 artifacts, and mise does not retain its separately resolved Windows RubyInstaller record after normal installation, so locked mode is intentionally not claimed as universal.
- `script/check_dependency_policy.rb` records exact approved SHA-256 values for every governed dependency manifest and lock. The recurring gate fails on any dependency-inventory change until the controller performs the ADR 0007 exception audit and updates that approval.

## Compatibility and security adjustments

- The original Go 1.26.2 review produced 13 module-level standard-library advisories whose fixes spanned 1.26.3 through 1.26.5. The toolchain was raised to Go 1.26.5 before freeze.
- The first Ruby advisory pass found four advisory matches involving `loofah 2.25.1` and `rails-html-sanitizer 1.7.0`. Resolution was raised within the approved graph to `loofah 2.25.2` and `rails-html-sanitizer 1.7.1` before the final lock.
- Brakeman 8.0.5 was omitted because its source-available public-use license does not satisfy this project's open-source dependency rule. The recurring checkpoint uses `bundler-audit`, Aube audit/build checks, fnox secret scanning, exact dependency inventory enforcement, licenses, Go integrity/vet, and behavioral tests instead; T13 owns the later holistic hostile audit.
- The Rails/Inertia/Vite browser scaffold was written for Aube because the upstream Ruby generators do not recognize Aube as a package manager. Vite uses the checked-in Aube materialization at `node_modules/.bin/vite`.
- Pitchfork 0.18.2 removed Unicorn's `preload_app` configuration directive because Pitchfork always preloads. The inherited directive failed the full development smoke and was removed; Rails, Vite, Solid Queue, and AnyCable then ran together successfully.
- AnyCable Go moved from mise's deprecated UBI backend to the supported GitHub backend. Its seven target records map to five release assets whose SHA-256 values match GitHub's release metadata. No attestation-provenance field is present, so no provenance-attestation claim is made.

All looser manifest constraints are bounded by the committed locks and the exact-inventory gate. Any subsequent graph change is a controller-owned dependency exception, not an incidental install update.

## Vulnerability and recurring policy results

```text
$ mise run security
ruby-advisory-db: 1224 advisories
last updated: 2026-07-18 19:30:27 -0400
commit: 22dbb971f836ca61dc91d58613be1938fde502c9
No vulnerabilities found
No known vulnerabilities found
No ignored builds.
License audit: 133 Ruby gems; 170 browser packages; 16 Go modules
Dependency policy: approved frozen inventory exact; denylisted identifiers absent; AnyCable dev exception exact
all modules verified
exit 0
```

The browser license scanner sometimes obtains MIT metadata for five WASM support packages from the installed tree and sometimes reports it as `UNKNOWN` from the all-platform inventory. The policy therefore retains exact name/version fallbacks and accepts them whether fallback metadata is needed or agrees with known metadata. The remaining native/WASM exceptions are family- and version-bounded. New, removed, ambiguous, or re-versioned exceptions fail closed.

## Independent Go 1.26.5 rescan

`govulncheck v1.6.0` was built ephemerally with the pinned Go binary, isolated `/private/tmp` module/build caches, and `GO_TELEMETRY_CHILD=2`. It was not added to the repository because the scanner imports Go telemetry. The built scanner's SHA-256 was `ff234dfbcce4114bcbc915fdf8451573770a89cde9138252707bd09e89f18541`.

```text
Go: go1.26.5
Scanner: govulncheck@v1.6.0
Database: https://vuln.go.dev
Database updated: 2026-07-08 17:05:00 +0000 UTC

$ govulncheck -show version ./...
No vulnerabilities found.
exit 0

$ govulncheck -scan module -show version
No vulnerabilities found.
exit 0
```

Both commands ran from `cli/` with the isolated caches and telemetry startup disabled. This closes the earlier Go 1.26.2 module findings: zero reachable and zero module/non-reachable findings remained.

## Direct tool licenses and lock evidence

| Tool | Version | Upstream license | Lock evidence |
|---|---:|---|---|
| mise | `>= 2026.6.14` | [MIT](https://github.com/jdx/mise/blob/v2026.6.14/LICENSE) | Bootstrap prerequisite; minimum version checked by `mise.toml`, not downloaded by its own lock. |
| Ruby | `3.4.8` | [Ruby OR BSD-2-Clause](https://github.com/ruby/ruby/blob/v3_4_8/COPYING) | 6 Unix target URL/checksum entries for the ruby-lang source archive; no provenance field. The exact Windows pin is not artifact-locked. |
| Node.js | `24.7.0` | [MIT plus enumerated bundled notices](https://github.com/nodejs/node/blob/v24.7.0/LICENSE) | 7 URL/checksum entries; no provenance field. Linux x64 musl uses community unofficial builds; Linux arm64 musl builds from source. |
| Go | `1.26.5` | [BSD-3-Clause](https://github.com/golang/go/blob/go1.26.5/LICENSE) | 7 Google URL/checksum entries; no provenance field. Musl keys reuse the corresponding Linux archive. |
| Aube | `1.25.2` | [MIT](https://github.com/jdx/aube/blob/v1.25.2/LICENSE) | 6 published URL/checksum entries, all with `github-attestations`; no macOS x64 artifact. |
| fnox | `1.28.0` | [MIT](https://github.com/jdx/fnox/blob/v1.28.0/LICENSE) | 7 URL/asset-ID/checksum entries, all with `github-attestations`. |
| GoReleaser | `2.17.0` | [MIT](https://github.com/goreleaser/goreleaser/blob/v2.17.0/LICENSE.md) | 7 URL/checksum entries, all with `github-attestations`. |
| hk | `1.49.0` | [MIT](https://github.com/jdx/hk/blob/v1.49.0/LICENSE) | 6 published URL/checksum entries; no provenance field and no macOS x64 artifact. |
| PostgreSQL | `17.5` | [PostgreSQL License](https://github.com/postgres/postgres/blob/REL_17_5/COPYRIGHT) | Exact `asdf:postgres` version only; no artifact URL, checksum, or provenance record. |
| AnyCable Go | `1.6.15` | [MIT](https://github.com/anycable/anycable/blob/v1.6.15/MIT-LICENSE) | 7 target records / 5 GitHub assets with asset IDs and matching checksums; no provenance field. |

Only Aube, fnox, and GoReleaser carry `github-attestations` in the generated lock: 20 records. This table distinguishes checksum identity from attestation provenance instead of treating them as equivalent.

## Install/build surface review

`aube ignored-builds` returned exactly `No ignored builds.` The recurring security task now fails closed if that output changes, preventing a newly skipped lifecycle script from passing silently.

The materialized arm64-Darwin Ruby graph declares native extension entrypoints for:

| Gem | Declared entrypoint(s) |
|---|---|
| `bigdecimal 4.1.2` | `ext/bigdecimal/extconf.rb` |
| `bindex 0.8.1` | `ext/skiptrace/extconf.rb` |
| `bootsnap 1.24.6` | `ext/bootsnap/extconf.rb` |
| `cbor 0.5.10.3` | `ext/cbor/extconf.rb` |
| `date 3.5.1` | `ext/date/extconf.rb` |
| `debug 1.11.1` | `ext/debug/extconf.rb` |
| `erb 6.0.5` | `ext/erb/escape/extconf.rb` |
| `io-console 0.8.2` | `ext/io/console/extconf.rb` |
| `json 2.21.1` | `ext/json/ext/generator/extconf.rb`, `ext/json/ext/parser/extconf.rb` |
| `msgpack 1.8.3` | `ext/msgpack/extconf.rb` |
| `nio4r 2.7.5` | `ext/nio4r/extconf.rb` |
| `openssl 4.0.2` | `ext/openssl/extconf.rb` |
| `pitchfork 0.18.2` | `ext/pitchfork_http/extconf.rb` |
| `prism 1.9.0` | `ext/prism/extconf.rb` |
| `puma 8.0.2` | `ext/puma_http11/extconf.rb` |
| `racc 1.8.1` | `ext/racc/cparse/extconf.rb` |
| `rbs 4.0.3` | `ext/rbs_extension/extconf.rb` |
| `stringio 3.2.0` | `ext/stringio/extconf.rb` |
| `websocket-driver 0.8.2` | `ext/websocket-driver/extconf.rb` |

Host-native `google-protobuf 4.35.1-arm64-darwin`, `nokogiri 1.19.4-arm64-darwin`, and `pg 1.6.3-arm64-darwin` declare no install-time entrypoint. The lock also carries generic Ruby variants of google-protobuf and pg, so another platform may expose source-build paths not exercised here. PostgreSQL's asdf backend also executes an install recipe rather than consuming a lock-recorded artifact.

This inventory identifies executable install/build surface and couples it to checksum-locked archives where the backend provides them. It is not a source-code review of every extconf/Rake helper, vendored C/C++, generated build system, subprocess/network behavior, compiler/linker flag, or non-host source fallback. Those remain explicit residual supply-chain risk; a stronger claim requires clean installs and source review on every supported target.
