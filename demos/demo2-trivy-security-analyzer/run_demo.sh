#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Demo 2: Trivy Security Scan & Triage Runner
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
echo "Step 1: Running Trivy vulnerability & configuration scan on sample_app..."

# Run real Trivy if available, or fall back to realistic generated JSON
if command -v trivy &>/dev/null; then
  echo "Found Trivy CLI. Scanning filesystem and Dockerfile..."
  trivy fs --format json --output "$SCAN_JSON" "$APP_DIR" 2>/dev/null || true
fi

# Ensure scan JSON exists with realistic findings if trivy produced empty output
if [ ! -s "$SCAN_JSON" ]; then
  cat << 'EOF' > "$SCAN_JSON"
{
  "SchemaVersion": 2,
  "ArtifactName": "sample_app",
  "ArtifactType": "filesystem",
  "Results": [
    {
      "Target": "sample_app/package.json",
      "Class": "lang-pkgs",
      "Type": "npm",
      "Vulnerabilities": [
        {
          "VulnerabilityID": "CVE-2022-24999",
          "PkgName": "express",
          "InstalledVersion": "4.16.0",
          "FixedVersion": "4.18.2",
          "Severity": "HIGH",
          "Title": "express: qs denial of service / prototype pollution vulnerability",
          "PrimaryURL": "https://avd.aquasec.com/nvd/cve-2022-24999"
        },
        {
          "VulnerabilityID": "CVE-2020-8203",
          "PkgName": "lodash",
          "InstalledVersion": "4.17.15",
          "FixedVersion": "4.17.19",
          "Severity": "HIGH",
          "Title": "lodash: Prototype Pollution in zipObjectDeep function",
          "PrimaryURL": "https://avd.aquasec.com/nvd/cve-2020-8203"
        }
      ]
    },
    {
      "Target": "sample_app/Dockerfile (node:16.14.0-alpine)",
      "Class": "os-pkgs",
      "Type": "alpine",
      "Vulnerabilities": [
        {
          "VulnerabilityID": "CVE-2023-0286",
          "PkgName": "libssl3",
          "InstalledVersion": "3.0.7-r0",
          "FixedVersion": "3.0.8-r0",
          "Severity": "CRITICAL",
          "Title": "openssl: X.400 address type confusion vulnerability",
          "PrimaryURL": "https://avd.aquasec.com/nvd/cve-2023-0286"
        },
        {
          "VulnerabilityID": "CVE-2022-37434",
          "PkgName": "zlib",
          "InstalledVersion": "1.2.12-r1",
          "FixedVersion": "1.2.12-r3",
          "Severity": "CRITICAL",
          "Title": "zlib: heap-based buffer overflow in inflate",
          "PrimaryURL": "https://avd.aquasec.com/nvd/cve-2022-37434"
        }
      ],
      "Misconfigurations": [
        {
          "ID": "AVD-DS-0001",
          "Title": "Specify at least 1 USER command in Dockerfile",
          "Severity": "MEDIUM",
          "Resolution": "Add 'USER nonroot' to avoid running container as root."
        }
      ]
    }
  ]
}
EOF
fi

echo "✅ Trivy scan report ready ($(wc -l < "$SCAN_JSON" | tr -d ' ') lines of JSON)."
echo ""
echo "Step 2: Invoking Trivy Security Agent to triage findings..."
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

SYSTEM_PROMPT="$PROJECT_ROOT/agent_instructions/trivy_security_agent/system_prompt.md"

call_agent "$SYSTEM_PROMPT" \
  "Triage this raw Trivy security scan. Filter noise, identify root-cause fixes (like base image updates), highlight actionable CVEs, and generate copy-paste remediation diffs." \
  "$(cat "$SCAN_JSON")"

echo ""
echo "================================================================================"
echo " ✅ Demo 2 complete! Output formatted as PR Security Review."
echo "================================================================================"
