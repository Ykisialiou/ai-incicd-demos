#!/usr/bin/env python3
"""Strip an outer code fence wrapping an entire AI-generated report.

The model sometimes returns its whole answer wrapped in ```markdown ... ```.
Pasted verbatim into a PR comment or $GITHUB_STEP_SUMMARY, that renders the
report as one grey code block instead of formatted markdown. Inner fences
(HCL patches, JSON verdicts, log excerpts) must survive untouched, so the
outer pair is only removed when the fences in between are balanced.

Usage: strip_code_fence.py FILE   (rewrites FILE in place)
"""

import re
import sys

FENCE_OPEN = re.compile(r"^```[A-Za-z0-9_+-]*$")


def strip_outer_fence(text: str) -> str:
    lines = text.split("\n")

    start = 0
    while start < len(lines) and not lines[start].strip():
        start += 1
    end = len(lines) - 1
    while end >= 0 and not lines[end].strip():
        end -= 1
    if end <= start:
        return text

    if not FENCE_OPEN.match(lines[start].strip()) or lines[end].strip() != "```":
        return text

    inner = lines[start + 1:end]
    # Odd number of inner fences means the first line opened a real code block
    # that closes somewhere in the middle - not a wrapper around the whole doc.
    if sum(1 for line in inner if line.strip().startswith("```")) % 2 != 0:
        return text

    return "\n".join(inner).strip("\n") + "\n"


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: strip_code_fence.py FILE", file=sys.stderr)
        return 2

    path = sys.argv[1]
    with open(path, encoding="utf-8") as handle:
        original = handle.read()

    stripped = strip_outer_fence(original)
    if stripped == original:
        return 0

    with open(path, "w", encoding="utf-8") as handle:
        handle.write(stripped)
    print(f"🧹 Stripped outer code fence from {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
