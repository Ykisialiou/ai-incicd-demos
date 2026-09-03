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

echo ""
echo "Step 1b: The captured log — the haystack the agent is handed..."
echo "--------------------------------------------------------------------------------"
python3 "$SCRIPT_DIR/summarize_build_log.py" \
  --input "$LOG_FILE" \
  --exit-code "$BUILD_EXIT_CODE" \
  --out "$SCRIPT_DIR/build_log_summary.md"

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
echo "Step 2: Invoking Claude Code agent (claude CLI) to diagnose live failure log..."
echo "--------------------------------------------------------------------------------"

SYSTEM_PROMPT_FILE="$PROJECT_ROOT/agent_instructions/build_doctor_agent/system_prompt.md"

FINAL_PROMPT="System Instructions:
$(cat "$SYSTEM_PROMPT_FILE")

Task:
A CI/CD pipeline step just failed with exit code $BUILD_EXIT_CODE. Analyze this raw log, filter out irrelevant download/build noise, pinpoint the exact failing line and root cause, and provide a clear 1-2-3 fix for the engineer.

Input Build Log:
$(cat "$LOG_FILE")"

printf '%s' "$FINAL_PROMPT" | run_claude

echo ""
echo "================================================================================"
echo " ✅ Demo 3 complete! Root cause diagnosis generated live by AI agent."
echo "================================================================================"
