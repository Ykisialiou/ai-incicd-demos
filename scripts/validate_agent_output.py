#!/usr/bin/env python3
"""Fail a CI step when the agent returned something that is not a report.

Observed failure (run 33544768139): Claude Code's default system prompt primes
the model to reach for tools - here, to check project memory before answering.
Because the step runs with `--tools ""` there is no Bash tool to call, so the
model emitted the tool call as plain prose and stopped:

    Let me check for relevant project memory before analyzing this plan.
    **Tool: bash**
    ```json
    {"command": "cat .../memory/MEMORY.md", "description": "Check memory index"}
    ```

The CLI exited 0. The workflow wrote those 282 bytes into the job summary and
would have posted them to the pull request. Publishing that is worse than
failing, so this guard makes the failure loud and immediate.

The real fix is `--system-prompt`, which replaces the agentic default; this
check is the seatbelt that ensures a regression is never silent again.

Usage: validate_agent_output.py FILE [--min-bytes N] [--label NAME]
"""

import argparse
import re
import sys

# A model narrating a tool call instead of producing prose.
TOOL_CALL_PATTERNS = [
    re.compile(r"^\s*\*\*Tool:\s*\w+\*\*\s*$", re.MULTILINE),
    re.compile(r"^\s*Tool:\s*(bash|read|glob|grep|write|edit)\s*$", re.MULTILINE | re.IGNORECASE),
    re.compile(r"\{\s*\"command\"\s*:", re.MULTILINE),
    re.compile(r"<(antml:)?invoke\b", re.IGNORECASE),
    re.compile(r"^\s*Let me (check|look at|read|search)\b.*\.\s*$", re.MULTILINE | re.IGNORECASE),
]


def main() -> int:
    parser = argparse.ArgumentParser(description="Sanity-check an AI agent's report before publishing it")
    parser.add_argument("path")
    parser.add_argument("--min-bytes", type=int, default=400,
                        help="Reports shorter than this are treated as truncated/failed (default: 400)")
    parser.add_argument("--label", default=None, help="Human-readable step name for the error message")
    args = parser.parse_args()

    label = args.label or args.path

    try:
        with open(args.path, encoding="utf-8") as handle:
            content = handle.read()
    except OSError as exc:
        print(f"::error::{label}: agent produced no output file ({exc})")
        return 1

    size = len(content.encode("utf-8"))
    stripped = content.strip()

    if not stripped:
        print(f"::error::{label}: agent returned an empty response.")
        return 1

    if size < args.min_bytes:
        print(f"::error::{label}: agent returned only {size} bytes "
              f"(minimum {args.min_bytes}). This is a truncated or failed generation, not a report.")
        print("--- actual output ---")
        print(content)
        return 1

    for pattern in TOOL_CALL_PATTERNS:
        match = pattern.search(content)
        if match:
            print(f"::error::{label}: agent narrated a tool call instead of writing the report "
                  f"(matched {match.group(0).strip()!r}). "
                  f"Check that --system-prompt is set so the CLI's agentic default does not apply.")
            print("--- actual output ---")
            print(content[:1000])
            return 1

    print(f"✅ {label}: {size} bytes, passes report sanity checks")
    return 0


if __name__ == "__main__":
    sys.exit(main())
