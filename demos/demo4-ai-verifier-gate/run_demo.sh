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

  # Configure agy settings for API key authentication
  local api_key="${GEMINI_API_KEY:-${AGY_API_KEY:-}}"
  if [ -n "$api_key" ]; then
    export GEMINI_API_KEY="$api_key"
    export AGY_API_KEY="$api_key"
    mkdir -p "$HOME/.gemini/antigravity-cli" "$HOME/.antigravity" 2>/dev/null || true
    echo '{"modelProvider":"gemini"}' > "$HOME/.gemini/antigravity-cli/settings.json" 2>/dev/null || true
    echo '{"modelProvider":"gemini"}' > "$HOME/.antigravity/settings.json" 2>/dev/null || true
  fi

  local output=""
  if command -v agy &>/dev/null; then
    output=$(agy -p "$combined_prompt" --dangerously-skip-permissions 2>&1 || true)
    # Check if agy failed due to auth or timeout
    if echo "$output" | grep -qiE "authentication required|authentication failed|command not found|flag provided but not defined"; then
      output=""
    fi
  fi

  # Fallback to repo runner if agy binary not present or failed authentication
  if [ -z "$output" ]; then
    output=$(echo "$input_payload" | "$PROJECT_ROOT/bin/agy" --system-prompt "$system_prompt_file" --prompt "$task_prompt")
  fi

  echo "$output"
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

  local clean_json
  clean_json=$(echo "$result_json" | sed -e 's/^```json//g' -e 's/^```//g' -e 's/```$//g')

  local passed verdict score
  passed=$(echo "$clean_json" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('verification_passed', False))" 2>/dev/null || echo "False")
  verdict=$(echo "$clean_json" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('audit_verdict', 'UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")
  score=$(echo "$clean_json" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('factual_accuracy_score', 0))" 2>/dev/null || echo "0")

  if [ "$passed" = "True" ] || [ "$passed" = "true" ]; then
    echo ""
    echo "🟢 [CI GATE PASSED] Verdict: $verdict | Accuracy Score: ${score}%"
    echo "✅ Verification Approved: All claims factually grounded in raw plan.json."
    echo ""
  else
    echo ""
    echo "🔴 [CI GATE BLOCKED] Verdict: $verdict | Accuracy Score: ${score}%"
    echo "🚨 HALLUCINATIONS DETECTED BY AI AUDITOR:"
    echo "$clean_json" | python3 -c "import sys, json; data=json.load(sys.stdin); [print(f'   - ❌ {h}') for h in data.get('hallucinations_detected', [])]" 2>/dev/null || true
    echo ""
    echo "⛔ Pipeline execution halted. Report blocked from posting to PR."
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
