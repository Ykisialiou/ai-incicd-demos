# Demo 4: AI Verifier & Anti-Hallucination Gate (LLM-as-a-Judge) 🛡️

This demo showcases how to introduce an independent **AI Fact-Checking Verifier** (Two-Pass Verification / LLM-as-a-Judge) into CI/CD pipelines to guarantee that AI-generated reports, risk scores, and PR comments are 100% grounded in raw telemetry data and free from hallucinations before reaching developers or SREs.

---

## 🎯 The Problem

1. **Hallucination Risk**: An AI agent might misinterpret an AST JSON, fabricate a non-existent database drop, invent a fictitious CVE, or propose dangerous commands.
2. **Trust & Governance Barrier**: Enterprise SRE and security teams require mathematical and factual verification gates before approving autonomous agent comments and actions in CI/CD.

---

## 💡 The Two-Pass Solution (LLM-as-a-Judge)

```
┌────────────────────────┐
│ Raw Ground Truth Data  │
│ (plan.json / Scan Log) │
└───────────┬────────────┘
            │
            ▼
┌────────────────────────┐
│ 1. AI Primary Agent    │ (Generates Risk Assessment / Fix Recommendation)
└───────────┬────────────┘
            │ Draft Report
            ▼
┌────────────────────────┐
│ 2. AI Verifier Agent   │ ◄── Cross-references draft against Raw Ground Truth Data
│ (LLM-as-a-Judge)       │
└───────────┬────────────┘
            │ Structured JSON Verdict
            ▼
┌──────────────────────────────────────────────┐
│ 3. CI/CD Gate Decision                       │
│    • Passed (Score >= 90%, 0 Hallucinations) ├─► ✅ Publish to PR / Step Summary
│    • Failed (Hallucinations detected)        ├─► ❌ Block Pipeline & Alert SRE
└──────────────────────────────────────────────┘
```

---

## 🚀 Running the Contrast Demo

You can run the full two-pass contrast demo locally or trigger it via GitHub Actions:

```bash
# Run both contrast scenarios (Pass vs Fail)
./demos/demo4-ai-verifier-gate/run_demo.sh

# Run only the valid verification pass
./demos/demo4-ai-verifier-gate/run_demo.sh pass

# Run only the hallucination detection block
./demos/demo4-ai-verifier-gate/run_demo.sh fail
```

---

## 📊 Evaluation Rubric & Outputs

- **Scenario 1 (Grounded Analysis)**:
  - Ground Truth: Real Terraform AST with RDS replacement & Security Group modification.
  - Candidate Report: Accurate analysis correctly identifying destructive actions.
  - **Verdict**: `🟢 APPROVED` | Accuracy: `99%` | Hallucinations: `0`
- **Scenario 2 (Hallucination Contrast)**:
  - Ground Truth: Real Terraform AST.
  - Candidate Report: Simulated ungrounded report claiming deletion of non-existent `aws_rds_cluster.payment_gateway` and fake `CVE-2024-99999`.
  - **Verdict**: `🔴 REJECTED` | Accuracy: `38%` | Caught Hallucinations: `3`
