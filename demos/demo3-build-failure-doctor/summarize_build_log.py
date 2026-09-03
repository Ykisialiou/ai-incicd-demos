#!/usr/bin/env python3
"""
summarize_build_log.py - Render the captured CI log as the "before" half of demo 3.

The Build Doctor's claim is that it finds three useful lines in a log nobody
wants to read. That only lands if the audience sees the log first - so this
prints the whole thing, plus a count of how much of it is download chatter
versus actual error output.

It classifies lines by simple pattern matching and does no diagnosis: it will
tell you 20 lines are npm noise, but not which error matters or how to fix it.
That is the agent's job, immediately below.

Usage:
    summarize_build_log.py --input build_output.log [--exit-code 1]
                           [--out build_log_summary.md]
"""

import argparse
import re
import sys

NOISE = re.compile(r"npm (http )?fetch|GET 200|\(from cache\)|^\s*$", re.IGNORECASE)
ERROR = re.compile(r"gyp ERR!|npm ERR!|\bERROR\b|\bError:|FAIL(ED)?\b|Traceback", re.IGNORECASE)
SCAFFOLD = re.compile(r"^\[(CI|INFO|WARN|DEBUG)\]", re.IGNORECASE)


def classify(lines: list) -> dict:
    noise = [l for l in lines if NOISE.search(l)]
    errors = [l for l in lines if ERROR.search(l) and not NOISE.search(l)]
    scaffold = [l for l in lines if SCAFFOLD.search(l) and not ERROR.search(l)]
    counted = set(map(id, noise + errors + scaffold))
    other = [l for l in lines if id(l) not in counted]
    return {"noise": noise, "errors": errors, "scaffold": scaffold, "other": other}


def render(lines: list, buckets: dict, exit_code, byte_len: int) -> str:
    total = len(lines)
    if total == 0:
        return ("### 📄 Captured Build Log\n\n"
                "**The log is empty.** The build step produced no output at all, which "
                "usually means it failed before it started rather than during the build.\n")

    def pct(n):
        return f"{round(100 * n / total)}%" if total else "—"

    rows = [
        ("Dependency-download chatter", len(buckets["noise"])),
        ("Error output (`gyp ERR!` / `npm ERR!`)", len(buckets["errors"])),
        ("CI scaffolding (`[CI]` / `[INFO]`)", len(buckets["scaffold"])),
        ("Everything else", len(buckets["other"])),
    ]

    exit_note = f" · exit code `{exit_code}`" if exit_code is not None else ""
    out = [
        "### 📄 Captured Build Log",
        "",
        f"> **{total} lines captured**{exit_note} · {byte_len:,} bytes  ",
        f"> {len(buckets['errors'])} of those lines are error output — "
        f"the rest is noise the engineer has to scroll past.",
        "",
        "| Line type | Lines | Share |",
        "| :--- | ---: | ---: |",
    ]
    out += [f"| {label} | {count} | {pct(count)} |" for label, count in rows if count]

    out += [
        "",
        f"<details><summary>Full captured log ({total} lines) — this is the input the agent receives</summary>",
        "",
        "```text",
    ]
    out += lines
    out += [
        "```",
        "",
        "</details>",
        "",
        "> ⬆️ **This is the haystack.** No highlighting, no ordering, no root cause — "
        "exactly what lands in a CI tab at 5pm. The diagnosis below reads the same text.",
        "",
    ]
    return "\n".join(out)


def main() -> int:
    parser = argparse.ArgumentParser(description="Summarize a captured CI build log")
    parser.add_argument("--input", required=True)
    parser.add_argument("--exit-code", default=None)
    parser.add_argument("--out", default="build_log_summary.md")
    args = parser.parse_args()

    try:
        with open(args.input, encoding="utf-8", errors="replace") as handle:
            raw = handle.read()
    except OSError as exc:
        print(f"❌ Could not read build log from {args.input}: {exc}", file=sys.stderr)
        return 1

    lines = raw.rstrip("\n").split("\n") if raw.strip() else []
    markdown = render(lines, classify(lines), args.exit_code, len(raw.encode("utf-8")))

    with open(args.out, "w", encoding="utf-8") as handle:
        handle.write(markdown)

    # Console gets the counts; the full log is already on stdout from the build step.
    print("\n".join(markdown.split("<details>")[0].rstrip().split("\n")))
    print(f"\n📄 Wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
