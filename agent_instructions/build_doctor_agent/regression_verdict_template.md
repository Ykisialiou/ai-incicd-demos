# Build Doctor — Contextual Regression Verdict Template

Use this template when the input includes repository history and the question is
**who broke this**, not merely **what broke**. Output the markdown below and
nothing else — no preamble, no wrapping code fence around the whole response.

```markdown
# 🩺 Build Doctor — Contextual Regression Verdict

### ⚖️ Verdict
| | |
| :--- | :--- |
| **Did this pull request cause the failure?** | {NO — PRE-EXISTING ENVIRONMENT REGRESSION / YES — INTRODUCED BY THIS PR / INCONCLUSIVE} |
| **Confidence** | {HIGH / MEDIUM / LOW} |
| **Culprit** | `{SHA}` "{SUBJECT}" — {AUTHOR}, {AGE} |
| **Mechanism** | {one line: what that commit removed or changed, and how it reaches this test} |
| **Also affected** | {every other open PR / only this branch / production too} |

---

### 🔍 What the log says
- **Failing assertion**: `{TEST_NAME}` — expected `{EXPECTED}`, received `{RECEIVED}`
- **Named source file**: `{FILE}:{LINE}` — last changed `{SHA}` ({AGE})
- **Pattern**: {e.g. "every non-English locale fails; en-US passes"}

### 🧾 Evidence chain
| # | Evidence | Where it came from |
| :--- | :--- | :--- |
| 1 | {fact} | {log line N / git log / image provenance} |
| 2 | {fact} | {...} |
| 3 | {fact} | {...} |

Each row must be checkable against the supplied input. Do not include a step
that requires information not present in the context pack.

---

### 🕳️ What a log-only tool would have told you

> {the plausible, wrong conclusion the log supports on its own}

{Why it is wrong, in one or two sentences.}

### 🚫 Do not apply this fix
```{lang}
{the tempting patch — usually editing the expectation, skipping the test, or
adding the missing dependency in the wrong place}
```
{What this costs: which users get the defect, which detector it deletes.}

---

### ✅ Correct fix — right file, right owner

**Owner**: {team or author of the culprit commit}
**File**: `{PATH}`

```diff
{the minimal patch, at the place the regression was introduced}
```

**Verify**:
```bash
{command that reproduces the failure and confirms the fix}
```

### 🛡️ Preventing the recurrence
- {a guard that would have caught this at the culprit commit, not three days later}

---

**Recommendation**: {MERGE — unrelated failure / HOLD — fix the environment first / BLOCK — PR is at fault}
```
