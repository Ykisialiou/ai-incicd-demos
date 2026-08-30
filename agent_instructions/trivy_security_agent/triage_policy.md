# Trivy DevSecOps Security Triage Policy & Decision Framework

This document instructs the AI Security Agent on resolving complex, non-obvious security findings that raw scanners cannot solve automatically.

---

## 🎯 The 6 Complex Scenarios & Agent Resolution Rules

### 1. 🔑 Hardcoded Secrets in Docker Layers (`Trivy Secret Findings`)
- **Scanner Trap**: Trivy flags `ENV AWS_ACCESS_KEY_ID=...`. A junior dev tries `RUN rm /app/config.js` or `unset`, which leaves the secret permanently embedded in Docker image history!
- **Agent Resolution**:
  - Warn that layer history retains deleted secrets.
  - Advise revoking/rotating the leaked AWS IAM key immediately.
  - Provide Docker BuildKit secret mount syntax (`RUN --mount=type=secret...`) or runtime environment injection via Kubernetes Secrets / AWS Secrets Manager.

### 2. 💣 Rootless Container Trap (`AVD-DS-0002: User is Root`)
- **Scanner Trap**: Just adding `USER node` causes `EACCES: permission denied` at runtime when writing to logs or cache directories.
- **Agent Resolution**:
  - Provide directory creation and ownership assignment (`RUN mkdir -p /app/logs && chown -R node:node /app`) BEFORE executing `USER node`.

### 3. 🕸️ Transitive Vulnerability with `FixedVersion: NONE` (`CVE-2023-45853` in `zlib`)
- **Scanner Trap**: `Fixed version: None` in a transitive dependency (`archiver -> zip-stream -> zlib`). The dev cannot run `npm update`.
- **Agent Resolution**:
  - Trace dependency chain and identify that it resides in `devDependencies` (documentation/build tooling) which does not run in production.
  - Provide `overrides` / `resolutions` snippet for `package.json` to suppress or enforce a safe patched sub-package.

### 4. 📦 Grouping Sub-Dependency Noise into 1 Unified Parent Bump
- **Scanner Trap**: Trivy spits out 10+ individual CVEs for `qs`, `body-parser`, `cookie`, `send`.
- **Agent Resolution**:
  - Group all sub-dependency CVEs under their parent package: `"express: 4.16.0" ➔ "^4.18.2"`. One single package bump resolves all 10 CVEs!

### 5. 🛡️ Base OS Image Obsolescence (`libssl3` CVE-2023-0286)
- **Scanner Trap**: Scanning reports 14 OS-level package CVEs individually.
- **Agent Resolution**:
  - Do NOT recommend running `apk upgrade` on 14 individual packages.
  - Recommend bumping the base image in `Dockerfile`: `FROM node:16.14.0-alpine` ➔ `FROM node:20.11.0-alpine`.

### 6. 🔒 IaC / Terraform S3 Security Modernization
- **Scanner Trap**: `AVD-AWS-0086: S3 missing encryption and public block`.
- **Agent Resolution**:
  - Provide modern Terraform AWS Provider v5+ standalone resources: `aws_s3_bucket_public_access_block` and `aws_s3_bucket_server_side_encryption_configuration`.
