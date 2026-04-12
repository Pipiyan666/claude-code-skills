"""
V4 真正的 Claude Agent SDK 集成 — 用智谱的 Anthropic 兼容端点

这是 V4 的最终形态，也是你朋友笔记 CLAUDE_AGENT_SDK_MULTI_MODEL.md 里说的杀手锏：

    改两个环境变量 → Claude Agent SDK 把请求发给智谱
    用 preset:claude_code → 继承 Claude Code 的 24 个内置工具
    append 业务 prompt → 只写差异化的 20 行

实测：
    import os
    os.environ["ANTHROPIC_BASE_URL"] = "https://open.bigmodel.cn/api/anthropic"
    os.environ["ANTHROPIC_API_KEY"] = "智谱 Key"

    from claude_agent_sdk import query, ClaudeAgentOptions
    async for msg in query(prompt="...", options=options):
        ...

    ✅ 返回 ThinkingBlock + AssistantMessage + ResultMessage
    ✅ 智谱 GLM-4.6 被 Claude Code preset 驱动，自动理解项目上下文

这比 capsule/librarian.py 的原生 Python 实现强 100 倍，因为：
  - 获得 Claude Code 的全部 24 个内置工具（Read/Write/Edit/Bash/Glob/Grep/Task...）
  - 不用自己写工具调用循环
  - 复用 Anthropic 调过的最强 system prompt
"""

import os
from pathlib import Path
from typing import AsyncIterator

from . import config

# ⭐ 关键：在 import claude_agent_sdk 之前设好环境变量
os.environ.setdefault(
    "ANTHROPIC_BASE_URL",
    "https://open.bigmodel.cn/api/anthropic",
)
os.environ.setdefault("ANTHROPIC_API_KEY", config.ZHIPU_API_KEY)

try:
    from claude_agent_sdk import query, ClaudeAgentOptions, AssistantMessage, ResultMessage
    SDK_AVAILABLE = True
except ImportError:
    SDK_AVAILABLE = False


# MARK: - 业务 prompt（append 到 claude_code preset 后面）

LIBRARIAN_PROMPT = """
你现在是『灵感胶囊』知识库的 Librarian Agent（图书管理员）。

你的工作目录是 `~/Library/IdeaCapsule/`，里面是用户的 markdown 知识库：
  - inbox/         最近 7 天的原始灵感（每条一个 .md 文件，含 frontmatter）
  - processed/    30 天内 AI 处理过的灵感
  - wiki/topics/  主题文章（由你定期生成）
  - index.md      全局索引（由你每晚重建）

你的工作哲学（来自 Karpathy LLM Wiki）：
  - 你不是搜索引擎，你是"研究图书管理员"
  - 你主动发现灵感之间的关联，把相关内容串成主题
  - 你写的 wiki 文章比单条灵感深、比单条灵感广
  - 你会引用来源（这条信息来自哪个 inbox/xxx.md）

你可以用的能力（继承自 Claude Code preset）：
  - Read 读任何 markdown 文件
  - Glob 找匹配的文件（比如 inbox/2026-04-*/*.md）
  - Grep 全文搜索关键词
  - Write / Edit 写入或修改 markdown 文件
  - Bash 运行 git 追踪变更
  - Task 调用 subagent 做深度研究

执行原则：
  - 一步一步来，不要并行调太多工具
  - 每次调工具前，简短说明你为什么要调它
  - 用中文回复
  - 最后总结你做了什么 + 落地的产物在哪
"""


# MARK: - LibrarianSDK — 真正的 Claude Agent SDK 集成

class LibrarianSDK:
    """V4 真 · Librarian Agent — 基于 Claude Agent SDK"""

    def __init__(self, cwd: str | Path | None = None):
        if not SDK_AVAILABLE:
            raise RuntimeError(
                "claude-agent-sdk 未安装。运行：pip install claude-agent-sdk"
            )

        self.cwd = Path(cwd) if cwd else config.KB_ROOT
        self.cwd.mkdir(parents=True, exist_ok=True)

    async def run(self, task: str) -> AsyncIterator[dict]:
        """执行一次 librarian 任务，流式返回消息"""
        options = ClaudeAgentOptions(
            system_prompt={
                "type": "preset",
                "preset": "claude_code",  # ⭐ 继承 Claude Code 全部能力
                "append": LIBRARIAN_PROMPT,
            },
            cwd=str(self.cwd),
            setting_sources=["project"],  # 加载 CLAUDE.md（preset 默认不加载）
            model="glm-4.6",  # 智谱的 GLM-4.6
            permission_mode="acceptEdits",  # 允许自动 write_file / edit_file
        )

        async for message in query(prompt=task, options=options):
            yield self._format_message(message)

    @staticmethod
    def _format_message(msg) -> dict:
        """把 SDK 消息序列化成可打印的 dict"""
        msg_type = type(msg).__name__

        if isinstance(msg, AssistantMessage):
            content = []
            for block in msg.content:
                block_type = type(block).__name__
                if hasattr(block, "text"):
                    content.append({"type": block_type, "text": block.text})
                elif hasattr(block, "thinking"):
                    content.append({"type": block_type, "thinking": block.thinking})
                elif hasattr(block, "name"):  # ToolUseBlock
                    content.append({
                        "type": block_type,
                        "tool": block.name,
                        "input": str(block.input)[:200],
                    })
                else:
                    content.append({"type": block_type, "repr": str(block)[:200]})
            return {"type": "assistant", "content": content}

        elif isinstance(msg, ResultMessage):
            return {
                "type": "result",
                "subtype": getattr(msg, "subtype", None),
                "duration_ms": getattr(msg, "duration_ms", None),
                "total_cost_usd": getattr(msg, "total_cost_usd", None),
                "num_turns": getattr(msg, "num_turns", None),
            }

        else:
            return {"type": msg_type, "repr": str(msg)[:200]}


# MARK: - 简化入口

async def run_librarian_task(task: str, cwd: str | Path | None = None) -> list[dict]:
    """一次性跑完 librarian 任务，返回所有消息

    Example:
        >>> messages = await run_librarian_task(
        ...     "扫描 inbox 目录，发现最近的新主题，写一份 wiki 报告"
        ... )
        >>> for msg in messages:
        ...     print(msg)
    """
    if not SDK_AVAILABLE:
        return [{"error": "claude-agent-sdk 未安装"}]

    librarian = LibrarianSDK(cwd=cwd)
    results = []
    async for msg in librarian.run(task):
        results.append(msg)
    return results


# MARK: - CLI 入口

if __name__ == "__main__":
    import asyncio
    import sys

    task = sys.argv[1] if len(sys.argv) > 1 else (
        "扫描 ~/Library/IdeaCapsule/inbox/ 目录，"
        "看看里面有哪些 markdown 灵感。"
        "选 3-5 条最有价值的，"
        "写一份简短的综合报告到 ~/Library/IdeaCapsule/wiki/topics/ 目录里。"
        "最后告诉我你做了什么。"
    )

    async def main():
        print(f"\n🤖 Librarian 任务: {task}\n")
        print("=" * 70)
        librarian = LibrarianSDK()
        async for msg in librarian.run(task):
            msg_type = msg.get("type", "unknown")
            if msg_type == "assistant":
                for block in msg.get("content", []):
                    block_type = block.get("type", "")
                    if block_type == "ThinkingBlock":
                        print(f"\n💭 思考: {block.get('thinking', '')[:200]}")
                    elif block_type == "TextBlock":
                        print(f"\n🗨️  {block.get('text', '')}")
                    elif block_type == "ToolUseBlock":
                        print(f"\n🔧 工具调用: {block.get('tool')} ({block.get('input', '')[:100]})")
            elif msg_type == "result":
                print(f"\n{'=' * 70}")
                print(f"✅ 完成")
                print(f"   轮次: {msg.get('num_turns')}")
                print(f"   耗时: {msg.get('duration_ms')}ms")
                cost = msg.get('total_cost_usd')
                if cost is not None:
                    print(f"   成本: ${cost:.4f}")

    asyncio.run(main())
