#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Simulates a broken CI build step with noisy logs
# ------------------------------------------------------------------------------
set -e

echo "[CI] Starting pipeline job: build-and-test (Runner: ubuntu-latest / alpine-container)"
echo "[CI] Git commit: 4f8b92a (feat: integrate local SQLite cache)"
echo "[INFO] Setting up Node.js environment v20.10.0..."
echo "[INFO] Running: npm ci --prefer-offline"
echo ""

# Output 30 lines of realistic build progress
for i in {1..20}; do
  echo "npm http fetch GET 200 https://registry.npmjs.org/package-$i 42ms (from cache)"
done

echo ""
echo "> better-sqlite3@7.5.0 install /app/node_modules/better-sqlite3"
echo "> node-gyp rebuild"
echo ""
echo "gyp info it worked if it ends with ok"
echo "gyp info using node-gyp@8.4.1"
echo "gyp info using node@20.10.0 | linux | arm64"
echo "gyp ERR! find Python"
echo "gyp ERR! find Python - \"python3\" can't be in PATH"
echo "gyp ERR! find Python - Python is not installed in the system"
echo "gyp ERR! find Python - checking if Python is installed in /usr/bin/python"
echo "gyp ERR! find Python - \"python\" can't be in PATH"
echo "gyp ERR! stack Error: Could not find any Python installation to use"
echo "gyp ERR! stack     at PythonFinder.fail (/usr/local/lib/node_modules/npm/node_modules/node-gyp/lib/find-python.js:330:47)"
echo "gyp ERR! stack     at PythonFinder.runChecks (/usr/local/lib/node_modules/npm/node_modules/node-gyp/lib/find-python.js:123:21)"
echo "gyp ERR! System Linux 5.15.49-linuxkit"
echo "gyp ERR! command \"/usr/local/bin/node\" \"/usr/local/lib/node_modules/npm/node_modules/node-gyp/bin/node-gyp.js\" \"rebuild\""
echo "gyp ERR! cwd /app/node_modules/better-sqlite3"
echo "gyp ERR! node -v v20.10.0"
echo "gyp ERR! node-gyp -v v8.4.1"
echo "gyp ERR! not ok"
echo ""
echo "npm ERR! code 1"
echo "npm ERR! path /app/node_modules/better-sqlite3"
echo "npm ERR! command failed"
echo "npm ERR! command sh -c node-gyp rebuild"
echo ""
echo "[ERROR] Process completed with exit code 1."
exit 1
