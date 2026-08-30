# 📄 RFC-20260831-01: Production Infrastructure Release — Customer DB & Data Lake

> **Status**: 🔴 `PENDING_CAB_REVIEW` | **Target Window**: `Tomorrow, 2026-08-31 03:00 UTC` | **Author**: `CI/CD Automation Agent (agy)`

---

## 📌 Metadata & Approvals

| Property | Value |
| :--- | :--- |
| **Service Affected** | `Customer Database & Analytics Storage` |
| **Environment** | `Production (AWS us-east-1)` |
| **Pull Request** | `[PR #142: feat(infra): update db cluster and analytics](https://github.com/org/repo/pull/142)` |
| **Risk Classification** | 🔴 **CRITICAL RISK** |
| **Blast Radius Score** | **9.5 / 10** |
| **Downtime Expected** | ⚠️ **~10 minutes maintenance (DB Replacement)** |
| **CAB Reviewers** | `@sre-lead`, `@security-lead`, `@platform-manager` |

---

## 🎯 Executive Summary & Business Justification
- **Primary Goal**: Update database identifier and provision raw analytics data lake bucket.
- **Impact**: Changes target the production customer database cluster (`aws_db_instance.production_db`).

---

## 🏗️ Detailed Infrastructure Changes

| Resource Address | Provider Type | Action | SRE Blast Radius |
| :--- | :--- | :--- | :--- |
| `aws_db_instance.production_db` | `aws_db_instance` | 💥 **REPLACE (DESTROY -> CREATE)** | 🔴 **CRITICAL** |
| `aws_security_group.allow_ssh` | `aws_security_group` | ⚠️ **CREATE** | 🟠 **HIGH** (`0.0.0.0/0:22`) |
| `aws_s3_bucket.data_lake` | `aws_s3_bucket` | ✨ **CREATE** | 🟢 **LOW** |

> [!CAUTION]
> **Destructive Replacement Warning**:
> `aws_db_instance.production_db` is marked for destruction and recreation due to identifier rename. Ensure snapshot backup is complete and add `lifecycle.prevent_destroy` before proceeding.

---

## 🛡️ Rollback & Contingency Strategy

1. **Trigger Condition**: Any 5xx error rate > 0.5% or application connection timeout exceeding 30 seconds.
2. **Automated Rollback**:
   ```bash
   gh workflow run rollback.yml -f ref=4f8b92a
   ```
3. **Database Restore**:
   Restore RDS snapshot `snapshot-pre-release-20260831` (Recovery time: ~12 minutes).

---

## 🧪 Post-Release Verification & Sign-off

- [ ] Check Datadog / CloudWatch RDS CPU & IOPS dashboards.
- [ ] Run synthetic end-to-end integration test suite (`pytest tests/smoke`).
- [ ] Confirm no open SSH ports (`0.0.0.0/0`) remain in security groups.
