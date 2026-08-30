# ------------------------------------------------------------------------------
# DEMO 2: Microservice Dockerfile with Realistic Security Anti-Patterns
# ------------------------------------------------------------------------------

# Anti-Pattern 1: Outdated base image with 14 OS CVEs (libssl3, busybox)
FROM node:16.14.0-alpine

# Set working directory
WORKDIR /app

# Anti-Pattern 2: Hardcoded demo secret exposed in image layer history (Trivy Secret finding)
ENV AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
ENV AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

# Copy dependency manifests
COPY package*.json ./

# Anti-Pattern 3: Running npm install as root without user separation
RUN npm install --production

# Copy application source
COPY . .

# Expose app port
EXPOSE 3000

# Anti-Pattern 4: Container runs as root by default (AVD-DS-0002)
CMD ["node", "server.js"]
