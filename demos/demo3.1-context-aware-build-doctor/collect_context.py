#!/usr/bin/env python3
"""
collect_context.py - assemble the evidence pack for demo 3.1, and establish the
baseline the agent has to beat.

Demo 3 hands the agent a log. This demo hands it a log *and* the repository's
real history, because the answer to this failure is not in the log at all.

Two jobs, in order:

1. Compute the log-only verdict, honestly. Not a claim about what a log parser
   would say - an actual sweep over the captured log, ranking the lines a human
   reaches for first and resolving the files they name. That verdict points at
   `charts/payments/templates/deployment.yaml`: correct, unchanged in four
   months, and not in the pull request. Acting on it means editing a template
   that is doing exactly what it was written to do.

2. Assemble the context pack: real `git log` / `git diff` / `git show` output
   from the fixture repository, plus what the run actually resolved - the
   lockfile Helm wrote this time, and the subchart it pulled in.

Usage:
    collect_context.py --log ci_run.log --repo .workspace/repo
                       --chart charts/payments --out context_pack.md
"""

import argparse
import os
import re
import subprocess
import sys
from collections import Counter

# Lines a log reader's eye - and `grep -iE 'error|fail'` - lands on first.
ATTENTION = re.compile(r"POLICY FAIL|\berror\b|\bfail(ed|ure|s)?\b|violation",
                       re.IGNORECASE)

# Helm and repository chatter: most of the file, none of the signal.
NOISE = re.compile(r"Successfully got an update|Hang tight|Happy Helming|"
                   r"^\s*$|^---$|^# Source:")

# A repository path as it appears in policy output.
SOURCE_REF = re.compile(r"\b((?:charts|ci|templates)/[\w./-]+\.(?:yaml|yml|tpl|py|sh))")


def git(repo: str, *args: str) -> str:
    """Run git in the fixture repo and return stdout, or an error marker."""
    try:
        done = subprocess.run(
            ["git", "-C", repo, *args],
            capture_output=True, text=True, check=True,
        )
        return done.stdout.rstrip("\n")
    except (OSError, subprocess.CalledProcessError) as exc:
        detail = getattr(exc, "stderr", "") or str(exc)
        return f"<git {' '.join(args)} failed: {detail.strip()}>"


def read(path: str, missing: str = "(not present)") -> str:
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            return handle.read().rstrip("\n")
    except OSError:
        return missing


def log_only_verdict(lines: list, pr_files: set) -> dict:
    """What the log alone offers, and which of it the pull request can explain."""
    attention = [(n, l) for n, l in enumerate(lines, 1)
                 if ATTENTION.search(l) and not NOISE.search(l)]

    # Only files named on a failure line count as blame. Paths that merely
    # appear in a command line are not accusations.
    refs = Counter()
    for _, line in attention:
        for path in SOURCE_REF.findall(line):
            refs[path] += 1

    blamed = list(refs)
    return {
        "attention": attention,
        "refs": refs,
        "blamed": blamed,
        "untouched_by_pr": [p for p in blamed if p not in pr_files],
    }


def lockfile_history(repo: str, chart: str) -> tuple:
    """The commit that removed Chart.lock, and the pin it was holding."""
    lock = f"{chart}/Chart.lock"
    sha = git(repo, "log", "--diff-filter=D", "--format=%H", "-1", "--", lock)
    if not sha or sha.startswith("<git "):
        return None, "(Chart.lock was never removed in this history)"
    return sha, git(repo, "show", f"{sha}^:{lock}")


def render(log_lines: list, verdict: dict, repo: str, chart: str,
           pr_files: set, exit_code) -> str:
    total = len(log_lines)
    noise = sum(1 for l in log_lines if NOISE.search(l))
    head_branch = git(repo, "rev-parse", "--abbrev-ref", "HEAD")
    pr_sha = git(repo, "log", "-1", "--format=%h")
    del_sha, old_lock = lockfile_history(repo, chart)

    out = [
        "# Demo 3.1 - Context Pack",
        "",
        "Everything below is captured at run time: the log from the failing job, real",
        "`git` output from the repository under test, and the dependency state this run",
        "actually resolved.",
        "",
        "---",
        "",
        "## A. The failing pipeline log",
        "",
        f"- **{total} lines**, exit code `{exit_code}`",
        f"- **{noise}** lines of Helm and repository chatter",
        f"- **{len(verdict['attention'])}** lines mention a failure at all",
        "",
        "```text",
    ]
    out += log_lines
    out += [
        "```",
        "",
        "---",
        "",
        "## B. The log-only verdict (baseline to beat)",
        "",
        "Every line in the capture above that mentions a failure:",
        "",
        "```text",
    ]
    for n, line in verdict["attention"][:12]:
        out.append(f"{n:>4} | {line}")
    out += [
        "```",
        "",
        "Files named on those lines:",
        "",
        "| File | Times named | Changed by this pull request? |",
        "| :--- | ---: | :--- |",
    ]
    for path, count in verdict["refs"].most_common():
        out.append(f"| `{path}` | {count} | {'yes' if path in pr_files else '**no**'}   |")

    primary = verdict["blamed"][0] if verdict["blamed"] else "(none)"
    out += [
        "",
        f"> **The gate points at `{primary}`.** That is the whole of what the log knows.",
        "> `helm lint` passed, `helm template` exited 0, and no line in the run records",
        "> which version of the dependency was resolved. The sections below supply what",
        "> the log cannot.",
        "",
        "---",
        "",
        "## C. Repository history (real git output)",
        "",
        "### C1. `git log -n 6 --date=relative` on the target branch",
        "",
        "```text",
        git(repo, "log", "-n", "6", "--date=relative",
            "--format=%h  %ad  %an <%ae>%n        %s"),
        "```",
        "",
        f"### C2. `git log -p` for the chart manifest, its lockfile, and .gitignore",
        "",
        "```diff",
        git(repo, "log", "-p", "--date=iso", "--",
            f"{chart}/Chart.yaml", f"{chart}/Chart.lock", ".gitignore"),
        "```",
        "",
        f"### C3. The pull request under review (`git diff main...{head_branch}`)",
        "",
        f"Head commit `{pr_sha}` - the run that went red.",
        "",
        "```diff",
        git(repo, "diff", f"main...{head_branch}"),
        "```",
        "",
        "### C4. Last change to each file the gate blames",
        "",
        "```text",
    ]
    for path in verdict["refs"] or ["(none)"]:
        out.append(git(repo, "log", "-1", "--date=relative",
                       f"--format=%h  %ad  %an  -  {path}: %s", "--", path)
                   or f"(no history for {path})")
    out += [
        "```",
        "",
        "### C5. The last version of Chart.lock that was ever committed",
        "",
        f"Removed by `{(del_sha or '')[:7]}`; this is its content at the parent commit.",
        "",
        "```yaml",
        old_lock,
        "```",
        "",
        "---",
        "",
        "## D. What this run actually resolved",
        "",
        "Dependencies are downloaded per run and are not in git. This is the state the",
        "pipeline built for itself a few seconds ago.",
        "",
        f"### D1. `{chart}/Chart.lock`, as written by this run",
        "",
        "```yaml",
        read(os.path.join(repo, chart, "Chart.lock")),
        "```",
        "",
        "### D2. The resolved subchart",
        "",
        "```yaml",
        read(os.path.join(repo, chart, "charts", "acme-common", "Chart.yaml")),
        "```",
        "",
        "Its resources helper - the template the chart calls to build the block the",
        "policy gate is complaining about:",
        "",
        "```gotemplate",
        read(os.path.join(repo, chart, "charts", "acme-common",
                          "templates", "_resources.tpl")),
        "```",
        "",
        "### D3. The values the chart supplies to it",
        "",
        "```yaml",
        read(os.path.join(repo, chart, "values.yaml")),
        "```",
        "",
    ]
    return "\n".join(out)


def main() -> int:
    parser = argparse.ArgumentParser(description="Assemble the demo 3.1 evidence pack")
    parser.add_argument("--log", required=True)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--chart", default="charts/payments")
    parser.add_argument("--exit-code", default="1")
    parser.add_argument("--out", default="context_pack.md")
    args = parser.parse_args()

    try:
        with open(args.log, encoding="utf-8", errors="replace") as handle:
            raw = handle.read()
    except OSError as exc:
        print(f"Could not read the pipeline log at {args.log}: {exc}", file=sys.stderr)
        return 1

    log_lines = raw.rstrip("\n").split("\n") if raw.strip() else []
    if not log_lines:
        print("The pipeline log is empty - the failing step produced no output.",
              file=sys.stderr)
        return 1

    head_branch = git(args.repo, "rev-parse", "--abbrev-ref", "HEAD")
    named = git(args.repo, "diff", "--name-only", f"main...{head_branch}")
    pr_files = {p for p in named.split("\n") if p and not p.startswith("<git ")}

    verdict = log_only_verdict(log_lines, pr_files)
    markdown = render(log_lines, verdict, args.repo, args.chart,
                      pr_files, args.exit_code)

    with open(args.out, "w", encoding="utf-8") as handle:
        handle.write(markdown)

    print(f"  Captured log        : {len(log_lines)} lines, exit code {args.exit_code}")
    print(f"  Lines naming a fail : {len(verdict['attention'])}")
    print(f"  Files blamed by log : {', '.join(verdict['refs']) or 'none'}")
    print(f"  Files in the PR     : {', '.join(sorted(pr_files)) or 'none'}")
    print()
    primary = verdict["blamed"][0] if verdict["blamed"] else "(none)"
    print(f"  LOG-ONLY VERDICT    : the gate blames {primary}")
    if primary not in pr_files:
        print("                        ...which this pull request does not touch.")
        print("                        helm lint passed. helm template exited 0.")
        print("                        The log never records which version was resolved.")
    print()
    print(f"  Wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
