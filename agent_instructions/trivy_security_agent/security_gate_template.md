# Trivy Security Gate & Remediation Output Template

Use the following markdown template when triaging Trivy security scans:

```markdown
# 🛡️ Trivy Security Triage: {GATE_STATUS: [PASSED | ACTION REQUIRED | BLOCKED]}

### 🎯 Triage Summary
- **Total Scanned Items**: {TOTAL_COUNT} findings ({CRITICAL_COUNT} Critical, {HIGH_COUNT} High, {MED_COUNT} Med, {LOW_COUNT} Low)
- **Noise Suppressed**: {NOISE_COUNT} (Unexploitable or unfixable upstream)
- **Actionable Threats Requiring Attention**: **{ACTIONABLE_COUNT} Findings**
- **Security Gate Decision**: {DECISION_ICON} **{FINAL_DECISION: PASSED | WARNING | BLOCKED}**

---

### 🔍 Actionable Vulnerability Triage

| Target / Package | CVE ID | Severity | Exploit Context | Fixed Version | Recommended Action |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `{PkgName} ({InstalledVersion})` | `{VulnerabilityID}` | `{SEVERITY_ICON} {Severity}` | `{Exploit status / EPSS}` | `{FixedVersion}` | `{Upgrade action}` |

---

### 🚀 Instant Remediation Patch

{IF BASE IMAGE OUTDATED:
#### 1. Upgrade Docker Base Image
```diff
- FROM {OLD_BASE_IMAGE}
+ FROM {NEW_BASE_IMAGE}
```
*Note: This single upgrade resolves {RESOLVED_BY_BASE_COUNT} underlying OS vulnerabilities.*
}

{IF APPLICATION DEPENDENCY VULNERABLE:
#### 2. Update Application Dependencies (`{MANIFEST_FILE}`)
```diff
- "{PACKAGE}": "{OLD_VERSION}"
+ "{PACKAGE}": "{NEW_VERSION}"
```
}

---

**Next Steps**: Apply the suggested diff above and re-trigger the security scan.
```
