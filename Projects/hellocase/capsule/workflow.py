"""
V2 Workflow 编排器

固定 pipeline：
  截图(可选) → ScreenshotAgent → ClassifyAgent → TagAgent → SummaryAgent → InsightAgent → 存储
                                                                                              ↓
                                                                                         ClusterAgent
                                                                                         (定时任务)

特点：
- 每个 Agent 职责单一，串行执行
- 前一个 Agent 的输出累积到 context 里，传给下一个
- 任何一步失败，整个 pipeline 标记为部分失败但继续
- 全程打日志（每个 Agent 的耗时 + 输入/输出）
"""

import logging
from datetime import datetime
from pathlib import Path

from .agents import (
    AgentResult,
    ClassifyAgent,
    ClusterAgent,
    InsightAgent,
    ScreenshotAgent,
    SummaryAgent,
    TagAgent,
)
from .storage import Insight, list_insights, save_insight

logger = logging.getLogger(__name__)


class CaptureWorkflow:
    """V2 灵感捕获 pipeline"""

    def __init__(self):
        self.screenshot_agent = ScreenshotAgent()
        self.classify_agent = ClassifyAgent()
        self.tag_agent = TagAgent()
        self.summary_agent = SummaryAgent()
        self.insight_agent = InsightAgent()

    def run_text(self, text: str) -> tuple[Insight, list[AgentResult]]:
        """文字灵感的完整 pipeline"""
        context = {"raw_text": text}
        results = []

        # ClassifyAgent
        r = self.classify_agent.run(context)
        results.append(r)
        if r.success:
            context.update(r.output)

        # TagAgent
        r = self.tag_agent.run(context)
        results.append(r)
        if r.success:
            context.update(r.output)

        # SummaryAgent
        r = self.summary_agent.run(context)
        results.append(r)
        if r.success:
            context.update(r.output)

        # InsightAgent
        r = self.insight_agent.run(context)
        results.append(r)
        if r.success:
            context.update(r.output)

        ins = self._build_insight(context, source="text")
        return ins, results

    def run_image(self, image_path: str | Path) -> tuple[Insight, list[AgentResult]]:
        """截图灵感的完整 pipeline（先 OCR 再走文字流程）"""
        context = {"image_path": str(Path(image_path).expanduser().resolve())}
        results = []

        # 第 1 步：OCR
        r = self.screenshot_agent.run(context)
        results.append(r)
        if not r.success:
            raise RuntimeError(f"ScreenshotAgent 失败: {r.error}")
        context.update(r.output)

        # 第 2-5 步：和 text 流程一样
        for agent in (self.classify_agent, self.tag_agent, self.summary_agent, self.insight_agent):
            r = agent.run(context)
            results.append(r)
            if r.success:
                context.update(r.output)

        ins = self._build_insight(context, source="image")
        ins.image_path = context["image_path"]
        return ins, results

    @staticmethod
    def _build_insight(context: dict, source: str) -> Insight:
        prefix = "ins-img" if source == "image" else "ins"
        return Insight(
            id=f"{prefix}-{int(datetime.now().timestamp())}",
            summary=context.get("summary", ""),
            tags=context.get("tags", []),
            keywords=context.get("keywords", []),
            category=context.get("category", "其他"),
            insight=context.get("insight", ""),
            timestamp=datetime.now().isoformat(timespec="seconds"),
            source=source,
            raw_text=context.get("raw_text", ""),
        )


def run_nightly_cluster() -> dict:
    """V2 定时任务：扫描所有 inbox，发现共同主题"""
    items = list_insights(limit=20)
    insights = [ins for _, ins in items]

    cluster_agent = ClusterAgent()
    result = cluster_agent.run({"insights": insights})
    if not result.success:
        return {"error": result.error}
    return result.output
