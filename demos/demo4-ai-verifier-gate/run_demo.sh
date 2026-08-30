#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Demo 4: AI Verifier & Fact-Checking Gate (LLM-as-a-Judge)
# Contrasts valid AI analysis vs hallucination detection & CI blocking
# ------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SYSTEM_PROMPT="$PROJECT_ROOT/agent_instructions/verifier_agent/system_prompt.md"
GROUND_TRUTH_TF="$PROJECT_ROOT/demos/demo1-terraform-analyzer/terraform/plan.json"
VALID_REPORT="$SCRIPT_DIR/sample_valid_report.md"
HALLUCINATED_REPORT="$SCRIPT_DIR/sample_hallucinated_report.md"

MODE="${1:-all}" # 'all', 'pass', or 'fail'

export GEMINI_API_KEY="${GEMINI_API_KEY:-${AGY_API_KEY:-}}"
export AGY_API_KEY="${AGY_API_KEY:-${GEMINI_API_KEY:-}}"
export GOOGLE_API_KEY="${GOOGLE_API_KEY:-${GEMINI_API_KEY:-}}"

# Ensure agy headless config exists
mkdir -p "$HOME/.gemini/antigravity-cli" "$HOME/.antigravity" 2>/dev/null || true
echo '{"modelProvider":"gemini"}' > "$HOME/.gemini/antigravity-cli/settings.json" 2>/dev/null || true
echo '{"modelProvider":"gemini"}' > "$HOME/.antigravity/settings.json" 2>/dev/null || true

run_verification() {
  local title="$1"
  local report_file="$2"

  echo "================================================================================"
  echo " 🧪 RUNNING: $title"
  echo "================================================================================"
  echo "Ground Truth: $GROUND_TRUTH_TF"
  echo "Candidate AI Report: $report_file"
  echo ""

  local payload
  payload="$(cat << PAYLOAD
=== [GROUND TRUTH: RAW INPUT DATA] ===
$(cat "$GROUND_TRUTH_TF")

=== [AI GENERATED REPORT TO AUDIT] ===
$(cat "$report_file")
PAYLOAD
)"

  local verifier_prompt
  verifier_prompt="System Instructions:
$(cat "$SYSTEM_PROMPT")

=== TASK INSTRUCTIONS ===
Verify the candidate AI report against ground truth. Output strictly raw JSON without markdown code blocks.

=== INPUT DATA ===
$payload"

  echo "🤖 Invoking Official Antigravity Verifier Agent (LLM-as-a-Judge)..."
  local result_json
  rm -f /tmp/agy_verifier.log
  result_json=$(agy --log-file /tmp/agy_verifier.log -p "$verifier_prompt" --dangerously-skip-permissions 2>&1 || true)
  if [ -f /tmp/agy_verifier.log ]; then
    echo "--- [DEBUG AGY LOG] ---"
    cat /tmp/agy_verifier.log
    echo "-----------------------"
  fi

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
  run_verification "Scenario 1: Grounded AI Analysis (Accurate & Verified)" "$VALID_REPORT"
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "fail" ]; then
  run_verification "Scenario 2: Hallucinated AI Analysis (Fabricated DB & Fake CVE)" "$HALLUCINATED_REPORT"
fi

echo "================================================================================"
echo " 🏁 Verification Gate Demo Completed!"
echo "================================================================================"
