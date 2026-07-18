# Triage Labels

| Canonical role | GitHub label | Meaning |
|---|---|---|
| `needs-triage` | `needs-triage` | Maintainer evaluation is required |
| `needs-info` | `needs-info` | Waiting for information from the reporter |
| `ready-for-agent` | `ready-for-agent` | Fully specified and safe for an AFK agent |
| `ready-for-human` | `ready-for-human` | Requires human judgment, authority, or action |
| `wontfix` | `wontfix` | Will not be actioned |

Skills use the canonical role on the left and apply the corresponding GitHub label on the right.

Auth/session boundaries, deletion/data integrity, production credentials, and public trust-contract changes require explicit authority plus enhanced review. Outside an active delegated goal they are human gates. Inside a goal whose `RUN.md` records the operator's bounded delegation, the top-level controller supplies routine approval; changes to the trust contract or authority envelope still return to the operator.
