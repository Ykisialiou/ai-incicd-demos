# Autonomous CI/CD: AI Agents in Delivery Pipelines 🚀

An end-to-end presentation and practical demonstration repository showcasing how to integrate autonomous, context-aware AI Agents into CI/CD pipelines (GitHub Actions, Antigravity CLI `agy`, and Google Gemini).

---

## 📚 Repository Map

```
ai-incicd-demos/
├── presentation/                                   # Presentation & Conference Materials
│   ├── presentation_outline.md                     # 25-35 min slide deck outline & speaker script
│   └── agent_patterns_in_cicd.md                   # Architectural diagrams & CI/CD agentic patterns
├── agent_instructions/                             # Agent Personas, Rules & Output Schemas
│   ├── README.md                                   # Agent system architecture guide
│   ├── terraform_analyzer_agent/                   # Infrastructure Blast Radius & Safety Reviewer
│   │   ├── system_prompt.md
│   │   ├── blast_radius_rules.md
│   │   └── pr_comment_template.md
│   ├── trivy_security_agent/                       # DevSecOps Vulnerability Triager
│   │   ├── system_prompt.md
│   │   ├── triage_policy.md
│   │   └── security_gate_template.md
│   └── build_doctor_agent/                         # Failure Interceptor & Root Cause Analyzer
│       ├── system_prompt.md
│       ├── log_filtering_rules.md
│       └── fix_recommendation_template.md
├── bin/
│   └── agy                                         # Lightweight Antigravity CLI runner (pipe logs to agent)
├── demos/
│   ├── demo1-terraform-analyzer/                   # Demo 1: Real Terraform Plan & State Analysis ($0 cost)
│   │   ├── README.md
│   │   ├── terraform/                              # Real AWS RDS (replacement trigger) + SG (0.0.0.0/0)
│   │   └── run_demo.sh
│   ├── demo2-trivy-security-analyzer/              # Demo 2: Real Trivy Security Scan & Triage
│   │   ├── README.md
│   │   ├── sample_app/                             # Outdated Dockerfile & package manifests
│   │   └── run_demo.sh
│   └── demo3-build-failure-doctor/                 # Demo 3: Broken CI/CD Pipeline & Log Root Cause Analyzer
│       ├── README.md
│       ├── sample_broken_pipeline/                 # Realistic failing build project (300+ line log)
│       └── run_demo.sh
└── .github/workflows/                              # Production GitHub Actions Workflows
    ├── terraform-analyzer.yml                      # Pre-apply Terraform AI safety gate
    ├── trivy-security-gate.yml                     # DevSecOps vulnerability triage & patch generator
    └── build-doctor-on-failure.yml                 # Auto-diagnosis on step failure
```

---

## ⚡ The Three Live Demos

### 1. [Demo 1: Terraform Plan & Blast Radius Analyzer](./demos/demo1-terraform-analyzer/)
- **Trigger**: Pull Request with infrastructure changes.
- **Problem**: A developer renames an RDS database identifier (which silently triggers a destructive drop-and-recreate) and opens SSH `0.0.0.0/0`.
- **AI Solution**: The agent parses the Terraform AST JSON, calculates a **Blast Radius Score of 9.5/10**, and posts a **BLOCKED** gate decision with an HCL `prevent_destroy` patch.
- **Run**:
  ```bash
  ./demos/demo1-terraform-analyzer/run_demo.sh
  ```

### 2. [Demo 2: Trivy Security Scan Triage & Remediation](./demos/demo2-trivy-security-analyzer/)
- **Trigger**: Container image build / Trivy vulnerability scan.
- **Problem**: Traditional scanners output 18+ noisy CVEs, causing developer alert fatigue.
- **AI Solution**: The agent identifies that 14 OS CVEs are caused by an outdated base image, suppresses unfixable noise, and produces a 1-line Dockerfile diff (`node:16-alpine` ➔ `node:20-alpine`).
- **Run**:
  ```bash
  ./demos/demo2-trivy-security-analyzer/run_demo.sh
  ```

### 3. [Demo 3: CI/CD Build Failure Doctor](./demos/demo3-build-failure-doctor/)
- **Trigger**: Step failure (`if: failure()`, exit code != 0).
- **Problem**: Build fails with 300+ lines of messy compile output (`gyp ERR! find Python - "python3" can't be in PATH`).
- **AI Solution**: The agent ignores 280 lines of irrelevant download logs, isolates the missing Alpine C++ compiler dependencies, and outputs the exact fix command (`apk add --no-cache python3 make g++`).
- **Run**:
  ```bash
  ./demos/demo3-build-failure-doctor/run_demo.sh
  ```

---

## 🛠️ Prerequisites & Setup

- **Python**: Python 3.10+ (standard library only, zero external Python package dependencies required).
- **Terraform & Trivy**:
  - `brew install terraform` (Optional for live generation; demo includes offline fallback fixtures).
  - `brew install trivy` (Optional for live scans).
- **Antigravity CLI (`agy`) / API Key**:
  - Offline / Demo Mode: All scripts run out-of-the-box in simulation mode without an API key.
  - Live AI Mode: Export your Antigravity / Google AI API key:
    ```bash
    export AGY_API_KEY="your-api-key-here"
    ```

---

## 🎤 Presentation Materials

- **[Presentation Outline & Speaker Track](./presentation/presentation_outline.md)**: 25-35 minute slide-by-slide guide with timings, narrative arcs, and demo transition points.
- **[Architectural Patterns](./presentation/agent_patterns_in_cicd.md)**: Deep-dive into Sentinel Gates, Contextual Triagers, and Build Doctors with Mermaid diagrams.
