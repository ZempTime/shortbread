# Production-shaped runtime

Shortbread ships one candidate application image with four explicit process roles: `migrate`, `web`, `worker`, and `cable`. The image runs as UID/GID `10001:10001`; PostgreSQL and the private local Blob volume are external dependencies. This is a local, credential-free rehearsal contract. It is not a stable published artifact or a live-provider deployment.

## Rehearse the complete stack

Copy the environment template to a private file outside Git, restrict its permissions, and fill every required value:

```sh
cp .env.production.example .env.production.local
chmod 600 .env.production.local
```

For the checked-in Compose stack, the database host is `postgres`; `DATABASE_URL` and `QUEUE_DATABASE_URL` must select distinct PostgreSQL databases. The internal AnyCable endpoints are `http://shortbread.localhost:3000/_anycable` and `http://cable:8090/_broadcast`. Use synthetic local secrets of at least 32 characters. `SHORTBREAD_BOOTSTRAP_TOKEN` is a web-only Producer credential and must be exactly 64 lowercase hexadecimal characters so it is safe in the unquoted Compose environment file. Generate it through a private secret-manager/editor boundary; never print it or place it in a command argument. Never commit the completed file.

Build and start the candidate:

```sh
docker build --pull --tag shortbread:production-candidate .
docker compose --env-file .env.production.local --file compose.production.yml config --quiet
docker compose --env-file .env.production.local --file compose.production.yml up --detach
docker compose --env-file .env.production.local --file compose.production.yml ps --all
```

Compose starts PostgreSQL, runs `migrate` to completion, and starts `web` and `worker` only after that migration succeeds. `cable` waits for the web readiness check. A migration failure prevents the serving processes from starting.

The retained, disposable verification performs the same build plus fail-fast configuration, non-root, migration ordering, process health, and restart assertions:

```sh
bin/production-smoke
```

The smoke uses only synthetic credentials and removes its isolated database and Blob volumes when it exits.

## Process and health contract

The image entrypoint is `bin/production`. A scheduler can invoke these roles from the same image:

| Role | Command | Healthy when |
|---|---|---|
| Migration | `bin/production migrate` | `db:prepare` exits successfully |
| Web | `bin/production web` | apex-host `GET /health/ready` reaches both databases and writable private Blob storage |
| Worker | `bin/production worker` | a Solid Queue `Worker` has a fresh heartbeat |
| WebSocket | `bin/production cable` | AnyCable serves its `/health` endpoint |

`GET /health/live` proves the Rails process can answer without touching dependencies. `GET /health/ready` proves the primary and queue databases respond and the private Blob root is writable. Both routes are available only on the configured apex host. The Compose healthchecks exercise the same public process probes through `bin/production health web|worker|cable`.

Inspect failures without printing the environment:

```sh
docker compose --env-file .env.production.local --file compose.production.yml ps --all
docker compose --env-file .env.production.local --file compose.production.yml logs migrate web worker cable
docker compose --env-file .env.production.local --file compose.production.yml exec web bin/production config
```

The `config` inventory redacts secrets and database URLs. Missing or contradictory configuration exits with status 78 before a role starts. In particular, production requires a valid lowercase apex hostname, distinct PostgreSQL databases, an absolute Blob root, non-development secrets, HTTP AnyCable RPC/broadcast URLs, and a secure public WebSocket URL. Only `web` receives, requires, or inventories `SHORTBREAD_BOOTSTRAP_TOKEN`; `migrate`, `worker`, and `cable` do not receive the Producer credential.

## Restart and stop

Restart stateless processes independently; their healthchecks must recover:

```sh
docker compose --env-file .env.production.local --file compose.production.yml restart web worker cable
docker compose --env-file .env.production.local --file compose.production.yml ps --all
```

Stop the rehearsal while retaining PostgreSQL and private Blobs:

```sh
docker compose --env-file .env.production.local --file compose.production.yml down
```

The named `postgres` and `blobs` volumes are the durable local state. Removing those volumes destroys the rehearsal's database and Blob data; back them up before any explicit `down --volumes` operation.
