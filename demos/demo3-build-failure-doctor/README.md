# Demo 3 — Build Failure Doctor

A Node build fails inside an Alpine container. `npm ci` triggers a `node-gyp`
rebuild of `better-sqlite3`, and the image has no Python or C++ toolchain.

The agent gets the raw console output and returns the failing command, the root
cause, and the fix (`apk add --no-cache python3 make g++`).

The answer is present in the log — the work is filtering the dependency chatter
around it. Demo 3.1 is the case where the answer is not in the log at all.

## Running

```bash
./demos/demo3-build-failure-doctor/run_demo.sh
```

## Contents

| Path | What |
| :--- | :--- |
| `sample_broken_pipeline/broken_build.sh` | Emits the failing build's console output, exits 1 |
| `run_demo.sh` | Runs the broken build, captures the log, invokes the agent |
| `summarize_build_log.py` | Classifies the captured lines, so the log is visible before the diagnosis |
