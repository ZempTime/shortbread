# Stage 05 Delivery Tracker

Stage 05 was published and promoted on 2026-07-20. GitHub #19–#56 are the executable leaves; original #3–#17 remain acceptance umbrellas. U01/#19 is integrated and U02/#20 is the sole frontier. Every other leaf stays blocked until all unit dependencies are integrated and the current controller promotes it.

| Unit | Acceptance umbrella | Blocked by units | GitHub | State |
|---|---:|---|---|---|
| U01 | #3 | #2 integrated | [#19](https://github.com/ZempTime/shortbread/issues/19) | Integrated by [#57](https://github.com/ZempTime/shortbread/pull/57) at `45db8bd`; reviewed candidate `21a08c9` |
| U02 | #4 | U01 | [#20](https://github.com/ZempTime/shortbread/issues/20) | `ready-for-agent` frontier |
| U03 | #12 | U02 | [#21](https://github.com/ZempTime/shortbread/issues/21) | Blocked |
| U04 | #13 | U03 | [#22](https://github.com/ZempTime/shortbread/issues/22) | Blocked |
| U05 | #4 | U02 | [#23](https://github.com/ZempTime/shortbread/issues/23) | Blocked |
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

## Promotion Rule

Only the current campaign controller changes frontier state. After a leaf is reviewed and integrated, it records evidence here and on the issue, removes `ready-for-agent` from the completed leaf, then promotes only dependency-satisfied leaves that fit the active campaign. A pause or campaign end must leave the repository with no falsely active state and one exact fresh-context resume instruction in `RUN.md`.
