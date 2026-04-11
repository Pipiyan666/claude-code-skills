"""
V4 LibrarianAgent — 知识库的"图书管理员"

这是 V4 的核心 Agent，模拟了 Claude Agent SDK 的 `preset: claude_code` 思想：
  - 一个 agent，配备一组工具，靠 LLM 自主决策完成所有"图书管理"任务
  - 任务包括：处理 inbox 新灵感、定期重建 index、发现主题、生成 wiki 文章

如果用真正的 Claude Agent SDK，代码可以是：
  ```python
  from claude_agent_sdk import ClaudeAgentOptions, query
  options = ClaudeAgentOptions(
      system_prompt={
          "type": "preset",
          "preset": "claude_code",      # ← 继承 Claude Code 全部能力
          "append": LIBRARIAN_PROMPT,    # ← 业务 prompt
      },
      cwd="~/Library/IdeaCapsule",
  )
  async for msg in query(prompt="处理今天的 inbox 并更新 wiki", options=options):
      ...
  ```

但我们用智谱 API，所以这里是"概念等价"的实现：
  - 用智谱 GLM-4-Flash 做决策
  - 复用 V3 的 Tool Use 框架
  - 加上一组 librarian 专属工具
"""

import json
import logging

from openai import OpenAI

from . import config
from .tools import TOOL_REGISTRY, TOOL_SCHEMAS

logger = logging.getLogger(__name__)


# 这就是"append 到 preset 后面"的业务 prompt
# 在真正的 Claude Agent SDK 里，preset:claude_code 会自动加上文件操作、bash 等工具
# 我们用智谱实现，所以工具已经内置在 TOOL_SCHEMAS 里了
LIBRARIAN_PROMPT = """你是『灵感胶囊』的 Librarian Agent —— 知识库的图书管理员。

你的工作目录是 ~/Library/IdeaCapsule/，里面是用户的 markdown 知识库：
  - inbox/         最近 7 天的原始灵感
  - processed/     AI 加工过的灵感
  - wiki/topics/   主题文章（你定期重建）
  - index.md       全局索引

你的核心能力：
  1. read_kb     - 读用户已经记录过的灵感
  2. web_search  - 搜索外部信息补充知识
  3. fetch_url   - 抓取网页深入阅读
  4. write_kb_report - 把综合后的知识写成 wiki 文章

你的工作哲学（Karpathy LLM Wiki 风格）：
  - 你不是简单的搜索引擎，是一个"研究图书管理员"
  - 你会主动发现知识库里的关联，把相关灵感串起来
  - 你写的每一篇 wiki 文章都应该比单条灵感更深、更广
  - 你会引用来源（说明信息来自哪条灵感、哪个外部 URL）

执行原则：
  - 收到任务后，先看用户已有的知识，再决定怎么补充
  - 一次只调一个工具，看到结果后再决定下一步
  - 任务完成后，总结你做了什么 + 把成果保存到知识库
  - 用中文"""


class LibrarianAgent:
    """V4 核心 Agent — 自主管理知识库"""

    name = "LibrarianAgent"

    def __init__(self, max_iterations: int = 10):
        self.max_iterations = max_iterations
        self.client = OpenAI(
            api_key=config.ZHIPU_API_KEY,
            base_url=config.ZHIPU_BASE_URL,
        )
        self.trace: list[dict] = []

    def run(self, task: str) -> dict:
        """执行一次 librarian 任务"""
        self.trace = []
        messages = [
            {"role": "system", "content": LIBRARIAN_PROMPT},
            {"role": "user", "content": task},
        ]

        for iteration in range(self.max_iterations):
            logger.info(f"[Librarian] iter {iteration + 1}/{self.max_iterations}")

            response = self.client.chat.completions.create(
                model=config.ZHIPU_MODEL,
                messages=messages,
                tools=TOOL_SCHEMAS,
                tool_choice="auto",
                temperature=0.3,
                max_tokens=2000,
            )

            msg = response.choices[0].message

            # 记录 trace
            self.trace.append({
                "iteration": iteration + 1,
                "type": "thinking",
                "content": msg.content or "",
                "tool_calls": [
                    {"name": tc.function.name, "args": tc.function.arguments}
                    for tc in (msg.tool_calls or [])
                ],
            })

            # 加入历史
            assistant_msg = {"role": "assistant", "content": msg.content or ""}
            if msg.tool_calls:
                assistant_msg["tool_calls"] = [
                    {
                        "id": tc.id,
                        "type": "function",
                        "function": {
                            "name": tc.function.name,
                            "arguments": tc.function.arguments,
                        },
                    }
                    for tc in msg.tool_calls
                ]
            messages.append(assistant_msg)

            # 没有工具调用 → 完成
            if not msg.tool_calls:
                logger.info(f"[Librarian] DONE after {iteration + 1} iterations")
                return {
                    "final_response": msg.content or "",
                    "trace": self.trace,
                    "iterations": iteration + 1,
                }

            # 执行工具
            for tool_call in msg.tool_calls:
                tool_name = tool_call.function.name
                try:
                    args = json.loads(tool_call.function.arguments)
                except json.JSONDecodeError:
                    args = {}

                logger.info(f"[Librarian] tool: {tool_name}({list(args.keys())})")

                if tool_name not in TOOL_REGISTRY:
                    result = json.dumps({"error": f"未知工具: {tool_name}"})
                else:
                    try:
                        result = TOOL_REGISTRY[tool_name](**args)
                    except Exception as e:
                        result = json.dumps({"error": f"{type(e).__name__}: {e}"})

                self.trace.append({
                    "iteration": iteration + 1,
                    "type": "tool_result",
                    "tool": tool_name,
                    "args": args,
                    "result_preview": result[:300],
                })

                messages.append({
                    "role": "tool",
                    "tool_call_id": tool_call.id,
                    "content": result,
                })

        return {
            "final_response": "（达到最大迭代次数）",
            "trace": self.trace,
            "iterations": self.max_iterations,
        }
