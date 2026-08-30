# Outdated Node.js Alpine base image with known vulnerabilities (CVE-2023-0286 in libssl3, etc.)
FROM node:16.14.0-alpine

# Set working directory
WORKDIR /app

# Copy dependency manifests
COPY package*.json ./

# Install dependencies (running as root without user restriction)
RUN npm install --production

# Copy application source
COPY . .

# Expose app port
EXPOSE 3000

# Container runs as root (misconfiguration finding)
CMD ["node", "server.js"]
