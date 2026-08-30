#!/usr/bin/env python3
"""
publish_notion_rfc.py - Saves and optionally publishes RFC to Notion/Confluence.

Usage:
    python3 publish_notion_rfc.py --input change_requests/RFC-20260831-01-customer-db.md
"""

import os
import sys
import json
import argparse
import urllib.request
import urllib.error

def publish_to_notion_api(api_key: str, parent_page_id: str, title: str, markdown_content: str):
    """Optional live push to personal Notion page using Notion API v1."""
    url = "https://api.notion.com/v1/pages"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "Notion-Version": "2022-06-28"
    }
    
    # Split content into Notion paragraph blocks
    blocks = []
    for line in markdown_content.splitlines():
        if line.startswith("# "):
            blocks.append({
                "object": "block",
                "type": "heading_1",
                "heading_1": {"rich_text": [{"type": "text", "text": {"content": line[2:]}}]}
            })
        elif line.startswith("## "):
            blocks.append({
                "object": "block",
                "type": "heading_2",
                "heading_2": {"rich_text": [{"type": "text", "text": {"content": line[3:]}}]}
            })
        elif line.startswith("> "):
            blocks.append({
                "object": "block",
                "type": "callout",
                "callout": {
                    "rich_text": [{"type": "text", "text": {"content": line[2:]}}],
                    "icon": {"type": "emoji", "emoji": "⚠️"}
                }
            })
        elif line.strip():
            blocks.append({
                "object": "block",
                "type": "paragraph",
                "paragraph": {"rich_text": [{"type": "text", "text": {"content": line[:2000]}}]}
            })

    payload = {
        "parent": {"page_id": parent_page_id},
        "properties": {
            "title": {
                "title": [{"type": "text", "text": {"content": title}}]
            }
        },
        "children": blocks[:95] # Notion block limit per request
    }

    req = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            notion_url = data.get("url", "")
            print(f"🚀 Successfully published live RFC page to Notion: {notion_url}")
            return notion_url
    except Exception as e:
        print(f"Notice: Live Notion API upload skipped or failed ({str(e)}). Saved local RFC file.")
        return None

def main():
    parser = argparse.ArgumentParser(description="Publish RFC to Notion / Local Change Requests")
    parser.add_argument("--input", "-i", required=True, help="Path to RFC markdown file")
    args = parser.parse_args()

    if not os.path.exists(args.input):
        print(f"Error: Input file {args.input} not found.")
        sys.exit(1)

    with open(args.input, "r", encoding="utf-8") as f:
        content = f.read()

    notion_api_key = os.getenv("NOTION_API_KEY")
    notion_page_id = os.getenv("NOTION_PAGE_ID") or os.getenv("NOTION_DATABASE_ID")

    print(f"📄 Local Notion/Confluence RFC Document ready at: {args.input}")
    
    if notion_api_key and notion_page_id:
        publish_to_notion_api(notion_api_key, notion_page_id, "RFC-20260831-01: Production DB & Analytics Release", content)
    else:
        print("💡 (To sync live with Notion in presentation, export NOTION_API_KEY and NOTION_PAGE_ID)")

if __name__ == "__main__":
    main()
