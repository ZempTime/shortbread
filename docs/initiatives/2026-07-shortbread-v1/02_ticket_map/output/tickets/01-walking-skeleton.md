# Publish, invite, and view one private page locally

Parent: #1
Blocked by: none
Local ticket ID: T01

## Outcome

A clean clone has the audited/frozen dependency baseline, a runnable Rails/Postgres application, and a real Go `shortbread` binary. Using a local bootstrap automation credential, an Owner can create one Site/Person/Grant/Invitation, publish a one-file Bundle through the API, and a Viewer can explicitly accept the preview-safe Invitation and open the private page on its Site host.

## Acceptance

- Pin/install the approved `mise.toml` toolchain; scaffold Rails 8.1/Inertia/React/TS and `cli/`; add the approved Ruby/JS/Go dependency manifests and committed lockfiles.
- This dependency-bootstrap checkpoint is where the controller may inspect an available, Operator-designated local template and selectively adapt generic code/configuration patterns. Rails defaults, standard Go tooling, and the checked-in dependency baseline are the sufficient fallback; a clean clone must never require the template or sibling-repository access.
- Do not copy template product behavior, data, assets, identifiers, telemetry, proprietary integrations, or manual infrastructure assumptions.
- Audit direct/transitive licenses, install/build scripts, known vulnerabilities, and proprietary-service coupling; record compatibility adjustments, then freeze dependency surfaces under controller ownership.
- Add actual `mise` tasks for setup, database, dev, test, lint, typecheck, CLI build/test, and the walking skeleton.
- Implement the thinnest durable domain/API/storage seams for one Site, Release, Blob/Manifest Entry, Person, Grant, preview-safe Invitation, host session, and private HTML response. A local BlobStore adapter is acceptable; production R2 is T05.
- Build the real CLI to create the minimum records and safely publish one HTML file; reject traversal, symlinks, reserved paths, and a representative secret-like file before upload.
- A GET/preview does not consume the Invitation; an explicit POST does; an unauthenticated Site request cannot read the page.

## Evidence and review

- One black-box test drives built CLI → Rails API → browser acceptance/private Site page.
- Rails request/system tests cover host routing, Invitation side effects, session, and private serving.
- Full bootstrap/test/lint/type/security/license/build evidence runs from a clean checkout.
- Independent Standards + Spec review; security review for the minimal auth boundary; explicit harvest result.

Do not promote scaffolding without the end-to-end tracer. Do not add dependencies after the freeze checkpoint without the ADR 0007 exception process.
