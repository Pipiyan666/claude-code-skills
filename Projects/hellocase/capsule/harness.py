"""
V4 Multi-Agent Harness — 多 Agent 协调器

这是 V4 的核心：把多个 Agent + EventBus + 状态持久化整合到一起。

架构等价于 Claude Agent SDK 的 Harness，但用 Python 极简实现：
  - LibrarianAgent: 主 Agent，自主决策（V3 ResearchAgent 的进化版）
  - InboxAgent: 监听 inbox/ 目录，发现新灵感
  - ClusterAgent: 定时任务，跨灵感聚类
  - LinkAgent: 跨灵感双向链接更新

执行模式：
  Harness.start()
    → InboxAgent 扫描 inbox/，发现新文件 → emit "new_capture"
    → CaptureWorkflow 订阅 "new_capture"，处理 → emit "captured"
    → 累积 N 条灵感 → emit "ready_for_clustering"
    → LibrarianAgent 订阅 "ready_for_clustering"，自主决定要不要做 cluster
"""

import json
import logging
from datetime import datetime
from pathlib import Path

from . import config
from .events import Event, EventBus
from .librarian import LibrarianAgent
from .storage import list_insights
from .workflow import CaptureWorkflow

logger = logging.getLogger(__name__)


class CapsuleHarness:
    """V4 主调度器"""

    def __init__(self):
        self.bus = EventBus()
        self.workflow = CaptureWorkflow()
        self.librarian = LibrarianAgent(max_iterations=8)

        # 状态持久化（hot/warm/cold 分层的简化版）
        self.session_state_file = config.KB_ROOT / ".session_state.json"
        self.session_state: dict = self._load_state()

        # 注册事件订阅
        self._register_handlers()

    # ---------- 状态持久化（V4 记忆分层的简化版）----------
    def _load_state(self) -> dict:
        if self.session_state_file.exists():
            try:
                return json.loads(self.session_state_file.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                pass
        return {
            "captures_since_last_cluster": 0,
            "last_cluster_at": None,
            "last_librarian_run": None,
            "events_total": 0,
        }

    def _save_state(self) -> None:
        config.ensure_dirs()
        self.session_state_file.write_text(
            json.dumps(self.session_state, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    # ---------- 事件订阅 ----------
    def _register_handlers(self) -> None:
        self.bus.subscribe("new_capture", self._on_new_capture)
        self.bus.subscribe("captured", self._on_captured)
        self.bus.subscribe("ready_for_librarian", self._on_ready_for_librarian)

    # ---------- 事件处理器 ----------
    def _on_new_capture(self, event: Event) -> None:
        """收到新灵感，跑 V2 workflow 处理"""
        text = event.payload.get("text", "")
        if not text:
            return

        logger.info(f"[Harness] 处理新灵感: {text[:50]}...")
        ins, results = self.workflow.run_text(text)

        # 保存到 markdown
        from .storage import save_insight
        path = save_insight(ins)

        # emit "captured"
        self.bus.emit(Event(
            type="captured",
            source="Harness",
            payload={
                "insight_id": ins.id,
                "summary": ins.summary,
                "category": ins.category,
                "path": str(path),
                "agent_results": [
                    {"agent": r.agent, "duration_ms": r.duration_ms, "success": r.success}
                    for r in results
                ],
            },
        ))

    def _on_captured(self, event: Event) -> None:
        """灵感已捕获，累计计数 → 决定是否触发 librarian"""
        self.session_state["captures_since_last_cluster"] += 1
        self.session_state["events_total"] += 1
        self._save_state()

        # 累计 3 条触发一次 librarian（demo 用，生产环境可以是每晚定时）
        if self.session_state["captures_since_last_cluster"] >= 3:
            self.bus.emit(Event(
                type="ready_for_librarian",
                source="Harness",
                payload={"reason": "累计 3 条新灵感，触发 librarian 自主整理"},
            ))

    def _on_ready_for_librarian(self, event: Event) -> None:
        """触发 LibrarianAgent 自主整理知识库"""
        reason = event.payload.get("reason", "")
        logger.info(f"[Harness] 唤起 LibrarianAgent: {reason}")

        result = self.librarian.run(
            f"任务: 帮我整理知识库。\n触发原因: {reason}\n"
            "请你自主决策：先看 read_kb 看用户最近记录了什么，"
            "如果发现某个主题出现 2 次以上，就用 web_search 补充信息，"
            "然后用 write_kb_report 把综合分析保存到 wiki/topics/。"
        )

        self.session_state["captures_since_last_cluster"] = 0
        self.session_state["last_librarian_run"] = datetime.now().isoformat()
        self._save_state()

        self.bus.emit(Event(
            type="librarian_done",
            source="LibrarianAgent",
            payload={
                "iterations": result.get("iterations", 0),
                "final_response": result.get("final_response", "")[:500],
            },
        ))

    # ---------- 公共 API ----------
    def capture(self, text: str) -> None:
        """对外入口：捕获一条新灵感"""
        self.bus.emit(Event(
            type="new_capture",
            source="user",
            payload={"text": text},
        ))

    def force_librarian(self, task: str) -> dict:
        """对外入口：强制运行 librarian"""
        return self.librarian.run(task)

    def get_state(self) -> dict:
        """对外入口：查看当前 harness 状态"""
        return {
            "session_state": self.session_state,
            "events_log_count": len(self.bus.event_log),
            "subscribers": {k: len(v) for k, v in self.bus._subscribers.items()},
        }

    def get_event_log(self) -> list[dict]:
        """对外入口：查看完整事件流"""
        return [
            {
                "type": e.type,
                "source": e.source,
                "timestamp": e.timestamp,
                "payload_preview": str(e.payload)[:200],
            }
            for e in self.bus.event_log
        ]
