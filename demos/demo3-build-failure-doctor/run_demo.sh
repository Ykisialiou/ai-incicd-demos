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

SYSTEM_PROMPT="$PROJECT_ROOT/agent_instructions/build_doctor_agent/system_prompt.md"

CLI_CMD="agy"
if ! command -v agy &>/dev/null; then
  CLI_CMD="$PROJECT_ROOT/bin/agy"
fi

cat "$LOG_FILE" | $CLI_CMD \
  --system-prompt "$SYSTEM_PROMPT" \
  --prompt "A CI/CD pipeline step just failed with exit code 1. Analyze this raw log, filter out irrelevant download/build noise, pinpoint the exact failing line and root cause, and provide a clear 1-2-3 fix for the engineer."

echo ""
echo "================================================================================"
echo " ✅ Demo 3 complete! Diagnostic report ready for PR comment or Slack alert."
echo "================================================================================"
