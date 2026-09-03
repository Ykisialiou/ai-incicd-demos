# CI/CD Pipeline Workflows Catalog

This directory contains production-ready pipeline definitions demonstrating how to embed AI agents into CI/CD systems.

## Workflow Index

| Pipeline | Target Agent | Trigger Event | Output Action |
| :--- | :--- | :--- | :--- |
| **[terraform-analyzer.yml](./github-actions/terraform-ai-gate.yml)** | Terraform Analyzer Agent | `pull_request` affecting `.tf` files | Calculates Blast Radius & posts blocking PR safety review |
| **[trivy-security-gate.yml](./github-actions/trivy-ai-triage.yml)** | Trivy Security Agent | Container scan / Dockerfile change | Triages CVEs & provides copy-paste Dockerfile/dependency patch |
| **[build-doctor-on-failure.yml](./github-actions/build-doctor-on-failure.yml)** | Build Doctor Agent | `if: failure()` on any build step | Pinpoints exact failing line & posts instant remediation fix |
