# Demo 2: Trivy Security Scan Triage & Auto-Remediation

This demo showcases an AI Agent acting as an automated DevSecOps security gate, converting raw vulnerability scan dumps into high-signal developer remediation patches.

---

## 🎯 Demo Storyline & Scenario

1. **The Context**: A CI pipeline builds a container image and runs `trivy` to scan for CVEs and Dockerfile misconfigurations.
2. **The Problem (Alert Fatigue)**:
   - Trivy outputs dozens of CVEs across base OS packages (`libssl3`, `zlib`, `busybox`, `musl`, etc.) and NPM dependencies (`express`, `lodash`).
   - Developers usually ignore long raw CVE tables or get blocked on unfixable upstream issues.
3. **The AI Agent Solution**:
   - The **Trivy Security Agent** ingests the raw Trivy JSON.
   - It distinguishes between unfixable noise and actionable exploits.
   - It detects that all OS-level vulnerabilities can be resolved simultaneously by bumping the base image from `node:16.14.0-alpine` to `node:20.11-alpine`.
   - It provides a 1-click mergeable code diff directly in the PR review.

---

## 🚀 Running the Demo

Execute the demo script:
```bash
./demos/demo2-trivy-security-analyzer/run_demo.sh
```

### Optional: Live Antigravity Mode
To run against the live model:
```bash
export AGY_API_KEY="your-api-key-here"
./demos/demo2-trivy-security-analyzer/run_demo.sh
```

---

## 🎤 Presenter Talking Points

> *"Standard security scanners tell you WHAT is wrong across 50 lines. The AI agent tells you the ROOT CAUSE: 'Upgrade your base Dockerfile by 1 line, and 14 of these 16 vulnerabilities disappear.' This eliminates alert fatigue and bridges the gap between security teams and developers."*
