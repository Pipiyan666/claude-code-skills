"""
ClusterAgent — 多条灵感 → 共同主题

定时任务（每晚跑一次），扫描所有 inbox，发现跨灵感的隐藏主题。
是 V2 唯一一个"非 pipeline"的 Agent，独立运行。
"""

from .base import Agent
from ..agent import call_llm, parse_json_safe

CLUSTER_PROMPT = """你是一个洞察分析师。下面是用户最近保存的所有灵感卡片，请帮 TA 找到这些灵感之间的隐藏关联和共同主题。

灵感列表：
\"\"\"
{insights_text}
\"\"\"

请返回严格的 JSON 格式：

{{
  "main_themes": [
    {{
      "theme": "主题名称（5-10字）",
      "description": "为什么这是一个主题（30字）",
      "related_insights": ["相关关键词1", "关键词2"]
    }}
  ],
  "user_profile": "基于这些灵感，对用户最近关注点的一句话画像",
  "next_actions": [
    "建议的下一步 1",
    "建议的下一步 2",
    "建议的下一步 3"
  ]
}}

注意：
- 至少 2 个主题，最多 4 个
- 用中文，直接返回 JSON，不要 ```json 包裹"""


class ClusterAgent(Agent):
    """单一职责：跨灵感主题聚类"""

    name = "ClusterAgent"
    description = "扫描所有 inbox 灵感，发现共同主题"

    def _run(self, context: dict) -> dict:
        insights = context.get("insights", [])
        if len(insights) < 2:
            return {
                "main_themes": [],
                "user_profile": "灵感太少，无法分析",
                "next_actions": ["先添加几条灵感再来"],
            }

        # 序列化灵感列表（限制 15 条避免超 token）
        items_text = "\n\n".join(
            f"{i+1}. [{ins.category}] {ins.summary} (标签: {', '.join(ins.tags)})"
            for i, ins in enumerate(insights[:15])
        )

        prompt = CLUSTER_PROMPT.format(insights_text=items_text)
        response = call_llm(prompt, max_tokens=1200)
        return parse_json_safe(response)
