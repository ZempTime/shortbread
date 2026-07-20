# Stage 05 Delivery Tracker

Local delivery units are reviewed and approved. GitHub leaf publication is pending; this file will receive issue numbers/URLs before Stage 05 promotion. Until then no leaf is executable.

| Unit | Acceptance umbrella | Blocked by units | GitHub | State |
|---|---:|---|---|---|
| U01 | #3 | #2 integrated | Pending | Publication frontier |
| U02 | #4 | U01 | Pending | Blocked |
| U03 | #12 | U02 | Pending | Blocked |
| U04 | #13 | U03 | Pending | Blocked |
| U05 | #4 | U02 | Pending | Blocked |
| U06 | #4 | U05 | Pending | Blocked |
| U07 | #4 | U06 | Pending | Blocked |
| U08 | #4 | U05, U07 | Pending | Blocked |
| U09 | #3 | U01, U05 | Pending | Blocked |
| U10 | #5 | U07, U08 | Pending | Blocked |
| U11 | #5 | U10 | Pending | Blocked |
| U12 | #5 | U11 | Pending | Blocked |
| U13 | #5 | U12 | Pending | Blocked |
| U14 | #5 | U05, U13 | Pending | Blocked |
| U15 | #6 | U01, U04 | Pending | Blocked |
| U16 | #6 | U07, U15 | Pending | Blocked |
| U17 | #7 | U16 | Pending | Blocked |
| U18 | #7 | U13, U17 | Pending | Blocked |
| U19 | #7 | U13, U18 | Pending | Blocked |
| U20 | #14 | U08, U14, U16, U19 | Pending | Blocked |
| U21 | #8 | U13, U19, U20 | Pending | Blocked |
| U22 | #8 | U01, U21 | Pending | Blocked |
| U23 | #9 | U08, U13, U19, U20 | Pending | Blocked |
| U24 | #9 | U03, U23 | Pending | Blocked |
| U25 | #10 | U08, U13, U18, U20 | Pending | Blocked |
| U26 | #11 | U08, U11, U23, U25 | Pending | Blocked |
| U27 | #11 | U15, U26 | Pending | Blocked |
| U28 | #12 | U03, U19, U22, U24, U25, U27 | Pending | Blocked |
| U29 | #12 | U01, U08, U10, U11, U12, U23, U25, U26 | Pending | Blocked |
| U30 | #12 | U28, U29 | Pending | Blocked |
| U31 | #13 | U04, U28 | Pending | Blocked |
| U32 | #13 | U24, U30, U31 | Pending | Blocked |
| U33 | #15 | U01, U13, U22, U24, U25, U27 | Pending | Blocked |
| U34 | #15 | U33 | Pending | Blocked |
| U35 | #16 | U20, U27, U30, U32, U34 | Pending | Blocked |
| U36 | #16 | U35 | Pending | Blocked |
| U37 | #14, #17 | U20, U27, U30, U32, U34, U36 | Pending | Blocked |
| U38 | #17 | U37 | Pending | Blocked |

## Publication Rule

Publish in unit order. Issue bodies use the exact unit cards from the canonical delivery plan plus the common unit-contract link. After all issues exist, replace `Pending` with links, comment the mapped leaves on each umbrella, remove executable labels/assignments from #3/#4, apply `ready-for-agent` only to U01, and update the root `RUN.md` resume capsule.
