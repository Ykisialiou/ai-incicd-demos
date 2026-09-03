# Corporate Infrastructure & Architecture Governance Policy

This document defines the organizational architecture rules that the Claude CI/CD Agent enforces across all Terraform Pull Requests.

---

## 🏛️ Rule 1: Domain & Public Routing Policy (`*.company.com`)
- **Core API Domain**: `api.company.com` is the primary business API gateway endpoint.
- **Routing Requirement**: All public API traffic **MUST** route through the enterprise API Gateway with Cloudflare WAF inspection.
- **Direct Edge Ban**: Creating direct Route53 DNS records pointing `api.company.com` to raw S3/CloudFront origins without WAF is **STRICTLY FORBIDDEN** (Risk: Traffic hijacking, bypassing rate-limiting, customer data leakage).
- **Classification**: Static linters classify new DNS records as `🟢 LOW (Additive)` because no existing resource is modified or destroyed. The Agent **MUST** elevate any change that attaches an `api.*` domain — as a Route53 record **or** as a CloudFront `aliases` entry — to **🔴 CRITICAL (Business Routing & Policy Violation)** and set the Gate Verdict to **BLOCKED**.

### 📖 Protected Domain Registry

Every DNS or CDN alias change **MUST** be looked up in this registry before a verdict is issued.
Criticality here **overrides** any structural risk score derived from the plan's action type.

| Domain | Criticality | Owner | Required Routing Path | Change Policy |
| :--- | :--- | :--- | :--- | :--- |
| `api.company.com` | 🔴 **CRITICAL** | Platform API Team | API Gateway ➔ Cloudflare WAF ➔ origin | **Frozen.** No new origin attachments without CAB approval. |
| `api-v2.company.com` | 🔴 **CRITICAL** | Platform API Team | API Gateway ➔ Cloudflare WAF ➔ origin | **Reserved** for the v2 API cutover. Already pre-registered in partner IP allowlists and WAF rule sets. Attaching it to any other origin silently serves production API traffic from an unprotected edge. **FORBIDDEN.** |
| `cdn.company.com` | 🟢 LOW | Web Platform Team | Direct CloudFront ➔ S3 | Free to attach or detach. Static assets only, no authenticated traffic. |
| `docs.company.com` | 🟢 LOW | Developer Relations | Direct CloudFront ➔ S3 | Free to attach or detach. Public documentation only. |

> **Note for the Agent**: not every DNS change is dangerous. A new record for a `🟢 LOW`
> registry domain is genuinely additive and should be **APPROVED** — agreeing with the
> static analyzer. Escalate only what the registry says is protected, and name the row
> you relied on.

---

## 🔒 Rule 2: Database State & Protection Policy
- Any change that forces replacement of production RDS databases (`aws_db_instance`) is **🔴 CRITICAL** and must be blocked automatically.
- Production databases must contain `lifecycle { prevent_destroy = true }`.

---

## 🎯 Rule 3: PR Scope & Intent Alignment
- If a PR is titled *"update customer db"*, but introduces unrelated networking/DNS modifications (e.g. hijacking `api.company.com`), the Agent must flag this as **Scope Mismatch / Unintended Side-Effect**.

---

## 📊 Rule 4: Data Classification & Compliance Scope

Any resource carrying `DataClassification = "Confidential"` **or** a `ComplianceScope`
tag naming an audited regime (`SOC2-Type2`, `PCI-DSS`, `HIPAA`, `ISO27001`) is **in
audit scope** and **MUST** be checked against the controls below. A resource that
declares itself confidential and then fails any of them is **🔴 CRITICAL** — a failed
control on an in-scope resource is an audit finding, not a hardening suggestion.

**Required controls for in-scope resources:**

| Control | Terraform expression | Failure verdict |
| :--- | :--- | :--- |
| Encryption at rest | `server_side_encryption_configuration`, or `storage_encrypted = true` for RDS | 🔴 CRITICAL |
| Public access blocked | a matching `aws_s3_bucket_public_access_block` with all four flags `true` | 🔴 CRITICAL |
| Versioning / point-in-time recovery | `aws_s3_bucket_versioning` enabled, or RDS backup retention > 1 day | 🔴 CRITICAL |
| Access logging | `aws_s3_bucket_logging`, or an equivalent audit trail | 🟠 HIGH |
| Ownership recorded | an `Owner` tag naming a real team | 🟡 MEDIUM |

- **The tag is a claim, and the plan is the evidence.** Tagging a bucket
  `ComplianceScope = "SOC2-Type2"` while leaving it unencrypted and world-readable is
  worse than leaving it untagged: it asserts a control environment to auditors that
  the infrastructure does not implement.
- **This is not a generic S3 hardening rule.** An identical bucket with no
  classification tags is scored on its own merits and may be perfectly acceptable.
  The escalation is triggered by the *combination* of a compliance claim and a
  missing control.
- **A compliant in-scope resource is APPROVED.** If a `Confidential` / SOC2 resource
  satisfies every required control, say so plainly and score it 🟢 — do not escalate a
  resource merely for being in audit scope. Name the controls you verified.

---

## 🧪 Rule 5: Environment Scoping — When to De-escalate

A standard IaC linter applies the same hardening checks to every resource of a given
type. It cannot tell a customer data lake from a CI scratch bucket, so it reports both
identically. **The Agent is expected to de-escalate where context justifies it.**

- A resource tagged `Environment = test | dev | sandbox`, carrying no `Confidential`
  classification and no `ComplianceScope`, holding no customer data, is **🟢 LOW**
  even when the linter reports missing encryption, versioning, or logging on it.
- Say so explicitly: name the linter findings you are **overriding** and the context
  that justifies it. "Static flags 8 S3 hardening findings; this is an ephemeral CI
  artifact bucket with no customer data, so LOW — do not block the pipeline."
- Do **not** de-escalate on a tag alone. If a resource is labelled `test` but is
  clearly wired into production traffic (a real domain, a production origin, a
  production security group), trust the wiring over the label and say why.

Blocking a release over a scratch bucket is how a gate loses the team's trust, and a
gate nobody trusts gets switched off. Reducing false positives is as much a part of
this job as catching real ones.

---

## 💰 Rule 6: Cost Governance — Orphaned Billable Resources

Security scanners have no opinion about money. Nothing is exposed and nothing is at
risk, so they report nothing at all — while the resource bills hourly, forever.

Flag as **🟡 MEDIUM (Waste — no security impact)**:

| Pattern | Why it is waste |
| :--- | :--- |
| `aws_eip` with no `instance`, `network_interface`, or association | An unassociated Elastic IP is billed per hour precisely *because* it is idle |
| `aws_ebs_volume` with no attachment | Provisioned GB billed monthly for an unreadable disk |
| `aws_nat_gateway` in a subnet with no outbound workloads | Hourly charge plus per-GB processing for zero traffic |
| Autoscaling group with `min_size = max_size = 0` | Usually an incomplete migration left half-applied |

- Never block a release for cost alone — this is a 🟡 note for the owner, not a gate.
- Name the tag that identifies who pays: `Owner`, `CostCenter`, or the team in
  `Purpose`. A waste finding routed to nobody gets fixed by nobody.
- If a `Purpose` tag describes an intent that the plan does not carry out (for example
  "reserved for a migration"), say so — an unfinished migration is the single most
  common source of orphaned spend.
