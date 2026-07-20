# Phase-one dependency freeze review

Phase one is frozen at `3c40a6755109db46aafb85ac7f359e522470678d`, relative to the pinned ticket baseline `412be84d441325c5e61004da87ec6878e588d7b4`.

## Independent verdicts

| Review | Fixed input | Verdict |
|---|---|---|
| Standards | `13e69f4..3c40a67`, with prior baseline facts reconfirmed | **Approve** — no blocker or should-fix finding. |
| Security/Operations | `13e69f4..3c40a67`, with prior controls reconfirmed | **Approve** — no blocker or should-fix finding. |
| Specification | `412be84d..3c40a67` | **Approve** — no blocker or should-fix finding under the accepted reachability threshold. |

The final targeted review verified that `bin/bootstrap` checks a cached PostgreSQL installer before mise can execute it. Absence is allowed so the checked-in commit pin can install the plugin; wrong origin, wrong revision, a non-Git path, unreadable metadata, or a dirty tree fails closed. Five focused tests produced 17 assertions. The recurring dependency policy independently rejects a dirty installed plugin.

## Repair history

- `914ddd6` was the first audited bootstrap checkpoint. Review rejected outdated vulnerable runtime pins, a bearer-token query seam, non-loopback web binding, and setup/CI ordering and support-claim gaps.
- `214e1da` repaired those findings. Its rerun identified mise install statistics, AnyCable PostHog reporting, Go local telemetry, and floating executable installer sources.
- `715e7d8` disabled mise install statistics.
- `13e69f4` disabled AnyCable reporting, isolated Go tooling in repository-scoped `off` mode, and commit-pinned the PostgreSQL plugin and ruby-build.
- `3c40a67` closed the final ordering gap by placing a tested system-shell installer preflight before `mise install` and documenting installer licenses/integrity limits.

## Controller disposition and evidence

The Operator explicitly accepted a solid, license-compliant starting point without patch-version perfection. The documented mise and fnox findings are reachability-bounded for the frozen task graph and must be revisited before their inactive capabilities are enabled; they do not trigger another version-selection loop.

Final evidence on macOS arm64:

- `bin/bootstrap` passed through the pre-install check, repository-only tool installation, frozen dependency installation, and database preparation.
- `mise exec -- bin/ci` passed Setup, Bootstrap, Lint, Typecheck, Security, Tests, and Build in 12.96 seconds.
- Rails tests: 6 runs, 18 assertions, no failures; Go tests and build passed; 28 Ruby files passed lint; browser typecheck/build passed.
- License audit: 133 Ruby gems, 170 browser packages with 40 bounded metadata exceptions, and 16 Go modules.
- The global Go telemetry directory was byte-identical before and after CI; the repository telemetry directory remained the checked-in `off` mode only.
- Dependency manifests and lockfiles did not change in the final ordering repair.

Phase one is approved and closed. Ticket #2 is promoted to the publish → Invitation → explicit acceptance → private Site view tracer.
