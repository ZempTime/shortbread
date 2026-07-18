# Stage 02 Tracker

Published 2026-07-18 under controller approval. Textual `Parent` and `Blocked by` edges in each issue are authoritative unless replaced by equivalent native GitHub relationships.

| Local | GitHub | Blocked by | Initial state |
|---|---|---|---|
| T01 | [#2](https://github.com/ZempTime/shortbread/issues/2) | — | `ready-for-agent` frontier |
| T02 | [#3](https://github.com/ZempTime/shortbread/issues/3) | #2 | Blocked |
| T03 | [#4](https://github.com/ZempTime/shortbread/issues/4) | #2 | Blocked |
| T04 | [#5](https://github.com/ZempTime/shortbread/issues/5) | #4 | Blocked |
| T05 | [#6](https://github.com/ZempTime/shortbread/issues/6) | #3 | Blocked |
| T06 | [#7](https://github.com/ZempTime/shortbread/issues/7) | #5, #6 | Blocked |
| T07 | [#8](https://github.com/ZempTime/shortbread/issues/8) | #5, #7 | Blocked |
| T08 | [#9](https://github.com/ZempTime/shortbread/issues/9) | #5, #7 | Blocked |
| T09 | [#10](https://github.com/ZempTime/shortbread/issues/10) | #5, #7 | Blocked |
| T10 | [#11](https://github.com/ZempTime/shortbread/issues/11) | #5, #6, #9, #10 | Blocked |
| T11 | [#12](https://github.com/ZempTime/shortbread/issues/12) | #4, #6, #7 | Blocked |
| T12 | [#13](https://github.com/ZempTime/shortbread/issues/13) | #12, #14 | Blocked |
| T13 | [#14](https://github.com/ZempTime/shortbread/issues/14) | #4, #5, #6, #7 | Blocked |
| T14 | [#15](https://github.com/ZempTime/shortbread/issues/15) | #8, #9, #10, #11 | Blocked |
| T15 | [#16](https://github.com/ZempTime/shortbread/issues/16) | #13, #14, #15 | Blocked |
| T16 | [#17](https://github.com/ZempTime/shortbread/issues/17) | #11, #13, #14, #16 | Blocked |

The controller recomputes the frontier after each integrated ticket and adds/removes `ready-for-agent` accordingly. Assignment claims work; labels alone do not.
