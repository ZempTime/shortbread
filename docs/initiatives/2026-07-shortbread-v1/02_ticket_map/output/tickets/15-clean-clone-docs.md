# Make a clean clone understandable and operable

Parent: #1
Blocked by: #13, #14, #15
Local ticket ID: T15

## Outcome

The public repository explains the product and AI-process experiment and lets an independent reader go from clean clone to local example and credential-ready production operations without private knowledge or undocumented steps.

## Acceptance

- README covers product/status/trust/no-build boundary, quickstart, self-host/open-source posture, CLI install, MIT, screenshots/tour, and the agent/MWP experiment.
- Guides cover prerequisites, mise/bootstrap, local dev/tests, Owner bootstrap/recovery, remote CLI login/profiles/CI tokens, API/publish/Bundle/offline semantics, and troubleshooting.
- Production setup enumerates every credential/value and runs plan/apply/resume/doctor/deploy; no secret belongs in mise/Git/process arguments.
- Operations cover upgrades, compatibility, migrations, rollback, health, logs/redaction, backup/restore realities, R2/PlanetScale, Site deletion, and disaster recovery.
- Security/threat, architecture/domain/ADRs, contribution, testing, dependency exception, release, and MWP/factory demonstration docs are linked and current.
- Commands, internal/external links, screenshot manifest, and example flow are mechanically checked.

## Evidence and review

- An independent clean-room agent follows only public docs on a fresh checkout and records every gap; repair and repeat to green.
- Standards + Spec + docs/operations/security review, command/link checks, final setup inventory and harvest.
