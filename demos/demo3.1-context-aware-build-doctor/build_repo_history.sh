#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Demo 3.1 - fixture builder: a REAL git repository with a REAL commit history.
#
# Nothing here is a canned text file pretending to be `git log`. This script
# initialises an actual repository, writes actual file revisions, and commits
# them with backdated author timestamps, so every piece of context the agent
# receives later comes out of real `git log` / `git diff` / `git show`.
#
# The story it encodes:
#   * `templates/deployment.yaml` was written 4 months ago and never touched.
#   * 2 days ago the platform team stopped committing Chart.lock and loosened
#     the acme-common dependency from `2.3.1` to `^2.3.0`.
#   * Priya's pull request bumps an image tag. One line.
#
# The pipeline that fails is Priya's. The commit that broke it is not hers.
# ------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${1:-$SCRIPT_DIR/.workspace/repo}"

# Backdated timestamps, computed portably. `date -d` (GNU) and `date -v` (BSD)
# disagree on flags; python3 is already a hard dependency of every demo here.
stamp() {
  python3 - "$1" <<'PY'
import datetime, sys
delta = datetime.timedelta(days=float(sys.argv[1]))
print((datetime.datetime.now(datetime.timezone.utc) - delta).strftime("%Y-%m-%dT%H:%M:%S+00:00"))
PY
}

commit_as() {
  local name="$1" email="$2" days="$3" subject="$4" body="${5:-}"
  local when; when="$(stamp "$days")"
  git -C "$REPO" add -A
  if [ -n "$body" ]; then
    GIT_AUTHOR_NAME="$name" GIT_AUTHOR_EMAIL="$email" GIT_AUTHOR_DATE="$when" \
    GIT_COMMITTER_NAME="$name" GIT_COMMITTER_EMAIL="$email" GIT_COMMITTER_DATE="$when" \
      git -C "$REPO" commit -q -m "$subject" -m "$body"
  else
    GIT_AUTHOR_NAME="$name" GIT_AUTHOR_EMAIL="$email" GIT_AUTHOR_DATE="$when" \
    GIT_COMMITTER_NAME="$name" GIT_COMMITTER_EMAIL="$email" GIT_COMMITTER_DATE="$when" \
      git -C "$REPO" commit -q -m "$subject"
  fi
}

rm -rf "$REPO"
mkdir -p "$REPO"
git -C "$REPO" init -q -b main
git -C "$REPO" config user.name "Fixture"
git -C "$REPO" config user.email "fixture@example.invalid"
git -C "$REPO" config commit.gpgsign false

# ------------------------------------------------------------------------------
# Commit 1 (4 months ago) - the chart. `templates/deployment.yaml` is written
# here and never touched again, which will not stop the policy gate from
# blaming it four months from now.
# ------------------------------------------------------------------------------
mkdir -p "$REPO/charts/payments/templates" "$REPO/ci"

cat > "$REPO/charts/payments/Chart.yaml" <<'EOF'
apiVersion: v2
name: payments
description: Payments API
type: application
version: 1.8.2
appVersion: "1.8.2"

dependencies:
  - name: acme-common
    version: 2.3.1
    repository: https://charts.acme.io
EOF

# Committed lockfile: the pin that is about to be thrown away.
cat > "$REPO/charts/payments/Chart.lock" <<EOF
dependencies:
- name: acme-common
  repository: https://charts.acme.io
  version: 2.3.1
digest: sha256:6f0b7c4a1d3e58921ac4f0e7b25d9a4c8e13f60d5b7a29c4e08f1d3b6a75e2c9
generated: "$(stamp 120)"
EOF

cat > "$REPO/charts/payments/values.yaml" <<'EOF'
replicaCount: 3

image:
  repository: ghcr.io/acme/payments
  tag: "1.8.2"
  pullPolicy: IfNotPresent

service:
  port: 80

container:
  port: 8080

resources:
  limits:
    memory: 512Mi
    cpu: 500m
  requests:
    memory: 256Mi
    cpu: 100m
EOF

cat > "$REPO/charts/payments/templates/deployment.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}
  labels:
    app.kubernetes.io/name: payments
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app.kubernetes.io/name: payments
  template:
    metadata:
      labels:
        app.kubernetes.io/name: payments
    spec:
      containers:
        - name: payments
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.container.port }}
          resources:
            {{- include "acme-common.resources" . | nindent 12 }}
EOF

cat > "$REPO/charts/payments/templates/service.yaml" <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}
  labels:
    app.kubernetes.io/name: payments
spec:
  type: ClusterIP
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      name: http
  selector:
    app.kubernetes.io/name: payments
EOF

# The policy gate. Deliberately reports the chart source file, not just the
# rendered artifact - which is what makes its (correct) output so misleading.
cat > "$REPO/ci/policy_gate.py" <<'EOF'
#!/usr/bin/env python3
"""Fail the pipeline when a rendered container has no resource limits.

Stands in for conftest/OPA or Kyverno in this pipeline. Line-oriented on
purpose: a policy gate that needs a YAML library is a policy gate that does not
run on every image.
"""
import re
import sys

LIMITS = ("memory", "cpu")


def containers(lines):
    """Yield (container_name, source_file, resources_block_lines)."""
    name = source = citems = None
    block, in_block, indent = [], False, 0
    for line in lines + ["\n"]:
        # Helm labels each document with its template, relative to the chart.
        # Charts live under charts/<name>/, so that is the repo path.
        m = re.match(r"^# Source: (\S+)", line)
        if m:
            source, citems = "charts/" + m.group(1), None
        # Only a `- name:` at the containers list indent is a container; the
        # same shape appears one level deeper for each named port.
        m = re.match(r"^(\s*)containers:\s*$", line)
        if m:
            citems = len(m.group(1)) + 2
        m = re.match(r"^(\s*)- name: (\S+)\s*$", line)
        if m and not in_block and citems is not None and len(m.group(1)) == citems:
            name = m.group(2)
        m = re.match(r"^(\s*)resources:\s*(\S*)\s*$", line)
        if m:
            if in_block:
                yield name, source, block
            in_block, indent, block = True, len(m.group(1)), []
            continue
        if in_block:
            stripped = line.rstrip("\n")
            if stripped and (len(stripped) - len(stripped.lstrip())) <= indent:
                yield name, source, block
                in_block, block = False, []
            else:
                block.append(stripped)
    if in_block:
        yield name, source, block


def main():
    with open(sys.argv[1], encoding="utf-8") as handle:
        lines = handle.readlines()

    violations = 0
    for name, source, block in containers(lines):
        text = "\n".join(block)
        has_limits = "limits:" in text
        for key in LIMITS:
            if not has_limits or not re.search(rf"^\s+{key}:", text, re.MULTILINE):
                print(f'POLICY FAIL  {source}  container "{name}": '
                      f"resources.limits.{key} is not set")
                violations += 1

    if violations:
        print(f"{violations} violations, gate failed")
        return 1
    print("0 violations, gate passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
EOF
chmod +x "$REPO/ci/policy_gate.py"

cat > "$REPO/ci/pipeline.sh" <<'EOF'
#!/usr/bin/env bash
# Resolve dependencies, render the chart, run it past the policy gate.
set -euo pipefail

helm repo add acme https://charts.acme.io
helm dependency update charts/payments
helm lint charts/payments
helm template payments charts/payments --namespace payments > rendered.yaml
timeout 120 python3 ci/policy_gate.py rendered.yaml
EOF
chmod +x "$REPO/ci/pipeline.sh"

# Resolved dependencies are downloaded in CI, not committed. Standard practice,
# and the reason the lockfile was the only record of which version was in use.
cat > "$REPO/.gitignore" <<'EOF'
charts/*/charts/
rendered.yaml
EOF

commit_as "Marta Lind" "marta.lind@acme.io" 120 \
  "feat: payments chart on the shared acme-common building blocks"

# ------------------------------------------------------------------------------
# Commit 2 (6 weeks ago) - unrelated chart work. Note it touches service.yaml,
# not deployment.yaml.
# ------------------------------------------------------------------------------
python3 - "$REPO/charts/payments/values.yaml" <<'PY'
import sys
path = sys.argv[1]
text = open(path).read().replace(
    "service:\n  port: 80\n",
    "service:\n  port: 80\n  metricsPort: 9090\n")
open(path, "w").write(text)
PY

cat > "$REPO/charts/payments/templates/service.yaml" <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}
  labels:
    app.kubernetes.io/name: payments
spec:
  type: ClusterIP
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      name: http
    - port: {{ .Values.service.metricsPort }}
      targetPort: metrics
      name: metrics
  selector:
    app.kubernetes.io/name: payments
EOF

commit_as "Marta Lind" "marta.lind@acme.io" 41 \
  "feat(payments): expose the metrics port on the service"

# ------------------------------------------------------------------------------
# Commit 3 (2 days ago) - THE CULPRIT.
#
# Two changes that are each defensible on their own and lethal together:
# delete the lockfile, and loosen the version range it was pinning.
# ------------------------------------------------------------------------------
rm "$REPO/charts/payments/Chart.lock"

cat > "$REPO/.gitignore" <<'EOF'
charts/*/charts/
Chart.lock
rendered.yaml
EOF

python3 - "$REPO/charts/payments/Chart.yaml" <<'PY'
import sys
path = sys.argv[1]
text = open(path).read().replace("    version: 2.3.1\n", "    version: ^2.3.0\n")
open(path, "w").write(text)
PY

commit_as "Platform Bot" "platform-bot@acme.io" 2 \
  "chore(ci): stop committing Chart.lock" \
  "Chart.lock conflicts on every release train and helm dependency update
regenerates it in CI anyway, so there is no reason to keep it in git.

Loosening the acme-common range to ^2.3.0 at the same time, so upstream patch
fixes land without a PR in every service repo."

# ------------------------------------------------------------------------------
# Commit 4 (1 day ago) - noise, so the culprit is not simply "the last commit".
# ------------------------------------------------------------------------------
mkdir -p "$REPO/docs"
cat > "$REPO/docs/runbook.md" <<'EOF'
# Payments runbook

- Staging namespace: `payments-staging`
- Chart validation runs on every pull request (`ci/pipeline.sh`).
- Ask in #platform if the policy gate fails on a chart you did not touch.
EOF

commit_as "Dan Weber" "dan.weber@acme.io" 1 \
  "docs: note the staging namespace in the runbook"

# ------------------------------------------------------------------------------
# Commit 5 (10 hours ago) - a much more tempting false lead: somebody changed
# the CI pipeline itself, hours before the failure.
# ------------------------------------------------------------------------------
python3 - "$REPO/ci/pipeline.sh" <<'PY'
import sys
path = sys.argv[1]
text = open(path).read().replace("timeout 120 python3", "timeout 300 python3")
open(path, "w").write(text)
PY

commit_as "Marta Lind" "marta.lind@acme.io" 0.42 \
  "chore(ci): raise the policy gate timeout"

# ------------------------------------------------------------------------------
# Commit 6 (2 hours ago) - the pull request under review. An image tag and a
# chart version. Three lines, no templates, no dependencies.
# ------------------------------------------------------------------------------
git -C "$REPO" checkout -q -b feat/bump-payments-1.9.0

python3 - "$REPO/charts/payments/values.yaml" "$REPO/charts/payments/Chart.yaml" <<'PY'
import sys
values, chart = sys.argv[1], sys.argv[2]
text = open(values).read().replace('tag: "1.8.2"', 'tag: "1.9.0"')
open(values, "w").write(text)
text = open(chart).read().replace("version: 1.8.2", "version: 1.9.0")
open(chart, "w").write(text.replace('appVersion: "1.8.2"', 'appVersion: "1.9.0"'))
PY

commit_as "Priya Nair" "priya.nair@acme.io" 0.08 \
  "release(payments): bump payments to 1.9.0"

echo "Built a real git repository at: $REPO"
echo "  $(git -C "$REPO" rev-list --count main) commits on main, plus 1 on feat/bump-payments-1.9.0"
