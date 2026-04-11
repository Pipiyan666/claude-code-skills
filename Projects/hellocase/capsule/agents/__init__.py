"""
V2 Agent 编排 — 多 Agent 固定 workflow

每个 Agent 职责单一，组合成 pipeline：
  ScreenshotAgent → ClassifyAgent → TagAgent → SummaryAgent → InsightAgent → 存储
                                                                                ↓
                                                              ClusterAgent (定时任务)
"""

from .base import Agent, AgentResult
from .classify import ClassifyAgent
from .cluster import ClusterAgent
from .insight import InsightAgent
from .ocr import ScreenshotAgent
from .summary import SummaryAgent
from .tag import TagAgent

__all__ = [
    "Agent",
    "AgentResult",
    "ScreenshotAgent",
    "ClassifyAgent",
    "TagAgent",
    "SummaryAgent",
    "InsightAgent",
    "ClusterAgent",
]
