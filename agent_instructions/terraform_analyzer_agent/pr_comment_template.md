# Terraform PR Comment & Engineering Review Template

Designed for **Team Leads, SREs, and Release Managers** to evaluate infrastructure changes in 15 seconds without sifting through thousands of lines of raw Terraform diffs.

---

```markdown
# 🛑 Terraform SRE Gate: {GATE_STATUS: [APPROVED | WARNING | BLOCKED]}

> **Blast Radius Score**: **{SCORE}/10 ({RISK_LEVEL: LOW | MEDIUM | HIGH | CRITICAL})**  
> **Change Summary**: `+{ADD_COUNT}` to add, `~{CHANGE_COUNT}` to change, `💥{REPLACE_COUNT}` to replace, `-{DESTROY_COUNT}` to destroy.  
> **Notion RFC Page**: [📄 View CAB RFC Document]({NOTION_RFC_LINK_OR_FILE})

---

### 📋 Engineering Change Matrix (Fast-Scan for Team Leads & Release Managers)

| Resource | Action | Risk Level | Reason & Production Impact |
| :--- | :--- | :--- | :--- |
| `{resource.address}` | `{action: ✨ CREATE \| 🔄 UPDATE \| 💥 REPLACE \| ❌ DESTROY}` | `{RISK_ICON} {LEVEL}` | `{Clear 1-line business & technical explanation}` |

---

### 🚨 Critical Alerts & Hazards
{IF DESTRUCTIVE_REPLACEMENT:
- 💥 **DESTRUCTIVE REPLACEMENT DETECTED**: `{RESOURCE_ADDRESS}` will be **DROPPED AND RECREATED**. Potential data loss and downtime!
}
{IF OPEN_INGRESS:
- ⚠️ **PUBLIC INGRESS HAZARD**: `{SECURITY_GROUP_ADDRESS}` opens port `{PORT}` to `0.0.0.0/0` (Entire Internet).
}

---

### 🛡️ Recommended HCL Remediation Patch

```hcl
# Fix proposed by Antigravity Infrastructure Agent
{HCL_CODE_DIFF_OR_PREVENT_DESTROY_SNIPPET}
```

---

**Gate Verdict**: {DECISION_ICON} **{FINAL_DECISION: 🟢 APPROVED | 🟡 WARN (Manual Review) | 🔴 BLOCKED (Action Required)}**
```
