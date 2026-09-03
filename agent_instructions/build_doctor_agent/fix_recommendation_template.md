# CI Build Doctor Diagnostic Output Template

Use the following markdown template when generating diagnoses for failed CI/CD pipeline steps:

```markdown
# 🩺 CI/CD Build Doctor: Pipeline Failure Diagnosis

### 🎯 Diagnosis Summary
- **Failure Category**: {FAILURE_CATEGORY: [Dependency Compilation | Missing Environment Secret | Test Assertion | Docker Layer Failure | Lint/Type Error]}
- **Failing Step / Command**: `{FAILING_COMMAND}` (Line {LINE_NUMBER_APPROX})
- **Primary Root Cause**: {ONE_SENTENCE_ROOT_CAUSE}

---

### 🔍 Key Log Excerpt (Culprit)
```text
{ISOLATED_ERROR_SNIPPET}
```

---

### 💡 Step-by-Step Remediation

1. **Root Cause Explanation**:
   {CONCISE_EXPLANATION_OF_WHY_IT_FAILED}

2. **Immediate Code / Config Fix**:
   {CODE_OR_CONFIG_DIFF_SNIPPET}

3. **Local Reproduction / Verification Command**:
   ```bash
   {LOCAL_VERIFY_COMMAND}
   ```

---

**Status**: 🛠️ Remediation ready. Apply fix and re-run pipeline.
```
