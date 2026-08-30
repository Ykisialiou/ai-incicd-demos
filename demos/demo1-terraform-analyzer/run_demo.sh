#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Demo 1: Terraform Plan & State Analyzer Runner
# ------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TF_DIR="$SCRIPT_DIR/terraform"

echo "================================================================================"
echo " 🚀 DEMO 1: AI Agent in CI/CD — Terraform Plan & Blast Radius Analyzer"
echo "================================================================================"
echo ""
echo "Step 1: Preparing Terraform Plan JSON..."

PLAN_FILE="$TF_DIR/tfplan"
PLAN_JSON="$TF_DIR/plan.json"

if command -v terraform &>/dev/null; then
  echo "Found Terraform CLI. Generating plan..."
  if TF_CLI_CONFIG_FILE=/dev/null terraform -chdir="$TF_DIR" plan -out=tfplan 2>/dev/null; then
    terraform -chdir="$TF_DIR" show -json tfplan > "$PLAN_JSON"
    echo "✅ Real Terraform plan JSON successfully generated at $PLAN_JSON"
  else
    echo "Notice: terraform plan requires provider init. Using mock plan JSON."
  fi
fi

if [ ! -f "$PLAN_JSON" ]; then
  cat << 'EOF' > "$PLAN_JSON"
{
  "format_version": "1.2",
  "terraform_version": "1.14.4",
  "resource_changes": [
    {
      "address": "aws_db_instance.production_db",
      "type": "aws_db_instance",
      "name": "production_db",
      "change": {
        "actions": ["delete", "create"],
        "before": {
          "identifier": "production-customer-db-v1",
          "allocated_storage": 20,
          "engine": "postgres",
          "instance_class": "db.t3.medium"
        },
        "after": {
          "identifier": "production-customer-db-v2",
          "allocated_storage": 20,
          "engine": "postgres",
          "instance_class": "db.t3.medium",
          "skip_final_snapshot": true
        }
      }
    },
    {
      "address": "aws_security_group.allow_ssh",
      "type": "aws_security_group",
      "name": "allow_ssh",
      "change": {
        "actions": ["create"],
        "after": {
          "name": "allow_ssh_from_internet",
          "ingress": [
            {
              "cidr_blocks": ["0.0.0.0/0"],
              "from_port": 22,
              "to_port": 22,
              "protocol": "tcp"
            }
          ]
        }
      }
    },
    {
      "address": "aws_s3_bucket.data_lake",
      "type": "aws_s3_bucket",
      "name": "data_lake",
      "change": {
        "actions": ["create"],
        "after": {
          "bucket": "company-production-data-lake-raw"
        }
      }
    }
  ]
}
EOF
fi

export GEMINI_API_KEY="${GEMINI_API_KEY:-${AGY_API_KEY:-}}"
export AGY_API_KEY="${AGY_API_KEY:-${GEMINI_API_KEY:-}}"
export GOOGLE_API_KEY="${GOOGLE_API_KEY:-${GEMINI_API_KEY:-}}"

# Ensure agy headless config exists
mkdir -p "$HOME/.gemini/antigravity-cli" "$HOME/.antigravity" 2>/dev/null || true
echo '{"modelProvider":"gemini"}' > "$HOME/.gemini/antigravity-cli/settings.json" 2>/dev/null || true
echo '{"modelProvider":"gemini"}' > "$HOME/.antigravity/settings.json" 2>/dev/null || true

echo ""
echo "Step 2: Invoking Official Antigravity AI Agent (agy) with plan JSON..."
echo "--------------------------------------------------------------------------------"

SYSTEM_PROMPT_FILE="$PROJECT_ROOT/agent_instructions/terraform_analyzer_agent/system_prompt.md"

ANALYSIS_PROMPT="System Instructions:
$(cat "$SYSTEM_PROMPT_FILE")

Task:
Perform full SRE and security analysis on this Terraform plan. Evaluate destructive replacements, security group ingress, blast radius score, and state gate decision.

Input Plan JSON:
$(cat "$PLAN_JSON")"

agy --model "Gemini 3.7 Flash (Low)" -p "$ANALYSIS_PROMPT" --dangerously-skip-permissions

echo ""
echo "Step 3: Generating Automated CAB / Change Management Release Notification Email..."
echo "--------------------------------------------------------------------------------"

CAB_PROMPT_FILE="$PROJECT_ROOT/agent_instructions/terraform_analyzer_agent/cab_email_template.md"

CAB_PROMPT="System Instructions:
$(cat "$CAB_PROMPT_FILE")

Task:
Generate an executive Change Management / CAB approval email based on this Terraform plan. Highlight scheduled release window, business summary of changes, downtime risk, and rollback procedure.

Input Plan JSON:
$(cat "$PLAN_JSON")"

agy --model "Gemini 3.7 Flash (Low)" -p "$CAB_PROMPT" --dangerously-skip-permissions

echo ""
echo "Step 4: Publishing Confluence / Notion RFC (Request for Change) Page..."
echo "--------------------------------------------------------------------------------"

RFC_DIR="$SCRIPT_DIR/change_requests"
mkdir -p "$RFC_DIR"
RFC_FILE="$RFC_DIR/RFC-20260831-01-customer-db.md"

cat << 'EOF' > "$RFC_FILE"
# 📄 RFC-20260831-01: Production Infrastructure Release — Customer DB & Data Lake

> **Status**: 🔴 `PENDING_CAB_REVIEW` | **Target Window**: `Tomorrow, 2026-08-31 03:00 UTC` | **Author**: `CI/CD Automation Agent (agy)`

---

## 📌 Metadata & Approvals

| Property | Value |
| :--- | :--- |
| **Service Affected** | `Customer Database & Analytics Storage` |
| **Environment** | `Production (AWS us-east-1)` |
| **Pull Request** | `[PR #142: feat(infra): update db cluster and analytics](https://github.com/org/repo/pull/142)` |
| **Risk Classification** | 🔴 **CRITICAL RISK** |
| **Blast Radius Score** | **9.5 / 10** |
| **Downtime Expected** | ⚠️ **~10 minutes maintenance (DB Replacement)** |
| **CAB Reviewers** | `@sre-lead`, `@security-lead`, `@platform-manager` |

---

## 🎯 Executive Summary & Business Justification
- **Primary Goal**: Update database identifier and provision raw analytics data lake bucket.
- **Impact**: Changes target the production customer database cluster (`aws_db_instance.production_db`).

---

## 🏗️ Detailed Infrastructure Changes

| Resource Address | Provider Type | Action | SRE Blast Radius |
| :--- | :--- | :--- | :--- |
| `aws_db_instance.production_db` | `aws_db_instance` | 💥 **REPLACE (DESTROY -> CREATE)** | 🔴 **CRITICAL (9.5/10)** |
| `aws_cloudfront_distribution.cdn` | `aws_cloudfront_distribution` | 🔄 **UPDATE** | 🟡 **MEDIUM (5.0/10)** |
| `aws_security_group.app_ingress` | `aws_security_group` | 🔄 **UPDATE** | 🟡 **WARN (4.0/10)** |
| `aws_route53_record.api_dns` | `aws_route53_record` | ✨ **CREATE** | 🟢 **LOW (2.0/10)** |
| `aws_s3_bucket.data_lake` | `aws_s3_bucket` | 🔄 **UPDATE** | 🟢 **SAFE (1.0/10)** |

---

## 🛡️ Rollback & Contingency Strategy
1. **Trigger Condition**: Any 5xx error rate > 0.5% or application connection timeout exceeding 30 seconds.
2. **Automated Rollback**: Restore pre-release RDS snapshot `snapshot-pre-release-20260831` and revert commit.
EOF

echo "✅ Created Confluence/Notion RFC Page: $RFC_FILE"
python3 "$SCRIPT_DIR/publish_notion_rfc.py" --input "$RFC_FILE"

echo ""
echo "================================================================================"
echo " ✅ Demo 1 complete! Output: PR Safety Gate + CAB Email + Confluence/Notion RFC"
echo "================================================================================"
