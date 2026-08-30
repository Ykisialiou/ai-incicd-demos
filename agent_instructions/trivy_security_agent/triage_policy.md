# Trivy Security Triage Policy & Decision Framework

## Triage Priority Matrix

| Category | Conditions | Triage Action | CI Pipeline Decision |
| :--- | :--- | :--- | :--- |
| **Tier 1 (Emergency)** | Critical Severity + In-the-Wild Exploit (KEV) + Fix Available | Immediate fix required | 🔴 **BLOCK Pipeline** |
| **Tier 2 (High Priority)** | High/Critical Severity + Patch Available in Upstream | Recommend version bump | 🟡 **WARN (Allow with notice)** |
| **Tier 3 (Informational)** | Medium/Low Severity OR No Fix Available Upstream | Log in step summary | 🟢 **PASS** |
| **Tier 4 (Base Image)** | Multiple OS vulnerabilities from old base image | Recommend single base image bump | 🟡 **WARN (Fix base image)** |

---

## Noise Reduction Rules

1. **Suppression of Unfixable Upstream CVEs**:
   - If `FixedVersion` is empty / null in Trivy JSON, flag as "No fix available". Do not fail the build for things developers cannot fix, unless it is a catastrophic active 0-day.
2. **Contextual Reachability**:
   - Differentiate between standard production runtime dependencies (e.g. `express`, `django`, `requests`) and build-only/test dependencies.
3. **Misconfiguration Triage**:
   - For Trivy IaC / Dockerfile misconfigs (e.g., `AVD-DS-0001: Running as root`, `AVD-DS-0002: Missing HEALTHCHECK`):
     - Provide the exact lines in `Dockerfile` to add `USER appuser` and `HEALTHCHECK`.
