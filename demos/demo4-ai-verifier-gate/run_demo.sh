#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Demo 4: AI Verifier & Fact-Checking Gate (LLM-as-a-Judge) (100% Live)
#
# Pass 1  : a primary agent analyses the real Terraform plan and writes a report.
# Forgery : a deterministic script seeds a COPY with known fabrications.
# Pass 2  : the judge audits both, and is scored against the answer key.
# ------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERIFIER_DIR="$PROJECT_ROOT/agent_instructions/verifier_agent"
TF_DIR="$PROJECT_ROOT/demos/demo1-terraform-analyzer/terraform"
GROUND_TRUTH="$TF_DIR/plan.json"

CLEAN_REPORT="$SCRIPT_DIR/report_clean.md"
TAMPERED_REPORT="$SCRIPT_DIR/report_tampered.md"
MANIFEST="$SCRIPT_DIR/injection_manifest.json"
VERDICT_CLEAN="$SCRIPT_DIR/verdict_clean.json"
VERDICT_TAMPERED="$SCRIPT_DIR/verdict_tampered.json"

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

# --system-prompt replaces Claude Code's agentic default; without it the CLI
# primes the model to reach for tools and, with none available, it narrates the
# tool call instead of writing a report.
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


echo "################################################################################"
echo "  🛡️ DEMO 4: AI Verifier & Anti-Hallucination Gate in CI/CD (LLM-as-a-Judge)"
echo "################################################################################"
echo ""
echo "Step 1: Ensuring live ground truth plan.json exists..."

if [ ! -f "$GROUND_TRUTH" ]; then
  cd "$TF_DIR"
  terraform init -backend=false -input=false
  terraform plan -out=tfplan -input=false
  terraform show -json tfplan > plan.json
  cd "$PROJECT_ROOT"
fi
echo "✅ Ground truth: $GROUND_TRUTH ($(wc -c < "$GROUND_TRUTH") bytes)"

echo ""
echo "Step 2: Pass 1 — primary agent writes the report (live)..."
echo "--------------------------------------------------------------------------------"

STAGE1_PROMPT="Analyse this Terraform plan and report the planned infrastructure changes and their risks.

Output exactly this structure and nothing else:

# Terraform Plan Analysis

> **Changes**: \`+{ADD}\` add, \`~{CHANGE}\` change, \`💥{REPLACE}\` replace, \`-{DESTROY}\` destroy

| Resource | Action | Risk | Impact |
| :--- | :--- | :--- | :--- |
| \`{resource_address}\` | {create/update/destroy/replace} | {🟢 LOW / 🟡 MEDIUM / 🔴 CRITICAL} | {one line} |

### Summary
- {2 to 3 bullets}

One row per resource in the plan. Every claim must be grounded in the JSON below - do not speculate about resources that are not present. Keep it under 40 lines. No preamble, no code fence around the whole response.

=== INPUT TERRAFORM PLAN JSON ===
$(cat "$GROUND_TRUTH")"

printf '%s' "$STAGE1_PROMPT" | run_claude | tee "$CLEAN_REPORT"
python3 "$PROJECT_ROOT/scripts/strip_code_fence.py" "$CLEAN_REPORT"
python3 "$PROJECT_ROOT/scripts/validate_agent_output.py" "$CLEAN_REPORT" --min-bytes 300 --label "pass 1 report"

echo ""
echo "Step 3: Forging a corrupted copy (deterministic, no AI)..."
echo "--------------------------------------------------------------------------------"

python3 "$SCRIPT_DIR/inject_hallucinations.py" \
  --input "$CLEAN_REPORT" \
  --output "$TAMPERED_REPORT" \
  --manifest "$MANIFEST"

echo ""
echo "Diff (genuine vs tampered):"
diff "$CLEAN_REPORT" "$TAMPERED_REPORT" || true

judge() {
  local candidate="$1" out="$2" label="$3" expectation="$4"
  echo ""
  echo "--------------------------------------------------------------------------------"
  echo "🤖 Judge auditing: $label (expect $expectation)"
  echo "--------------------------------------------------------------------------------"

  local prompt
  prompt="$(cat "$VERIFIER_DIR/system_prompt.md")

=== VERIFICATION RULES (source file: agent_instructions/verifier_agent/verification_rules.md) ===
$(cat "$VERIFIER_DIR/verification_rules.md")

=== [GROUND TRUTH: RAW INPUT DATA] ===
$(cat "$GROUND_TRUTH")

=== [AI GENERATED REPORT TO AUDIT] ===
$(cat "$candidate")"

  printf '%s' "$prompt" | run_claude | tee "$out"
  python3 "$PROJECT_ROOT/scripts/strip_code_fence.py" "$out"
  python3 "$PROJECT_ROOT/scripts/validate_agent_output.py" "$out" --min-bytes 120 --label "$label verdict"
}

echo ""
echo "Step 4: Pass 2 — the same judge audits both candidates..."
judge "$CLEAN_REPORT"    "$VERDICT_CLEAN"    "genuine report"  "APPROVED"
judge "$TAMPERED_REPORT" "$VERDICT_TAMPERED" "tampered report" "REJECTED"

echo ""
echo "Step 5: Scoring the judge against the answer key..."
echo "--------------------------------------------------------------------------------"
python3 "$SCRIPT_DIR/render_audit_table.py" \
  --clean "$VERDICT_CLEAN" \
  --tampered "$VERDICT_TAMPERED" \
  --manifest "$MANIFEST" \
  --out "$SCRIPT_DIR/audit_table.md"

echo ""
echo "================================================================================"
echo " 🏁 Demo 4 complete — two live judge passes, scored against a known answer key."
echo "================================================================================"
