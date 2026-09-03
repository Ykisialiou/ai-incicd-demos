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

# Claude Code CLI configuration
CLAUDE_MODEL="${CLAUDE_MODEL:-claude-sonnet-5}"

if ! command -v claude >/dev/null 2>&1; then
  echo "❌ claude CLI not found. Install it with: npm install -g @anthropic-ai/claude-code"
  exit 1
fi

# The CLI is what builds the API request, so an old one can emit a request shape
# current models reject (e.g. a 400 naming "thinking.type.enabled"). CI installs
# the latest on every run; a laptop can be many releases behind.
CLAUDE_CLI_VERSION="$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
CLI_MINOR="$(printf '%s' "${CLAUDE_CLI_VERSION:-0.0.0}" | cut -d. -f3)"
CLI_MAJOR_MINOR="$(printf '%s' "${CLAUDE_CLI_VERSION:-0.0.0}" | cut -d. -f1,2)"
if [ "$CLI_MAJOR_MINOR" = "2.1" ] && [ "${CLI_MINOR:-0}" -lt 100 ] 2>/dev/null; then
  echo "⚠️  claude CLI $CLAUDE_CLI_VERSION is well behind the release CI uses."
  echo "    If this run fails with a 400 mentioning \"thinking.type.enabled\", upgrade:"
  echo "      npm install -g @anthropic-ai/claude-code@latest"
  echo ""
fi

# Credentials: either an exported API key, or an interactive `claude auth login`
# session. Testing ANTHROPIC_API_KEY alone refuses to run for anyone signed in
# with a Claude subscription - the usual setup on a laptop.
if [ -z "${ANTHROPIC_API_KEY:-}" ] &&
   ! claude auth status --json 2>/dev/null | grep -q '"loggedIn"[[:space:]]*:[[:space:]]*true'; then
  echo "❌ No Anthropic credentials found. Do either:"
  echo "     claude auth login                        # sign in with your Anthropic account"
  echo "   or"
  echo "     export ANTHROPIC_API_KEY=\"sk-ant-...\"    # use an API key"
  exit 1
fi

# Headless invocation: prompt on stdin, no tools, plain text out.
# --system-prompt replaces Claude Code's agentic default; without it the CLI
# primes the model to reach for tools (e.g. "let me check project memory") and,
# with no tools available, it narrates the tool call instead of writing a report.
AGENT_SYSTEM_PROMPT="You are a non-interactive report generator running inside a CI pipeline. You have no tools, no filesystem access, and no memory, and you must never announce, narrate, or emit a tool call. Everything you need is in the user message. Respond with the finished document only."

run_claude() {
  # Cleared per variable, so the demo behaves the same on any machine:
  #   CLAUDECODE*        - the CLI refuses to nest inside a Claude Code session
  #   CLAUDE_EFFORT,     - ambient thinking/effort settings. An older CLI turns
  #   MAX_THINKING_TOKENS  these into the retired `thinking.type.enabled` request
  #                        shape, which current models reject with a 400.
  #   ANTHROPIC_MODEL    - would silently override the model this demo pins
  # --setting-sources "" covers settings FILES only; env vars are read separately,
  # which is why they have to be unset here as well.
  env -u CLAUDECODE -u CLAUDE_CODE_SSE_PORT -u CLAUDE_CODE_ENTRYPOINT \
      -u CLAUDE_EFFORT -u MAX_THINKING_TOKENS -u ANTHROPIC_MODEL \
    claude -p --model "$CLAUDE_MODEL" --output-format text \
      --tools "" --setting-sources "" \
      --system-prompt "$AGENT_SYSTEM_PROMPT"
}


echo ""
echo "Step 2: Claude Code agent reviewing the plan WITH architecture context..."
echo "--------------------------------------------------------------------------------"

AGENT_DIR="$PROJECT_ROOT/agent_instructions/terraform_analyzer_agent"

ANALYSIS_PROMPT="$(cat "$AGENT_DIR/system_prompt.md")

=== CORPORATE ARCHITECTURE & GOVERNANCE POLICY (source file: agent_instructions/terraform_analyzer_agent/architecture_policy.md) ===
$(cat "$AGENT_DIR/architecture_policy.md")

=== BLAST RADIUS CLASSIFICATION RULES (source file: agent_instructions/terraform_analyzer_agent/blast_radius_rules.md) ===
$(cat "$AGENT_DIR/blast_radius_rules.md")


=== TASK ===
Perform full SRE and security analysis on this Terraform plan. Evaluate destructive replacements, security group ingress, blast radius score, and state gate decision.

Fill BOTH verdict columns: the Static Verdict a standard IaC linter (tfsec/checkov/trivy config) would give - it reads attributes and catches open CIDRs, missing encryption and similar, but knows nothing of the policy above - and your contextual verdict after also applying that policy.

- Look up every DNS record name and every CloudFront alias in the Protected Domain Registry before scoring it.
- Where the two columns differ, name the rule or registry row that justifies it, citing the source file by the exact path in the section header above - never invent a filename.
- Where they agree, say so plainly. Do not manufacture risk to look thorough.
- Keep the whole report under 60 lines.

Input Plan JSON:
$(cat "$PLAN_JSON")"

REVIEW_FILE="$SCRIPT_DIR/terraform_review.md"
printf '%s' "$ANALYSIS_PROMPT" | run_claude | tee "$REVIEW_FILE"
python3 "$PROJECT_ROOT/scripts/strip_code_fence.py" "$REVIEW_FILE"
python3 "$PROJECT_ROOT/scripts/validate_agent_output.py" "$REVIEW_FILE" --min-bytes 400 --label "SRE review"

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

printf '%s' "$CAB_PROMPT" | run_claude

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
printf '%s' "$RFC_PROMPT" | run_claude > "$LIVE_RFC_FILE"
python3 "$PROJECT_ROOT/scripts/strip_code_fence.py" "$LIVE_RFC_FILE"
python3 "$PROJECT_ROOT/scripts/validate_agent_output.py" "$LIVE_RFC_FILE" --min-bytes 400 --label "RFC"

python3 "$SCRIPT_DIR/publish_notion_rfc.py" --input "$LIVE_RFC_FILE"

echo ""
echo "================================================================================"
if [ -n "${NOTION_API_KEY:-}" ]; then
  echo " ✅ Demo 1 complete! Live plan evaluated & RFC published to Notion."
else
  echo " ✅ Demo 1 complete! Live plan evaluated; RFC written to $LIVE_RFC_FILE."
  echo "    (export NOTION_API_KEY and NOTION_PAGE_ID to also publish it to Notion)"
fi
echo "================================================================================"
