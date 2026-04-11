"""
知识库工具 — 读 / 写本地 markdown 知识库
"""

import json
from datetime import datetime
from pathlib import Path

from .. import config
from ..storage import list_insights, search_insights


def read_kb(query: str = "", limit: int = 10) -> str:
    """
    读知识库 — 返回与 query 相关的灵感（或最近 N 条）

    Args:
        query: 搜索关键词（空字符串则返回最近的）
        limit: 最多返回多少条

    Returns:
        JSON 字符串，包含灵感列表
    """
    if query:
        items = search_insights(query)[:limit]
    else:
        items = list_insights(limit=limit)

    result = {
        "query": query,
        "count": len(items),
        "insights": [
            {
                "id": ins.id,
                "summary": ins.summary,
                "category": ins.category,
                "tags": ins.tags,
                "keywords": ins.keywords,
                "raw_text_preview": ins.raw_text[:200],
                "timestamp": ins.timestamp,
            }
            for _, ins in items
        ],
    }
    return json.dumps(result, ensure_ascii=False, indent=2)


def write_kb_report(title: str, content: str) -> str:
    """
    写一份调研报告到 wiki/topics/

    Args:
        title: 报告标题
        content: markdown 格式的报告正文

    Returns:
        保存路径
    """
    config.ensure_dirs()
    topics_dir = config.KB_WIKI / "topics"
    topics_dir.mkdir(parents=True, exist_ok=True)

    safe_title = title.replace("/", "_").replace(" ", "_")[:50]
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    path = topics_dir / f"{timestamp}-{safe_title}.md"

    md = f"""---
title: {title}
generated_by: V3 ResearchAgent
generated_at: {datetime.now().isoformat(timespec="seconds")}
---

# {title}

{content}
"""
    path.write_text(md, encoding="utf-8")
    return json.dumps({
        "saved_to": str(path.relative_to(config.KB_ROOT)),
        "absolute_path": str(path),
        "size_bytes": len(md.encode("utf-8")),
    }, ensure_ascii=False)
