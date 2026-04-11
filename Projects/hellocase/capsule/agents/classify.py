"""
ClassifyAgent — 文字 → 分类

把灵感归类到固定的几个 bucket 之一。
"""

from .base import Agent
from ..agent import call_llm

CATEGORIES = [
    "社媒灵感",
    "会议记录",
    "产品想法",
    "学习笔记",
    "生活待办",
    "聊天截图",
    "其他",
]

CLASSIFY_PROMPT = """请把下面这条灵感归类到下列类别之一：

{categories}

灵感原文：
\"\"\"
{text}
\"\"\"

只返回类别名称（一个词），不要任何解释。"""


class ClassifyAgent(Agent):
    """单一职责：把灵感分类"""

    name = "ClassifyAgent"
    description = "把灵感归类到固定 bucket"

    def _run(self, context: dict) -> dict:
        text = context.get("raw_text", "")
        if not text:
            raise ValueError("ClassifyAgent 需要 raw_text")

        prompt = CLASSIFY_PROMPT.format(
            categories="\n".join(f"- {c}" for c in CATEGORIES),
            text=text[:1500],  # 截断避免超 token
        )
        result = call_llm(prompt, max_tokens=20).strip().strip("。.,，").strip()

        # 容错：如果模型返回了完整句子，找一个匹配的类别
        for cat in CATEGORIES:
            if cat in result:
                return {"category": cat}

        return {"category": "其他"}
