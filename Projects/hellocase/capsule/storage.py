"""
存储层 — Markdown-as-DB

每条灵感 = 一个 .md 文件，含 YAML frontmatter（元数据）+ 正文（内容）。
SQLite 索引层在 V2 加，V1 直接扫文件就够用（< 1000 条灵感性能完全够）。
"""

import re
from dataclasses import asdict, dataclass, field
from datetime import datetime
from pathlib import Path

from . import config


@dataclass
class Insight:
    """单条灵感数据结构（与 hackathon_demo/data/insights.json 兼容）"""

    id: str
    summary: str
    tags: list[str]
    keywords: list[str]
    category: str
    insight: str
    timestamp: str
    source: str  # text / image / link / voice
    raw_text: str = ""           # 原始内容（OCR 后的文字）
    image_path: str = ""          # 截图路径（如果是 image 来源）
    links: list[str] = field(default_factory=list)  # Obsidian 风格双向链接

    def to_markdown(self) -> str:
        """序列化成带 frontmatter 的 markdown 文件内容"""
        fm_lines = [
            "---",
            f"id: {self.id}",
            f"created: {self.timestamp}",
            f"source: {self.source}",
            f"category: {self.category}",
            f"tags: [{', '.join(self.tags)}]",
            f"keywords: [{', '.join(self.keywords)}]",
        ]
        if self.image_path:
            fm_lines.append(f"image: {self.image_path}")
        if self.links:
            fm_lines.append(f"links: [{', '.join(self.links)}]")
        fm_lines.append("---")

        body_lines = [
            "",
            f"# {self.summary}",
            "",
            "## 原文",
            "",
            self.raw_text,
            "",
            "## AI 洞察",
            "",
            self.insight,
            "",
        ]

        return "\n".join(fm_lines + body_lines)

    @classmethod
    def from_markdown(cls, path: Path) -> "Insight":
        """从 markdown 文件读回 Insight 对象"""
        text = path.read_text(encoding="utf-8")
        fm_match = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.DOTALL)
        if not fm_match:
            raise ValueError(f"文件没有 frontmatter: {path}")

        fm_text, body = fm_match.groups()
        fm: dict = {}
        for line in fm_text.splitlines():
            if ":" not in line:
                continue
            k, _, v = line.partition(":")
            v = v.strip()
            if v.startswith("[") and v.endswith("]"):
                v = [x.strip() for x in v[1:-1].split(",") if x.strip()]
            fm[k.strip()] = v

        # 从正文里提取 raw_text 和 insight
        raw_text = ""
        insight = ""
        if "## 原文" in body:
            after_raw = body.split("## 原文", 1)[1]
            if "## AI 洞察" in after_raw:
                raw_text = after_raw.split("## AI 洞察", 1)[0].strip()
            else:
                raw_text = after_raw.strip()
        if "## AI 洞察" in body:
            insight = body.split("## AI 洞察", 1)[1].strip()

        return cls(
            id=fm.get("id", ""),
            summary=fm.get("created", "").split("T")[0] if not body.strip().startswith("# ") else body.strip().split("\n", 1)[0].lstrip("# "),
            tags=fm.get("tags", []) if isinstance(fm.get("tags"), list) else [],
            keywords=fm.get("keywords", []) if isinstance(fm.get("keywords"), list) else [],
            category=fm.get("category", "其他"),
            insight=insight,
            timestamp=fm.get("created", ""),
            source=fm.get("source", "unknown"),
            raw_text=raw_text,
            image_path=fm.get("image", ""),
            links=fm.get("links", []) if isinstance(fm.get("links"), list) else [],
        )


def _slugify(text: str, max_len: int = 30) -> str:
    """从摘要生成 URL 友好的文件名片段"""
    text = re.sub(r"[^\w\u4e00-\u9fff]+", "-", text).strip("-")
    return text[:max_len] or "untitled"


def save_insight(ins: Insight) -> Path:
    """把 Insight 保存到 inbox/YYYY-MM-DD/HHMMSS-{slug}.md"""
    config.ensure_dirs()
    ts = datetime.fromisoformat(ins.timestamp)
    day_dir = config.KB_INBOX / ts.strftime("%Y-%m-%d")
    day_dir.mkdir(parents=True, exist_ok=True)

    slug = _slugify(ins.summary)
    filename = f"{ts.strftime('%H%M%S')}-{slug}.md"
    path = day_dir / filename

    path.write_text(ins.to_markdown(), encoding="utf-8")
    return path


def list_insights(limit: int | None = None) -> list[tuple[Path, Insight]]:
    """列出所有 inbox 里的灵感（按时间倒序）"""
    config.ensure_dirs()
    files = sorted(config.KB_INBOX.rglob("*.md"), key=lambda p: p.stat().st_mtime, reverse=True)
    if limit:
        files = files[:limit]

    results = []
    for f in files:
        try:
            results.append((f, Insight.from_markdown(f)))
        except (ValueError, KeyError):
            continue
    return results


def search_insights(keyword: str) -> list[tuple[Path, Insight]]:
    """全文搜索（V1 版：grep 风格）"""
    keyword_lower = keyword.lower()
    results = []
    for path, ins in list_insights():
        haystack = " ".join([
            ins.summary,
            ins.raw_text,
            ins.insight,
            " ".join(ins.tags),
            " ".join(ins.keywords),
        ]).lower()
        if keyword_lower in haystack:
            results.append((path, ins))
    return results


def get_stats() -> dict:
    """知识库统计"""
    insights = list_insights()
    tag_count: dict[str, int] = {}
    cat_count: dict[str, int] = {}
    for _, ins in insights:
        for tag in ins.tags:
            tag_count[tag] = tag_count.get(tag, 0) + 1
        cat_count[ins.category] = cat_count.get(ins.category, 0) + 1
    return {
        "total": len(insights),
        "by_tag": dict(sorted(tag_count.items(), key=lambda x: -x[1])),
        "by_category": cat_count,
        "kb_path": str(config.KB_ROOT),
    }
