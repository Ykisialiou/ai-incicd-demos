# Demo 1 — Terraform Plan Analyzer

A pull request changes infrastructure. An agent reviews the `terraform plan` JSON
before anything is applied.

The plan contains five resources chosen so that a linter and the agent disagree
in every possible direction:

| Resource | Linter | Agent | Why |
| :--- | :--- | :--- | :--- |
| `aws_security_group.app_ingress` | bad | bad | `0.0.0.0/0` — linters are good at this |
| `aws_db_instance` (renamed identifier) | quiet | critical | Renaming an RDS identifier forces destroy-and-recreate |
| `aws_route53_record.api_v2_dns` | fine | critical | Additive record, but the domain is reserved in the policy registry |
| `aws_s3_bucket.data_lake` | hardening | critical | Claims SOC2 scope, implements none of its controls |
| `aws_s3_bucket.ci_scratch` | 8 findings | low | Same findings, but ephemeral CI bucket with no customer data |
| `aws_eip.orphaned_nat` | silent | medium | Nothing exposed; just billed hourly for nothing |

The agent's context is the plan JSON plus
[`architecture_policy.md`](../../agent_instructions/terraform_analyzer_agent/),
which is where the domain registry and the de-escalation rules live.

## Running

```bash
./demos/demo1-terraform-analyzer/run_demo.sh
```

## Contents

| Path | What |
| :--- | :--- |
| `terraform/` | The Terraform config and the generated `plan.json` |
| `run_demo.sh` | Runs `terraform plan`, then the agent over the plan JSON |
| `publish_notion_rfc.py` | Optional: publishes the generated CAB/RFC to Notion |

Regenerate the plan by hand:

```bash
terraform -chdir=demos/demo1-terraform-analyzer/terraform init -backend=false
terraform -chdir=demos/demo1-terraform-analyzer/terraform plan -out=tfplan
terraform -chdir=demos/demo1-terraform-analyzer/terraform show -json tfplan > demos/demo1-terraform-analyzer/terraform/plan.json
```
