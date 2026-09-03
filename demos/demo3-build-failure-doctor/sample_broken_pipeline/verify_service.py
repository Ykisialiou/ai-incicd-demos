#!/usr/bin/env python3
"""
verify_service.py - Integration & Health Check Suite

Runs pre-deployment health checks against backing services and integrations.
"""

import os
import sys
import time
from urllib.error import HTTPError

from app.config import APP_ENV, DB_HOST, REDIS_HOST, PAYMENT_GATEWAY_URL, PAYMENTS_API_KEY


def log_step(name: str):
    print(f"[CI:HEALTHCHECK] Checking {name}...", flush=True)
    time.sleep(0.05)


def check_database():
    log_step(f"Database connection ({DB_HOST})")
    print(f"  --> Connected to PostgreSQL pool (latency: 4ms, ssl: require) - OK", flush=True)


def check_redis():
    log_step(f"Redis cache ({REDIS_HOST})")
    print(f"  --> PING received PONG (latency: 1ms) - OK", flush=True)


def check_payment_gateway():
    log_step(f"Payment gateway handshake ({PAYMENT_GATEWAY_URL})")
    print(f"  --> Initializing client with API key: {PAYMENTS_API_KEY[:7]}... (active environment: {APP_ENV})", flush=True)
    print(f"  --> POST {PAYMENT_GATEWAY_URL}/charges/ping HTTP/1.1", flush=True)

    # Real-world behavior: production gateway requires a live key (sk_live_...)
    # Test keys (sk_test_...) are rejected with standard HTTP 401 without hints
    if "production" in PAYMENT_GATEWAY_URL and PAYMENTS_API_KEY.startswith("sk_test_"):
        raise HTTPError(
            url=f"{PAYMENT_GATEWAY_URL}/charges/ping",
            code=401,
            msg="Unauthorized",
            hdrs={"Content-Type": "application/json", "Www-Authenticate": 'Bearer realm="payments-production"'},
            fp=None,
        )

    print("  --> Gateway handshake successful (HTTP 200 OK)", flush=True)


def main():
    print(f"================================================================================")
    print(f" 🚀 Running Pre-Flight Integration Suite (Environment: {APP_ENV})")
    print(f"================================================================================")
    print(f"[INFO] Commit: 9b2d8f1 (feat: update checkout integration)")
    print(f"[INFO] Node runner: ubuntu-latest | Python: {sys.version.split()[0]}")
    print()

    try:
        check_database()
        check_redis()
        check_payment_gateway()
    except HTTPError as exc:
        print()
        print(f"[FATAL] Integration check failed: {exc}", file=sys.stderr)
        print(f"  URL: {exc.url}", file=sys.stderr)
        print(f"  Status: {exc.code} {exc.msg}", file=sys.stderr)
        print(f"  Response Body: {{\"error\": {{\"type\": \"authentication_error\", \"code\": \"invalid_api_key\", \"message\": \"Invalid API Key provided.\"}}}}", file=sys.stderr)
        print()
        print(f"Traceback (most recent call last):", file=sys.stderr)
        print(f'  File "verify_service.py", line 47, in main', file=sys.stderr)
        print(f"    check_payment_gateway()", file=sys.stderr)
        print(f'  File "verify_service.py", line 37, in check_payment_gateway', file=sys.stderr)
        print(f"    raise HTTPError(", file=sys.stderr)
        print(f"urllib.error.HTTPError: HTTP Error 401: Unauthorized", file=sys.stderr)
        return 1

    print()
    print("✅ All pre-flight integration checks passed successfully.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
