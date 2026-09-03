# Demo 2 — Trivy Scan Triage

A `trivy fs --scanners vuln,secret,misconfig` run over a small Node service
produces ~19 CVEs across the lock file plus 4 Dockerfile misconfigurations. The
agent triages that dump into a short list of root-cause fixes.

What it separates:

- CVEs that collapse into one dependency bump (`lodash` 4.17.15 → 4.17.21,
  `express` 4.16.0 → current) from ones that need individual attention
- Findings with no available fix, which are noise in a gate
- Dockerfile issues that are not CVEs at all — AWS credentials baked into `ENV`
  layers, container running as `root`

Because this is a filesystem scan, findings come from `package-lock.json` and the
`Dockerfile`. Base-OS CVEs (`libssl3`, `zlib`, `busybox`, `musl`) require
building the image and running `trivy image` instead.

## Running

```bash
./demos/demo2-trivy-security-analyzer/run_demo.sh
```

## Contents

| Path | What |
| :--- | :--- |
| `sample_app/` | Dockerfile and package manifests with known-vulnerable pins |
| `trivy_scan.json` | A captured scan, so the demo runs without Trivy installed |
| `run_demo.sh` | Runs the scan (or uses the capture), then the agent over the JSON |
| `summarize_trivy.py` | Counts the raw findings, so the triage has a before/after |

Regenerate the scan by hand:

```bash
trivy fs --scanners vuln,secret,misconfig --format json \
  -o demos/demo2-trivy-security-analyzer/trivy_scan.json \
  demos/demo2-trivy-security-analyzer/sample_app
```
