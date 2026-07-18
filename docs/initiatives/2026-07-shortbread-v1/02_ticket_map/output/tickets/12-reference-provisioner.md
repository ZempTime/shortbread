# Provision the reference stack from credentials only

Parent: #1
Blocked by: #12, #14
Local ticket ID: T12

## Outcome

One idempotent plan/apply/resume/doctor workflow is ready to accept least-privilege credentials and deployment values at the final setup ceremony and prepare Northflank, PlanetScale Postgres, private Cloudflare R2, wildcard DNS/TLS, secrets, migrations, health, and deployment without undocumented dashboard construction. This ticket proves it without requesting live credentials mid-build.

## Acceptance

- Setup enumerates exact accounts/projects/region/apex/domain and credentials/scopes. The Operator runs secret entry directly through no-echo stdin/provider-native browser auth, OS keychain, or direct provider/GitHub secret-store configuration; secrets never enter chat, agent prompts, Git, process args, captured tool output, mise, or repo fnox files.
- A versioned manifest names every managed resource. Plan is credential-free against command-contract fakes, non-interactive-capable, and shows changes/plan-cost choices without mutation.
- Apply creates/updates only namespaced manifest resources, is idempotent/resumable, and never adopts/deletes unknown existing resources, upgrades plans, purchases/transfers domains, or accepts legal/billing terms.
- Deploy orders secrets, database, R2, DNS/TLS, migrate, web/worker/WebSocket, health, then smoke safely.
- `doctor` verifies scopes/config/DNS/TLS/app/db/R2/queue/WebSocket/API compatibility without leaking secrets.
- Agents may run plans and inspect redacted `doctor`/smoke results. This ticket does not solicit live values; T16/#17 owns the single end-of-goal ceremony. There, live apply/smoke is automatic only when the runtime can guarantee values stay out of model/tool logs; otherwise the Operator runs one exact generated command directly and returns only redacted results. Absent credentials leave ready-to-run instructions, not a false success.

## Evidence and review

- Provider command-contract/failure-injection tests plus an isolated clean-room plan/apply/resume/doctor rehearsal with fake endpoints.
- Optional live manifest/smoke evidence kept redacted outside public fixtures.
- Standards + Spec + secrets/infrastructure/operations review, setup/runbook docs and harvest.
