#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Simulates a failing CI pipeline integration / smoke test step
# ------------------------------------------------------------------------------
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[CI] Starting pipeline job: pre-flight-integration-tests"
echo "[CI] Runner: GitHub Actions Hosted Runner (ubuntu-latest)"
echo "[CI] Branch: refs/heads/feat/checkout-flow-v2"
echo ""

# In a real CI environment, the runner sets secrets for the test stage:
export PAYMENTS_API_KEY="sk_test_9921_stage_checkout"
export DB_HOST="postgres-staging.internal:5432"
export REDIS_HOST="redis-staging.internal:6379"

# Note: The developer forgot to set APP_ENV="staging" in the workflow env block!
# Because APP_ENV is unset, the app config defaults to "production".

echo "[CI] Executing command: python3 verify_service.py"
python3 "$SCRIPT_DIR/verify_service.py"
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  echo ""
  echo "[ERROR] Process completed with exit code $EXIT_CODE."
fi

exit $EXIT_CODE
