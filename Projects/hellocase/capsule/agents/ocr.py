"""
ScreenshotAgent — 截图 → 文字

V2 阶段：调用 GLM-4V 做 OCR + 简单理解
V1 阶段：可以用 macOS Vision Framework 本地 OCR（这里用云端 GLM-4V 代替）
"""

import base64
from pathlib import Path

from openai import OpenAI

from .. import config
from .base import Agent

OCR_PROMPT = """请精确识别这张截图里的所有文字（OCR），保持原始格式和换行。
直接返回文字，不要任何解释、不要 markdown 代码块标记。
如果是社媒截图，连标题、正文、评论都识别出来。"""


class ScreenshotAgent(Agent):
    """从截图提取纯文字"""

    name = "ScreenshotAgent"
    description = "OCR 截图提取所有文字"

    def __init__(self):
        self._client: OpenAI | None = None

    def _get_client(self) -> OpenAI:
        if self._client is None:
            self._client = OpenAI(
                api_key=config.ZHIPU_API_KEY,
                base_url=config.ZHIPU_BASE_URL,
            )
        return self._client

    def _run(self, context: dict) -> dict:
        """
        输入: context["image_path"] 或 context["image_bytes"]
        输出: {"raw_text": "..."}
        """
        if "image_bytes" in context:
            image_bytes = context["image_bytes"]
        elif "image_path" in context:
            image_bytes = Path(context["image_path"]).expanduser().read_bytes()
        else:
            raise ValueError("ScreenshotAgent 需要 image_path 或 image_bytes")

        # 智谱 GLM-4V-Flash 实测限制：max_tokens 上限 300，不接受 temperature
        img_b64 = base64.b64encode(image_bytes).decode()
        response = self._get_client().chat.completions.create(
            model=config.ZHIPU_VISION_MODEL,
            max_tokens=300,
            messages=[{
                "role": "user",
                "content": [
                    {"type": "text", "text": OCR_PROMPT},
                    {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{img_b64}"}},
                ],
            }],
        )
        return {"raw_text": response.choices[0].message.content.strip()}
