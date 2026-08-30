# Demo 1: Terraform Plan & State Blast Radius Analyzer

This demo illustrates an autonomous AI Agent embedded in a CI/CD pipeline evaluating a Pull Request that introduces infrastructure changes.

---

## 🎯 Demo Storyline & Scenario

1. **The Context**: A junior developer opens a Pull Request updating Terraform code.
2. **The Problem**:
   - The developer modified the database `identifier` from `production-customer-db-v1` to `production-customer-db-v2`. In Terraform/AWS, changing the RDS identifier forces a **destroy-then-recreate (`replace`)** operation, leading to catastrophic database loss and downtime.
   - The developer also added a security group opening SSH (`port 22`) to `0.0.0.0/0` (the entire internet).
3. **The AI Agent Solution**:
   - The CI pipeline runs `terraform plan` and exports the plan as JSON (`terraform show -json`).
   - The **Terraform Analyzer Agent** ingests the plan, calculates the **Blast Radius Score (9.5/10)**, flags the destructive database drop, catches the `0.0.0.0/0` ingress, and automatically sets the CI Gate to **BLOCKED** with a suggested HCL remediation patch.
   - **Enterprise Killer Feature**: The agent automatically drafts an executive **Change Advisory Board (CAB) / Change Management RFC Email** ready to send to operations (business summary, expected downtime, rollback steps, verification plan).

---

## 🚀 Running the Demo

Execute the demo script:
```bash
./demos/demo1-terraform-analyzer/run_demo.sh
```

### Optional: Live Antigravity Mode
To run against the live model instead of offline simulation:
```bash
export AGY_API_KEY="your-api-key-here"
./demos/demo1-terraform-analyzer/run_demo.sh
```

---

## 💰 Zero-Cost Architecture

This demo uses genuine Terraform HCL and AST schemas without incurring any cloud bills:
- `terraform/providers.tf` is configured with `skip_credentials_validation = true` and `skip_requesting_account_id = true`.
- `terraform plan` evaluates resource definitions and produces genuine AWS resource diffs locally with **\$0.00** AWS cost.

---

## 🎤 Presenter Talking Points

> *"Notice how the agent didn't just summarize what changed. It detected the subtle difference between an in-place update and a destructive replacement. In standard GitHub diffs, a 1-line change to `identifier` looks innocent. In reality, it drops the production database. The agent prevents this outage before `terraform apply` can ever run."*
