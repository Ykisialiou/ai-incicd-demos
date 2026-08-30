# Agent Instructions Library

This directory contains production-grade system prompts, operational rules, and output schemas for AI agents embedded inside CI/CD pipelines.

## Agent Directory Overview

| Agent | Target CI/CD Event | Primary Objective | Output Format |
| :--- | :--- | :--- | :--- |
| **[Terraform Analyzer Agent](./terraform_analyzer_agent/)** | Pull Request / `terraform plan` | Detect destructive replacements, data loss, security misconfigurations (e.g. `0.0.0.0/0`), and assess blast radius. | PR Review Comment & Pipeline Safety Gate |
| **[Trivy Security Agent](./trivy_security_agent/)** | Vulnerability Scan / Image Build | Triage CVE noise, contextualize reachability/exploitability, provide instant copy-paste patch diffs. | Security Gate Decision & PR Triage Table |
| **[Build Doctor Agent](./build_doctor_agent/)** | CI Job Failure / Step Exit Code != 0 | Ingest massive failed build logs (500+ lines), pinpoint the exact failing line, root cause, and remediation command. | Incident / PR Comment & Fix Instructions |
| **[Verifier Agent (LLM-as-a-Judge)](./verifier_agent/)** | Pre-publication / Gate Evaluation | Audit primary agent reports against raw AST/logs, detect hallucinations, and score factual accuracy. | Strict JSON Audit Verdict & CI Gate Block |

---

## Design Principles for CI/CD Agents

1. **Deterministic Structure**: Output should follow predictable markdown sections and tables suitable for GitHub Step Summaries (`$GITHUB_STEP_SUMMARY`), GitLab CI reports, and PR comments.
2. **Actionability Over Verbosity**: SREs and developers do not want a generic 10-paragraph essay. Every finding must state:
   - **What** changed or failed
   - **Why** it matters (Blast radius / Risk)
   - **How** to fix it immediately (Code diff or CLI command)
3. **Strict Gate Verdicts**: Every analysis must conclude with an unambiguous verdict:
   - 🟢 `APPROVE` (Safe to merge/deploy)
   - 🟡 `WARN` (Non-blocking, but requires review)
   - 🔴 `BLOCK` (Hard gate failure, automated pipeline halt)

---

## Invocation Pattern

Agents are invoked via the official Google Antigravity CLI (`agy`):

```bash
# Example: Invoke agent with instructions and input data non-interactively
PROMPT="System Instructions:
$(cat agent_instructions/terraform_analyzer_agent/system_prompt.md)

Task:
Analyze this plan against production safety rules.

Input Plan JSON:
$(cat terraform_plan.json)"

agy -p "$PROMPT" --dangerously-skip-permissions
```
