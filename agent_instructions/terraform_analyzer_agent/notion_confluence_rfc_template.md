# Confluence / Notion RFC (Request for Change) Page Template

This template structures the Terraform change analysis as a formal Confluence / Notion Release RFC document.

---

```markdown
# 📄 RFC-{YEAR}{MONTH}{DAY}-01: Production Infrastructure Release — {SERVICE_NAME}

> **Status**: 🔴 `PENDING_CAB_REVIEW` | **Target Window**: `{SCHEDULED_RELEASE_WINDOW}` | **Author**: `CI/CD Automation Agent (agy)`

---

## 📌 Metadata & Approvals

| Property | Value |
| :--- | :--- |
| **Service Affected** | `{SERVICE_NAME}` |
| **Environment** | `Production (AWS us-east-1)` |
| **Pull Request** | `[PR #{PR_NUMBER}: {PR_TITLE}]({PR_URL})` |
| **Risk Classification** | `{RISK_BADGE: 🟢 LOW | 🟡 MEDIUM | 🔴 CRITICAL}` |
| **Blast Radius Score** | **{BLAST_RADIUS_SCORE} / 10** |
| **Downtime Expected** | `{DOWNTIME_ESTIMATE: Zero-downtime | ~X mins maintenance}` |
| **CAB Reviewers** | `@sre-lead`, `@security-lead`, `@platform-manager` |

---

## 🎯 Executive Summary & Business Justification
{BULLET_POINTS_SUMMARIZING_WHY_AND_WHAT}
- **Primary Goal**: Update database configuration and provision analytics bucket.
- **Impact**: Changes target the production customer database cluster.

---

## 🏗️ Detailed Infrastructure Changes

| Resource Address | Provider Type | Action | SRE Blast Radius |
| :--- | :--- | :--- | :--- |
| `{resource.address}` | `{resource.type}` | `{action: CREATE | REPLACE | DESTROY}` | `{RISK_ICON} {risk_level}` |

> [!CAUTION]
> **Destructive Replacement Warning**:
> `{DESTRUCTIVE_RESOURCE_NAME}` is marked for destruction and recreation. Ensure snapshot backup is complete before proceeding.

---

## 🛡️ Rollback & Contingency Strategy

1. **Trigger Condition**: Any 5xx error rate > 0.5% or application connection timeout exceeding 30 seconds.
2. **Automated Rollback**:
   ```bash
   gh workflow run rollback.yml -f ref={PREVIOUS_STABLE_COMMIT}
   ```
3. **Database Restore**:
   Restore RDS snapshot `snapshot-pre-release-{TIMESTAMP}` (Recovery time: ~12 minutes).

---

## 🧪 Post-Release Verification & Sign-off

- [ ] Check Datadog / CloudWatch RDS CPU & IOPS dashboards.
- [ ] Run synthetic end-to-end integration test suite.
- [ ] Confirm no open SSH ports (`0.0.0.0/0`) remain in security groups.
```
