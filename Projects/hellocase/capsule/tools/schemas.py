"""
工具 schema 定义（OpenAI function calling 格式 — 智谱 GLM 兼容）
"""

from .kb_tools import read_kb, write_kb_report
from .web_tools import fetch_url, web_search

# OpenAI function calling 格式的 schema
TOOL_SCHEMAS = [
    {
        "type": "function",
        "function": {
            "name": "read_kb",
            "description": "读取本地知识库 — 搜索与 query 相关的灵感笔记。当你需要了解用户已经记录过什么的时候用这个。",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "搜索关键词。空字符串则返回最近的灵感",
                    },
                    "limit": {
                        "type": "integer",
                        "description": "最多返回多少条灵感（默认 10）",
                    },
                },
                "required": ["query"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "web_search",
            "description": "网络搜索 — 查找外部信息（市场数据、竞品、趋势等）。当你需要补充用户灵感之外的信息时用这个。",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "搜索关键词",
                    },
                    "max_results": {
                        "type": "integer",
                        "description": "最多返回结果数（默认 3）",
                    },
                },
                "required": ["query"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "fetch_url",
            "description": "抓取一个 URL 的文本内容 — 用于深入阅读 web_search 返回的链接。",
            "parameters": {
                "type": "object",
                "properties": {
                    "url": {
                        "type": "string",
                        "description": "要抓取的 URL（必须以 http 或 https 开头）",
                    },
                },
                "required": ["url"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "write_kb_report",
            "description": "把调研结果写成 markdown 报告，保存到本地知识库的 wiki/topics/ 目录。当你完成调研、要把成果落地的时候用这个。",
            "parameters": {
                "type": "object",
                "properties": {
                    "title": {
                        "type": "string",
                        "description": "报告标题",
                    },
                    "content": {
                        "type": "string",
                        "description": "Markdown 格式的报告正文（含分节、列表等）",
                    },
                },
                "required": ["title", "content"],
            },
        },
    },
]

# 工具注册表（name → callable）
TOOL_REGISTRY = {
    "read_kb": read_kb,
    "web_search": web_search,
    "fetch_url": fetch_url,
    "write_kb_report": write_kb_report,
}
