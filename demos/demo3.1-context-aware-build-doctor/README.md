# Demo 3.1 — Context-Aware Build Doctor

A failure whose cause is not in the log at any line.

Priya bumps the payments image tag from `1.8.2` to `1.9.0`. Three lines, no
templates. The chart-validate job goes red:

```
+ helm lint charts/payments
1 chart(s) linted, 0 chart(s) failed

+ helm template payments charts/payments --namespace payments > rendered.yaml
helm template exit code: 0

+ timeout 300 python3 ci/policy_gate.py rendered.yaml
POLICY FAIL  charts/payments/templates/deployment.yaml  container "payments": resources.limits.memory is not set
POLICY FAIL  charts/payments/templates/deployment.yaml  container "payments": resources.limits.cpu is not set
```

The rendered Deployment has `resources:` and nothing under it. The gate names
`templates/deployment.yaml` — untouched for four months, and not in Priya's diff.
`helm lint` passed. `helm template` exited 0. Nothing warned about anything.

## What actually happened

| When | What | Who |
| :--- | :--- | :--- |
| 4 months ago | Chart written against `acme-common` 2.3.1, pinned in `Chart.lock` | Marta Lind |
| 2 days ago | `chore(ci): stop committing Chart.lock` — deletes the lockfile, gitignores it, and loosens the range to `^2.3.0` | Platform Bot |
| last night | `acme-common` 2.4.0 published: container settings move from `.Values.resources` to `.Values.container.resources` | upstream |
| 2 hours ago | Priya's PR is the first run to resolve the range freshly | Priya Nair |

`values.yaml` still sets `resources:` at the top level. The 2.4.0 helper reads
`.Values.container.resources`. `container` exists (it has `port`), so the lookup
returns nil rather than erroring, `with` skips the block, and Helm renders the
key with an empty body. Valid YAML, accepted by Kubernetes, no limits.

Three properties make this the interesting case:

1. **The answer is absent from the log.** `helm dependency update` prints that it
   downloaded something, never which version it settled on.
2. **The obvious fix is harmful.** Hardcoding `resources:` into
   `templates/deployment.yaml` turns the gate green and leaves every other
   service on `acme-common` rendering without limits, undiagnosed.
3. **There is a lag.** The culprit commit was green when it merged, which is
   exactly why nobody suspects it.

Solving it requires correlating the log against `git log`, the PR diff, and what
the run actually resolved. The verdict is an attribution: the branch is innocent,
the culprit commit and its author are named, and the tempting fix is refused.

Rules and verdict format:
[`agent_instructions/build_doctor_agent/`](../../agent_instructions/build_doctor_agent/)
(`blame_correlation_rules.md`, `regression_verdict_template.md`).

## Running

```bash
./demos/demo3.1-context-aware-build-doctor/run_demo.sh
```

Needs `helm` (the chart is rendered for real) plus the `claude` CLI.

The run makes the same model answer twice — once with the log alone (~8 KB of
context), once with the history attached (~22 KB). Between them it prints the
log-only baseline: an actual sweep over the captured log, reporting where it
lands. It ends by **proving** the diagnosis rather than asserting it — pinning
`acme-common` back to 2.3.1, re-rendering, and putting the result past the same
gate, which passes with Priya's branch untouched.

## What is real

| Stage | Real or reproduced |
| :--- | :--- |
| The git history | **Real** — an actual repo with 6 backdated commits, built at run time |
| `helm lint`, `helm template`, the rendered manifest | **Real** — the empty `resources:` block is genuinely what Helm produced |
| The policy gate and its verdict | **Real** |
| The log-only baseline sweep | **Real** — regex over the captured log |
| Both agent passes | **Real** model calls |
| `helm dependency update` resolving `^2.3.0` → 2.4.0 | **Simulated** — there is no charts.acme.io; `registry/` stands in for it and the lockfile Helm would have written is written for it |

## Contents

| Path | What |
| :--- | :--- |
| `build_repo_history.sh` | Builds the real git repo, the chart, and the policy gate |
| `registry/` | The stand-in chart repository: `acme-common` 2.3.1 and 2.4.0 |
| `failing_ci_run.sh` | Runs the chart-validate job — real helm, real gate, exits 1 |
| `collect_context.py` | Log-only baseline, then assembles the evidence pack |
| `run_demo.sh` | Orchestrates all of it, both agent passes, and the proof |

Poke at the fixture after a run:

```bash
git -C demos/demo3.1-context-aware-build-doctor/.workspace/repo log -p -- charts/payments/Chart.lock
```
