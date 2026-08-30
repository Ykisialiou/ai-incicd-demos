#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Demo 3: CI/CD Build Failure Doctor Runner
# ------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SAMPLE_DIR="$SCRIPT_DIR/sample_broken_pipeline"
LOG_FILE="$SAMPLE_DIR/broken_build_output.log"

echo "================================================================================"
echo " 🩺 DEMO 3: AI Agent in CI/CD — Build Failure Doctor & Log Root Cause Analyzer"
echo "================================================================================"
echo ""
echo "Step 1: Simulating CI build step failure and capturing raw console log..."

# Run simulated broken build if log file doesn't exist
if [ ! -f "$LOG_FILE" ]; then
  echo "Running broken build reproduction..."
  bash "$SAMPLE_DIR/broken_build.sh" > "$LOG_FILE" 2>&1 || true
fi

echo "Captured failed CI build log ($(wc -l < "$LOG_FILE" | tr -d ' ') lines):"
echo "--------------------------------------------------------------------------------"
head -n 15 "$LOG_FILE"
echo "..."
tail -n 10 "$LOG_FILE"
echo "--------------------------------------------------------------------------------"

echo ""
echo "Step 2: Intercepting failure and invoking Build Doctor Agent..."
echo "--------------------------------------------------------------------------------"

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

  # Fallback to local runner if agy binary not present or failed authentication
  if [ -z "$output" ]; then
    output=$(echo "$input_payload" | "$PROJECT_ROOT/bin/agy" --system-prompt "$system_prompt_file" --prompt "$task_prompt")
  fi

  echo "$output"
}

SYSTEM_PROMPT="$PROJECT_ROOT/agent_instructions/build_doctor_agent/system_prompt.md"

call_agent "$SYSTEM_PROMPT" \
  "A CI/CD pipeline step just failed with exit code 1. Analyze this raw log, filter out irrelevant download/build noise, pinpoint the exact failing line and root cause, and provide a clear 1-2-3 fix for the engineer." \
  "$(cat "$LOG_FILE")"

echo ""
echo "================================================================================"
echo " ✅ Demo 3 complete! Diagnostic report ready for PR comment or Slack alert."
echo "================================================================================"
