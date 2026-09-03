import os

# Environment: defaults to production if not explicitly configured
APP_ENV = os.getenv("APP_ENV", "production")

# Infrastructure endpoints
DB_HOST = os.getenv("DB_HOST", "postgres-staging.internal:5432")
REDIS_HOST = os.getenv("REDIS_HOST", "redis-staging.internal:6379")

# Third-party integrations
if APP_ENV == "production":
    PAYMENT_GATEWAY_URL = "https://api.payments.production.company.internal/v2"
else:
    PAYMENT_GATEWAY_URL = "https://staging-api.payments.company.internal/v2"

# API credentials (in CI/test environment, a test key is injected)
PAYMENTS_API_KEY = os.getenv("PAYMENTS_API_KEY", "sk_test_9921_stage_checkout")
