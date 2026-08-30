# Demo 3: CI/CD Build Failure Doctor & Log Root Cause Analyzer

This demo illustrates an autonomous AI Agent acting as an instant on-call debugger when a CI/CD job fails, cutting Mean Time to Recovery (MTTR) from minutes to seconds.

---

## 🎯 Demo Storyline & Scenario

1. **The Context**: A developer adds a new caching library (`better-sqlite3`) to their Node.js service. The CI pipeline runs `npm ci` inside a lightweight Alpine container.
2. **The Problem**:
   - The build crashes with 300+ lines of messy compile output and cryptic `node-gyp` stack traces.
   - The developer is forced to hunt through hundreds of lines of npm download logs to find why `exit code 1` occurred.
3. **The AI Agent Solution**:
   - The CI pipeline failure handler catches the non-zero exit code and pipes the raw stdout/stderr log buffer into the **Build Doctor Agent**.
   - The agent filters out the download noise, pinpoints the root cause (`node-gyp` failed because Alpine lacks Python 3 and C++ build tools), and generates the exact fix command (`apk add --no-cache python3 make g++`).

---

## 🚀 Running the Demo

Execute the demo script:
```bash
./demos/demo3-build-failure-doctor/run_demo.sh
```

### Optional: Live Antigravity Mode
To run against the live model:
```bash
export AGY_API_KEY="your-api-key-here"
./demos/demo3-build-failure-doctor/run_demo.sh
```

---

## 🎤 Presenter Talking Points

> *"When a build fails, developers hate scrolling through 500 lines of npm or Gradle logs. The Build Doctor Agent intercepts the failure immediately, extracts the 3 critical lines that matter, and tells the developer exactly what package to install. This saves engineering hours every single sprint."*
