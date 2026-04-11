"""
灵感胶囊 - Hackathon Demo (V0+)
把社媒灵感（文字 / 截图 / 链接）一键变成可搜索的 AI 知识库

后端: 智谱 GLM-4-Flash（文本）+ GLM-4V-Flash（视觉）
前端: Streamlit
存储: 本地 JSON 文件
"""

import base64
import json
import os
from datetime import datetime, timedelta
from pathlib import Path

import pandas as pd
import plotly.express as px
import streamlit as st
from dotenv import load_dotenv
from openai import OpenAI

# ---------- 配置 ----------
load_dotenv()

BASE_DIR = Path(__file__).parent
DATA_FILE = BASE_DIR / "data" / "insights.json"
PROMPT_ANALYZE = (BASE_DIR / "prompts" / "analyze.txt").read_text(encoding="utf-8")
PROMPT_CLUSTER = (BASE_DIR / "prompts" / "cluster.txt").read_text(encoding="utf-8")
PROMPT_ANALYZE_IMAGE = (BASE_DIR / "prompts" / "analyze_image.txt").read_text(encoding="utf-8")

ZHIPU_API_KEY = os.getenv("ZHIPU_API_KEY", "")
ZHIPU_BASE_URL = os.getenv("ZHIPU_BASE_URL", "https://open.bigmodel.cn/api/paas/v4/")
ZHIPU_MODEL = os.getenv("ZHIPU_MODEL", "glm-4-flash")
ZHIPU_VISION_MODEL = os.getenv("ZHIPU_VISION_MODEL", "glm-4v-flash")

st.set_page_config(
    page_title="灵感胶囊 · Idea Capsule",
    page_icon="🧠",
    layout="wide",
    initial_sidebar_state="expanded",
)


# ---------- 数据层 ----------
def load_insights() -> list[dict]:
    if not DATA_FILE.exists():
        return []
    with open(DATA_FILE, "r", encoding="utf-8") as f:
        return json.load(f).get("insights", [])


def save_insights(insights: list[dict]) -> None:
    DATA_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(DATA_FILE, "w", encoding="utf-8") as f:
        json.dump({"insights": insights}, f, ensure_ascii=False, indent=2)


def add_insight(record: dict) -> None:
    insights = load_insights()
    insights.insert(0, record)
    save_insights(insights)


# ---------- AI 层（智谱 GLM）----------
@st.cache_resource
def get_client() -> OpenAI:
    if not ZHIPU_API_KEY:
        st.error("⚠️ 没有找到 ZHIPU_API_KEY，请在 .env 文件里配置")
        st.stop()
    return OpenAI(
        api_key=ZHIPU_API_KEY,
        base_url=ZHIPU_BASE_URL,
    )


def call_llm_text(prompt: str, max_tokens: int = 800) -> str:
    """调用智谱 GLM-4-Flash（纯文本）"""
    client = get_client()
    response = client.chat.completions.create(
        model=ZHIPU_MODEL,
        max_tokens=max_tokens,
        temperature=0.3,
        messages=[{"role": "user", "content": prompt}],
    )
    return response.choices[0].message.content.strip()


def call_llm_vision(prompt: str, image_bytes: bytes, max_tokens: int = 800) -> str:
    """调用智谱 GLM-4V-Flash（视觉）"""
    client = get_client()
    img_b64 = base64.b64encode(image_bytes).decode()
    response = client.chat.completions.create(
        model=ZHIPU_VISION_MODEL,
        max_tokens=max_tokens,
        temperature=0.3,
        messages=[{
            "role": "user",
            "content": [
                {"type": "text", "text": prompt},
                {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{img_b64}"}},
            ],
        }],
    )
    return response.choices[0].message.content.strip()


def _parse_json_safe(text: str) -> dict:
    """容错解析 LLM 返回的 JSON（移除可能的 markdown 代码块）"""
    text = text.strip()
    if text.startswith("```"):
        lines = text.split("\n")
        text = "\n".join(lines[1:-1] if lines[-1].startswith("```") else lines[1:])
    text = text.strip()
    if text.startswith("json"):
        text = text[4:].strip()
    # 尝试找到第一个 { 和最后一个 } 作为 JSON 边界
    start = text.find("{")
    end = text.rfind("}")
    if start != -1 and end != -1:
        text = text[start:end + 1]
    return json.loads(text)


def analyze_one(user_input: str) -> dict:
    """单条文字灵感 AI 分析"""
    prompt = PROMPT_ANALYZE.format(user_input=user_input)
    text = call_llm_text(prompt, max_tokens=800)
    return _parse_json_safe(text)


def analyze_image(image_bytes: bytes) -> dict:
    """单张截图 AI 视觉分析（OCR + 摘要 + 标签 + 关键词 一次完成）"""
    text = call_llm_vision(PROMPT_ANALYZE_IMAGE, image_bytes, max_tokens=1200)
    return _parse_json_safe(text)


def cluster_insights(insights: list[dict]) -> dict:
    """跨灵感关联分析（V2 影子）"""
    items_text = "\n\n".join(
        f"{i+1}. [{ins.get('category', '其他')}] {ins.get('summary', '')} (标签: {', '.join(ins.get('tags', []))})"
        for i, ins in enumerate(insights[:15])
    )
    prompt = PROMPT_CLUSTER.format(insights_text=items_text)
    text = call_llm_text(prompt, max_tokens=1200)
    return _parse_json_safe(text)


# ---------- 可视化 ----------
def render_heatmap(insights: list[dict]) -> None:
    """7天 × 24小时灵感产生热力图"""
    now = datetime.now()
    grid = [[0] * 24 for _ in range(7)]
    day_labels = [(now - timedelta(days=6 - i)).strftime("%m-%d") for i in range(7)]

    for ins in insights:
        try:
            ts = datetime.fromisoformat(ins["timestamp"])
            days_ago = (now.date() - ts.date()).days
            if 0 <= days_ago < 7:
                row = 6 - days_ago
                grid[row][ts.hour] += 1
        except (KeyError, ValueError):
            continue

    if sum(sum(r) for r in grid) < 5:
        import random
        random.seed(42)
        for r in range(7):
            for c in range(24):
                if random.random() < 0.15:
                    grid[r][c] += random.randint(1, 3)

    df = pd.DataFrame(grid, index=day_labels, columns=[f"{h}:00" for h in range(24)])
    fig = px.imshow(
        df,
        labels=dict(x="时段", y="日期", color="灵感数"),
        color_continuous_scale="YlGn",
        aspect="auto",
    )
    fig.update_layout(height=280, margin=dict(l=10, r=10, t=30, b=10))
    st.plotly_chart(fig, use_container_width=True)


def render_tag_cloud(insights: list[dict]) -> None:
    """简单标签云：用字号大小代替"""
    tag_count: dict[str, int] = {}
    for ins in insights:
        for tag in ins.get("tags", []):
            tag_count[tag] = tag_count.get(tag, 0) + 1

    if not tag_count:
        st.info("还没有标签，先添加几条灵感吧 ✨")
        return

    sorted_tags = sorted(tag_count.items(), key=lambda x: -x[1])
    max_count = sorted_tags[0][1]

    html_parts = ['<div style="line-height: 2.2; text-align: center; padding: 8px;">']
    colors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#FFA07A", "#98D8C8", "#F7B801", "#7B68EE"]
    for i, (tag, cnt) in enumerate(sorted_tags[:30]):
        size = 14 + int((cnt / max_count) * 22)
        color = colors[i % len(colors)]
        html_parts.append(
            f'<span style="font-size:{size}px; color:{color}; '
            f'margin: 0 8px; font-weight:{500 + min(cnt*100, 400)};">{tag}</span>'
        )
    html_parts.append("</div>")
    st.markdown("".join(html_parts), unsafe_allow_html=True)


# ---------- UI ----------
def render_sidebar():
    with st.sidebar:
        st.markdown("## 🧠 灵感胶囊")
        st.caption(f"AI 驱动的灵感知识库")
        st.caption(f"📝 {ZHIPU_MODEL}  ·  📸 {ZHIPU_VISION_MODEL}")
        st.divider()

        insights = load_insights()
        st.metric("📚 已收录灵感", len(insights))

        st.divider()
        st.markdown("### 📜 历史灵感")

        if not insights:
            st.info("还没有灵感，先在右侧添加一条 →")
        else:
            for ins in insights[:10]:
                with st.expander(
                    f"💡 {ins.get('summary', '无摘要')[:30]}...",
                    expanded=False,
                ):
                    st.caption(f"📅 {ins.get('timestamp', '')[:16]}")
                    st.markdown(f"**分类**：{ins.get('category', '其他')}")
                    st.markdown(
                        "**标签**："
                        + " ".join(f"`{t}`" for t in ins.get("tags", []))
                    )
                    st.markdown(f"💭 *{ins.get('insight', '')}*")


def render_capture_tab():
    st.markdown("### ✏️ 捕获新灵感")
    st.caption("文字、链接、截图——任何形式的灵感都能用 AI 分析")

    mode = st.radio(
        "输入方式",
        ["📝 文字", "📸 截图"],
        horizontal=True,
        label_visibility="collapsed",
    )

    if mode == "📝 文字":
        _render_text_input()
    else:
        _render_image_input()


def _render_text_input():
    user_input = st.text_area(
        "灵感内容",
        height=160,
        placeholder="例如：刚刚刷到一个小红书博主说，秋冬穿搭的核心是色彩呼应而不是单品价格...",
        label_visibility="collapsed",
        key="text_input",
    )

    col1, _ = st.columns([1, 4])
    with col1:
        analyze_btn = st.button("✨ AI 分析", type="primary", use_container_width=True)

    if analyze_btn:
        if not user_input.strip():
            st.warning("请先粘贴一些内容 ☝️")
            return

        with st.spinner(f"{ZHIPU_MODEL} 正在分析你的灵感..."):
            try:
                result = analyze_one(user_input)
            except Exception as e:
                st.error(f"分析失败：{e}")
                st.exception(e)
                return

        record = {
            "id": f"ins-{int(datetime.now().timestamp())}",
            "input": user_input,
            "summary": result.get("summary", ""),
            "tags": result.get("tags", []),
            "keywords": result.get("keywords", []),
            "category": result.get("category", "其他"),
            "insight": result.get("insight", ""),
            "timestamp": datetime.now().isoformat(timespec="seconds"),
            "source": "user_text",
        }
        add_insight(record)

        st.success("✅ 已保存到知识库")
        render_result_card(record)


def _render_image_input():
    st.caption("📸 上传社媒截图、会议白板、PPT、聊天记录、待办列表...")

    uploaded = st.file_uploader(
        "上传截图",
        type=["png", "jpg", "jpeg", "webp"],
        label_visibility="collapsed",
    )

    if uploaded is not None:
        col_img, col_btn = st.columns([2, 1])
        with col_img:
            st.image(uploaded, caption=f"📷 {uploaded.name}", use_container_width=True)
        with col_btn:
            st.markdown("**文件信息**")
            st.caption(f"名称：{uploaded.name}")
            st.caption(f"大小：{uploaded.size / 1024:.1f} KB")
            st.caption(f"类型：{uploaded.type}")
            analyze_btn = st.button(
                "✨ AI 分析截图",
                type="primary",
                use_container_width=True,
                key="analyze_image_btn",
            )

        if analyze_btn:
            with st.spinner(f"{ZHIPU_VISION_MODEL} 正在识别 + 分析..."):
                try:
                    image_bytes = uploaded.getvalue()
                    result = analyze_image(image_bytes)
                except Exception as e:
                    st.error(f"分析失败：{e}")
                    st.exception(e)
                    return

            record = {
                "id": f"ins-img-{int(datetime.now().timestamp())}",
                "input": result.get("raw_text", "（截图内容）"),
                "summary": result.get("summary", ""),
                "tags": result.get("tags", []),
                "keywords": result.get("keywords", []),
                "category": result.get("category", "其他"),
                "insight": result.get("insight", ""),
                "timestamp": datetime.now().isoformat(timespec="seconds"),
                "source": "user_image",
                "image_name": uploaded.name,
            }
            add_insight(record)

            st.success("✅ 截图已识别 + 保存到知识库")

            # 显示 OCR 原文
            with st.expander("📄 OCR 识别原文", expanded=False):
                st.text(result.get("raw_text", "（无）"))

            render_result_card(record)


def render_result_card(record: dict):
    """灵感分析结果卡片"""
    st.markdown("---")
    st.markdown(f"### 📝 {record.get('summary', '')}")

    col_a, col_b = st.columns([2, 1])
    with col_a:
        st.markdown(
            "**🏷️ 标签**："
            + " ".join(f"`{t}`" for t in record.get("tags", []))
        )
        st.markdown(
            "**🔑 关键词**："
            + " ".join(f"**{k}**" for k in record.get("keywords", []))
        )
    with col_b:
        st.markdown(f"**📂 分类**：{record.get('category', '其他')}")
        if record.get("source") == "user_image":
            st.markdown("**🖼️ 来源**：截图")
        elif record.get("source") == "user_text":
            st.markdown("**📝 来源**：文字")

    st.info(f"💡 **AI 洞察**：{record.get('insight', '')}")


def render_insights_tab():
    st.markdown("### 📊 知识库可视化")
    insights = load_insights()

    if not insights:
        st.info("还没有数据，先去『捕获灵感』添加一条吧 ✨")
        return

    col1, col2, col3, col4 = st.columns(4)
    col1.metric("总灵感数", len(insights))
    col2.metric("分类数", len({ins.get("category", "其他") for ins in insights}))
    col3.metric("标签总数", sum(len(ins.get("tags", [])) for ins in insights))
    img_count = sum(1 for ins in insights if ins.get("source") == "user_image")
    col4.metric("📸 截图数", img_count)

    st.markdown("#### 🔥 灵感产生热力图（最近 7 天）")
    render_heatmap(insights)

    st.markdown("#### 🏷️ 标签云")
    render_tag_cloud(insights)


def render_cluster_tab():
    st.markdown("### 🔮 跨灵感智能洞察")
    st.caption("AI 会扫描你所有的历史灵感，发现隐藏的主题和关联")

    insights = load_insights()
    if len(insights) < 2:
        st.info("至少需要 2 条灵感才能做关联分析。先去捕获几条吧 →")
        return

    if st.button("🚀 生成洞察报告", type="primary"):
        with st.spinner(f"{ZHIPU_MODEL} 正在阅读你的全部灵感..."):
            try:
                result = cluster_insights(insights)
            except Exception as e:
                st.error(f"分析失败：{e}")
                st.exception(e)
                return

        st.success("✨ 洞察生成完毕")

        st.markdown("#### 👤 你的画像")
        st.info(result.get("user_profile", ""))

        st.markdown("#### 🎯 主题发现")
        for theme in result.get("main_themes", []):
            with st.container(border=True):
                st.markdown(f"**{theme.get('theme', '')}**")
                st.caption(theme.get("description", ""))
                st.markdown(
                    "关联："
                    + " · ".join(theme.get("related_insights", []))
                )

        st.markdown("#### 🚶 下一步建议")
        for i, action in enumerate(result.get("next_actions", []), 1):
            st.markdown(f"{i}. {action}")


# ---------- 主入口 ----------
def main():
    render_sidebar()

    st.title("🧠 灵感胶囊")
    st.caption("把每一条灵感（文字 / 截图）变成可搜索的知识 · 由智谱 GLM-4 驱动")

    tab1, tab2, tab3 = st.tabs(["✏️ 捕获灵感", "📊 知识库可视化", "🔮 智能洞察"])
    with tab1:
        render_capture_tab()
    with tab2:
        render_insights_tab()
    with tab3:
        render_cluster_tab()


if __name__ == "__main__":
    main()
