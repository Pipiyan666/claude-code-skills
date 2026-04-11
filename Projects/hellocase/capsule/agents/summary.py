"""
SummaryAgent — 文字 → 30-50 字摘要
"""

from .base import Agent
from ..agent import call_llm

SUMMARY_PROMPT = """用 30-50 字总结下面这条灵感的核心。要求：
- 用一句完整的话
- 抓最关键的信息（数字、人名、动作）
- 不要套话、不要"这条灵感讲述了"这种废话

原文：
\"\"\"
{text}
\"\"\"

只返回摘要，不要任何标点之外的修饰。"""


class SummaryAgent(Agent):
    """单一职责：生成 30-50 字摘要"""

    name = "SummaryAgent"
    description = "生成 30-50 字的核心摘要"

    def _run(self, context: dict) -> dict:
        text = context.get("raw_text", "")
        if not text:
            raise ValueError("SummaryAgent 需要 raw_text")

        prompt = SUMMARY_PROMPT.format(text=text[:1500])
        summary = call_llm(prompt, max_tokens=150).strip().strip('"').strip("「」")

        return {"summary": summary}
