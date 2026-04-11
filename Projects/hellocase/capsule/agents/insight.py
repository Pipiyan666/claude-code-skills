"""
InsightAgent — 文字 → 延伸思考 / 行动建议
"""

from .base import Agent
from ..agent import call_llm

INSIGHT_PROMPT = """基于下面这条灵感，给一个有用的延伸思考或下一步行动建议。要求：
- 50 字以内
- 具体、可执行（不是空话）
- 类似一个朋友看到你的笔记后给你的反馈

灵感原文：
\"\"\"
{text}
\"\"\"

摘要：{summary}
分类：{category}

只返回建议，不要"建议："这种前缀。"""


class InsightAgent(Agent):
    """单一职责：生成延伸思考 / 行动建议"""

    name = "InsightAgent"
    description = "生成 50 字延伸思考或行动建议"

    def _run(self, context: dict) -> dict:
        text = context.get("raw_text", "")
        summary = context.get("summary", "")
        category = context.get("category", "其他")
        if not text:
            raise ValueError("InsightAgent 需要 raw_text")

        prompt = INSIGHT_PROMPT.format(
            text=text[:1500],
            summary=summary,
            category=category,
        )
        insight = call_llm(prompt, max_tokens=200).strip().strip('"').strip("「」")

        return {"insight": insight}
