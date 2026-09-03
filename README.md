# AI Agents in CI/CD — Demos

Five scenarios where an agent reads real pipeline data and returns a decision:
a Terraform plan, a vulnerability scan, two build failures, and a report that
needs fact-checking.

| Demo | Scenario | What the agent gets |
| :--- | :--- | :--- |
| [1 — Terraform Plan Analyzer](./demos/demo1-terraform-analyzer/) | A PR renames an RDS identifier, opens a security group, and adds a reserved DNS record | `terraform show -json` output + an architecture policy |
| [2 — Trivy Scan Triage](./demos/demo2-trivy-security-analyzer/) | ~19 CVEs and 4 Dockerfile misconfigurations from one filesystem scan | Raw Trivy JSON |
| [3 — Build Failure Doctor](./demos/demo3-build-failure-doctor/) | A pre-flight integration check fails with HTTP 401; the secret is blamed, but `APP_ENV` defaulted to production | The failing build's console output |
| [3.1 — Context-Aware Build Doctor](./demos/demo3.1-context-aware-build-doctor/) | A Helm policy gate blames a template untouched for four months; the cause is a CI commit from two days earlier that deleted `Chart.lock` | The log **plus** `git log -p`, the PR diff, and the dependency state the run resolved |
| [4 — AI Verifier Gate](./demos/demo4-ai-verifier-gate/) | An agent's report is checked for fabrications before it reaches a PR | A candidate report + the raw data it claims to describe |

Demo 3 and demo 3.1 are a pair: the first has its answer buried in the log, the
second has no answer in the log at all.

## Layout

```
agent_instructions/     System prompts, policies, and output templates per agent
demos/                  One folder per scenario: input data + run_demo.sh
scripts/                Output guards used by the runners and the workflows
.github/workflows/      The same demos, wired as pipelines
```

Every demo runs the same way:

```bash
./demos/<demo-folder>/run_demo.sh
```

Agents are invoked headlessly through the Claude Code CLI:

```bash
npm install -g @anthropic-ai/claude-code
claude auth login            # or: export ANTHROPIC_API_KEY="sk-ant-..."
```

```bash
claude -p --model claude-sonnet-5 --output-format text \
  --tools "" --setting-sources "" \
  --system-prompt "$AGENT_SYSTEM_PROMPT" < prompt.txt
```

`--tools ""` and `--setting-sources ""` keep the run hermetic; the explicit
`--system-prompt` replaces Claude Code's agentic default, which otherwise primes
the model to reach for tools it does not have and narrate the call instead of
answering. `scripts/validate_agent_output.py` fails the step when that happens
anyway.
