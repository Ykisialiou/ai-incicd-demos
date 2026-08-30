#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Demo 3: Build Doctor Failure Analyzer Runner (100% Live)
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
echo "Step 1: Executing broken build script and capturing real console logs..."

chmod +x "$SAMPLE_DIR/broken_build.sh"
set +e
bash "$SAMPLE_DIR/broken_build.sh" > "$LOG_FILE" 2>&1
BUILD_EXIT_CODE=$?
set -e

echo "✅ Real build executed with exit code $BUILD_EXIT_CODE ($(wc -l < "$LOG_FILE") lines captured)"

export GEMINI_API_KEY="${GEMINI_API_KEY:-${AGY_API_KEY:-}}"
export AGY_API_KEY="${AGY_API_KEY:-${GEMINI_API_KEY:-}}"
export GOOGLE_API_KEY="${GOOGLE_API_KEY:-${GEMINI_API_KEY:-}}"

# Configure agy settings
mkdir -p "$HOME/.gemini/antigravity-cli" "$HOME/.antigravity" 2>/dev/null || true
echo '{"modelProvider":"gemini","model":"Gemini 3.5 Flash (Low)","defaultModel":"Gemini 3.5 Flash (Low)"}' > "$HOME/.gemini/antigravity-cli/settings.json" 2>/dev/null || true
echo '{"modelProvider":"gemini","model":"Gemini 3.5 Flash (Low)","defaultModel":"Gemini 3.5 Flash (Low)"}' > "$HOME/.antigravity/settings.json" 2>/dev/null || true

echo ""
echo "Step 2: Invoking Official Antigravity AI Agent (agy) to diagnose live failure log..."
echo "--------------------------------------------------------------------------------"

SYSTEM_PROMPT_FILE="$PROJECT_ROOT/agent_instructions/build_doctor_agent/system_prompt.md"

FINAL_PROMPT="System Instructions:
$(cat "$SYSTEM_PROMPT_FILE")

Task:
A CI/CD pipeline step just failed with exit code $BUILD_EXIT_CODE. Analyze this raw log, filter out irrelevant download/build noise, pinpoint the exact failing line and root cause, and provide a clear 1-2-3 fix for the engineer.

Input Build Log:
$(cat "$LOG_FILE")"

agy --model "Gemini 3.7 Flash (Low)" -p "$FINAL_PROMPT" --dangerously-skip-permissions

echo ""
echo "================================================================================"
echo " ✅ Demo 3 complete! Root cause diagnosis generated live by AI agent."
echo "================================================================================"
