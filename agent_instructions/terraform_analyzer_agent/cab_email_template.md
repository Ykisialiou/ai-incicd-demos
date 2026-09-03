# Change Management / CAB (Change Advisory Board) Email Template

Use this template when generating automated RFC (Request for Change) emails and Change Management tickets based on analyzed Terraform plans and pipeline diffs.

---

```markdown
Subject: [RFC - Change Request] Production Infrastructure Release: {SERVICE_OR_SYSTEM_NAME} ({DATE}) - Risk Level: {RISK_LEVEL: LOW | MEDIUM | HIGH | CRITICAL}

Hi Change Advisory Board (CAB) & Operations Team,

Please review and approve the following Change Request for the upcoming production release window.

================================================================================
📋 1. CHANGE OVERVIEW & SCHEDULE
================================================================================
• Service / Component : {SERVICE_OR_SYSTEM_NAME}
• Target Environment  : Production ({AWS_REGION_OR_CLUSTER})
• Planned Window      : {SCHEDULED_DATETIME_UTC}
• Expected Duration   : {ESTIMATED_DURATION_MINS} minutes
• Expected Downtime   : {DOWNTIME_STATUS: None / Zero-downtime / ~X minutes maintenance}
• Initiated By        : {AUTHOR_OR_PIPELINE}
• Git Reference / PR  : {PR_URL_OR_COMMIT}

================================================================================
🔍 2. EXECUTIVE SUMMARY OF PLANNED CHANGES
================================================================================
{CONCISE_BULLET_POINTS_EXPLAINING_INFRASTRUCTURE_EDITS_IN_PLAIN_ENGLISH}
• Example: "Adding new read-only replica S3 bucket for data analytics."
• Example: "Upgrading production RDS database instance class and tags."

================================================================================
⚖️ 3. RISK ASSESSMENT & BLAST RADIUS
================================================================================
• Overall Risk Rating : {RISK_ICON} {RISK_LEVEL: LOW / MEDIUM / HIGH / CRITICAL}
• Blast Radius Score  : {BLAST_RADIUS_SCORE} / 10
• Stateful Destructions: {DESTRUCTIVE_COUNT} ({IF_NONE: "None - all updates are non-disruptive and in-place"})
• Security Impact     : {SECURITY_IMPACT_SUMMARY}

================================================================================
🔄 4. ROLLBACK & CONTINGENCY PLAN
================================================================================
• Rollback Trigger    : If automated smoke tests fail or 5xx error rate spikes > 1% within 10 mins post-apply.
• Rollback Procedure  :
  1. Trigger automated rollback workflow: `gh workflow run rollback-terraform.yml -f commit={PREVIOUS_STABLE_COMMIT}`
  2. Restore database snapshot if stateful changes occurred: `snapshot-pre-release-{TIMESTAMP}`.
  3. Re-verify health endpoints (`/healthz`).
• Estimated Rollback Time : ~5-10 minutes.

================================================================================
🧪 5. POST-DEPLOYMENT VERIFICATION STEPS
================================================================================
1. Verify CloudWatch / Datadog latency and error dashboards.
2. Run end-to-end automated synthetic smoke tests.
3. Validate DB connection pool metrics and application readiness probes.

---
Generated automatically by Claude CI/CD Infrastructure Agent.
Please reply with 'APPROVED' or log questions directly on the Pull Request.
```
