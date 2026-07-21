# Autonomous Execution

Shortbread's trusted-project Codex configuration keeps the workspace sandbox and routes eligible boundary requests to automatic review. The active initiative's `RUN.md` remains the authority envelope; automatic review changes who reviews an eligible runtime escalation, not what the controller is authorized to do.

## Stable command boundary

Agent shell commands must not prepend environment assignments to `mise`, Rails, Go, Git, or GitHub commands. Environment-prefixed and overly compound shell commands cannot be matched reliably by Codex command rules.

Use these stable entry points for isolated verification:

| Need | Command |
|---|---|
| Start isolated PostgreSQL | `mise run agent:db:start` |
| Prepare isolated application databases | `mise run agent:database` |
| Run a focused Rails command | `mise run agent:rails -- test test/path_test.rb` |
| Run all Rails and Go tests | `mise run agent:test` |
| Run the bootstrap gate | `mise run agent:bootstrap-check` |
| Run the real CLI/browser tracer | `mise run agent:walking-skeleton` |
| Stop isolated PostgreSQL | `mise run agent:db:stop` |

`bin/agent-env` derives short PostgreSQL paths, a worktree-specific port, and isolated Go/RuboCop caches from the worktree root. Its state directory is owner-only. `bin/db` disables PostgreSQL TCP listening and makes the Unix socket owner-only before using local trust authentication. The wrapper also keeps explicit human overrides when they are deliberately supplied. Agents should invoke it through the public `mise run agent:*` tasks.

On the current macOS sandbox, PostgreSQL shared-memory setup and database-socket clients cross the process boundary and therefore request escalation. That is expected: the stable task name gives automatic review one narrow, readable action instead of an opaque environment-prefixed shell command. Non-database checks continue inside the workspace sandbox.

Keep local verification, Git staging/committing, network pushes, and GitHub mutations in separate tool calls. This lets the sandbox and project rules evaluate the narrowest possible action.

## Codex boundary

- `.codex/config.toml` selects `workspace-write`, `on-request`, and automatic review for trusted Shortbread sessions.
- The same project config routes mise's disposable path cache to `/private/tmp`, which is writable inside the workspace sandbox.
- `.codex/rules/shortbread.rules` identifies routine Git and GitHub command families and explicitly routes their boundary crossings to automatic review; it does not allow unsandboxed execution by prefix alone.
- Unexpected commands still go through automatic review. Denials, true stop conditions, missing credentials, destructive production actions, and authority changes still return to the operator.
- Project configuration and rules take effect in a new or restarted Codex session.
