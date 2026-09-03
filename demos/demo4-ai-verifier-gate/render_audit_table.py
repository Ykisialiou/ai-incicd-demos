#!/usr/bin/env python3
"""
render_audit_table.py - Turn two judge verdicts into one compact comparison table.

Demo 4 runs the LLM-as-a-judge twice over the same ground truth: once against
the genuine Stage 1 report, once against a copy seeded with known fabrications.
Both verdicts arrive as the strict JSON contract in
agent_instructions/verifier_agent/system_prompt.md.

This renders them side by side, and scores the judge against the injection
manifest - the number that actually matters is how many planted fabrications it
caught, not how confident it sounded.

Usage:
    render_audit_table.py --clean verdict_clean.json --tampered verdict_tampered.json
                          --manifest manifest.json [--out audit_table.md]
"""

import argparse
import json
import re
import sys

FENCE = re.compile(r"^\s*```[a-zA-Z]*\s*|\s*```\s*$")


def load_verdict(path: str) -> dict:
    """Read a judge verdict, tolerating a stray code fence or leading prose."""
    try:
        with open(path, encoding="utf-8") as handle:
            raw = handle.read()
    except OSError as exc:
        return {"_error": f"could not read {path}: {exc}"}

    cleaned = FENCE.sub("", raw).strip()
    try:
        return json.loads(cleaned)
    except json.JSONDecodeError:
        # Fall back to the outermost JSON object in the response.
        start, end = cleaned.find("{"), cleaned.rfind("}")
        if start != -1 and end > start:
            try:
                return json.loads(cleaned[start:end + 1])
            except json.JSONDecodeError:
                pass
    return {"_error": f"{path} did not contain parseable JSON"}


def caught_ids(verdict: dict, manifest: dict) -> set:
    """Which planted fabrications does this verdict actually mention?"""
    if "_error" in verdict:
        return set()
    haystack = " ".join([
        " ".join(str(x) for x in verdict.get("hallucinations_detected", [])),
        " ".join(str(x) for x in verdict.get("inconsistencies", [])),
        str(verdict.get("summary", "")),
    ]).lower()

    caught = set()
    for item in manifest.get("injected", []):
        # Match on the distinctive token from each planted claim.
        needles = {
            "phantom-resource": ["payment_gateway"],
            "flipped-action": ["data_lake"],
            "invented-cve": ["2024-99999", "99999"],
            "blast-radius-math": ["blast radius", "destructive replacement", "10.0", "10/10"],
        }.get(item["id"], [item["id"]])
        if any(n.lower() in haystack for n in needles):
            caught.add(item["id"])
    return caught


def row(label: str, verdict: dict, expected: str) -> str:
    if "_error" in verdict:
        return f"| {label} | ⚠️ UNPARSEABLE | — | — | {verdict['_error']} |"

    passed = verdict.get("verification_passed")
    outcome = verdict.get("audit_verdict", "UNKNOWN")
    icon = "🟢" if passed else "🔴"
    score = verdict.get("factual_accuracy_score", "—")
    found = len(verdict.get("hallucinations_detected", []) or [])
    match = "✅ as expected" if outcome.upper() == expected else f"⚠️ expected {expected}"
    return f"| {label} | {icon} **{outcome}** | {score}% | {found} | {match} |"


def main() -> int:
    parser = argparse.ArgumentParser(description="Render the two-pass audit comparison")
    parser.add_argument("--clean", required=True)
    parser.add_argument("--tampered", required=True)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--out", default="audit_table.md")
    args = parser.parse_args()

    clean = load_verdict(args.clean)
    tampered = load_verdict(args.tampered)
    try:
        with open(args.manifest, encoding="utf-8") as handle:
            manifest = json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"❌ Could not read manifest: {exc}", file=sys.stderr)
        return 1

    planted = manifest.get("injected", [])
    caught = caught_ids(tampered, manifest)

    lines = [
        "### 🛡️ Two-Pass Verification Result",
        "",
        "The same judge, the same ground truth, two candidate reports:",
        "",
        "| Candidate Report | Verdict | Accuracy | Hallucinations Found | Outcome |",
        "| :--- | :--- | :--- | :--- | :--- |",
        row("Genuine Stage 1 output", clean, "APPROVED"),
        row("Same report, 4 fabrications injected", tampered, "REJECTED"),
        "",
        f"**Detection rate: {len(caught)} / {len(planted)} planted fabrications caught.**",
        "",
        "| Planted Fabrication | Rubric Dimension | Caught? |",
        "| :--- | :--- | :--- |",
    ]
    for item in planted:
        mark = "✅ caught" if item["id"] in caught else "❌ missed"
        lines.append(f"| {item['claim']} | {item['dimension']} | {mark} |")

    lines += [
        "",
        "> ℹ️ **Advisory gate**: both verdicts are reported; the job does not fail.",
        "> The clean report is generated live, then a deterministic script seeds a copy",
        "> with known fabrications — so the judge is measured against an answer key,",
        "> not against a vibe.",
        "",
    ]
    markdown = "\n".join(lines)

    with open(args.out, "w", encoding="utf-8") as handle:
        handle.write(markdown)

    print(markdown)
    if "_error" not in tampered and len(caught) < len(planted):
        missed = [i["claim"] for i in planted if i["id"] not in caught]
        print(f"::warning::Judge missed {len(missed)} planted fabrication(s): {'; '.join(missed)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
