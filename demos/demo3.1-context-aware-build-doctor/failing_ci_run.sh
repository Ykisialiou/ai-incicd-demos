#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Demo 3.1 - the red pipeline run.
#
# This is the chart-validate job: resolve dependencies, render, run the policy
# gate. `helm template` and the policy gate are executed for real against the
# fixture repository, so the rendered manifest in the log is genuinely what Helm
# produced - including the empty `resources:` block that is the whole point.
#
# One step is simulated: `helm dependency update`. There is no charts.acme.io,
# so the resolution of `^2.3.0` to 2.4.0 is performed by copying from the local
# registry/ fixture and writing the lockfile Helm would have written. Every
# other command is the real thing.
#
# What matters for the demo is what the log does NOT contain. Helm resolves a
# floating range without printing the version it picked, renders a missing value
# as empty without warning, and exits 0. There is no mention of acme-common's
# version, of the values key that moved, or of any commit but Priya's.
#
# Usage: failing_ci_run.sh --repo <path> --registry <path>
# Env:   PR_COMMIT_SHA, PR_COMMIT_SUBJECT
# ------------------------------------------------------------------------------
set -u

REPO="" REGISTRY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="$2"; shift 2;;
    --registry) REGISTRY="$2"; shift 2;;
    *) shift;;
  esac
done

SHA="${PR_COMMIT_SHA:-0000000}"
SUBJECT="${PR_COMMIT_SUBJECT:-release(payments): bump payments to 1.9.0}"
RESOLVED_VERSION="2.4.0"

echo "[CI] Job: payments / chart-validate  (pull_request #482)"
echo "[CI] Branch: feat/bump-payments-1.9.0 -> main"
echo "[CI] Commit: $SHA  $SUBJECT"
echo "[CI] Author: Priya Nair <priya.nair@acme.io>"
echo "[CI] Runner: ubuntu-24.04 (2-core, 7 GB)"
echo "[CI] Workflow step: ci/pipeline.sh"
echo "[CI] helm: $(helm version --template '{{.Version}}' 2>/dev/null || echo v3.16.2)"
echo ""

# ------------------------------------------------------------------------------
# Repository chatter. Every service pipeline in the fleet prints this, nobody
# reads it, and it is where the one interesting line is going to hide.
# ------------------------------------------------------------------------------
echo "+ helm repo add acme https://charts.acme.io"
echo "\"acme\" has been added to your repositories"
echo "+ helm repo update"
echo "Hang tight while we grab the latest from your chart repositories..."
for r in bitnami acme acme-legacy prometheus-community grafana ingress-nginx jetstack external-secrets; do
  echo "...Successfully got an update from the \"$r\" chart repository"
done
echo "[WARN] chartmuseum: ERROR 404 fetching index.yaml for repo \"acme-legacy\" (skipped, not referenced by this chart)"
echo "Update Complete. ⎈Happy Helming!⎈"
echo ""

# ------------------------------------------------------------------------------
# Dependency resolution. THE SIMULATED STEP.
#
# Note what real `helm dependency update` prints: that it downloaded something,
# not which version it settled on. With Chart.lock deleted and the range
# loosened to ^2.3.0, that decision is made here, silently, and the log keeps
# no record of it.
# ------------------------------------------------------------------------------
echo "+ helm dependency update charts/payments"
echo "Hang tight while we grab the latest from your chart repositories..."
echo "...Successfully got an update from the \"acme\" chart repository"
echo "Update Complete. ⎈Happy Helming!⎈"
echo "Saving 1 charts"
echo "Downloading acme-common from repo https://charts.acme.io"
echo "Deleting outdated charts"

mkdir -p "$REPO/charts/payments/charts"
rm -rf "$REPO/charts/payments/charts/acme-common"
cp -r "$REGISTRY/acme-common-$RESOLVED_VERSION" "$REPO/charts/payments/charts/acme-common"

cat > "$REPO/charts/payments/Chart.lock" <<EOF
dependencies:
- name: acme-common
  repository: https://charts.acme.io
  version: $RESOLVED_VERSION
digest: sha256:2b9e77c1a0f4d38e5c62b148af07d9e3c5a81f60b47e2d9a3c08b5f17e64d0a2
generated: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EOF
echo ""

# ------------------------------------------------------------------------------
# Lint. Passes, because nothing here is malformed - the chart is valid and the
# values it reads are simply not the values it is given.
# ------------------------------------------------------------------------------
echo "+ helm lint charts/payments"
(cd "$REPO" && helm lint charts/payments 2>&1) || true
echo "manifest_sorter.go:192: info: skipping unknown hook: \"crd-install\""
echo ""

# ------------------------------------------------------------------------------
# Render. Real Helm, real output, exit code 0.
# ------------------------------------------------------------------------------
echo "+ helm template payments charts/payments --namespace payments > rendered.yaml"
(cd "$REPO" && helm template payments charts/payments --namespace payments > rendered.yaml 2>/tmp/helm_stderr.$$)
HELM_EXIT=$?
sed 's/^/helm: /' /tmp/helm_stderr.$$ 2>/dev/null | head -5
rm -f /tmp/helm_stderr.$$
echo "helm template exit code: $HELM_EXIT"
echo ""
echo "+ cat rendered.yaml"
cat "$REPO/rendered.yaml"
echo ""

# ------------------------------------------------------------------------------
# The policy gate. The only thing in this pipeline that notices, and the only
# file name it can offer is the template - which is correct, and useless.
# ------------------------------------------------------------------------------
echo "+ timeout 300 python3 ci/policy_gate.py rendered.yaml"
(cd "$REPO" && python3 ci/policy_gate.py rendered.yaml)
GATE_EXIT=$?
echo ""
echo "[ERROR] Policy gate failed. Process completed with exit code $GATE_EXIT."
exit "$GATE_EXIT"
