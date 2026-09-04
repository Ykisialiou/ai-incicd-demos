#!/usr/bin/env python3
"""
publish_notion_rfc.py - Converts Markdown RFCs into Beautiful Native Notion Blocks & Pages.

Features:
- Real Notion native Tables with headers and formatted cells
- Colored Callout Boxes for Critical Risk & SRE Warnings
- Rich Text formatting (Bold, Code, Links)
- Interactive To-Do Checklist blocks
- Native Code blocks with syntax highlighting
"""

import os
import re
import sys
import json
import argparse
import urllib.request
import urllib.error

def clean_page_id(raw_id: str) -> str:
    """Sanitizes user-provided Notion page ID / URL string to 32-hex ID."""
    if not raw_id:
        return ""
    cleaned = raw_id.strip().split("?")[0].split("/")[-1]
    match = re.search(r'([a-fA-F0-9]{32})$', cleaned)
    if match:
        return match.group(1)
    match_uuid = re.search(r'([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})', cleaned)
    if match_uuid:
        return match_uuid.group(1)
    return cleaned

def text_to_rich_text(text: str) -> list:
    """Parses markdown bold, code, and links into Notion rich_text array."""
    if not text:
        return [{"type": "text", "text": {"content": ""}}]

    pattern = re.compile(r'(\*\*.*?\*\*|`.*?`|\[.*?\]\(.*?\))')
    parts = pattern.split(text)
    rich_text = []
    
    for part in parts:
        if not part:
            continue
        if part.startswith("**") and part.endswith("**") and len(part) >= 4:
            rich_text.append({
                "type": "text",
                "text": {"content": part[2:-2][:2000]},
                "annotations": {"bold": True}
            })
        elif part.startswith("`") and part.endswith("`") and len(part) >= 2:
            rich_text.append({
                "type": "text",
                "text": {"content": part[1:-1][:2000]},
                "annotations": {"code": True}
            })
        elif part.startswith("[") and "](" in part and part.endswith(")"):
            try:
                link_text = part[1:part.index("](")][:2000]
                link_url = part[part.index("](") + 2:-1][:2000]
                rich_text.append({
                    "type": "text",
                    "text": {"content": link_text, "link": {"url": link_url}}
                })
            except Exception:
                rich_text.append({"type": "text", "text": {"content": part[:2000]}})
        else:
            rich_text.append({
                "type": "text",
                "text": {"content": part[:2000]}
            })
            
    return rich_text if rich_text else [{"type": "text", "text": {"content": text[:2000]}}]

NOTION_LANGUAGES = {
    "abap", "abc", "agda", "arduino", "ascii art", "assembly", "bash", "basic", "bnf",
    "c", "c#", "c++", "clojure", "coffeescript", "coq", "css", "dart", "dhall", "diff",
    "docker", "ebnf", "elixir", "elm", "erlang", "f#", "flow", "fortran", "gherkin",
    "glsl", "go", "graphql", "groovy", "haskell", "hcl", "html", "idris", "java",
    "javascript", "json", "julia", "kotlin", "latex", "less", "lisp", "livescript",
    "llvm ir", "lua", "makefile", "markdown", "markup", "matlab", "mathematica",
    "mermaid", "nix", "notion formula", "objective-c", "ocaml", "pascal", "perl",
    "php", "plain text", "powershell", "prolog", "protobuf", "purescript", "python",
    "r", "racket", "reason", "ruby", "rust", "sass", "scala", "scheme", "scss",
    "shell", "smalltalk", "solidity", "sql", "swift", "toml", "typescript", "vb.net",
    "verilog", "vhdl", "visual basic", "webassembly", "xml", "yaml", "java/c/c++/c#"
}

LANGUAGE_ALIASES = {
    "terraform": "hcl",
    "tf": "hcl",
    "sh": "bash",
    "zsh": "bash",
    "dockerfile": "docker",
    "js": "javascript",
    "ts": "typescript",
    "py": "python",
    "yml": "yaml",
    "text": "plain text",
    "txt": "plain text",
    "plain_text": "plain text",
    "plaintext": "plain text",
    "none": "plain text",
    "": "plain text"
}

def normalize_code_language(raw_lang: str) -> str:
    lang = raw_lang.strip().lower()
    if lang in LANGUAGE_ALIASES:
        return LANGUAGE_ALIASES[lang]
    if lang in NOTION_LANGUAGES:
        return lang
    return "plain text"


def parse_markdown_to_notion_blocks(markdown_content: str) -> list:
    """Parses full markdown document into clean, beautiful Notion block tree."""
    blocks = []
    lines = markdown_content.splitlines()
    
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if not stripped:
            i += 1
            continue

        # Skip main # Title (handled in page properties)
        if stripped.startswith("# "):
            i += 1
            continue

        # Headings
        if stripped.startswith("## "):
            blocks.append({
                "object": "block",
                "type": "heading_2",
                "heading_2": {
                    "rich_text": text_to_rich_text(stripped[3:])
                }
            })
            i += 1
            continue
        elif stripped.startswith("### "):
            blocks.append({
                "object": "block",
                "type": "heading_3",
                "heading_3": {
                    "rich_text": text_to_rich_text(stripped[4:])
                }
            })
            i += 1
            continue

        # Divider
        if stripped in ["---", "***", "___"]:
            blocks.append({
                "object": "block",
                "type": "divider",
                "divider": {}
            })
            i += 1
            continue

        # Callouts (> Alert)
        if stripped.startswith("> "):
            callout_text = stripped[2:].replace("[!CAUTION]", "🛑 CRITICAL:").replace("[!WARNING]", "⚠️ WARNING:").replace("[!IMPORTANT]", "ℹ️ IMPORTANT:")
            color = "red_background" if ("CRITICAL" in callout_text or "CAUTION" in callout_text or "DROP" in callout_text) else "yellow_background" if "WARNING" in callout_text else "blue_background"
            emoji = "🛑" if "CRITICAL" in callout_text or "CAUTION" in callout_text else "⚠️" if "WARNING" in callout_text else "📋"
            
            blocks.append({
                "object": "block",
                "type": "callout",
                "callout": {
                    "rich_text": text_to_rich_text(callout_text),
                    "icon": {"type": "emoji", "emoji": emoji},
                    "color": color
                }
            })
            i += 1
            continue

        # Code block
        if stripped.startswith("```"):
            lang = stripped[3:].strip().lower()
            code_lang = normalize_code_language(lang)
            code_lines = []
            i += 1
            while i < len(lines) and not lines[i].strip().startswith("```"):
                code_lines.append(lines[i])
                i += 1
            if i < len(lines):
                i += 1 # skip closing ```
            
            blocks.append({
                "object": "block",
                "type": "code",
                "code": {
                    "rich_text": [{"type": "text", "text": {"content": "\n".join(code_lines)[:2000]}}],
                    "language": code_lang
                }
            })
            continue

        # Tables (| Col 1 | Col 2 |)
        if stripped.startswith("|"):
            table_lines = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                if not re.match(r'^[\|\s\-:]+$', lines[i].strip()):
                    table_lines.append(lines[i].strip())
                i += 1

            if table_lines:
                # Extract rows
                rows_data = []
                for tline in table_lines:
                    cols = [c.strip() for c in tline.split("|")[1:-1]]
                    rows_data.append(cols)

                if rows_data:
                    width = max(len(r) for r in rows_data)
                    table_children = []
                    for row_idx, row in enumerate(rows_data):
                        # Pad row if needed
                        padded = row + [""] * (width - len(row))
                        cells = []
                        for cell_text in padded:
                            cell_rt = text_to_rich_text(cell_text)
                            if row_idx == 0:
                                for item in cell_rt:
                                    item.setdefault("annotations", {})["bold"] = True
                            cells.append(cell_rt)
                            
                        table_children.append({
                            "type": "table_row",
                            "table_row": {"cells": cells}
                        })

                    blocks.append({
                        "object": "block",
                        "type": "table",
                        "table": {
                            "table_width": width,
                            "has_column_header": True,
                            "has_row_header": False,
                            "children": table_children
                        }
                    })
            continue

        # Checkbox / To-Do
        if stripped.startswith("- [ ] ") or stripped.startswith("- [x] "):
            checked = stripped.startswith("- [x] ")
            todo_text = stripped[6:]
            blocks.append({
                "object": "block",
                "type": "to_do",
                "to_do": {
                    "rich_text": text_to_rich_text(todo_text),
                    "checked": checked
                }
            })
            i += 1
            continue

        # Bullet List Item
        if stripped.startswith("- ") or stripped.startswith("* ") or stripped.startswith("• "):
            bullet_text = stripped[2:]
            blocks.append({
                "object": "block",
                "type": "bulleted_list_item",
                "bulleted_list_item": {
                    "rich_text": text_to_rich_text(bullet_text)
                }
            })
            i += 1
            continue

        # Numbered List Item
        if re.match(r'^\d+\.\s+', stripped):
            num_text = re.sub(r'^\d+\.\s+', '', stripped)
            blocks.append({
                "object": "block",
                "type": "numbered_list_item",
                "numbered_list_item": {
                    "rich_text": text_to_rich_text(num_text)
                }
            })
            i += 1
            continue

        # Standard Paragraph
        blocks.append({
            "object": "block",
            "type": "paragraph",
            "paragraph": {
                "rich_text": text_to_rich_text(stripped)
            }
        })
        i += 1

    return blocks[:98] # Notion request limit

def publish_to_notion_api(api_key: str, raw_parent_page_id: str, title: str, markdown_content: str):
    """Pushes formal Change Management RFC page to Notion API."""
    parent_id = clean_page_id(raw_parent_page_id)
    url = "https://api.notion.com/v1/pages"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "Notion-Version": "2022-06-28"
    }

    blocks = parse_markdown_to_notion_blocks(markdown_content)

    payload = {
        "parent": {"page_id": parent_id},
        "icon": {"type": "emoji", "emoji": "📑"},
        "cover": {
            "type": "external",
            "external": {"url": "https://images.unsplash.com/photo-1558494949-ef010cbdcc31?w=1200"}
        },
        "properties": {
            "title": {
                "title": [{"type": "text", "text": {"content": title}}]
            }
        },
        "children": blocks
    }

    req = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            notion_url = data.get("url", "")
            print("\n" + "="*80)
            print(f"🎉 SUCCESS! Formal Change Management RFC published to Notion:")
            print(f"🔗 {notion_url}")
            print("="*80 + "\n")
            return notion_url
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8")
        print(f"❌ Notion API HTTP Error {e.code}: {error_body}")
        return None
    except Exception as e:
        print(f"❌ Connection error to Notion API: {str(e)}")
        return None

def extract_title_from_markdown(content: str, default_title: str) -> str:
    for line in content.splitlines():
        if line.strip().startswith("# "):
            title = line.strip()[2:].strip()
            if title:
                return title
    return default_title

def main():
    parser = argparse.ArgumentParser(description="Publish RFC to Notion / Change Management")
    parser.add_argument("--input", "-i", required=True, help="Path to RFC markdown file")
    parser.add_argument("--title", "-t", default=None, help="Optional custom title for Notion page")
    args = parser.parse_args()

    if not os.path.exists(args.input):
        print(f"Error: Input file {args.input} not found.")
        sys.exit(1)

    with open(args.input, "r", encoding="utf-8") as f:
        content = f.read()

    notion_api_key = os.getenv("NOTION_API_KEY")
    notion_page_id = os.getenv("NOTION_PAGE_ID") or os.getenv("NOTION_DATABASE_ID")

    page_title = args.title or extract_title_from_markdown(content, "RFC: Live Infrastructure Release Analysis")

    print(f"📄 Local RFC Document ready at: {args.input}")
    print(f"📑 Extracted Document Title: {page_title}")
    
    if notion_api_key and notion_page_id:
        publish_to_notion_api(
            api_key=notion_api_key,
            raw_parent_page_id=notion_page_id,
            title=page_title,
            markdown_content=content
        )
    else:
        print("💡 (To sync live with Notion, export NOTION_API_KEY and NOTION_PAGE_ID)")

if __name__ == "__main__":
    main()
