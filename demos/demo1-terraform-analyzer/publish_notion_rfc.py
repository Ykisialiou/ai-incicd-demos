#!/usr/bin/env python3
"""
publish_notion_rfc.py - Converts and publishes RFC Change Management records to Notion API.

Usage:
    python3 publish_notion_rfc.py --input change_requests/RFC-20260831-01-customer-db.md
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
    # Check for 32 hex characters at the end of the slug
    match = re.search(r'([a-fA-F0-9]{32})$', cleaned)
    if match:
        return match.group(1)
    # Check for standard UUID format
    match_uuid = re.search(r'([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})', cleaned)
    if match_uuid:
        return match_uuid.group(1)
    return cleaned

def parse_markdown_to_notion_blocks(markdown_content: str) -> list:
    """Converts standard Markdown into Notion Block Objects."""
    blocks = []
    lines = markdown_content.splitlines()
    in_code_block = False
    code_lines = []
    code_lang = "plain_text"

    for line in lines:
        stripped = line.strip()

        # Handle Code blocks
        if stripped.startswith("```"):
            if in_code_block:
                in_code_block = False
                code_text = "\n".join(code_lines)[:2000]
                blocks.append({
                    "object": "block",
                    "type": "code",
                    "code": {
                        "rich_text": [{"type": "text", "text": {"content": code_text}}],
                        "language": code_lang if code_lang in ["bash", "javascript", "python", "json", "yaml", "html", "css", "dockerfile", "sql"] else "plain_text"
                    }
                })
                code_lines = []
            else:
                in_code_block = True
                lang = stripped[3:].strip().lower()
                code_lang = lang if lang else "plain_text"
            continue

        if in_code_block:
            code_lines.append(line)
            continue

        if not stripped:
            continue

        # Headings
        if stripped.startswith("# "):
            continue # Title handled in page properties
        elif stripped.startswith("## "):
            blocks.append({
                "object": "block",
                "type": "heading_2",
                "heading_2": {"rich_text": [{"type": "text", "text": {"content": stripped[3:]}}]}
            })
        elif stripped.startswith("### "):
            blocks.append({
                "object": "block",
                "type": "heading_3",
                "heading_3": {"rich_text": [{"type": "text", "text": {"content": stripped[4:]}}]}
            })
        # Callouts / Alerts
        elif stripped.startswith("> "):
            callout_text = stripped[2:].replace("[!CAUTION]", "⚠️ CAUTION:").replace("[!WARNING]", "⚠️ WARNING:").replace("[!IMPORTANT]", "ℹ️ IMPORTANT:")
            blocks.append({
                "object": "block",
                "type": "callout",
                "callout": {
                    "rich_text": [{"type": "text", "text": {"content": callout_text[:2000]}}],
                    "icon": {"type": "emoji", "emoji": "🛑" if "CAUTION" in callout_text or "CRITICAL" in callout_text else "📋"}
                }
            })
        # Checkbox / To-Do
        elif stripped.startswith("- [ ] ") or stripped.startswith("- [x] "):
            checked = stripped.startswith("- [x] ")
            todo_text = stripped[6:]
            blocks.append({
                "object": "block",
                "type": "to_do",
                "to_do": {
                    "rich_text": [{"type": "text", "text": {"content": todo_text[:2000]}}],
                    "checked": checked
                }
            })
        # Bullet list
        elif stripped.startswith("- ") or stripped.startswith("* ") or stripped.startswith("• "):
            bullet_text = stripped[2:]
            blocks.append({
                "object": "block",
                "type": "bulleted_list_item",
                "bulleted_list_item": {"rich_text": [{"type": "text", "text": {"content": bullet_text[:2000]}}]}
            })
        # Horizontal Rule
        elif stripped == "---" or stripped == "***":
            blocks.append({
                "object": "block",
                "type": "divider",
                "divider": {}
            })
        # Table rows or standard text
        elif stripped.startswith("|"):
            if "---" in stripped:
                continue
            cols = [c.strip() for c in stripped.split("|")[1:-1]]
            row_text = " │ ".join(cols)
            blocks.append({
                "object": "block",
                "type": "paragraph",
                "paragraph": {"rich_text": [{"type": "text", "text": {"content": row_text[:2000]}}]}
            })
        else:
            blocks.append({
                "object": "block",
                "type": "paragraph",
                "paragraph": {"rich_text": [{"type": "text", "text": {"content": stripped[:2000]}}]}
            })

    return blocks[:98] # Max blocks allowed by Notion per request

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
        if e.code == 404:
            print("\n💡 Troubleshooting 404:")
            print("1. Did you connect the integration to your Notion page? (Click '...' -> Connections -> Add your Integration)")
            print(f"2. Verified Page ID: '{parent_id}'")
        return None
    except Exception as e:
        print(f"❌ Connection error to Notion API: {str(e)}")
        return None

def main():
    parser = argparse.ArgumentParser(description="Publish RFC to Notion / Change Management")
    parser.add_argument("--input", "-i", required=True, help="Path to RFC markdown file")
    args = parser.parse_args()

    if not os.path.exists(args.input):
        print(f"Error: Input file {args.input} not found.")
        sys.exit(1)

    with open(args.input, "r", encoding="utf-8") as f:
        content = f.read()

    notion_api_key = os.getenv("NOTION_API_KEY")
    notion_page_id = os.getenv("NOTION_PAGE_ID") or os.getenv("NOTION_DATABASE_ID")

    print(f"📄 Local RFC Document ready at: {args.input}")
    
    if notion_api_key and notion_page_id:
        publish_to_notion_api(
            api_key=notion_api_key,
            raw_parent_page_id=notion_page_id,
            title="RFC-20260831-01: Production DB & Analytics Infrastructure Release",
            markdown_content=content
        )
    else:
        print("💡 (To sync live with Notion, export NOTION_API_KEY and NOTION_PAGE_ID)")

if __name__ == "__main__":
    main()
