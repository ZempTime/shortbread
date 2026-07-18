---
name: to-tickets
description: Decompose an accepted PRD into a reviewed dependency graph of vertical tracer tickets. Use after to-spec and before autonomous implementation begins.
---

# To Tickets

Create agent-sized, user-visible slices with explicit blocking edges and complete PRD coverage.

## Authority

Interactive work normally presents the draft graph for operator approval before publication. When the active `RUN.md` delegates this approval to a top-level controller, the controller must perform and record that review; its sign-off replaces another operator interruption.

## Shape the graph locally

1. Read the canonical PRD, parent issue, glossary/ADRs, active `RUN.md`, and the stage output path.
2. Identify the smallest end-to-end walking skeleton. Ticket 1 must reach a real actor-visible outcome across necessary layers; it may include minimum scaffolding, but cannot be a horizontal infrastructure ticket.
3. Add slices that deepen behavior through the public seam. Prefer one fresh implementation context per ticket. If a coherent slice is necessarily larger, name a controller checkpoint and safe split rule.
4. Give every ticket:
   - outcome-oriented title;
   - parent PRD and `Blocked by` edges;
   - actor-visible behavior and failure/recovery behavior;
   - precise acceptance criteria;
   - required browser/request/CLI/unit/provider seams;
   - allowed/central edit-surface warning;
   - security, privacy, docs, screenshots, and operations impact;
   - evidence required for integration;
   - factory harvest or `No reusable harvest` requirement.
5. Build a PRD-story-to-ticket coverage table and a runnable-frontier summary.

Avoid one ticket per technical layer, speculative abstraction tickets, vague “finish integration” work, and false parallelism around schema, routes, dependency manifests, lockfiles, root docs, generated assets, or release state.

## Controller review

Before publication, independently challenge:

- missing stories or terminal evidence;
- oversized slices and hidden dependencies;
- blocked tickets incorrectly placed on the frontier;
- setup/security/docs deferred into an unbounded final bucket;
- dependency additions after the approved bootstrap;
- tickets that cannot demonstrate value when complete.

Revise until the graph is executable. Record controller approval in the local output.

## Publish and track

Publish children in dependency order with parent/blocker text or native relationships. Record issue numbers, URLs, and edges in the stage tracker file. Apply `ready-for-agent` to the current unblocked child frontier; keep fully specified blocked work out of the frontier until its edges close. Once decomposition is published, remove `ready-for-agent` from the non-actionable parent PRD so it cannot masquerade as executable frontier work. Update `RUN.md` with durable promotion evidence.

Do not create ceremonial per-ticket workspaces during decomposition. `implement` creates one only when the slice's uncertainty or duration justifies it.
