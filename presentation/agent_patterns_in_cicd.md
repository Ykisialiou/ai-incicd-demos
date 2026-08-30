# Architectural Patterns for AI Agents in CI/CD

This document details the mental models, event triggers, and architectural flows for embedding AI agents into modern DevOps pipelines.

---

## 1. Pattern 1: The Sentinel Gate (Pre-Apply Infrastructure Safety)

```mermaid
flowchart TD
    A[Developer Submits PR] --> B[CI Runner: terraform plan]
    B --> C[Export Plan to JSON: terraform show -json]
    C --> D[Terraform Analyzer Agent]
    D --> E{Blast Radius & Destruction Check}
    E -- Destructive DB Replace or 0.0.0.0/0 --> F[🔴 Block Pipeline & Post PR Safety Review]
    E -- Safe Update --> G[🟢 Approve & Proceed to Apply]
```

### Key Capabilities:
- Ingests structured JSON AST of infrastructure changes.
- Evaluates replacement hazards on stateful resources (Databases, S3, Disks).
- Provides instant PR feedback with HCL fixes before changes reach production.

---

## 2. Pattern 2: The Contextual Triager (DevSecOps Vulnerability Noise Reducer)

```mermaid
flowchart TD
    A[Container / IaC Scan Step] --> B[Trivy Scan: JSON Output]
    B --> C[Trivy Security Agent]
    C --> D[Filter Noise: Unexploitable / No-Fix CVEs]
    C --> E[Isolate Root Cause: Old Base Image]
    D & E --> F[Generate Clean Actionable Report & Diff Patch]
    F --> G[Post GitHub Step Summary / PR Comment]
```

### Key Capabilities:
- Aggregates multiple CVEs into a single root cause fix (e.g. 1 base image bump solves 15 CVEs).
- Filters out non-actionable upstream noise.
- Generates directly mergeable code diffs.

---

## 3. Pattern 3: The Build Doctor (Failure Interceptor & Root Cause Analyzer)

```mermaid
flowchart TD
    A[CI Pipeline Step: Build / Test] --> B{Step Exit Code}
    B -- Exit Code == 0 --> C[Proceed Next Step]
    B -- Exit Code != 0 --> D[Capture stderr & stdout Log Buffer]
    D --> E[Build Doctor Agent]
    E --> F[Log Forensics: Pinpoint Exact Failing Line & Reason]
    F --> G[Generate Fix Command & Diff]
    G --> H[Post Diagnostic Alert to PR / Slack]
```

### Key Capabilities:
- Intercepts failure hooks without modifying core application code.
- Reduces MTTR (Mean Time To Recovery) from minutes to seconds.
- Eliminates developer frustration with deep dependency/compiler stack traces.
