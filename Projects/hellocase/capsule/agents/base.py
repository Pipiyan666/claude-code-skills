"""
Agent 基类 — 定义所有 Agent 的契约

每个 Agent：
  - 有唯一的 name
  - 有 run(context) 方法，接收 dict，返回 AgentResult
  - 不持有状态（每次 run 独立）
"""

import logging
import time
from abc import ABC, abstractmethod
from dataclasses import dataclass, field

logger = logging.getLogger(__name__)


@dataclass
class AgentResult:
    """单个 Agent 的执行结果"""
    agent: str
    success: bool
    output: dict = field(default_factory=dict)
    error: str = ""
    duration_ms: int = 0


class Agent(ABC):
    """所有 Agent 的基类"""

    name: str = "base"
    description: str = ""

    @abstractmethod
    def _run(self, context: dict) -> dict:
        """子类实现：接收 pipeline 的累积上下文，返回新增的字段"""
        ...

    def run(self, context: dict) -> AgentResult:
        """统一的执行入口（带计时和异常处理）"""
        start = time.time()
        logger.info(f"[{self.name}] start")
        try:
            output = self._run(context)
            duration = int((time.time() - start) * 1000)
            logger.info(f"[{self.name}] done in {duration}ms → {list(output.keys())}")
            return AgentResult(
                agent=self.name,
                success=True,
                output=output,
                duration_ms=duration,
            )
        except Exception as e:
            duration = int((time.time() - start) * 1000)
            logger.exception(f"[{self.name}] FAILED in {duration}ms")
            return AgentResult(
                agent=self.name,
                success=False,
                error=f"{type(e).__name__}: {e}",
                duration_ms=duration,
            )
