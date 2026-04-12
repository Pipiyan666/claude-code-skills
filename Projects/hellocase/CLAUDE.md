# Claude Code 项目级指令 — 灵感胶囊（Idea Capsule）

> 这份文档是 Claude Code 在这个项目里工作时**自动加载**的指令。
> 它定义了项目的核心信息、当前进度、文档地图、工作规范。
> 任何新的 Claude Code 会话进来后，应该**第一时间读这份文档恢复上下文**。

---

## 1. 项目核心信息

### 项目名
**灵感胶囊（Idea Capsule）** — 一个 iOS 知识库 App，把社媒截图、灵感、笔记一键变成可搜索的 AI 知识库

### 个人目标
- **求职作品集** — 通过这个项目走完互联网产品的完整流程（调研 → PRD → 架构 → 多版本迭代）
- **学习 Claude Agent SDK** — 借这个项目深度掌握 Multi-Agent / Tool Use / Harness 等核心概念

### 目标用户
18-35 岁女性、社媒重度用户（小红书 / 抖音）、内容创作者

### 核心场景
粘贴一条小红书笔记 / 会议片段 / 随手想法 → AI 5 秒生成摘要 + 标签 + 关键词 + 洞察

### 隐私哲学（不可妥协）
所有用户数据**默认在本地**，云端只是**可选增强**。这是相对 Notion / Get 笔记的核心差异化。

---

## 2. 当前进度（截至 2026-04-12 凌晨 03:05）

### ✅ V0-V4 全部完成（Python 实现，端到端测试通过）

| 版本 | 形态 | 路径 | 状态 |
|------|------|------|------|
| **V0+** | Streamlit Web Demo + GLM-4 + GLM-4V 截图 | `hackathon_demo/` | ✅ 运行中（http://localhost:8501） |
| **V1** | Markdown 知识库 + CLI | `capsule/` (cli.py / storage.py / agent.py) | ✅ 端到端测试通过 |
| **V2** | 多 Agent 固定 Workflow（4 Agent + Cluster） | `capsule/agents/` + `capsule/workflow.py` | ✅ 端到端测试通过 |
| **V3** | Agent + Tool Use（ReAct 循环） | `capsule/research_agent.py` + `capsule/tools/` | ✅ 真实网络抓取测试通过 |
| **V4** | Multi-Agent Harness + LibrarianAgent | `capsule/harness.py` + `capsule/librarian.py` + `capsule/events.py` | ✅ 自主生成 wiki 报告 |

**实测数据**：
- 知识库现有 5 条 inbox 灵感 + 1 份 LibrarianAgent 自主生成的 wiki 主题报告
- V2 一次完整 pipeline ~5 秒（4 次智谱 API 调用）
- V3 ResearchAgent 4 次工具调用完成深度调研（含真实 fetch_url）
- V4 Harness 累计 3 条捕获后自动触发 Librarian，自主决策 4 次

**完整交付报告**：`DEMO_SHOWCASE.md`

### 🛠️ 技术栈实际选型
- **LLM**：智谱 GLM-4-Flash（文本）+ GLM-4V-Flash（视觉）
- **SDK**：openai（用 OpenAI 兼容格式调用智谱）
- **Web UI**：Streamlit
- **存储**：Markdown 文件 + frontmatter（位于 `~/Library/IdeaCapsule/`）
- **依赖**：streamlit, openai, plotly, pandas, python-dotenv

### 📋 后续待办（V5 / 真实 iOS 化）
- V5: SwiftUI 原生实现 + Apple Foundation Models 本地模型 + 快捷指令
- 调研 + PRD 撰写（阶段 0）
- 接 SerpAPI / Bing 替换 mock web_search
- 把 Python 版的 Harness 接到真正的 Claude Agent SDK

---

## 3. 文档地图（开新会话必读顺序）

```
1️⃣ CLAUDE.md (本文件)              ← 项目入口和总览
2️⃣ ITERATION_ROADMAP.md            ← V1-V4 产品迭代路线（5 个月规划）
3️⃣ TECH_ARCHITECTURE.md            ← 完整技术架构总纲（核心文档）
4️⃣ HACKATHON_ARCHITECTURE.md       ← V0 黑客松简化架构（已完成）
5️⃣ hackathon_demo/                 ← V0 可运行的 demo
6️⃣ CLAUDE_AGENT_SDK_DEEP_DIVE.md   ← Claude Agent SDK 深度逆向工程笔记（V4 关键参考）
```

### 外部参考资料（不要修改）
```
references/
├── nanoclaw_sdk_docs/      ← 7 份 nanoclaw 项目的 SDK 文档（含 README 标注来源）
├── MineContext-main/       ← 同方向的开源项目（截图→洞察）⭐
├── MineContext/            ← 同上
├── knowledge-capture/      ← 之前的知识捕获探索
├── 照片清理产品方案.md     ← 之前的相册清理方案
├── iOS锁屏待办清单产品_技术方案.md
└── ai-photo-cards.html
```

---

## 4. 工作流规范

### 用户身份
**产品经理（非技术背景）** — 需要 Claude Code 在编码时给清晰的解释和可复制粘贴的命令

### Git 规范
- 每次有意义的修改要 commit + push
- commit message 用中文，说明"做了什么 + 为什么"
- 重要决策同步更新到对应的 markdown 文档

### 文档优先
- 所有架构决策、调研结论、灵感都先写到 markdown 文档
- 文档是项目的"长期记忆"，比口头讨论可靠

### 任务追踪
- 使用 Claude Code 的 TaskCreate / TaskUpdate 工具追踪进度
- 任务清单是工作的"短期记忆"

---

## 5. 关键技术决策（DAR 摘要）

| 决策 | 选择 | 理由 |
|------|------|------|
| 移动端框架 | SwiftUI（不选 React Native）| Apple Foundation Models 框架只支持 Swift |
| 数据存储 | Markdown 文件（不选 SQLite 主存储）| 学 Karpathy LLM Wiki，用户能随时打开数据 |
| 本地模型 | Apple Foundation Models 3B | iOS 26+ 内置，零成本零包大小 |
| 知识检索 | **不做 RAG**（直接用 markdown + 长上下文）| Karpathy 论证：100 篇文章规模下 markdown 比 RAG 节省 95% token |
| 模型路由 | 双轨：本地优先，云端可选 | 隐私承诺的核心 |
| V4 实现 | Claude Agent SDK + `preset: claude_code` + append 业务 prompt | 一行配置继承 Claude Code 全套能力，少写 90% 代码 |

详见 `TECH_ARCHITECTURE.md` 的 §10 DAR 章节。

---

## 6. ⚠️ 重大事故记录

### 2026-04-12：iCloud Drive Dataless File Bug

**事故经过**：
1. 项目最初在 `~/Documents/hellocase/`，被 iCloud Drive 同步过
2. iCloud 自动驱逐了部分文件的物理数据到云端，本地只剩占位符（dataless file）
3. 用 `mv` 把项目搬到 `~/Projects/hellocase/`，离开 iCloud Drive 范围
4. 离开后，dataless 占位符**永远无法触发下载**（iCloud 不知道去哪找）
5. 任何应用（cat / TextEdit / Cursor / VS Code）读取这些文件都 `Operation timed out`

**修复过程**：
1. 用 `stat -f "%N: size=%z block_count=%b"` 鉴定 dataless file（block_count=0 = 占位符）
2. 用 `rm` 删除占位符（rm 不需要 read 文件内容，可以成功）
3. 用 Claude Code 的 Write 工具从对话历史的内容重建 9 个文件
4. 从 `~/nanoclaw/docs/SDK_DEEP_DIVE.md` 复制了 SDK 深度文档作为 `CLAUDE_AGENT_SDK_MULTI_MODEL.md` 的内容替代
5. 这个 CLAUDE.md 本身也是事故后用模板重建的（原文 851 bytes 内容已永久丢失）

**永久教训**：
- ❌ **绝对不要把代码项目放在 `~/Documents` 或 `~/Desktop`**（如果开了 iCloud 桌面与文稿同步）
- ✅ 项目放在 `~/Projects/`（home 根目录的子目录，不在 iCloud 范围内）
- ✅ 重要文件每天 commit + push 到 git remote
- ✅ 每次 mv 大量文件后，立即 `find . -type f -exec stat -f "%b %z %N" {} \; | awk '$1==0 && $2>0'` 检查是否有占位符残留

**未恢复的丢失**：
- `CLAUDE_AGENT_SDK_MULTI_MODEL.md`（用户朋友写的笔记，12830 bytes）— 用 nanoclaw SDK_DEEP_DIVE.md 替代

---

## 7. 给未来 Claude Code 会话的指令

新会话开始时，请按这个顺序工作：

1. **读这份 CLAUDE.md** 了解项目全貌
2. **读 `TECH_ARCHITECTURE.md`** 了解架构（最重要的单一文档）
3. **读 `ITERATION_ROADMAP.md`** 了解迭代路线
4. **如果用户提到 V4 / Claude Agent SDK** → 读 `CLAUDE_AGENT_SDK_DEEP_DIVE.md`
5. **如果用户提到截图处理 / OCR / 知识捕获** → 看 `references/MineContext-main/examples/example_screenshot_to_insights.py`
6. **加载 Claude 记忆系统** → `~/.claude/projects/-Users-pipipiyan-Projects-hellocase/memory/MEMORY.md`

### 用户偏好（重要）
- **简洁优先** — 不要长篇大论
- **可执行优先** — 给命令而不是解释
- **PM 视角** — 用产品经理能理解的语言，避免过度技术化
- **每个建议带"为什么"** — 帮助 PM 学习而不只是执行

---

## 8. 联系信息和资源

- **GitHub**: （待补充）
- **iCloud 备份**: 已禁用本项目目录的 iCloud 同步
- **本地路径**: `/Users/pipipiyan/Projects/hellocase/`
- **Claude 记忆目录**: `~/.claude/projects/-Users-pipipiyan-Projects-hellocase/memory/`

## Skill routing

When the user's request matches an available skill, ALWAYS invoke it using the Skill
tool as your FIRST action. Do NOT answer directly, do NOT use other tools first.
The skill has specialized workflows that produce better results than ad-hoc answers.

Key routing rules:
- Product ideas, "is this worth building", brainstorming → invoke office-hours
- Bugs, errors, "why is this broken", 500 errors → invoke investigate
- Ship, deploy, push, create PR → invoke ship
- QA, test the site, find bugs → invoke qa
- Code review, check my diff → invoke review
- Update docs after shipping → invoke document-release
- Weekly retro → invoke retro
- Design system, brand → invoke design-consultation
- Visual audit, design polish → invoke design-review
- Architecture review → invoke plan-eng-review
- Save progress, checkpoint, resume → invoke checkpoint
- Code quality, health check → invoke health
