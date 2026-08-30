#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Demo 2: Trivy Security Scan & Triage Runner (100% Live)
# ------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
APP_DIR="$SCRIPT_DIR/sample_app"
SCAN_JSON="$SCRIPT_DIR/trivy_scan.json"

echo "================================================================================"
echo " 🛡️ DEMO 2: AI Agent in CI/CD — Trivy Security Scan & Intelligent Triage"
echo "================================================================================"
echo ""
echo "Step 1: Running real Trivy security scan on sample_app..."

trivy fs --format json --output "$SCAN_JSON" "$APP_DIR"
echo "✅ Real Trivy scan JSON generated at $SCAN_JSON ($(wc -c < "$SCAN_JSON") bytes)"

export GEMINI_API_KEY="${GEMINI_API_KEY:-${AGY_API_KEY:-}}"
export AGY_API_KEY="${AGY_API_KEY:-${GEMINI_API_KEY:-}}"
export GOOGLE_API_KEY="${GOOGLE_API_KEY:-${GEMINI_API_KEY:-}}"

# Configure agy settings
mkdir -p "$HOME/.gemini/antigravity-cli" "$HOME/.antigravity" 2>/dev/null || true
echo '{"modelProvider":"gemini","model":"Gemini 3.5 Flash (Low)","defaultModel":"Gemini 3.5 Flash (Low)"}' > "$HOME/.gemini/antigravity-cli/settings.json" 2>/dev/null || true
echo '{"modelProvider":"gemini","model":"Gemini 3.5 Flash (Low)","defaultModel":"Gemini 3.5 Flash (Low)"}' > "$HOME/.antigravity/settings.json" 2>/dev/null || true

echo ""
echo "Step 2: Invoking Official Antigravity AI Agent (agy) to triage live findings..."
echo "--------------------------------------------------------------------------------"

SYSTEM_PROMPT_FILE="$PROJECT_ROOT/agent_instructions/trivy_security_agent/system_prompt.md"

FINAL_PROMPT="System Instructions:
$(cat "$SYSTEM_PROMPT_FILE")

Task:
Triage this raw Trivy security scan. Filter noise, identify root-cause fixes (like base image updates), highlight actionable CVEs, and generate copy-paste remediation diffs.

Input Trivy Scan JSON:
$(cat "$SCAN_JSON")"

agy --model "Gemini 3.7 Flash (Low)" -p "$FINAL_PROMPT" --dangerously-skip-permissions

echo ""
echo "================================================================================"
echo " ✅ Demo 2 complete! Live scan triaged by Antigravity AI agent."
echo "================================================================================"
