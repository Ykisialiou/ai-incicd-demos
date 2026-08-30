# Corporate Infrastructure & Architecture Governance Policy

This document defines the organizational architecture rules that the Antigravity CI/CD Agent enforces across all Terraform Pull Requests.

---

## 🏛️ Rule 1: Domain & Public Routing Policy (`*.company.com`)
- **Core API Domain**: `api.company.com` is the primary business API gateway endpoint.
- **Routing Requirement**: All public API traffic **MUST** route through the enterprise API Gateway with Cloudflare WAF inspection.
- **Direct Edge Ban**: Creating direct Route53 DNS records pointing `api.company.com` to raw S3/CloudFront origins without WAF is **STRICTLY FORBIDDEN** (Risk: Traffic hijacking, bypassing rate-limiting, customer data leakage).
- **Classification**: Static linters classify new DNS records as `🟢 LOW (Additive)`. The Agent must elevate any `api.*` DNS change to **🟠 HIGH RISK (Business Routing & Policy Violation)**.

---

## 🔒 Rule 2: Database State & Protection Policy
- Any change that forces replacement of production RDS databases (`aws_db_instance`) is **🔴 CRITICAL** and must be blocked automatically.
- Production databases must contain `lifecycle { prevent_destroy = true }`.

---

## 🎯 Rule 3: PR Scope & Intent Alignment
- If a PR is titled *"update customer db"*, but introduces unrelated networking/DNS modifications (e.g. hijacking `api.company.com`), the Agent must flag this as **Scope Mismatch / Unintended Side-Effect**.
