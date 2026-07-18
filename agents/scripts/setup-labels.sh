#!/usr/bin/env bash
# Creates the tracker vocabulary used by the repo-local factory.
# Idempotent: --force updates existing labels in place.
set -euo pipefail

create() { gh label create "$1" --color "$2" --description "$3" --force; }

create bug d73a4a "Something is broken"
create enhancement a2eeef "New feature or improvement"
create needs-triage ededed "Maintainer needs to evaluate"
create needs-info fbca04 "Waiting on reporter for more information"
create ready-for-agent 0e8a16 "Fully specified; an agent can take it"
create ready-for-human 5319e7 "Needs judgment, authority, or action outside the controller envelope"
create wontfix ffffff "Will not be actioned"
