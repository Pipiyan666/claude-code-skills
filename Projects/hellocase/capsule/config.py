"""
全局配置 — 路径、模型、API
"""

import os
from pathlib import Path

from dotenv import load_dotenv

# 加载 .env（先找 capsule 同级，再找项目根）
_BASE_DIR = Path(__file__).resolve().parent.parent
for candidate in [_BASE_DIR / "hackathon_demo" / ".env", _BASE_DIR / ".env"]:
    if candidate.exists():
        load_dotenv(candidate)
        break

# ---------- 数据目录（Karpathy 风格的 Hot/Warm/Cold 分层）----------
KB_ROOT = Path(os.path.expanduser("~/Library/IdeaCapsule"))
KB_INBOX = KB_ROOT / "inbox"          # 🔥 Hot: 7 天内的原始灵感
KB_PROCESSED = KB_ROOT / "processed"  # ☀️ Warm: 30 天内 AI 处理过
KB_WIKI = KB_ROOT / "wiki"            # ❄️ Cold: 主题文章（V2 用）
KB_INDEX_FILE = KB_ROOT / "index.md"  # 📇 全局索引（V2 重建）

# ---------- 智谱 GLM API ----------
ZHIPU_API_KEY = os.getenv("ZHIPU_API_KEY", "")
ZHIPU_BASE_URL = os.getenv("ZHIPU_BASE_URL", "https://open.bigmodel.cn/api/paas/v4/")
ZHIPU_MODEL = os.getenv("ZHIPU_MODEL", "glm-4-flash")
ZHIPU_VISION_MODEL = os.getenv("ZHIPU_VISION_MODEL", "glm-4v-flash")


def ensure_dirs() -> None:
    """启动时确保所有数据目录存在"""
    for d in (KB_ROOT, KB_INBOX, KB_PROCESSED, KB_WIKI):
        d.mkdir(parents=True, exist_ok=True)
