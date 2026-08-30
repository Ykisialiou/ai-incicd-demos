#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Demo 1: Terraform Plan & State Analyzer Runner (100% Live)
# ------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TF_DIR="$SCRIPT_DIR/terraform"
PLAN_FILE="$TF_DIR/tfplan"
PLAN_JSON="$TF_DIR/plan.json"

echo "================================================================================"
echo " 🚀 DEMO 1: AI Agent in CI/CD — Terraform Plan & Blast Radius Analyzer"
echo "================================================================================"
echo ""
echo "Step 1: Generating real Terraform plan..."

cd "$TF_DIR"
terraform init -backend=false -input=false
terraform plan -out="$PLAN_FILE" -input=false
terraform show -json "$PLAN_FILE" > "$PLAN_JSON"
echo "✅ Real Terraform plan JSON generated ($(wc -c < "$PLAN_JSON") bytes)"
cd "$PROJECT_ROOT"

export GEMINI_API_KEY="${GEMINI_API_KEY:-${AGY_API_KEY:-}}"
export AGY_API_KEY="${AGY_API_KEY:-${GEMINI_API_KEY:-}}"
export GOOGLE_API_KEY="${GOOGLE_API_KEY:-${GEMINI_API_KEY:-}}"

# Configure agy settings
mkdir -p "$HOME/.gemini/antigravity-cli" "$HOME/.antigravity" 2>/dev/null || true
echo '{"modelProvider":"gemini","model":"Gemini 3.5 Flash (Low)","defaultModel":"Gemini 3.5 Flash (Low)"}' > "$HOME/.gemini/antigravity-cli/settings.json" 2>/dev/null || true
echo '{"modelProvider":"gemini","model":"Gemini 3.5 Flash (Low)","defaultModel":"Gemini 3.5 Flash (Low)"}' > "$HOME/.antigravity/settings.json" 2>/dev/null || true

echo ""
echo "Step 2: Invoking Official Antigravity AI Agent (agy) with live plan.json..."
echo "--------------------------------------------------------------------------------"

SYSTEM_PROMPT_FILE="$PROJECT_ROOT/agent_instructions/terraform_analyzer_agent/system_prompt.md"

ANALYSIS_PROMPT="System Instructions:
$(cat "$SYSTEM_PROMPT_FILE")

Task:
Perform full SRE and security analysis on this Terraform plan. Evaluate destructive replacements, security group ingress, blast radius score, and state gate decision.

Input Plan JSON:
$(cat "$PLAN_JSON")"

agy --model "Gemini 3.5 Flash (Low)" -p "$ANALYSIS_PROMPT" --dangerously-skip-permissions --log-file agy_debug.log || {
  echo "=== AGY DEBUG LOG ==="
  cat agy_debug.log || true
}

echo ""
echo "Step 3: Generating Live CAB / Change Management Release Notification Email..."
echo "--------------------------------------------------------------------------------"

CAB_PROMPT_FILE="$PROJECT_ROOT/agent_instructions/terraform_analyzer_agent/cab_email_template.md"

CAB_PROMPT="System Instructions:
$(cat "$CAB_PROMPT_FILE")

Task:
Generate an executive Change Management / CAB approval email based on this Terraform plan. Highlight scheduled release window, business summary of changes, downtime risk, and rollback procedure.

Input Plan JSON:
$(cat "$PLAN_JSON")"

agy --model "Gemini 3.5 Flash (Low)" -p "$CAB_PROMPT" --dangerously-skip-permissions

echo ""
echo "Step 4: AI Agent Generating Live Change Management RFC & Publishing to Notion..."
echo "--------------------------------------------------------------------------------"

RFC_PROMPT="You are an enterprise SRE Lead and Change Advisory Board (CAB) Lead.
Based on the following live Terraform plan JSON, generate a formal, complete, production-ready Change Management RFC (Request For Comments) markdown document.

Structure the RFC with the following exact sections:
1. Title line with # RFC-20260831-01: Production Infrastructure Release
2. Header with Status: PENDING_CAB_REVIEW, Target Window: Next Maintenance Window, Author: SRE AI Automation Agent
3. Metadata & Approvals Table (Service Affected, Environment, Risk Level, Blast Radius Score out of 10, Expected Downtime, Required Reviewers)
4. Executive Summary & Business Justification
5. Detailed Infrastructure Changes Table (Resource Name, Provider Type, Action [CREATE/UPDATE/REPLACE/DESTROY], SRE Blast Radius & Risk)
6. Critical Warnings (Highlight any destructive database recreations, DNS scope creep, or open security groups)
7. Rollback & Contingency Plan (Specific triggers, rollback command, and database snapshot recovery steps)
8. Post-Release Verification Checklist (Checkbox list with verification steps, e.g. Datadog dashboards, smoke tests, security group audits)

=== [INPUT TERRAFORM PLAN JSON] ===
$(cat "$PLAN_JSON")"

LIVE_RFC_FILE="$SCRIPT_DIR/live_generated_rfc.md"
agy --model "Gemini 3.5 Flash (Low)" -p "$RFC_PROMPT" --dangerously-skip-permissions > "$LIVE_RFC_FILE"

python3 "$SCRIPT_DIR/publish_notion_rfc.py" --input "$LIVE_RFC_FILE"

echo ""
echo "================================================================================"
echo " ✅ Demo 1 complete! Live plan evaluated & real RFC published to Notion."
echo "================================================================================"
