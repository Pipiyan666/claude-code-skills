"""
V4 事件总线 — 极简 pub/sub 实现

Agent 之间通过事件松耦合通信：
  - InboxAgent emit "new_capture" → 触发 ClassifyAgent
  - ClassifyAgent emit "categorized" → 触发 TagAgent / SummaryAgent (并行)
  - SummaryAgent emit "summarized" → 触发 InsightAgent
  - InsightAgent emit "completed" → 触发 storage.save_insight
  - ClusterAgent (定时) emit "themes_updated" → 触发 LinkAgent 更新双向链接

设计思想：和 Claude Agent SDK 的事件流类似，但用 Python 极简实现。
"""

import logging
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, Callable

logger = logging.getLogger(__name__)


@dataclass
class Event:
    """事件对象"""
    type: str
    payload: dict = field(default_factory=dict)
    timestamp: str = field(default_factory=lambda: datetime.now().isoformat())
    source: str = "unknown"  # 哪个 Agent 发的


class EventBus:
    """极简同步事件总线"""

    def __init__(self):
        self._subscribers: dict[str, list[Callable[[Event], None]]] = defaultdict(list)
        self.event_log: list[Event] = []  # 记录所有事件，用于 trace

    def subscribe(self, event_type: str, handler: Callable[[Event], None]) -> None:
        """订阅事件"""
        self._subscribers[event_type].append(handler)
        logger.info(f"[EventBus] subscribe: {event_type} → {handler.__qualname__}")

    def emit(self, event: Event) -> None:
        """发布事件，同步执行所有订阅者"""
        self.event_log.append(event)
        logger.info(f"[EventBus] emit: {event.type} from {event.source} → {len(self._subscribers[event.type])} handlers")

        for handler in self._subscribers[event.type]:
            try:
                handler(event)
            except Exception as e:
                logger.exception(f"[EventBus] handler {handler.__qualname__} failed: {e}")

    def get_log(self) -> list[Event]:
        return list(self.event_log)
