# Loom

**A declarative format for deploying a coding agent as a repeatable run.**

## About Loom

Loom turns an agent task into a **portable, verifiable unit of work.** Instead
of babysitting an agent in a terminal, you write a *Weave* — a small JSON file
(`*.loom.json`, spec `nautloom/v1`) that declares *what* to do, *where* to run
it, *what "done" means*, and *what to hand back*. Loom spins an isolated
sandbox, runs the agent, checks the acceptance criteria, and ships the result as
a branch + PR with a recorded report.

**The mental model.** A Weave is closer to a **Kubernetes Job manifest** or a
**CI workflow** than to Terraform. You *declaratively submit and verify* a run —
you do not declare a desired end-state and reconcile to it. Agent runs are
probabilistic and one-shot; there is no idempotent convergence. So Loom is
declarative **submission + verification**, not declarative **outcome**.

### When it grows up

Loom is meant to become the **common contract for running an agent on a task** —
the "Ansible playbook for agents":

- **Agent-agnostic** — the same Weave runs on Claude Code, Codex, Pi, Gemini,
  Aider, opencode, or any CLI that takes a prompt and exits. The `goal` is just
  text; the executor is pluggable.
- **Runtime-agnostic** — `runtime.provider` selects *where* it runs: GitVM
  microVMs today; Docker, e2b, and Daytona are the roadmap. Swap the backend
  without touching the task.
- **Runs anywhere** — one format that xNAUT's UI, a headless `loom` CLI, and CI
  all execute identically. Write once, run in any context.
- **Composable** — Weaves as building blocks: fan out a swarm, chain steps,
  gate on acceptance.
- **Verifiable & auditable** — sandbox isolation + acceptance checks + a
  recorded report make agent work reproducible and inspectable, not "I ran an
  agent and it did stuff."

### Where it is today

Honest status: the **Weave format is stable and portable.** The **runner ships
inside [xNAUT](https://github.com/48Nauts-Operator/xNaut)** (`nautloom.rs`) and
currently executes **Claude Code / Codex** on **GitVM** sandboxes. A standalone
`loom` CLI, more executors, and pluggable runtimes are the roadmap (see
[Roadmap](#roadmap)). This repo is the spec, examples, and reference runner that
get there — the format is real now; the "runs anywhere, any agent" vision is
being built.

## The Weave format

```json
{
  "spec": "nautloom/v1",
  "kind": "Weave",
  "metadata": { "name": "build-verify", "description": "…", "author": "…", "version": 1 },
  "runtime": {
    "provider": "gitvm",
    "template": "agent-desktop",
    "resources": { "vcpus": 4, "memoryMB": 8192, "ttl": 21600 },
    "tools": []
  },
  "intent": { "goal": "…what the agent should do…", "inputs": [] },
  "steps": [],
  "acceptance": [],
  "report": { "include": ["summary", "tests", "video"], "to": "agentic" }
}
```

| Field | Meaning |
|---|---|
| `spec` / `kind` | Always `nautloom/v1` / `Weave`. |
| `metadata` | Name, description, author, version. |
| `runtime` | Where it runs: `provider` (`gitvm`), sandbox `template`, `resources` (vcpus / memoryMB / ttl seconds), optional `tools`. |
| `intent` | `goal` (the task, pushed to the agent) + optional `inputs`. |
| `steps` | Optional ordered sub-steps; empty = the goal is run in one pass. |
| `acceptance` | Optional checks that define "done" (e.g. tests pass). |
| `report` | What to hand back: `include` (`summary` / `tests` / `video`) and `to`. |

The full JSON Schema is in [`schema/weave.schema.json`](schema/weave.schema.json).

## Run lifecycle

```
Weave (*.loom.json)
   │
   ├─ 1. spin an isolated sandbox (GitVM agent-desktop microVM)
   ├─ 2. sync the working dir + goal into the sandbox
   ├─ 3. run the agent (claude / codex) — live streamed, secret-redacted log
   ├─ 4. check acceptance (tests / criteria)
   ├─ 5. pull the code back, ship: branch + PR
   └─ 6. report: summary · test results · session video
```

The agent step is [`runner/agent-runner.sh`](runner/agent-runner.sh) — the
reference runner. It launches the coding CLI in a `tmux` session, streams a
readable log, and redacts credentials before anything is persisted.

## Examples

Real weaves in [`examples/`](examples/):

| Weave | What it does |
|---|---|
| `blank.loom.json` | No template — your instructions go to the agent verbatim. |
| `quick-run.loom.json` | A fast single-pass run. |
| `build-verify.loom.json` | Build the change and verify it before shipping. |
| `ui-record.loom.json` | Exercise a UI and record the session. |
| `swarm.loom.json` | Fan a task across parallel runs. |

## Runtime — GitVM

Weaves run on **GitVM**, a Firecracker microVM sandbox substrate. The default
`agent-desktop` template is an Ubuntu + Xfce desktop with a screen recorder and
the `claude` / `codex` CLIs — so a run is isolated, watchable (noVNC), and
recorded. One sandbox per working directory; parallel runs use one git worktree
each.

## Roadmap

- [ ] **`loom-core`** — extract the runner into a standalone crate that both
  xNAUT and the CLI share (no divergent runners).
- [ ] **Standalone `loom` CLI** — `loom run weave.json`, outside xNAUT.
- [ ] **More executors** — Pi, Gemini, Aider, opencode; config-driven so any
  headless CLI drops in.
- [ ] **Pluggable runtimes** — Docker, e2b, and Daytona alongside GitVM.
- [ ] **Composable weaves** — chaining + swarm fan-out as first-class.
- [ ] Weave registry + versioning.

## Related

- [xNAUT](https://github.com/48Nauts-Operator/xNaut) — the native terminal /
  agent cockpit that Loom ships inside today.
- [xnaut.dev](https://xnaut.dev) — product site.

## License

MIT © 2026 André Wolke, 48Nauts. See [LICENSE](LICENSE).
