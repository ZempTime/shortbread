# Shortbread

Private little websites for the people you choose.

Shortbread is an open-source, self-hosted application for publishing an already-built HTML directory as a private **Site**. Each publish creates an immutable **Release**. Named **Viewers** enter through personal accountless Invitations, can deliberately keep an eligible Release offline, and share one flat feedback thread anchored automatically to Release and page. Humans, CI, and agents use the same Go `shortbread` CLI and HTTP API.

Shortbread hosts, gates, and collects. It never builds Bundle content and never acts on feedback.

## Status

The dependency bootstrap is in progress; product behavior has not started. The product and delivery control plane are ready for the autonomous controller run:

- [accepted v1 PRD](docs/initiatives/2026-07-shortbread-v1/01_spec/output/2026-07-18-shortbread-v1-prd.md) — [GitHub #1](https://github.com/ZempTime/shortbread/issues/1)
- [tracer-ticket graph](docs/initiatives/2026-07-shortbread-v1/02_ticket_map/output/2026-07-18-ticket-map.md) — initial frontier [GitHub #2](https://github.com/ZempTime/shortbread/issues/2)
- [persistent controller goal](docs/initiatives/2026-07-shortbread-v1/03_goal_handoff/output/GOAL.md)
- [front-loaded dependency baseline](docs/initiatives/2026-07-shortbread-v1/03_goal_handoff/output/dependency-baseline.md)

The v1 build includes the web app, remote-authenticating Go CLI, credential-driven reference deployment, clean-clone setup/operations guides, released artifacts, a synthetic example Site, and screenshots captured repeatably from the real app.

## Development bootstrap

After cloning, explicitly trust this repository's checked-in mise configuration, install the pinned tools, and run the one setup task:

```sh
mise trust mise.toml
mise install
mise run setup
```

`mise.lock` supplies verified download URLs and checksums wherever the selected backend publishes them. In a clean-room environment, `MISE_GLOBAL_CONFIG_FILE=/dev/null mise install` limits installation to this repository instead of also installing tools from a personal global mise config. This checkpoint exercises the task graph on macOS arm64. The lock also inventories Linux arm64/x64 and Windows artifacts where upstream publishes them, but those entries are download coverage rather than claims of an exercised host or native `cmd.exe` compatibility.

`mise run setup` enters Bundler through the pinned Ruby with frozen-lock enforcement, installs the frozen Ruby, browser, and Go dependency graphs, and prepares repository-local PostgreSQL databases. It does not create product data or credentials. The conventional root `Gemfile` and `Gemfile.lock` remain the single Ruby dependency contract; there is no separate duplicate `mise bundle` task. Run `mise tasks` to see the public development, test, build, lint, typecheck, security, license, and bootstrap-check commands.

## Trust contract

> Shortbread itself never sends site content, feedback, invitation data, or viewer PII to AI, analytics, or optional third-party processors. Data is processed only by operator-configured Northflank, PlanetScale, and R2. Producers/agents outside Shortbread are operator-controlled.

Shortbread is server-private, not zero-knowledge. Saved offline copies may survive revocation. The reference stack uses private Cloudflare R2, PlanetScale Postgres, and Northflank; standard S3/PostgreSQL/container/HTTP/DNS seams keep self-hosting portable.

## Product shape

- one permanent Owner per installation;
- reusable People and per-Site Grants;
- preview-safe one-time Invitations, no passwords/email/SMS;
- apex Owner controls and Viewer Shelf;
- stable isolated `<slug>.sites.<apex>` Site origins;
- immutable content-addressed Releases with rollback;
- Viewer-controlled atomic Offline Copies;
- flat Release/path-anchored Comments and Owner-only View Receipts;
- Rails 8.1 + Inertia/React/TypeScript app and a single-binary Go CLI;
- no CMS, build pipeline, anonymous public links, notification system, analytics, or product-controlled AI.

Canonical vocabulary lives in [`CONTEXT.md`](CONTEXT.md); hard decisions live in [`docs/adr/`](docs/adr/).

## Building in public with agents

This repository is also Chris Zempel's experiment in building real software with a repo-local **Model Workspace Protocol (MWP)** and **Codex Ultra mode**: one durable controller coordinates bounded implementation/review agents without making chat history the workspace.

- GitHub issues and pull requests coordinate work across sessions.
- [`docs/initiatives/`](docs/initiatives/) contains bounded work, inputs, meaningful stages, harnesses, evidence, and handoffs.
- [`RUN.md`](docs/initiatives/2026-07-shortbread-v1/RUN.md) is the authoritative controller state.
- [`agents/`](agents/) is the reusable shipping factory.
- [`docs/agents/mwp.md`](docs/agents/mwp.md) defines Shortbread's local Model Workspace Protocol.
- Every implementation receives independent Standards and Spec review, and every run explicitly harvests reusable learning—or records that there was none.

The process artifacts are public on purpose: they should make the claims inspectable and eventually give other projects a useful, small factory to adapt.

## License

[MIT](LICENSE). See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for preserved upstream notices. The application, CLI, example content, documentation, and checked-in process factory must remain usable without proprietary application dependencies or private repository knowledge.
