#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Demo 3.1: Context-Aware Build Doctor - "your pull request is not the problem"
#
# Demo 3 gives the agent a log whose last few lines contain the answer. This one
# gives it a log whose answer is not in the log at any line. The policy gate is
# right, the file it names is right, and the file is innocent: the regression
# arrived two days earlier in a CI commit that deleted a lockfile, and reached
# this pipeline through a floating dependency range.
#
# The run has two agent passes, deliberately:
#   Pass 1 - the demo-3 agent. Same model, same task, log only.
#   Pass 2 - the same model, with the repository's real history attached.
#
# The difference between the two is the entire argument of this talk.
# ------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGENT_DIR="$PROJECT_ROOT/agent_instructions/build_doctor_agent"

WORKSPACE="$SCRIPT_DIR/.workspace"
REPO="$WORKSPACE/repo"
REGISTRY="$SCRIPT_DIR/registry"
LOG_FILE="$WORKSPACE/ci_run.log"
CHART="charts/payments"
CONTEXT_PACK="$SCRIPT_DIR/context_pack.md"
VERDICT_LOG_ONLY="$SCRIPT_DIR/verdict_log_only.md"
VERDICT_WITH_CONTEXT="$SCRIPT_DIR/verdict_with_context.md"

CLAUDE_MODEL="${CLAUDE_MODEL:-claude-sonnet-5}"

echo "################################################################################"
echo "  🧭 DEMO 3.1: Context-Aware Build Doctor — the answer is not in the log"
echo "################################################################################"
echo ""

# ------------------------------------------------------------------------------
# Preflight. Helm does the rendering for real, so it is a hard requirement.
# ------------------------------------------------------------------------------
if ! command -v helm >/dev/null 2>&1; then
  echo "❌ helm not found. This demo renders the chart for real."
  echo "   brew install helm    # or https://helm.sh/docs/intro/install/"
  exit 1
fi

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

# ------------------------------------------------------------------------------
# Step 1 - build the repository. Real git, real commits, real backdated history.
# ------------------------------------------------------------------------------
echo "Step 1: Building the repository under test (real git history)..."
echo "--------------------------------------------------------------------------------"
mkdir -p "$WORKSPACE"
bash "$SCRIPT_DIR/build_repo_history.sh" "$REPO"

echo ""
git -C "$REPO" log -n 6 --date=relative --format='  %h  %<(16)%ad  %<(14)%an  %s' main
echo "  ── branch feat/bump-payments-1.9.0 ──"
git -C "$REPO" log -n 1 --date=relative --format='  %h  %<(16)%ad  %<(14)%an  %s'
echo ""

# ------------------------------------------------------------------------------
# Step 2 - run the chart-validate job. Real helm, real policy gate.
# ------------------------------------------------------------------------------
PR_SHA="$(git -C "$REPO" log -1 --format=%h)"
PR_SUBJECT="$(git -C "$REPO" log -1 --format=%s)"

echo "Step 2: Running chart-validate for pull request #482..."
echo "--------------------------------------------------------------------------------"

set +e
PR_COMMIT_SHA="$PR_SHA" PR_COMMIT_SUBJECT="$PR_SUBJECT" \
  bash "$SCRIPT_DIR/failing_ci_run.sh" --repo "$REPO" --registry "$REGISTRY" \
  > "$LOG_FILE" 2>&1
BUILD_EXIT_CODE=$?
set -e

echo "  ❌ Pipeline failed with exit code $BUILD_EXIT_CODE ($(wc -l < "$LOG_FILE" | tr -d ' ') lines captured)"
echo "     helm lint: passed.  helm template: exit 0.  Only the policy gate objected."
echo ""

# ------------------------------------------------------------------------------
# Step 3 - the baseline. What the log alone supports, computed from the log.
# ------------------------------------------------------------------------------
echo "Step 3: Establishing the log-only baseline (no AI, just pattern matching)..."
echo "--------------------------------------------------------------------------------"
python3 "$SCRIPT_DIR/collect_context.py" \
  --log "$LOG_FILE" \
  --repo "$REPO" \
  --chart "$CHART" \
  --exit-code "$BUILD_EXIT_CODE" \
  --out "$CONTEXT_PACK"

# ------------------------------------------------------------------------------
# Step 4 - Pass 1: the demo-3 agent. Log in, diagnosis out, no history.
# ------------------------------------------------------------------------------
echo ""
echo "Step 4: PASS 1 — the demo-3 Build Doctor. Same model, log only."
echo "--------------------------------------------------------------------------------"

PASS1_PROMPT="System Instructions:
$(cat "$AGENT_DIR/system_prompt.md")

=== LOG FILTERING RULES (source: agent_instructions/build_doctor_agent/log_filtering_rules.md) ===
$(cat "$AGENT_DIR/log_filtering_rules.md")

=== OUTPUT TEMPLATE (source: agent_instructions/build_doctor_agent/fix_recommendation_template.md) ===
$(cat "$AGENT_DIR/fix_recommendation_template.md")

Task:
The chart-validate job failed with exit code $BUILD_EXIT_CODE on pull request #482. Diagnose the failure and give the engineer a fix. Keep it under 45 lines. No preamble, and do not wrap the whole response in a code fence.

=== INPUT PIPELINE LOG ===
$(cat "$LOG_FILE")"

printf '%s' "$PASS1_PROMPT" | run_claude | tee "$VERDICT_LOG_ONLY"
python3 "$PROJECT_ROOT/scripts/strip_code_fence.py" "$VERDICT_LOG_ONLY"
python3 "$PROJECT_ROOT/scripts/validate_agent_output.py" "$VERDICT_LOG_ONLY" \
  --min-bytes 300 --label "pass 1 (log only) diagnosis"

# ------------------------------------------------------------------------------
# Step 5 - Pass 2: same model, same failure, plus the repository's history.
# ------------------------------------------------------------------------------
echo ""
echo "Step 5: PASS 2 — the same model, with the repository's real history attached."
echo "--------------------------------------------------------------------------------"

PASS2_PROMPT="System Instructions:
$(cat "$AGENT_DIR/system_prompt.md")

=== BLAME CORRELATION RULES (source: agent_instructions/build_doctor_agent/blame_correlation_rules.md) ===
$(cat "$AGENT_DIR/blame_correlation_rules.md")

=== OUTPUT TEMPLATE (source: agent_instructions/build_doctor_agent/regression_verdict_template.md) ===
$(cat "$AGENT_DIR/regression_verdict_template.md")

Task:
Pull request #482 by Priya Nair is red. She bumped an image tag and is asking whether her branch is at fault. Decide, using the evidence pack below, and answer in the verdict template. Every claim must be traceable to a specific line of the log, a specific commit, or the resolved dependency state - do not assert anything the pack does not support. Keep it under 80 lines. No preamble, and do not wrap the whole response in a code fence.

=== EVIDENCE PACK ===
$(cat "$CONTEXT_PACK")"

printf '%s' "$PASS2_PROMPT" | run_claude | tee "$VERDICT_WITH_CONTEXT"
python3 "$PROJECT_ROOT/scripts/strip_code_fence.py" "$VERDICT_WITH_CONTEXT"
python3 "$PROJECT_ROOT/scripts/validate_agent_output.py" "$VERDICT_WITH_CONTEXT" \
  --min-bytes 400 --label "pass 2 (with history) verdict"

# ------------------------------------------------------------------------------
# Step 6 - the ground truth, proved rather than asserted.
#
# Re-resolve the dependency the way the deleted lockfile pinned it, render again,
# and put the result past the same gate. If the diagnosis is right, the limits
# come back without touching a single line of Priya's branch.
# ------------------------------------------------------------------------------
echo ""
echo "Step 6: Verifying the ground truth — pin acme-common back to 2.3.1 and re-render."
echo "--------------------------------------------------------------------------------"

rm -rf "$REPO/$CHART/charts/acme-common"
cp -r "$REGISTRY/acme-common-2.3.1" "$REPO/$CHART/charts/acme-common"
(cd "$REPO" && helm template payments "$CHART" --namespace payments > rendered.yaml)

echo "  Rendered resources block with acme-common 2.3.1:"
sed -n '/^          resources:/,/^---$/p' "$REPO/rendered.yaml" | sed '/^---$/d' | sed 's/^/    /'
echo ""
set +e
(cd "$REPO" && python3 ci/policy_gate.py rendered.yaml | sed 's/^/  /')
GATE_EXIT=$?
set -e

CULPRIT="$(git -C "$REPO" log -1 --format='%h  %s  (%an, %ad)' --date=relative -- "$CHART/Chart.lock")"

echo ""
echo "================================================================================"
echo " 📌 Ground truth (from the fixture, not from the model):"
echo "--------------------------------------------------------------------------------"
echo "   Culprit commit : $CULPRIT"
echo "   Mechanism      : deleting Chart.lock and loosening the range to ^2.3.0 let"
echo "                    acme-common resolve to 2.4.0, which moved the values key"
echo "                    from .Values.resources to .Values.container.resources."
echo "                    Helm renders a missing value as empty and exits 0."
echo "   Priya's diff   : $(git -C "$REPO" diff --name-only main...feat/bump-payments-1.9.0 | tr '\n' ' ')"
echo "   Proof          : pinning 2.3.1 restores the limits and the gate passes"
echo "                    (exit $GATE_EXIT above) with her branch untouched."
echo "================================================================================"
echo ""
echo " Artifacts:"
echo "   $CONTEXT_PACK"
echo "   $VERDICT_LOG_ONLY       (pass 1 - log only)"
echo "   $VERDICT_WITH_CONTEXT   (pass 2 - with history)"
echo ""
echo " ✅ Demo 3.1 complete — two live passes over the same failure."
echo "================================================================================"
