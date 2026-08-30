#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Demo 4: AI Verifier & Fact-Checking Gate (LLM-as-a-Judge)
# Contrasts valid AI analysis vs hallucination detection & CI blocking
# ------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

CLI_CMD="$PROJECT_ROOT/bin/agy"

SYSTEM_PROMPT="$PROJECT_ROOT/agent_instructions/verifier_agent/system_prompt.md"
GROUND_TRUTH_TF="$PROJECT_ROOT/demos/demo1-terraform-analyzer/terraform/plan.json"
VALID_REPORT="$SCRIPT_DIR/sample_valid_report.md"
HALLUCINATED_REPORT="$SCRIPT_DIR/sample_hallucinated_report.md"

MODE="${1:-all}" # 'all', 'pass', or 'fail'

call_agent() {
  local system_prompt_file="$1"
  local task_prompt="$2"
  local input_payload="$3"

  local combined_prompt
  combined_prompt="$(cat << PROMPT_EOF
$(cat "$system_prompt_file")

=== TASK INSTRUCTIONS ===
$task_prompt

=== INPUT DATA ===
$input_payload
PROMPT_EOF
)"

  if command -v agy &>/dev/null; then
    # Official Google Antigravity CLI binary
    agy -p "$combined_prompt" --dangerously-skip-permissions 2>/dev/null || agy -p "$combined_prompt"
  else
    # Fallback to local python runner if agy CLI is not in PATH
    echo "$input_payload" | "$PROJECT_ROOT/bin/agy" --system-prompt "$system_prompt_file" --prompt "$task_prompt"
  fi
}

run_verification() {
  local title="$1"
  local report_file="$2"
  local expected_outcome="$3"

  echo "================================================================================"
  echo " 🧪 RUNNING: $title"
  echo "================================================================================"
  echo "Ground Truth: $GROUND_TRUTH_TF"
  echo "Candidate AI Report: $report_file"
  echo ""

  # Create combined verification payload
  local payload
  payload="$(cat << PAYLOAD
=== [GROUND TRUTH: RAW INPUT DATA] ===
$(cat "$GROUND_TRUTH_TF")

=== [AI GENERATED REPORT TO AUDIT] ===
$(cat "$report_file")
PAYLOAD
)"

  echo "🤖 Invoking AI Verifier Agent (LLM-as-a-Judge)..."
  local result_json
  result_json=$(call_agent "$SYSTEM_PROMPT" "Verify the candidate AI report against ground truth. Output strictly raw JSON." "$payload")

  echo ""
  echo "📊 Audit Evaluation Result:"
  echo "--------------------------------------------------------------------------------"
  echo "$result_json"
  echo "--------------------------------------------------------------------------------"

  local passed verdict score
  passed=$(echo "$result_json" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('verification_passed', False))" 2>/dev/null || echo "False")
  verdict=$(echo "$result_json" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('audit_verdict', 'UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")
  score=$(echo "$result_json" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('factual_accuracy_score', 0))" 2>/dev/null || echo "0")

  if [ "$passed" = "True" ] || [ "$passed" = "true" ]; then
    echo ""
    echo "🟢 [CI GATE PASSED] Verdict: $verdict | Accuracy Score: ${score}%"
    echo "✅ No hallucinations detected. Safe to publish to Pull Request & proceed with deployment."
    echo ""
  else
    echo ""
    echo "🔴 [CI GATE BLOCKED] Verdict: $verdict | Accuracy Score: ${score}%"
    echo "🚨 HALLUCINATION DETECTED: Pipeline execution halted. Notification dispatched to SRE on-call."
    echo ""
  fi
}

echo "################################################################################"
echo "  🛡️ DEMO 4: AI Verifier & Anti-Hallucination Gate in CI/CD (LLM-as-a-Judge)"
echo "################################################################################"
echo ""

if [ "$MODE" = "all" ] || [ "$MODE" = "pass" ]; then
  run_verification "Scenario 1: Grounded AI Analysis (Accurate & Verified)" "$VALID_REPORT" "PASS"
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "fail" ]; then
  run_verification "Scenario 2: Hallucinated AI Analysis (Fabricated DB & Fake CVE)" "$HALLUCINATED_REPORT" "FAIL"
fi

echo "================================================================================"
echo " 🏁 Verification Gate Demo Completed!"
echo "================================================================================"
