# Build Doctor Log Filtering Rules & Patterns

This document defines regex patterns and heuristics for filtering noisy CI/CD logs down to actionable root causes.

## Noise Patterns to Skip
- Download progress lines (`Downloading... 45%`, `fetch http://...`)
- Standard info logs (`[INFO]`, `Resolving dependencies...`, `Scanning projects...`)
- Verbose test passing lines (`✓ test passed (3ms)`)
- Post-failure cleanup boilerplate (`exit status 1`, `cleaning up temporary workspace...`, `Process completed with exit code 1.`)

## Key Signal Indicators
- Compiler errors: `error:`, `fatal error:`, `gyp ERR!`, `clang: error:`
- Stack traces: `Error:`, `Exception:`, `Panic:`, `Traceback (most recent call last):`
- Assertion failures: `AssertionError`, `Expected: ... Received: ...`
- Missing commands/files: `command not found`, `No such file or directory`, `cannot find module`
- Permission errors: `EACCES: permission denied`, `403 Forbidden`, `Unauthorized`
- Out of memory: `JavaScript heap out of memory`, `Killed`, `exit code 137`
