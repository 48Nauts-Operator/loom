# Loom

**A declarative format for deploying a coding agent as a repeatable run.**

A *Weave* (`*.loom.json`, spec `nautloom/v1`) describes one agent run in a fixed
shape — the sandbox it runs in, the goal, the steps, what "done" means, and what
to report back. Loom takes that Weave, runs the agent in an isolated sandbox,
checks the acceptance criteria, and ships the result (branch + PR).

Think of a Weave as a *manifest for an agent run* — the way a Kubernetes
manifest describes a deployment, a Weave describes an agentic task.

> **Status:** the Weave **format** is stable and portable. The **runner**
> currently ships inside [xNAUT](https://github.com/48Nauts-Operator/xNaut)
> (`nautloom.rs`) and drives runs through [GitVM](https://xnaut.dev) sandboxes.
> A standalone `loom` CLI (`loom run weave.json`) is the roadmap — see
> [Roadmap](#roadmap). This repo is the spec, examples, and reference runner.

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

- [ ] Standalone `loom` CLI — `loom run weave.json` outside xNAUT.
- [ ] Pluggable runtimes beyond GitVM (local Docker, other microVM providers).
- [ ] Weave registry + versioning.

## Related

- [xNAUT](https://github.com/48Nauts-Operator/xNaut) — the native terminal /
  agent cockpit that Loom ships inside today.
- [xnaut.dev](https://xnaut.dev) — product site.

## License

MIT © 2026 André Wolke, 48Nauts. See [LICENSE](LICENSE).
