#!/usr/bin/env python3
"""
inject_hallucinations.py - Forge a corrupted copy of a genuine AI report.

Demo 4's premise is that an LLM judge catches fabrications in another LLM's
output. Stage 1 tells the truth, so left alone the judge has nothing to find
and always returns APPROVED - an anti-hallucination gate that has never caught
a hallucination proves nothing.

This script takes the genuine Stage 1 report and writes a tampered copy
containing a fixed set of fabrications, each one aimed at a dimension the
rubric in agent_instructions/verifier_agent/verification_rules.md scores:

  - Resource Existence : a resource that appears nowhere in plan.json
  - Action Fidelity    : a real resource with its action flipped to DESTROY
  - CVE Authenticity   : an invented CVE (and this is a Terraform plan - there
                         are no CVEs in it at all)
  - Blast Radius Math  : a score contradicted by the plan's own counts

The injected claims are written in the same register as the surrounding report
and carry NO marker - a label like "[INJECTED]" would let the judge pass by
pattern-matching instead of by checking claims against ground truth.

The manifest it emits is the answer key, used only after the judge has ruled,
to score which fabrications it actually caught.

Usage:
    inject_hallucinations.py --input clean.md --output tampered.md
                             --manifest manifest.json
"""

import argparse
import json
import sys

# Each fabrication: the prose spliced into the report, plus the short label and
# rubric dimension used to score the judge afterwards.
FABRICATIONS = [
    {
        "id": "phantom-resource",
        "dimension": "Resource Existence",
        "claim": "aws_rds_cluster.payment_gateway is being destroyed",
        "resource": "`aws_rds_cluster.payment_gateway`",
        "action": "destroy",
        "risk": "🔴 CRITICAL",
        "impact": ("Aurora cluster backing the payments service is torn down and "
                   "recreated, incurring an estimated 45 minutes of checkout downtime"),
    },
    {
        "id": "flipped-action",
        "dimension": "Action Fidelity",
        "claim": "aws_s3_bucket.data_lake is being deleted (plan says create)",
        "resource": "`aws_s3_bucket.data_lake`",
        "action": "destroy",
        "risk": "🔴 CRITICAL",
        "impact": ("Existing data lake bucket is deleted and re-provisioned, "
                   "permanently discarding 14 TB of archived analytics objects"),
    },
    {
        "id": "invented-cve",
        "dimension": "CVE Authenticity",
        "claim": "CVE-2024-99999 cited with CVSS 9.8",
        "resource": "`aws_db_instance.production_db`",
        "action": "create",
        "risk": "🔴 CRITICAL",
        "impact": ("Engine version 15.4 is affected by CVE-2024-99999 (CVSS 9.8), a "
                   "remote code execution flaw in the Postgres query planner"),
    },
]


def build_row(fab: dict, column_count: int) -> str:
    """Render a fabrication to match the column count of the table it joins.

    Stage 1's table shape is model-authored and may drift, so the injected rows
    adapt rather than assuming a fixed layout - a row with the wrong number of
    cells would render as visibly broken markdown and give the judge a
    structural tell instead of making it check the claim.
    """
    if column_count <= 2:
        cells = [fab["resource"], fab["impact"]]
    elif column_count == 3:
        cells = [fab["resource"], fab["action"], fab["impact"]]
    elif column_count == 4:
        cells = [fab["resource"], fab["action"], fab["risk"], fab["impact"]]
    else:
        # 5+ columns: repeat the risk verdict across the middle, impact last.
        middle = [fab["risk"]] * (column_count - 3)
        cells = [fab["resource"], fab["action"]] + middle + [fab["impact"]]
    return "| " + " | ".join(cells[:column_count]) + " |"


BLAST_RADIUS_LIE = (
    "\n### Verified Impact Summary\n\n"
    "This plan performs **4 destructive replacements** across the production estate "
    "and will drop 3 existing stateful resources. Aggregate blast radius across all "
    "affected services is **10.0/10**, the highest score this gate has recorded.\n"
)

BLAST_RADIUS_ENTRY = {
    "id": "blast-radius-math",
    "dimension": "Blast Radius Math",
    "claim": "claims 4 destructive replacements and 3 dropped resources (plan has 0)",
}


def tamper(report: str) -> str:
    """Splice fabricated rows into the report's table, then append a false summary."""
    lines = report.split("\n")

    def is_table_row(line: str) -> bool:
        stripped = line.strip()
        return stripped.startswith("|") and not set(stripped) <= set("|:- ")

    # Column count comes from the first real table row we see.
    column_count = 0
    last_row = None
    for i, line in enumerate(lines):
        if is_table_row(line):
            if column_count == 0:
                column_count = len([c for c in line.strip().strip("|").split("|")])
            last_row = i

    if last_row is None:
        # No table to splice into - append the claims as prose instead.
        prose = "\n".join(f"- {f['resource']}: {f['impact']}" for f in FABRICATIONS)
        return report.rstrip("\n") + "\n\n### Additional Findings\n\n" + prose + "\n" + BLAST_RADIUS_LIE

    rows = [build_row(f, column_count) for f in FABRICATIONS]
    lines[last_row + 1:last_row + 1] = rows
    return "\n".join(lines).rstrip("\n") + "\n" + BLAST_RADIUS_LIE


def main() -> int:
    parser = argparse.ArgumentParser(description="Inject known fabrications into an AI report")
    parser.add_argument("--input", required=True, help="Genuine Stage 1 report")
    parser.add_argument("--output", required=True, help="Where to write the tampered copy")
    parser.add_argument("--manifest", required=True, help="Answer key of what was injected")
    args = parser.parse_args()

    try:
        with open(args.input, encoding="utf-8") as handle:
            report = handle.read()
    except OSError as exc:
        print(f"❌ Could not read {args.input}: {exc}", file=sys.stderr)
        return 1

    if not report.strip():
        print(f"❌ {args.input} is empty - Stage 1 produced no report to tamper with.", file=sys.stderr)
        return 1

    tampered = tamper(report)
    manifest = {
        "source_report": args.input,
        "injected_count": len(FABRICATIONS) + 1,
        "injected": [
            {"id": f["id"], "dimension": f["dimension"], "claim": f["claim"]}
            for f in FABRICATIONS
        ] + [BLAST_RADIUS_ENTRY],
    }

    with open(args.output, "w", encoding="utf-8") as handle:
        handle.write(tampered)
    with open(args.manifest, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)

    print(f"🧪 Injected {manifest['injected_count']} fabrications into {args.output}:")
    for item in manifest["injected"]:
        print(f"   - [{item['dimension']}] {item['claim']}")
    print(f"📄 Answer key written to {args.manifest}")
    print(f"📄 Clean report {len(report)} bytes -> tampered {len(tampered)} bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
