"""
网络工具 — web_search + fetch_url

V3 简化版：
- web_search 用 mock 数据 + 智谱在线搜索（如果配置了）
- fetch_url 用 urllib（标准库，不引入新依赖）
"""

import json
import re
from urllib.error import URLError
from urllib.parse import urlparse
from urllib.request import Request, urlopen


# 最简 mock 知识库（demo 用）
_MOCK_SEARCH_DB = {
    "穿搭": [
        {"title": "2026 秋冬流行趋势报告", "snippet": "焦糖色系成为本季度主打色，与酒红、墨绿组合形成层次感"},
        {"title": "Vogue: 基础款穿搭法则", "snippet": "色彩呼应胜过单品堆砌，建立 3-5 件核心配饰"},
    ],
    "用户增长": [
        {"title": "Reforge: 留存比拉新更重要", "snippet": "D7 留存每提升 5%，LTV 提升 30%"},
        {"title": "Mixpanel 增长指标手册", "snippet": "Onboarding 设计的核心是核心价值时刻 (Aha Moment)"},
    ],
    "深度工作": [
        {"title": "Cal Newport: Deep Work", "snippet": "仪式感比意志力更可持续"},
        {"title": "Andrew Huberman: 大脑专注力研究", "snippet": "多巴胺基线影响专注力上限"},
    ],
    "Claude Agent SDK": [
        {"title": "Anthropic 官方文档", "snippet": "preset: claude_code 可继承全部 24 个内置工具"},
        {"title": "Building Effective Agents", "snippet": "先用 workflow，工作正常就别上 agent；只有任务真的需要动态决策时才升到 agent"},
    ],
}


def web_search(query: str, max_results: int = 3) -> str:
    """
    搜索网络信息（V3 demo 版：mock 数据，未来接 SerpAPI / Bing API）

    Args:
        query: 搜索关键词
        max_results: 最多返回结果数

    Returns:
        JSON 字符串，包含搜索结果列表
    """
    # 简单关键词匹配
    matched = []
    for keyword, results in _MOCK_SEARCH_DB.items():
        if keyword in query or query in keyword:
            matched.extend(results)

    if not matched:
        # 退路：返回一个泛化的"未找到"结果
        matched = [{
            "title": f"关于『{query}』的搜索",
            "snippet": "（V3 演示阶段：mock 知识库未命中。生产版本会接入 SerpAPI / Bing API / Google CSE）",
        }]

    return json.dumps({
        "query": query,
        "results": matched[:max_results],
    }, ensure_ascii=False, indent=2)


def fetch_url(url: str, max_chars: int = 3000) -> str:
    """
    抓取一个 URL 的文本内容

    Args:
        url: 要抓取的 URL
        max_chars: 返回的最大字符数（防止 token 爆炸）

    Returns:
        JSON 字符串，包含 url + title + content
    """
    parsed = urlparse(url)
    if not parsed.scheme.startswith("http"):
        return json.dumps({"error": "URL 必须是 http(s) 开头"})

    try:
        req = Request(url, headers={
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Capsule/1.0"
        })
        with urlopen(req, timeout=10) as resp:
            content_type = resp.headers.get("content-type", "")
            if "html" not in content_type and "text" not in content_type:
                return json.dumps({"error": f"非文本内容: {content_type}"})

            raw = resp.read(50000).decode("utf-8", errors="ignore")
    except URLError as e:
        return json.dumps({"error": f"网络错误: {e.reason}"})
    except Exception as e:
        return json.dumps({"error": f"{type(e).__name__}: {e}"})

    # 极简 HTML 清洗
    title_match = re.search(r"<title[^>]*>(.*?)</title>", raw, re.IGNORECASE | re.DOTALL)
    title = title_match.group(1).strip() if title_match else parsed.netloc

    text = re.sub(r"<script[^>]*>.*?</script>", " ", raw, flags=re.DOTALL | re.IGNORECASE)
    text = re.sub(r"<style[^>]*>.*?</style>", " ", text, flags=re.DOTALL | re.IGNORECASE)
    text = re.sub(r"<[^>]+>", " ", text)
    text = re.sub(r"\s+", " ", text).strip()

    return json.dumps({
        "url": url,
        "title": title[:200],
        "content": text[:max_chars],
        "truncated": len(text) > max_chars,
    }, ensure_ascii=False)
