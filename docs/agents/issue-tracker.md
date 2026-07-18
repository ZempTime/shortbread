# Issue Tracker: GitHub

Issues and PRDs live in [ZempTime/shortbread](https://github.com/ZempTime/shortbread/issues). Use the `gh` CLI for tracker operations.

## State ownership

- GitHub issues own cross-session status, assignment, dependencies, and acceptance criteria.
- Pull requests isolate and review implementation attempts. They are coordination surfaces, not feature-request intake.
- `docs/initiatives/` workspaces own bounded inputs, decisions, problem-specific harnesses, evidence, and handoffs.
- A workspace's `RUN.md` is authoritative for its live stage state. A branch, issue label, folder tree, or merge never proves that a stage ran.
- Code and executable tests are authoritative for implemented behavior.

## Conventions

- Create: `gh issue create --title "..." --body-file <path>`.
- Read: `gh issue view <number> --comments`.
- List: `gh issue list --state open --json number,title,body,labels,assignees`.
- Comment: `gh issue comment <number> --body-file <path>`.
- Label: `gh issue edit <number> --add-label "..."` or `--remove-label "..."`.
- Close: `gh issue close <number> --comment "..."`.
- Read PR: `gh pr view <number> --comments` and `gh pr diff <number>`.

GitHub shares one number space across issues and PRs. Resolve an ambiguous `#42` with `gh pr view 42`, then fall back to `gh issue view 42`.

## Publishing from skills

- `to-spec` publishes the accepted PRD as a GitHub issue.
- `to-tickets` publishes approved tracer-bullet child issues in dependency order.
- Apply `ready-for-agent` only after a ticket is fully specified and its blockers are represented.
- Do not close or rewrite a parent PRD while publishing child tickets.

## Dependencies and frontier

Prefer GitHub's native sub-issue and blocked-by relationships. If unavailable, put `Parent: #<number>` and `Blocked by: #<numbers>` at the top of each child issue.

The frontier is the set of open, unassigned child issues whose blockers are all closed. An execution session claims a frontier issue by assigning it to itself before implementation.

## Pull requests as a triage surface

**PRs as a request surface: no.** External requests begin as issues. PRs carry an already-accepted issue through review and integration.
