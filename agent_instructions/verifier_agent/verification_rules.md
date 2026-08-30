# AI Verification & Anti-Hallucination Guardrails

This policy defines the evaluation rubric executed by the **AI Verifier Agent** before any primary agent report can be posted to PR comments or executed in CI/CD.

---

## 🔍 Verification Dimensions

| Dimension | Ground Truth Anchor | Failure Trigger (Hallucination) | Penalty |
| :--- | :--- | :--- | :--- |
| **Resource Existence** | Terraform `resource_changes[].address` | AI mentions resources not found in AST (e.g. `aws_rds_cluster.auth`) | **-35% & Hard Block** |
| **Action Fidelity** | Terraform `resource_changes[].change.actions` | AI claims "DELETE" when action is only `["update"]` or `["create"]` | **-30% & Hard Block** |
| **CVE Authenticity** | Trivy `Results[].Vulnerabilities[].VulnerabilityID` | Invented CVE numbers or hallucinated CVSS scores | **-40% & Hard Block** |
| **Log Line Fidelity** | Raw CI Build Logs | AI quotes line numbers or compiler errors not present in logs | **-25%** |
| **Blast Radius Math** | Calculated Resource Weights | Score formula mismatch (e.g. 10/10 given for low-risk tags) | **-20%** |

---

## 🚦 Gate Verdict Logic

- **🟢 APPROVED**:
  - `verification_passed == true`
  - `factual_accuracy_score >= 90`
  - `hallucinated_claims_count == 0`
  - Action: Automatically post report to Pull Request and proceed with pipeline.

- **🔴 REJECTED**:
  - `verification_passed == false`
  - `factual_accuracy_score < 90` or `hallucinated_claims_count > 0`
  - Action: Abort automated merge, alert SRE on-call / DevSecOps team, attach side-by-side audit report to GitHub Step Summary.
