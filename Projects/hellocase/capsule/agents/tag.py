"""
TagAgent — 文字 → 标签 + 关键词

V2 拆分：之前 V1 用一次调用拿 5 个字段，V2 拆成多个 Agent，每个只关心一个字段。
这样的好处：
  - 每个 prompt 更聚焦，质量更高
  - 失败可以局部重试
  - 测试更容易（mock 单个 agent）
"""

import json

from .base import Agent
from ..agent import call_llm, parse_json_safe

TAG_PROMPT = """请为下面这条灵感生成 3-5 个分类标签和 3-5 个关键词。

灵感原文：
\"\"\"
{text}
\"\"\"

类别提示：{category}

返回严格的 JSON：
{{
  "tags": ["标签1", "标签2", "标签3"],
  "keywords": ["关键词1", "关键词2", "关键词3"]
}}

要求：
- 标签是抽象类别（如：穿搭、心理学、产品管理）
- 关键词是具体名词（如：焦糖色、ReAct、D7留存）
- 用中文，每个不超过 6 字
- 直接返回 JSON，不要 ```json 包裹"""


class TagAgent(Agent):
    """单一职责：给灵感打标签 + 提取关键词"""

    name = "TagAgent"
    description = "生成 3-5 个分类标签 + 3-5 个关键词"

    def _run(self, context: dict) -> dict:
        text = context.get("raw_text", "")
        category = context.get("category", "其他")
        if not text:
            raise ValueError("TagAgent 需要 raw_text")

        prompt = TAG_PROMPT.format(text=text[:1500], category=category)
        response = call_llm(prompt, max_tokens=300)
        data = parse_json_safe(response)

        return {
            "tags": data.get("tags", [])[:5],
            "keywords": data.get("keywords", [])[:5],
        }
