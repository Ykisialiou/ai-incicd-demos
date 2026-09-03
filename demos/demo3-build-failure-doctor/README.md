# Demo 3 — Build Failure Doctor

A pre-flight integration check fails with `HTTP 401: Unauthorized` against a payment gateway.
The surface error looks like a bad or expired credential:
`{"error": {"type": "authentication_error", "code": "invalid_api_key", "message": "Invalid API Key provided."}}`.

The engineer's instinct is to assume the CI secret is corrupted and waste time rotating credentials.
The agent analyzes the raw log, notices the database and cache resolved to `staging` endpoints while the gateway resolved to `production`, and deduces that `APP_ENV` defaulted to `production`—sending a staging test key (`sk_test_...`) to the production gateway.

The answer is present in the log — the challenge is cutting through the passing telemetry noise and spotting the environment mismatch behind the 401 red herring. Demo 3.1 is the contrasting case where the answer is not in the log at all.

## Running

```bash
./demos/demo3-build-failure-doctor/run_demo.sh
```

## Contents

| Path | What |
| :--- | :--- |
| `sample_broken_pipeline/app/config.py` | Configuration module where `APP_ENV` defaults to `production` |
| `sample_broken_pipeline/verify_service.py` | Integration test suite connecting to DB, cache, and payment gateway |
| `sample_broken_pipeline/broken_build.sh` | Runs the integration check in a simulated CI environment |
| `run_demo.sh` | Executes the broken pipeline, captures logs, and invokes the AI Build Doctor |
| `summarize_build_log.py` | Classifies telemetry noise vs error output before the diagnosis |
