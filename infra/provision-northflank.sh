#!/usr/bin/env bash
set -euo pipefail
# Creates the Northflank secret group (placeholder values), the migration job, and the
# web service. Requires NORTHFLANK_TOKEN in the env (project-scoped token — never stored,
# never echoed, never written to disk).
#
# Idempotent-aware: each resource is skipped if it already exists, so a partial run can be
# resumed. It does NOT reconcile drift — an existing resource is left exactly as it is.
#
# Does not create: the Postgres addon, domains, or the release workflow. Those are HUMAN
# steps — see docs/runbooks/deploy.md.

cd "$(dirname "$0")"
set -a; source ./app.env; set +a
: "${NORTHFLANK_TOKEN:?set NORTHFLANK_TOKEN (see docs/runbooks/deploy.md Phase 1)}"

api="https://api.northflank.com/v1/projects/$APP_NAME"

nf() { # nf <method> <path> [json-template]
  local method=$1 path=$2 tmpl=${3:-}
  if [ -n "$tmpl" ]; then
    python3 -c 'import os,sys; print(os.path.expandvars(sys.stdin.read()))' < "$tmpl" |
      curl -fsS -X "$method" -H "Authorization: Bearer $NORTHFLANK_TOKEN" \
        -H "Content-Type: application/json" "$api$path" -d @-
  else
    curl -fsS -X "$method" -H "Authorization: Bearer $NORTHFLANK_TOKEN" "$api$path"
  fi
}

exists() { # exists <path> — 0 if the resource is already there
  curl -fsS -o /dev/null -H "Authorization: Bearer $NORTHFLANK_TOKEN" "$api$1" 2>/dev/null
}

create() { # create <label> <get-path> <post-path> <template>
  local label=$1 get_path=$2 post_path=$3 tmpl=$4
  if exists "$get_path"; then
    echo "$label: exists, skipped"
  else
    nf POST "$post_path" "$tmpl" > /dev/null && echo "$label: created"
  fi
}

create "secret group" "/secrets/$APP_NAME-secrets" /secrets northflank/secret-group.json
create "migrate job"  /jobs/migrate            /jobs/manual        northflank/job-migrate.json
create "web service"  /services/web            /services/combined  northflank/service-web.json

WEB_DNS=$(nf GET /services/web/ports |
  python3 -c "import json,sys; print(json.load(sys.stdin)['data']['ports'][0]['dns'])")
echo "web dns: $WEB_DNS"
echo
echo "Next (all HUMAN, docs/runbooks/deploy.md):"
echo "  - enter real values over the placeholders, then restart the service"
echo "  - add $DOMAIN and $SITE_DOMAIN as domains, and create the release workflow"
