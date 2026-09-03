#!/usr/bin/env python3
"""
summarize_trivy.py - Condense a raw Trivy JSON report into a scannable summary.

Demo 2 is about alert fatigue, so the audience needs to see the "before" as a
number rather than as a 110KB wall of JSON they cannot read from row four. This
prints what the scanner found - counts by severity, a per-target breakdown, and
the full finding list folded away - immediately before the AI triage that turns
the same data into a handful of root-cause fixes.

It does no interpretation whatsoever: no ranking by exploitability, no grouping
by root cause, no fix advice. That is precisely the point of the contrast.

Usage:
    summarize_trivy.py --input trivy_scan.json [--out trivy_summary.md]
"""

import argparse
import json
import sys
from collections import Counter

SEVERITY_ORDER = ["CRITICAL", "HIGH", "MEDIUM", "LOW", "UNKNOWN"]
SEVERITY_ICON = {
    "CRITICAL": "🔴",
    "HIGH": "🟠",
    "MEDIUM": "🟡",
    "LOW": "🟢",
    "UNKNOWN": "⚪",
}


def collect(report: dict) -> dict:
    targets, vulns, misconfigs, secrets = [], [], [], []

    for result in report.get("Results", []) or []:
        v = result.get("Vulnerabilities") or []
        m = result.get("Misconfigurations") or []
        s = result.get("Secrets") or []
        if not (v or m or s):
            continue

        severities = [x.get("Severity", "UNKNOWN") for x in (v + m + s)]
        highest = min(
            (SEVERITY_ORDER.index(sev) for sev in severities if sev in SEVERITY_ORDER),
            default=len(SEVERITY_ORDER) - 1,
        )
        targets.append({
            "target": result.get("Target", "?"),
            "type": result.get("Type") or result.get("Class") or "-",
            "vulns": len(v),
            "misconfigs": len(m),
            "secrets": len(s),
            "highest": SEVERITY_ORDER[highest],
        })
        vulns.extend(v)
        misconfigs.extend(m)
        secrets.extend(s)

    return {"targets": targets, "vulns": vulns, "misconfigs": misconfigs, "secrets": secrets}


def render(report: dict, data: dict) -> str:
    vulns, misconfigs, secrets = data["vulns"], data["misconfigs"], data["secrets"]
    total = len(vulns) + len(misconfigs) + len(secrets)
    counts = Counter(x.get("Severity", "UNKNOWN") for x in (vulns + misconfigs + secrets))

    version = (report.get("Trivy") or {}).get("Version", "?")
    artifact = report.get("ArtifactName", "?")

    if total == 0:
        return (f"### 🔍 Trivy Raw Scan Output\n\n"
                f"**No findings.** Artifact `{artifact}`, Trivy {version}.\n\n"
                f"> ⚠️ Zero findings usually means the scanners or targets are misconfigured "
                f"rather than that the code is clean - check that a lock file is present and "
                f"that `--scanners` includes what you expect.\n")

    badge = " · ".join(
        f"{SEVERITY_ICON[sev]} {counts[sev]} {sev}"
        for sev in SEVERITY_ORDER if counts.get(sev)
    )

    out = [
        "### 🔍 Trivy Raw Scan Output",
        "",
        f"> **{total} findings** — {badge}  ",
        f"> Artifact `{artifact}` · Trivy {version} · "
        f"{len(vulns)} vulnerabilities, {len(misconfigs)} misconfigurations, {len(secrets)} secrets",
        "",
        "| Target | Type | Vulns | Misconfigs | Secrets | Highest |",
        "| :--- | :--- | ---: | ---: | ---: | :--- |",
    ]
    for t in data["targets"]:
        out.append(
            f"| `{t['target']}` | {t['type']} | {t['vulns']} | {t['misconfigs']} | "
            f"{t['secrets']} | {SEVERITY_ICON[t['highest']]} {t['highest']} |"
        )

    if vulns:
        ranked = sorted(
            vulns,
            key=lambda x: (SEVERITY_ORDER.index(x.get("Severity", "UNKNOWN"))
                           if x.get("Severity") in SEVERITY_ORDER else 99,
                           x.get("PkgName", "")),
        )
        out += [
            "",
            f"<details><summary>All {len(vulns)} CVEs, exactly as the scanner lists them "
            f"(by package, no exploitability ranking, no root cause)</summary>",
            "",
            "| Severity | CVE | Package | Installed | Fixed in |",
            "| :--- | :--- | :--- | :--- | :--- |",
        ]
        for x in ranked:
            sev = x.get("Severity", "UNKNOWN")
            fixed = x.get("FixedVersion") or "—"
            out.append(
                f"| {SEVERITY_ICON.get(sev, '⚪')} {sev} | {x.get('VulnerabilityID', '?')} "
                f"| `{x.get('PkgName', '?')}` | {x.get('InstalledVersion', '?')} | {fixed} |"
            )
        out.append("")
        out.append("</details>")

    if misconfigs:
        out += ["", "**Misconfigurations**", "", "| Severity | ID | Title |", "| :--- | :--- | :--- |"]
        seen = set()
        for m in sorted(misconfigs, key=lambda x: SEVERITY_ORDER.index(x.get("Severity", "UNKNOWN"))
                        if x.get("Severity") in SEVERITY_ORDER else 99):
            key = (m.get("ID"), m.get("Title"))
            if key in seen:
                continue
            seen.add(key)
            sev = m.get("Severity", "UNKNOWN")
            out.append(f"| {SEVERITY_ICON.get(sev, '⚪')} {sev} | {m.get('ID', '?')} | {m.get('Title', '?')} |")

    out += [
        "",
        f"> ⬆️ **This is what a developer gets today**: {total} findings, listed per package, "
        "with no ordering by exploitability and no indication that most of them share a handful "
        "of root causes. The AI triage below reads the same JSON.",
        "",
    ]
    return "\n".join(out)


def main() -> int:
    parser = argparse.ArgumentParser(description="Summarize a Trivy JSON report")
    parser.add_argument("--input", required=True)
    parser.add_argument("--out", default="trivy_summary.md")
    args = parser.parse_args()

    try:
        with open(args.input, encoding="utf-8") as handle:
            report = json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"❌ Could not read Trivy JSON from {args.input}: {exc}", file=sys.stderr)
        return 1

    markdown = render(report, collect(report))
    with open(args.out, "w", encoding="utf-8") as handle:
        handle.write(markdown)

    print(markdown)
    print(f"📄 Wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
