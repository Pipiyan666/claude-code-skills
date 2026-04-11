"""
AI 层 — 单 LLM Chat 调用（V1 阶段）

V1 是单次 LLM 调用，V2 会拆成多个 Agent。
本文件被 V1 (cli.py) 直接调用，V2 (workflow.py) 也会复用 call_llm()。
"""

import base64
import json
import re
from datetime import datetime
from pathlib import Path

from openai import OpenAI

from . import config
from .storage import Insight

# Prompt 模板（与 hackathon_demo/prompts/ 共享设计）
PROMPT_ANALYZE_TEXT = """你是一个专门为内容创作者整理灵感的 AI 助手。

请为下面这条灵感生成结构化的分析。返回**严格的 JSON 格式**，不要添加任何解释或 markdown 代码块标记。

灵感原文：
\"\"\"
{user_input}
\"\"\"

返回 JSON：
{{
  "summary": "用 30-50 字总结核心",
  "tags": ["3-5 个分类标签"],
  "keywords": ["3-5 个关键词"],
  "category": "社媒灵感 / 会议记录 / 产品想法 / 学习笔记 / 生活待办 / 其他",
  "insight": "用 50 字给一个延伸思考或下一步建议"
}}

注意：用中文，直接返回 JSON，不要 ```json 包裹。"""


PROMPT_ANALYZE_IMAGE = """请分析这张截图，返回结构化的灵感分析。返回**严格的 JSON 格式**：

{
  "raw_text": "OCR 识别出的所有文字（原文照抄）",
  "summary": "30-50 字总结核心",
  "tags": ["3-5 个分类标签"],
  "keywords": ["3-5 个关键词"],
  "category": "社媒灵感 / 会议记录 / 产品想法 / 学习笔记 / 生活待办 / 聊天截图 / 其他",
  "insight": "50 字延伸思考或行动建议"
}

用中文，直接返回 JSON，不要 ```json 包裹。"""


_client: OpenAI | None = None


def get_client() -> OpenAI:
    """单例 OpenAI 客户端（指向智谱）"""
    global _client
    if _client is None:
        if not config.ZHIPU_API_KEY:
            raise RuntimeError("ZHIPU_API_KEY 未配置，请在 .env 里设置")
        _client = OpenAI(
            api_key=config.ZHIPU_API_KEY,
            base_url=config.ZHIPU_BASE_URL,
        )
    return _client


def call_llm(prompt: str, max_tokens: int = 800, model: str | None = None) -> str:
    """调用智谱 GLM-4-Flash（纯文本）"""
    response = get_client().chat.completions.create(
        model=model or config.ZHIPU_MODEL,
        max_tokens=max_tokens,
        temperature=0.3,
        messages=[{"role": "user", "content": prompt}],
    )
    return response.choices[0].message.content.strip()


def call_llm_vision(prompt: str, image_bytes: bytes, max_tokens: int = 300) -> str:
    """调用智谱 GLM-4V-Flash（视觉）

    实测限制：智谱 GLM-4V API 不接受 temperature 参数，max_tokens 上限 300。
    超过会返回 1210 错误。
    """
    img_b64 = base64.b64encode(image_bytes).decode()
    response = get_client().chat.completions.create(
        model=config.ZHIPU_VISION_MODEL,
        max_tokens=min(max_tokens, 300),
        messages=[{
            "role": "user",
            "content": [
                {"type": "text", "text": prompt},
                {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{img_b64}"}},
            ],
        }],
    )
    return response.choices[0].message.content.strip()


def parse_json_safe(text: str) -> dict:
    """容错解析 LLM 返回的 JSON"""
    text = text.strip()
    if text.startswith("```"):
        lines = text.split("\n")
        text = "\n".join(lines[1:-1] if lines[-1].startswith("```") else lines[1:])
    text = text.strip()
    if text.startswith("json"):
        text = text[4:].strip()
    start = text.find("{")
    end = text.rfind("}")
    if start != -1 and end != -1:
        text = text[start:end + 1]
    return json.loads(text)


def analyze_text(user_input: str) -> Insight:
    """分析一段文字 → Insight 对象"""
    prompt = PROMPT_ANALYZE_TEXT.format(user_input=user_input)
    text = call_llm(prompt, max_tokens=800)
    data = parse_json_safe(text)
    return Insight(
        id=f"ins-{int(datetime.now().timestamp())}",
        summary=data.get("summary", ""),
        tags=data.get("tags", []),
        keywords=data.get("keywords", []),
        category=data.get("category", "其他"),
        insight=data.get("insight", ""),
        timestamp=datetime.now().isoformat(timespec="seconds"),
        source="text",
        raw_text=user_input,
    )


def analyze_image(image_path: str | Path) -> Insight:
    """分析一张截图 → Insight 对象（两步法）

    Step 1: GLM-4V-Flash OCR 提取截图文字（max_tokens=300）
    Step 2: GLM-4-Flash 用 OCR 文字走完整结构化分析

    为什么两步：智谱 GLM-4V max_tokens 上限 300，不够输出完整 JSON，
    所以视觉模型只做 OCR，文本模型做结构化分析。
    """
    path = Path(image_path).expanduser().resolve()
    image_bytes = path.read_bytes()

    # Step 1: OCR
    ocr_prompt = "请精确识别这张截图里的所有文字，保持原始格式。直接返回文字，不要任何解释或 markdown 标记。"
    raw_text = call_llm_vision(ocr_prompt, image_bytes, max_tokens=300)

    if not raw_text or raw_text.strip() in ("无文字", "无", "(无)", "（无）", ""):
        # 无文字截图：让视觉模型给一句描述
        desc_prompt = "用一句话（30 字内）描述这张图片的内容主题。"
        raw_text = call_llm_vision(desc_prompt, image_bytes, max_tokens=300)

    # Step 2: 结构化分析（复用文本分析）
    ins = analyze_text(raw_text)
    ins.id = f"ins-img-{int(datetime.now().timestamp())}"
    ins.source = "image"
    ins.image_path = str(path)
    return ins
