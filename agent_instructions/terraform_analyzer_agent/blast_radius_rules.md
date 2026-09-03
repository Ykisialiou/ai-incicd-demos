# Terraform Blast Radius & Risk Classification Rules

This document defines the heuristic scoring matrix used by the Terraform Analyzer Agent to classify infrastructure changes into actionable risk tiers for Team Leads and Release Managers.

---

## 🎯 Risk Classification & Blast Radius Matrix

| Change Pattern | Target Resource | Action | Risk Level | Blast Radius | SRE Action & Decision |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Destructive Replacement** | `aws_db_instance`, `google_sql_*`, `aws_rds_cluster` | `replace` (destroy ➔ create) | 🔴 **CRITICAL** | **9.0 - 10.0** | **BLOCK Pipeline**. Data loss hazard! Requires `prevent_destroy` or snapshot restore. |
| **Stateful Storage Destruction** | `aws_s3_bucket`, `aws_ebs_volume`, `aws_dynamodb_table` | `delete` / `replace` | 🔴 **CRITICAL** | **8.5 - 9.5** | **BLOCK Pipeline**. Persistent data deletion hazard. |
| **Global Edge & Distribution** | `aws_cloudfront_distribution`, `cloudflare_zone` | `update` (aliases, origins, SSL cert) | 🟡 **MEDIUM** | **4.5 - 6.0** | **ALLOW WITH NOTICE**. Edge deployment takes ~5-15 mins; verify ACM cert validation. |
| **Security Tightening** | `aws_security_group` (restricting `0.0.0.0/0` ➔ `10.0.0.0/16`) | `update` | 🟡 **WARN** | **3.5 - 5.0** | **WARN**. Security improvement, but SRE must verify no external consumers are dropped. |
| **Additive Networking / DNS** | `aws_route53_record`, `aws_subnet` | `create` | 🟢 **LOW** | **2.0 - 3.0** | **APPROVE**. Purely additive, zero impact on existing traffic. |
| **Metadata & Governance Tags** | Tags, descriptions, cost-center metadata on any resource | `update` (in-place) | 🟢 **SAFE** | **1.0 / 10** | **APPROVE**. In-place metadata update with zero downtime. |

---

## 🔍 SRE Analysis Checklist

1. **Tag Changes**:
   - Classify purely as metadata updates.
   - Note in summary: `"🟢 Tags updated safely in-place with zero downtime."`
2. **Security Group Changes**:
   - Differentiate between **Loose/Hazardous** (opening `0.0.0.0/0`) and **Tightened/Restrictive** (reducing CIDR scope).
3. **CloudFront & DNS**:
   - Flag propagation timing and SSL certificate alignment.
4. **Stateful Resources**:
   - Detect changes to immutable attributes (`identifier`, `engine`, `availability_zone`) that trigger silent replacement.
