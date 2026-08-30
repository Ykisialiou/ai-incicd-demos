# ------------------------------------------------------------------------------
# DEMO 2: Vulnerable Microservice (PR #3)
# Scanned by Trivy -> Triaged by AI Security Agent
# ------------------------------------------------------------------------------

# 1. Base OS Vulnerability: Outdated Node.js Alpine base image with libssl3 CVE-2023-0286
FROM node:16.14.0-alpine

# Set working directory
WORKDIR /app

# 2. Hardcoded Leaked Secret: Exposed in Docker layer history (AKIA...)
ENV AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
ENV AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

# Copy dependency manifests
COPY package*.json ./

# 3. Running as root without non-root user separation
RUN npm install --production

# Copy application source
COPY . .

# Expose app port
EXPOSE 3000

# 4. Container runs as root by default (AVD-DS-0002)
CMD ["node", "server.js"]
