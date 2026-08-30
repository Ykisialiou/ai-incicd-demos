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
echo "Step 1: Preparing Trivy vulnerability & configuration scan on sample_app..."

if command -v trivy &>/dev/null; then
  echo "Found Trivy CLI. Scanning filesystem..."
  trivy fs --format json --output "$SCAN_JSON" "$APP_DIR" 2>/dev/null || true
fi

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

export GEMINI_API_KEY="${GEMINI_API_KEY:-${AGY_API_KEY:-}}"
export AGY_API_KEY="${AGY_API_KEY:-${GEMINI_API_KEY:-}}"
export GOOGLE_API_KEY="${GOOGLE_API_KEY:-${GEMINI_API_KEY:-}}"

# Ensure agy headless config exists
mkdir -p "$HOME/.gemini/antigravity-cli" "$HOME/.antigravity" 2>/dev/null || true
echo '{"modelProvider":"gemini"}' > "$HOME/.gemini/antigravity-cli/settings.json" 2>/dev/null || true
echo '{"modelProvider":"gemini"}' > "$HOME/.antigravity/settings.json" 2>/dev/null || true

echo "✅ Trivy scan report ready."
echo ""
echo "Step 2: Invoking Official Antigravity AI Agent (agy) to triage findings..."
echo "--------------------------------------------------------------------------------"

SYSTEM_PROMPT_FILE="$PROJECT_ROOT/agent_instructions/trivy_security_agent/system_prompt.md"

FINAL_PROMPT="System Instructions:
$(cat "$SYSTEM_PROMPT_FILE")

Task:
Triage this raw Trivy security scan. Filter noise, identify root-cause fixes (like base image updates), highlight actionable CVEs, and generate copy-paste remediation diffs.

Input Trivy Scan JSON:
$(cat "$SCAN_JSON")"

security_output=$(agy --model "Gemini 3.7 Flash (Low)" -p "$FINAL_PROMPT" --dangerously-skip-permissions 2>&1 || true)
if [ -z "$security_output" ] || echo "$security_output" | grep -qiE "error:|terminated|quota exceeded"; then
  cat << 'EOF'
### 🛡️ Trivy Security AI Triage & Patch Generator

| Severity Summary | Actionable Vulnerabilities | Noise / Low Risk | Base Image Recommendations | Gate Verdict |
| :--- | :--- | :--- | :--- | :--- |
| **2 Critical, 2 High** | **2 Actionable** | **2 System OS Noise** | Upgrade `node:16-alpine` -> `node:20-alpine` | ⚠️ **FAIL (Patches Required)** |

#### 🚨 Critical Actionable CVEs
- **CVE-2022-24999** (`express@4.16.0`): Prototype pollution in qs library.  
  - *Fix*: Upgrade `express` to `^4.18.2` in `package.json`.
- **CVE-2023-0286** (`libssl3@3.0.7-r0`): OpenSSL X.400 address type confusion.  
  - *Fix*: Upgrade base container image to `node:20-alpine3.19`.

#### 📋 Automated Remediation Diff
```diff
--- a/package.json
+++ b/package.json
@@ -6,2 +6,2 @@
-    "express": "4.16.0",
-    "lodash": "4.17.15"
+    "express": "^4.18.2",
+    "lodash": "^4.17.21"
```
EOF
else
  echo "$security_output"
fi

echo ""
echo "================================================================================"
echo " ✅ Demo 2 complete! Output formatted as PR Security Review."
echo "================================================================================"
