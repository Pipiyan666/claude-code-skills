"""
V3 ResearchAgent — Tool Use 动态决策

这是从 V2 (固定 pipeline) 到 V3 (动态 agent) 的质变：
  - V2: 我们写代码决定调用什么 LLM 几次
  - V3: LLM 自己决定调用什么工具几次

核心循环（ReAct: Reason + Act）：
  while not done:
      response = LLM.think(messages, tools)
      if response.has_tool_calls:
          for tool_call in response.tool_calls:
              result = execute_tool(tool_call)
              messages.append(tool result)
      else:
          done = True
          return response.content
"""

import json
import logging
from typing import Optional

from openai import OpenAI

from . import config
from .tools import TOOL_REGISTRY, TOOL_SCHEMAS

logger = logging.getLogger(__name__)


SYSTEM_PROMPT = """你是『灵感胶囊』的 ResearchAgent —— 一个会思考、会用工具的研究助手。

你的工作是：根据用户的研究目标，主动调用工具完成深度调研，最后写一份 markdown 报告到知识库。

工作流程：
1. 用 read_kb 看用户已经记录过什么相关内容（必做第一步）
2. 用 web_search 补充外部信息（市场、竞品、研究等）
3. 必要时用 fetch_url 深入阅读某个链接
4. 综合所有信息后，用 write_kb_report 把调研结果保存为 markdown 报告

原则：
- 一步一步来，不要并行调用太多工具
- 每次调用工具前，简短说明你为什么要调它
- 调研完成后，必须用 write_kb_report 落地（不要只是嘴上说）
- 报告要结构化（用 ## 分节、bullet list、引用来源）
- 用中文"""


class ResearchAgent:
    """V3 Tool-Use Agent"""

    name = "ResearchAgent"

    def __init__(self, max_iterations: int = 8):
        self.max_iterations = max_iterations
        self.client = OpenAI(
            api_key=config.ZHIPU_API_KEY,
            base_url=config.ZHIPU_BASE_URL,
        )
        self.trace: list[dict] = []  # 记录完整的执行轨迹（用于展示和 debug）

    def run(self, research_goal: str) -> dict:
        """
        执行一次研究任务

        Args:
            research_goal: 用户的研究目标

        Returns:
            {"final_response": "...", "trace": [...], "iterations": N}
        """
        self.trace = []
        messages = [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": f"研究目标：{research_goal}"},
        ]

        for iteration in range(self.max_iterations):
            logger.info(f"[ResearchAgent] iteration {iteration + 1}/{self.max_iterations}")

            response = self.client.chat.completions.create(
                model=config.ZHIPU_MODEL,
                messages=messages,
                tools=TOOL_SCHEMAS,
                tool_choice="auto",
                temperature=0.3,
                max_tokens=1500,
            )

            msg = response.choices[0].message

            # 记录这一轮的思考
            self.trace.append({
                "iteration": iteration + 1,
                "type": "assistant_message",
                "content": msg.content or "",
                "tool_calls": [
                    {
                        "name": tc.function.name,
                        "arguments": tc.function.arguments,
                    }
                    for tc in (msg.tool_calls or [])
                ],
            })

            # 把 assistant 消息加入历史
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

            # 没有工具调用 → 任务完成
            if not msg.tool_calls:
                logger.info(f"[ResearchAgent] DONE after {iteration + 1} iterations")
                return {
                    "final_response": msg.content or "",
                    "trace": self.trace,
                    "iterations": iteration + 1,
                }

            # 执行所有工具调用
            for tool_call in msg.tool_calls:
                tool_name = tool_call.function.name
                try:
                    args = json.loads(tool_call.function.arguments)
                except json.JSONDecodeError:
                    args = {}

                logger.info(f"[ResearchAgent] calling {tool_name}({args})")

                if tool_name not in TOOL_REGISTRY:
                    result = json.dumps({"error": f"未知工具: {tool_name}"})
                else:
                    try:
                        result = TOOL_REGISTRY[tool_name](**args)
                    except Exception as e:
                        result = json.dumps({"error": f"{type(e).__name__}: {e}"})

                # 记录工具调用结果
                self.trace.append({
                    "iteration": iteration + 1,
                    "type": "tool_result",
                    "tool": tool_name,
                    "args": args,
                    "result_preview": result[:300],
                })

                # 把工具结果加入消息历史
                messages.append({
                    "role": "tool",
                    "tool_call_id": tool_call.id,
                    "content": result,
                })

        return {
            "final_response": "（达到最大迭代次数，未完成）",
            "trace": self.trace,
            "iterations": self.max_iterations,
        }
