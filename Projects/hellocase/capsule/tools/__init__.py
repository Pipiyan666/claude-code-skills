"""
V3 工具集 — Agent 可以主动调用的工具

设计原则：每个工具是一个纯函数，输入 JSON，输出 JSON。
工具的 schema（OpenAI function calling 格式）由 TOOL_SCHEMAS 维护。
"""

from .kb_tools import read_kb, write_kb_report
from .schemas import TOOL_SCHEMAS, TOOL_REGISTRY
from .web_tools import fetch_url, web_search

__all__ = [
    "read_kb",
    "write_kb_report",
    "fetch_url",
    "web_search",
    "TOOL_SCHEMAS",
    "TOOL_REGISTRY",
]
