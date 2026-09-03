# Demo 4 — AI Verifier Gate (LLM-as-a-Judge)

A second agent audits the first one's report against the raw data it was written
from, and blocks anything it cannot ground.

The run has three stages:

1. A primary agent analyses `demo1`'s `plan.json` and writes a report.
2. `inject_hallucinations.py` forges a copy with known fabrications — invented
   resources, altered risk scores, claims the plan does not support — and records
   what it changed in a manifest.
3. The judge audits both copies against the original `plan.json`. It should
   approve the genuine one and reject the forged one.

Because the forgery manifest is an answer key, the judge is scored rather than
taken at its word: the demo reports which planted claims it caught and which it
missed.

The judge's rules are in
[`agent_instructions/verifier_agent/`](../../agent_instructions/verifier_agent/).

## Running

```bash
./demos/demo4-ai-verifier-gate/run_demo.sh
```

## Contents

| Path | What |
| :--- | :--- |
| `run_demo.sh` | Runs both agent passes and scores the judge |
| `inject_hallucinations.py` | Deterministically forges a tampered report and writes the answer key |
| `render_audit_table.py` | Scores the judge's verdicts against that answer key |

Ground truth for both passes is `demos/demo1-terraform-analyzer/terraform/plan.json`.
