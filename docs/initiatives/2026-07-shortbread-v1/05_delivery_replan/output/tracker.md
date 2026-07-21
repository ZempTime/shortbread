# Stage 05 Delivery Tracker

Stage 05 was published and promoted on 2026-07-20. GitHub #19–#56 are the executable leaves; original #3–#17 remain acceptance umbrellas. C00 completed on 2026-07-21 with U01/#19 and U02/#20 integrated. C01 integrated U03/#21, then ended when the Operator selected the launch-today self-hosted path. U04/#22 was never started and is closed as not planned; its reference-provider acceptance was not delivered. U05/#23 through U38/#56 remain open, unassigned, and paused regardless of the historical dependency states shown below. No controller or frontier is active.

| Unit | Acceptance umbrella | Blocked by units | GitHub | State |
|---|---:|---|---|---|
| U01 | #3 | #2 integrated | [#19](https://github.com/ZempTime/shortbread/issues/19) | Integrated by [#57](https://github.com/ZempTime/shortbread/pull/57) at `45db8bd`; reviewed candidate `21a08c9` |
| U02 | #4 | U01 | [#20](https://github.com/ZempTime/shortbread/issues/20) | Integrated by [#59](https://github.com/ZempTime/shortbread/pull/59) at `181745c`; reviewed candidate `c523fac` |
| U03 | #12 | U02 | [#21](https://github.com/ZempTime/shortbread/issues/21) | Integrated by [#61](https://github.com/ZempTime/shortbread/pull/61) at `d30be56`; reviewed candidate `4b76c83` |
| U04 | #13 | U03 | [#22](https://github.com/ZempTime/shortbread/issues/22) | Closed as not planned for the launch-today self-hosted path; not started and reference-provider acceptance not delivered |
| U05 | #4 | U02 | [#23](https://github.com/ZempTime/shortbread/issues/23) | Paused and unclaimed; dependency-satisfied but campaign-gated for C02 |
| U06 | #4 | U05 | [#24](https://github.com/ZempTime/shortbread/issues/24) | Blocked |
| U07 | #4 | U06 | [#25](https://github.com/ZempTime/shortbread/issues/25) | Blocked |
| U08 | #4 | U05, U07 | [#26](https://github.com/ZempTime/shortbread/issues/26) | Blocked |
| U09 | #3 | U01, U05 | [#27](https://github.com/ZempTime/shortbread/issues/27) | Blocked |
| U10 | #5 | U07, U08 | [#28](https://github.com/ZempTime/shortbread/issues/28) | Blocked |
| U11 | #5 | U10 | [#29](https://github.com/ZempTime/shortbread/issues/29) | Blocked |
| U12 | #5 | U11 | [#30](https://github.com/ZempTime/shortbread/issues/30) | Blocked |
| U13 | #5 | U12 | [#31](https://github.com/ZempTime/shortbread/issues/31) | Blocked |
| U14 | #5 | U05, U13 | [#32](https://github.com/ZempTime/shortbread/issues/32) | Blocked |
| U15 | #6 | U01, U04 | [#33](https://github.com/ZempTime/shortbread/issues/33) | Blocked |
| U16 | #6 | U07, U15 | [#34](https://github.com/ZempTime/shortbread/issues/34) | Blocked |
| U17 | #7 | U16 | [#35](https://github.com/ZempTime/shortbread/issues/35) | Blocked |
| U18 | #7 | U13, U17 | [#36](https://github.com/ZempTime/shortbread/issues/36) | Blocked |
| U19 | #7 | U13, U18 | [#37](https://github.com/ZempTime/shortbread/issues/37) | Blocked |
| U20 | #14 | U08, U14, U16, U19 | [#38](https://github.com/ZempTime/shortbread/issues/38) | Blocked |
| U21 | #8 | U13, U19, U20 | [#39](https://github.com/ZempTime/shortbread/issues/39) | Blocked |
| U22 | #8 | U01, U21 | [#40](https://github.com/ZempTime/shortbread/issues/40) | Blocked |
| U23 | #9 | U08, U13, U19, U20 | [#41](https://github.com/ZempTime/shortbread/issues/41) | Blocked |
| U24 | #9 | U03, U23 | [#42](https://github.com/ZempTime/shortbread/issues/42) | Blocked |
| U25 | #10 | U08, U13, U18, U20 | [#43](https://github.com/ZempTime/shortbread/issues/43) | Blocked |
| U26 | #11 | U08, U11, U23, U25 | [#44](https://github.com/ZempTime/shortbread/issues/44) | Blocked |
| U27 | #11 | U15, U26 | [#45](https://github.com/ZempTime/shortbread/issues/45) | Blocked |
| U28 | #12 | U03, U19, U22, U24, U25, U27 | [#46](https://github.com/ZempTime/shortbread/issues/46) | Blocked |
| U29 | #12 | U01, U08, U10, U11, U12, U23, U25, U26 | [#47](https://github.com/ZempTime/shortbread/issues/47) | Blocked |
| U30 | #12 | U28, U29 | [#48](https://github.com/ZempTime/shortbread/issues/48) | Blocked |
| U31 | #13 | U04, U28 | [#49](https://github.com/ZempTime/shortbread/issues/49) | Blocked |
| U32 | #13 | U24, U30, U31 | [#50](https://github.com/ZempTime/shortbread/issues/50) | Blocked |
| U33 | #15 | U01, U13, U22, U24, U25, U27 | [#51](https://github.com/ZempTime/shortbread/issues/51) | Blocked |
| U34 | #15 | U33 | [#52](https://github.com/ZempTime/shortbread/issues/52) | Blocked |
| U35 | #16 | U20, U27, U30, U32, U34 | [#53](https://github.com/ZempTime/shortbread/issues/53) | Blocked |
| U36 | #16 | U35 | [#54](https://github.com/ZempTime/shortbread/issues/54) | Blocked |
| U37 | #14, #17 | U20, U27, U30, U32, U34, U36 | [#55](https://github.com/ZempTime/shortbread/issues/55) | Blocked |
| U38 | #17 | U37 | [#56](https://github.com/ZempTime/shortbread/issues/56) | Blocked |

## U01 Integration Evidence

- Preserved `ticket-3-releases-rollback@f5943d7` was reviewed at fixed SHA as source evidence and was never merged.
- Behavioral TDD began at red checkpoint `09c9bac`; fixed candidate `21a08c9` passed 132 Rails tests / 1,334 assertions, all Go tests, lint, typecheck, build, security, licenses, bootstrap, and the real CLI/browser Release tracer.
- A detached clean checkout rebuilt its database from migrations and replayed the full tests, tracer, and bootstrap successfully.
- Independent Standards + Spec and data-integrity specialist reviews both approved exact candidate `21a08c9` with no blockers or should-fix findings.
- [PR #57](https://github.com/ZempTime/shortbread/pull/57) merged as `45db8bd`; [U01/#19](https://github.com/ZempTime/shortbread/issues/19) closed. No reusable harvest.

## U02 Integration Evidence

- Merged PR #58 changed only authorized `agent:*` execution/isolation tasks but left the frozen `mise.toml` digest stale. Controller-owned [PR #60](https://github.com/ZempTime/shortbread/pull/60) updated only that digest after confirming no dependency, lockfile, tool version, installer pin, telemetry control, or trust-promise change.
- Exact PR #60 candidate `cd98357` passed the complete security gate, standalone license audit, and isolated bootstrap gate. Independent Standards + Spec and security/supply-chain reviewers approved it with no findings; it merged as `1a65ae3`.
- Current main was merged normally into `u02-owner-bootstrap` without rewriting history. Exact U02 candidate `c523fac` passed 149 Rails tests / 1,507 assertions plus all Go tests, Rails `test:all` at 151 / 1,523 including Chrome, focused auth at 21 / 190, dedicated Chrome WebAuthn at 2 / 16, lint, typecheck, build, security/dependency/license checks, bootstrap, and the real walking-skeleton tracer.
- Independent Standards + Spec and auth/security reviewers approved exact candidate `c523fac` with no blocker, should-fix, or note findings. The merge from main changed no auth, session, WebAuthn, schema, logging, test, manifest, lockfile, tool-pin, or `mise.toml` behavior from the previously approved U02 implementation.
- [PR #59](https://github.com/ZempTime/shortbread/pull/59) merged as `181745c`; [U02/#20](https://github.com/ZempTime/shortbread/issues/20) closed. Umbrella [#4](https://github.com/ZempTime/shortbread/issues/4) remains open for U05–U08. **No reusable harvest:** the project-specific governed-digest repair is durable in PR #60; the proposed `agent:security` wrapper lacks repeated evidence and is not promoted into `agents/` during C00.

## U03 Integration Evidence

- Exact candidate `4b76c83` passed test-first repair and the full relevant gates; independent Standards + Spec and operations/container/security reviewers approved it with no remaining findings. The [final fixed-head PR record](https://github.com/ZempTime/shortbread/pull/61#issuecomment-5037707914) owns the detailed evidence and residual risks.
- [PR #61](https://github.com/ZempTime/shortbread/pull/61) merged as `d30be56`; [U03/#21](https://github.com/ZempTime/shortbread/issues/21) closed. The U03 worktree and branches were removed only after integration and clean-state proof.
- U04/#22 closed as not planned without implementation when the Operator chose the launch-today self-hosted path. Its reference-provider acceptance remains undelivered; the later v1 backlog remains open and paused.
- **No reusable harvest:** retain the production smoke and fail-fast/redacted runtime pattern as a U28 candidate only. Promote nothing into `agents/` until the final image proves the pattern with its authoritative rebuild, digest, SBOM, vulnerability scan, and operations review.

## Promotion Rule

Only a current campaign controller changes frontier state. No controller is active and no leaf is promoted. Future execution requires explicit Operator direction, fresh reconciliation, and a new bounded campaign; the current `RUN.md` pause capsule is authoritative.
