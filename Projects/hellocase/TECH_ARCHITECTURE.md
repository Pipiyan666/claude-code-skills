# 灵感胶囊 · 技术架构总纲

> 这份文档定义了灵感胶囊从 V0 到 V4 的完整技术架构。
> 它不是给某个版本写的，而是回答一个根本问题：**这个产品应该长成什么样的技术形态，才能在隐私、智能、扩展三个维度都站得住？**

---

## 1. 设计哲学（三条不可妥协的原则）

### 原则 1：Local-First（本地优先）
**用户的相册截图、灵感笔记、知识图谱，所有数据默认在用户手机上。云端只是可选的同步层，不是数据的"主"存储。**

为什么：目标用户是 18-35 岁女性重度截图用户，相册里的内容包含大量隐私（聊天截图、个人照片、未公开想法）。任何"数据要上云才能 AI 分析"的产品都会触发她们的删除阈值。

### 原则 2：Markdown-as-a-Database（文档即数据库）
**所有结构化的灵感数据，最终落地为 Markdown 文件。SQLite 只是索引层，不是真相源。**

为什么：这是我们从 [Karpathy 的 LLM Wiki 思想](https://venturebeat.com/data/karpathy-shares-llm-knowledge-base-architecture-that-bypasses-rag-with-an) 学来的核心洞察——"LLM 最友好的数据格式就是 Markdown"。在 100 篇文章/40 万字的规模下，markdown 知识库比 RAG 系统节省 **95% 的 token 消耗**，而且：
- 用户可以随时用任何编辑器（Obsidian、Bear、VS Code）打开自己的数据
- 数据不绑定在我们的产品里，迁移成本极低 → 反而提升信任
- AI 调用知识库时直接读 markdown 文件，无需 embedding/vector store

### 原则 3：Two-Track Models（双轨模型策略）
**本地模型负责高频 + 隐私敏感任务，云端模型负责低频 + 高质量任务。两者通过统一的接口层屏蔽差异。**

为什么：单一选择都是错的。
- 全本地模型 → 质量差（3B 模型理解中文复杂语义有限）、用户首次安装包巨大
- 全云端模型 → 隐私破产 + API 成本随用户量爆炸

正确做法见 §5。

---

## 2. 业界优秀架构对标（我们的参考系）

| 参考系统 | 我们学到的核心思想 | 应用到我们的哪一层 |
|---------|------------------|------------------|
| **[Karpathy LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)** | 用 LLM 作为"研究图书管理员"维护一个不断进化的 markdown 库；定期 lint + 重建索引 | §4 数据架构、§7 存储分层 |
| **[Apple Foundation Models 2025](https://machinelearning.apple.com/research/apple-foundation-models-2025-updates)** | iOS 26+ 内置 3B 模型，`@Generable` 宏 + Tool Calling，**调用 API 零成本** | §5 模型层、§9 V1 实现 |
| **[Notion Local-First](https://www.notion.com/blog/how-we-made-notion-available-offline)** | Block model + CRDT + 客户端 SQLite 作为主写入目标 + 时间戳同步 | §7 存储分层、§8 同步策略 |
| **[Claude Agent SDK](https://docs.claude.com/en/api/agent-sdk)** | Agent + Harness 模式，Tool Use 标准化，session 持久化 | §6 Agent 编排、§9 V4 实现 |

---

## 3. 整体架构图（C4 容器视图）

```
┌──────────────────────────────────────────────────────────────┐
│                     用户的 iPhone (iOS 26+)                    │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │              UI 层 (SwiftUI)                            │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │  │
│  │  │ 灵感捕获  │ │ 知识库浏览│ │ AI 调研  │ │ 可视化   │  │  │
│  │  │ Capture  │ │ Browse   │ │ Research │ │ Insights │  │  │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘  │  │
│  └────────────────────────────────────────────────────────┘  │
│                            ↕                                  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │            Agent Harness 层 (V2-V4)                    │  │
│  │   ┌─────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │  │
│  │   │ Inbox   │ │ Classify │ │ Cluster  │ │ Research │  │  │
│  │   │ Agent   │ │  Agent   │ │  Agent   │ │  Agent   │  │  │
│  │   └─────────┘ └──────────┘ └──────────┘ └──────────┘  │  │
│  │   通过统一的 Tool 接口调用：read_kb / write_kb /      │  │
│  │                            web_search / fetch_url     │  │
│  └────────────────────────────────────────────────────────┘  │
│                            ↕                                  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │            模型路由层 (Model Router)                    │  │
│  │                                                        │  │
│  │   ┌─────────────────┐         ┌──────────────────┐    │  │
│  │   │ 本地路径 (默认)  │         │ 云端路径 (可选)   │    │  │
│  │   │ Apple FM 3B     │  ⇄     │ Claude Haiku/Sonnet│   │  │
│  │   │ Vision/OCR      │ 用户  │ + Web Search Tool │    │  │
│  │   │ NaturalLanguage │  授权  │ + Deep Research   │    │  │
│  │   └─────────────────┘         └──────────────────┘    │  │
│  └────────────────────────────────────────────────────────┘  │
│                            ↕                                  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │            数据层 (Markdown-as-DB)                      │  │
│  │                                                        │  │
│  │   📁 ~/Library/IdeaCapsule/                            │  │
│  │      ├── inbox/        (Hot: 7 天内的原始灵感)         │  │
│  │      ├── processed/    (Warm: 30 天内 AI 加工过的)     │  │
│  │      ├── wiki/         (Cold: AI 编译的主题文章)        │  │
│  │      ├── index.md      (全局索引，每晚重建)            │  │
│  │      └── .meta.sqlite  (查询索引，非真相源)            │  │
│  └────────────────────────────────────────────────────────┘  │
│                            ↕ (可选)                            │
└──────────────────────────────────────────────────────────────┘
                             │
                             ▼
       ┌─────────────────────────────────────────┐
       │   云端：Claude API（仅在用户开启时调用）   │
       │   - 深度调研（Research Tool）             │
       │   - 跨设备同步（CRDT，可选）              │
       └─────────────────────────────────────────┘
```

---

## 4. 数据架构：Karpathy 风格的 Markdown 知识库

### 文件组织（受 Karpathy LLM Wiki 启发）

```
~/Library/IdeaCapsule/
├── inbox/                          # 🔥 Hot: 原始灵感（7 天）
│   ├── 2026-04-12/
│   │   ├── 1430-小红书穿搭笔记.md
│   │   ├── 1502-产品会议要点.md
│   │   └── 1730-播客金句.md
│   └── 2026-04-11/
│       └── ...
│
├── processed/                      # ☀️ Warm: AI 处理过的（30 天）
│   ├── 2026-04-12-1430.md          # 含 frontmatter + 摘要 + 标签 + 关键词
│   └── ...
│
├── wiki/                           # ❄️ Cold: AI 编译的主题文章
│   ├── topics/
│   │   ├── 穿搭与色彩心理学.md       # 跨灵感综合的 wiki 文章
│   │   ├── 用户留存与onboarding.md
│   │   └── 深度工作方法论.md
│   └── people/                     # 提及的人物（如博主）
│       └── 某某穿搭博主.md
│
├── index.md                        # 全局索引（每晚 ClusterAgent 重建）
└── .meta.sqlite                    # 查询加速索引（可随时重建）
```

### 单条灵感的 Markdown 结构（带 frontmatter）

```markdown
---
id: ins-2026041214301234
created: 2026-04-12T14:30:00+08:00
source: screenshot                  # screenshot / paste / voice / link
category: 社媒灵感
tags: [穿搭, 色彩搭配, 时尚]
keywords: [焦糖色, 酒红, 墨绿, 层次感]
links: [[topics/穿搭与色彩心理学]]   # Obsidian 风格双向链接
processed_by: apple-fm-3b           # 哪个模型处理的
processed_at: 2026-04-12T14:30:05+08:00
---

# 秋冬色彩呼应穿搭法

## 摘要
今年秋冬的色彩趋势是焦糖色、酒红、墨绿。重点是把基础款穿出层次感...

## 原文
[OCR 提取的截图原文]

## AI 洞察
可以建立一个秋冬色彩参考板，每周尝试一种新组合并记录效果。

## 出处
- 来源：相册截图 IMG_2341.HEIC
- 时间：2026-04-12 14:30
```

### 为什么不用 SQLite 作为主存储？

| 维度 | SQLite 主 | Markdown 主（我们） |
|------|----------|-------------------|
| 用户能否打开数据 | ❌ 需要工具 | ✅ 任何编辑器 |
| 迁移成本 | 高 | 几乎为零 |
| AI 友好度 | 需要序列化 | ✅ 直接可读 |
| 用户信任度 | 低 | ✅ 高（数据在我手里） |
| 双向链接 | 需要建表 | ✅ `[[link]]` 语法天然支持 |
| 查询性能 | ✅ 高 | 慢 → 用 sqlite 索引层补救 |

**关键设计**：SQLite 只存"哪个文件在哪里、有什么标签、什么时间"——是**索引**，不是**数据**。这意味着 SQLite 文件丢了，重新扫描 markdown 目录就能完全重建。

---

## 5. 模型层架构：本地 / 云端双轨

### 任务路由表

| 任务类型 | 默认走哪条路径 | 为什么 |
|---------|--------------|-------|
| OCR（截图文字提取） | 本地 [Vision Framework](https://developer.apple.com/documentation/vision) | 苹果原生，免费、快、准 |
| 摘要 + 标签 + 关键词 | 本地 [Apple FM 3B](https://machinelearning.apple.com/research/apple-foundation-models-2025-updates) | iOS 26+ 内置，零成本，3B 够用 |
| 简单分类 | 本地 NaturalLanguage Framework | 系统原生，纳秒级 |
| 跨灵感主题聚类 | 本地 Apple FM 3B | 中等复杂度，本地够用 |
| **深度调研**（带 web search） | 云端 Claude Sonnet + Tool Use | 需要互联网检索，本地做不了 |
| **复杂逻辑推理** | 云端 Claude Sonnet | 3B 模型在多步推理上能力不够 |
| **跨设备同步** | 云端（用户授权后） | 必须有云端中转 |

### Model Router 接口设计（伪代码）

```swift
protocol IdeaCapsuleLLM {
    func summarize(_ text: String) async -> Summary
    func classify(_ text: String) async -> [Tag]
    func cluster(_ ideas: [Idea]) async -> [Theme]
    func research(_ idea: Idea, tools: [Tool]) async -> Report
}

// 本地实现：调用 Apple Foundation Models
class LocalLLM: IdeaCapsuleLLM { ... }

// 云端实现：调用 Claude API
class CloudLLM: IdeaCapsuleLLM { ... }

// 路由器根据任务类型 + 用户隐私设置自动选择
class ModelRouter {
    func pick(for task: TaskType) -> IdeaCapsuleLLM {
        if task.requiresInternet || task.complexity == .high {
            return cloudLLM ?? localLLM  // 用户没开云端就降级
        }
        return localLLM
    }
}
```

**关键设计**：用户在设置里可以一键关闭"云端 AI"，所有数据严格不出本机。这是我们对女性用户隐私顾虑的**核心承诺**。

---

## 6. Agent 编排架构（V2 → V4 演进）

### V1：单 LLM 调用（Chat）
```
input → LLM.summarize() → output
```
没有 Agent 概念，一次 API 调用搞定。**这是 V0/V1 的形态。**

### V2：Workflow 编排（多步骤但是固定流水线）
```
screenshot
  → OCRAgent (Vision FW)
  → ClassifyAgent (NaturalLanguage)
  → SummaryAgent (Apple FM)
  → 写入 inbox/

(每晚定时)
all inbox files
  → ClusterAgent
  → 生成 wiki/topics/*.md
  → 重建 index.md
```
每个 Agent 是一个职责单一的函数。**没有动态决策，只有固定 pipeline。**

### V3：Agent + Tool Use（动态决策）
```
user: "调研一下『焦糖色穿搭』这个主题"
  ↓
ResearchAgent (Claude Sonnet)
  ├── 决策：我需要先看本地有什么 → Tool: read_kb("焦糖色")
  ├── 决策：本地有 3 篇相关 → Tool: read_file(...)
  ├── 决策：缺市场数据 → Tool: web_search("焦糖色 穿搭趋势 2026")
  ├── 决策：找到 5 个来源 → Tool: fetch_url(...)
  └── 决策：信息够了 → Tool: write_kb("wiki/topics/焦糖色穿搭2026.md", report)
```
**Agent 自己决定调用什么工具、调用几次、何时停止。** 这是从 workflow 到 agent 的质变。

### V4：Multi-Agent Harness（Agent 之间通信）
```
ClusterAgent 每晚扫描 inbox/，发现"焦糖色"出现 5 次
  ↓
emit event: "new_hot_topic: 焦糖色"
  ↓
Harness 路由到 ResearchAgent
  ↓
ResearchAgent 自主调研，写入 wiki/topics/焦糖色穿搭2026.md
  ↓
emit event: "wiki_updated"
  ↓
LinkAgent 更新所有相关 inbox 文件的 [[link]]
```
**Agent 间通过事件总线松耦合通信。** 这是 V4 的形态，对应 Claude Agent SDK 的 Harness 概念。

### 🔑 V4 的杀手锏：`claude_code` Preset

**关键洞察**：[Claude Agent SDK 官方支持 `preset: "claude_code"` 参数](https://docs.claude.com/en/docs/agent-sdk/modifying-system-prompts)，可以让 SDK **一行配置就继承 Claude Code 产品的全部能力**——24 个内置工具（Read/Write/Edit/Bash/Glob/Grep/Task/WebFetch 等）+ 完整的 system prompt。

```python
# 这一句话，等于继承了 Claude Code 的所有能力
from claude_agent_sdk import ClaudeAgentOptions, query

options = ClaudeAgentOptions(
    system_prompt={
        "type": "preset",
        "preset": "claude_code",        # ← 继承 Claude Code 全套能力
        "append": IDEA_CAPSULE_PROMPT,  # ← 在后面追加我们的业务 prompt
    },
    setting_sources=["project"],         # ← 加载 CLAUDE.md（preset 默认不加载）
)

async for message in query(
    prompt="帮我整理今天的灵感并发现共同主题",
    options=options,
):
    ...
```

**这意味着什么？**

| 没有 preset | 有 `preset: claude_code` |
|-----------|------------------------|
| 自己实现文件读写工具 | ✅ 直接用 Read/Write/Edit |
| 自己实现 shell 调用 | ✅ 直接用 Bash |
| 自己实现搜索 | ✅ 直接用 Glob/Grep |
| 自己实现 sub-agent 编排 | ✅ 直接用 Task |
| 自己写一套 system prompt（容易出错）| ✅ 复用 Anthropic 调过的最强 prompt |
| 自己处理工具调用循环 | ✅ SDK 内置的 ReAct 循环 |

**对我们的业务实现，只需要写两件事**：
1. **业务 prompt（append 部分）**：告诉模型"你是灵感胶囊的 librarian agent，你的工作是 ……"
2. **业务专属工具（自定义 MCP server）**：比如 `get_today_inbox()`、`update_wiki_topic()` 这种 Claude Code 没有的、知识库专属的工具

**这是为什么 V4 比 V3 难度上升不是 10 倍而是 1.5 倍**：85% 的能力是 SDK 白送的，我们只写差异化的 15%。

### V4 完整业务实现示例（参考自用户业务案例）

```python
# capsule_agent.py
from claude_agent_sdk import ClaudeAgentOptions, query

# 业务专属 prompt（append 到 claude_code preset 后面）
CAPSULE_PROMPT = """
你现在是『灵感胶囊』的 Librarian Agent。

你的工作目录是 ~/Library/IdeaCapsule/，里面是用户的 markdown 知识库：
- inbox/         最近 7 天的原始灵感
- processed/     AI 加工过的灵感
- wiki/topics/   主题文章（你定期重建）
- index.md       全局索引（你定期重建）

你可以用 Read/Write/Edit/Glob/Grep 这些工具自由操作这些文件。
你也可以用 Bash 调用 git 来追踪知识库的变更。

每次被调用时，你的目标是帮用户：
1. 分析新灵感（如果有未处理的 inbox 文件）
2. 发现跨灵感主题（如果某个标签出现 5 次以上）
3. 更新 wiki 文章（基于发现的主题）
4. 重建 index.md
"""

async def run_nightly_librarian():
    options = ClaudeAgentOptions(
        system_prompt={
            "type": "preset",
            "preset": "claude_code",
            "append": CAPSULE_PROMPT,
        },
        cwd="/Users/me/Library/IdeaCapsule",  # 切换到知识库目录
        setting_sources=["project"],            # 加载本地 CLAUDE.md
    )

    async for message in query(
        prompt="帮我做今晚的整理：处理 inbox、发现主题、更新 wiki、重建索引。",
        options=options,
    ):
        print(message)
```

**就这样。** 一个文件，<50 行代码，就实现了 Karpathy 想象中的"AI 作为 research librarian"的形态。这就是 V4。

---

### 🌟 这个发现对整个项目意义有多大？

| 维度 | 影响 |
|------|------|
| **开发成本** | V4 从 4-6 周降到 2-3 周（不用自己造 harness） |
| **可靠性** | 复用 Anthropic 调试过的 system prompt + 工具链，比自己写少 90% bug |
| **求职故事** | 「我用 Claude Agent SDK 的 claude_code preset + 业务 append 实现了一个完整的 librarian agent」是顶级面试材料——证明你理解 Anthropic 的工程哲学 |
| **可扩展性** | 当 Claude Code 升级（比如出新工具），我们的 V4 自动继承 |

### V4 与 V1-V3 的关系（重新理解）

V1-V3 不是为了 V4 做铺垫，而是为了让我们**深刻理解 V4 在做什么**：
- V1：你知道"调一次 LLM"的成本和局限 → 才理解 V4 的 ReAct 循环值多少
- V2：你试过自己拆 workflow → 才理解为什么 SDK 的 Task 工具能省 80% 工作
- V3：你试过自己实现 Tool Use 框架 → 才理解 `preset: claude_code` 这一行的含金量

**没有 V1-V3 的痛苦，V4 就只是 copy-paste；有了 V1-V3 的痛苦，V4 是顿悟。** 这是面试讲故事的核心戏剧性。

---

## 7. 存储分层（Hot / Warm / Cold）

灵感来自 Karpathy 的"研究图书管理员"思想 —— 不是所有数据都同等重要。

| 层级 | 位置 | 内容 | 谁在维护 | 访问频率 |
|------|------|------|---------|---------|
| 🔥 **Hot** | `inbox/YYYY-MM-DD/` | 最近 7 天的原始灵感 | 用户写入 + InboxAgent 处理 | 极高（每次打开 App）|
| ☀️ **Warm** | `processed/` | 30 天内 AI 加工过的灵感 | InboxAgent + ClassifyAgent | 中（搜索/浏览时）|
| ❄️ **Cold** | `wiki/topics/`, `wiki/people/` | AI 编译的主题文章 | ClusterAgent + ResearchAgent（每晚） | 低（Research 时）|
| 📇 **Index** | `index.md`, `.meta.sqlite` | 全局索引 + 查询索引 | 每晚重建 | 极高（每次查询）|

### 数据流（一条灵感的完整生命周期）
```
Day 1 09:00  用户截图 → inbox/2026-04-12/0900-XXX.md
Day 1 09:00  InboxAgent 立即处理（OCR + 摘要）→ processed/2026-04-12-0900.md
Day 7 03:00  ClusterAgent 扫描，发现这条与其他 4 条形成主题 → wiki/topics/穿搭2026春.md
Day 30 03:00 文件从 processed/ 移除（已经被 wiki 综合了），但 inbox/ 永久保留原文
```

**关键设计**：原始灵感永远不删除（用户的"宁可不删"心理），但 AI 加工版本会过期，因为它们已经被更高维度的 wiki 文章吸收了。

---

## 8. 同步策略（V3+）

借鉴 [Notion 的 offline-first 模式](https://www.notion.com/blog/how-we-made-notion-available-offline)：

```
本地写入永远是同步的，云端同步是异步的。
即使没有云端，App 100% 可用。
```

### 同步原理（极简 CRDT）
- 每条灵感有一个 `id` + `last_modified`
- 同步时只传 `last_modified > server_last_seen` 的文件
- 冲突解决：后修改的赢（last-write-wins，对于个人产品够用）

**为什么不上 Yjs/Automerge？** 个人产品没有协作场景，CRDT 是过度工程化。等真有团队协作需求再加。

---

## 9. 各 V 版本的架构落地

### V0（黑客松半天 - 已完成 ✅）
```
Streamlit Web App → Claude Haiku API → JSON 文件
```
**目的**：验证"粘贴 → AI 一键分析"的核心体验。**没有 Agent、没有本地模型、没有 markdown 知识库。**

### V1（3-4 周）
```
SwiftUI iOS App
  → Apple FM 3B (本地)
  → markdown 文件 (~/Library/IdeaCapsule/)
  → SQLite 索引
```
**核心**：把 V0 的核心体验搬到 iOS 原生 + 用 Apple Foundation Models 替代 Claude API + 切到 markdown 存储。**第一次实现真正的隐私优先。**

### V2（3-4 周）
```
+ OCRAgent (Vision FW)
+ ClassifyAgent (NaturalLanguage FW)
+ SummaryAgent (Apple FM)
+ ClusterAgent (Apple FM, 定时任务)
+ 7 天热力图 + 标签云
```
**核心**：把单次调用拆成 4 个 Agent 的固定 pipeline。第一次出现 Agent 概念。

### V3（3-4 周）
```
+ ResearchAgent (Claude Sonnet, 用户授权云端)
+ Tool Use 框架 (web_search, fetch_url, read_kb, write_kb)
+ 双轨模型路由器
+ Markdown 双向链接 [[...]]
```
**核心**：第一次让 Agent 自己决策调用什么工具。从 workflow 到 agent 的质变。

### V4（4-6 周）
```
+ Claude Agent SDK 集成
+ Multi-Agent Harness (事件总线)
+ Hot/Warm/Cold 存储分层完整实现
+ 跨设备同步（last-write-wins）
+ 知识图谱可视化
```
**核心**：Agent 之间能互相通信，知识库自主演化（每晚自动重建索引、发现新主题、更新双向链接）。

---

## 10. 关键技术决策（DAR：Decision Architecture Records）

### DAR-001：选 SwiftUI 而不是 React Native / Flutter
**决策**：iOS 原生 SwiftUI
**理由**：
- Apple Foundation Models 框架仅 SwiftUI/Swift 可用，跨平台框架要等很久
- Vision/NaturalLanguage/Speech 等系统能力原生调用最快
- 目标用户是 iOS 重度用户（小红书女性用户主要在 iOS）
**代价**：放弃 Android。可接受，目标用户 90% 在 iOS。

### DAR-002：选 markdown 而不是 SQLite/CoreData
**决策**：Markdown-as-DB，SQLite 仅作为索引
**理由**：见 §4 表格
**代价**：复杂查询需要先扫文件构建索引。可接受，知识库规模 <10000 条灵感。

### DAR-003：选 Apple FM 3B 而不是自带 Llama
**决策**：默认 Apple Foundation Models
**理由**：
- App 包大小：自带 Llama 4-bit 量化要 2GB+，Apple FM 是系统内置不占用户磁盘
- 调用成本：Apple FM 框架调用零成本，Llama 自托管要管理内存/推理优化
- 集成成本：`@Generable` 宏 + Tool Calling，开发体验远好于 MLC-LLM
**代价**：要求 iOS 26+。可接受，上线时间是 2026 下半年，iOS 26 已普及。

### DAR-004：先不做 RAG / Vector Database
**决策**：直接用 markdown 文件 + LLM 长上下文
**理由**：[Karpathy 的论证](https://venturebeat.com/data/karpathy-shares-llm-knowledge-base-architecture-that-bypasses-rag-with-an)——在 100 篇文章/40 万字规模下，markdown 比 RAG 节省 95% token + 复杂度极低
**代价**：当用户的灵感超过 40 万字（约 3-5 年使用），可能需要重新引入 embedding + 检索。可接受，那是 V5 的事。

### DAR-005：双轨模型路由，本地优先
**决策**：`LocalLLM` 是默认实现，`CloudLLM` 是可选增强
**理由**：见 §1 原则 1
**代价**：要维护两套 prompt 模板。可接受，prompt 用 placeholder + 抽象层管理。

### DAR-006：V4 用 Claude Agent SDK 的 `claude_code` preset，不自己造 harness
**决策**：V4 的 Librarian Agent 直接用 `system_prompt={"type": "preset", "preset": "claude_code", "append": ...}`
**理由**：
- 一行配置继承 Claude Code 的 24 个内置工具（Read/Write/Edit/Bash/Glob/Grep/Task/WebFetch 等）
- 复用 Anthropic 调试过的最强 system prompt，比自己写少 90% bug
- 业务实现只需写 append 部分的业务 prompt + 少量 MCP 自定义工具
- Claude Code 升级时我们自动继承新能力
- 来源：[Anthropic 官方文档](https://docs.claude.com/en/docs/agent-sdk/modifying-system-prompts) + 业务实战案例（AI CDN 智能体也是这么做的）
**代价**：
- 强依赖 Anthropic 生态（不能切到 GPT/Gemini）— 可接受，整个项目就是赌 Claude
- preset 不会自动加载 CLAUDE.md，必须显式 `setting_sources=["project"]` — 注意点不是代价
- 知识库专属操作（read_inbox / update_topic）需要写自定义 MCP server — 工作量小，~200 行 Python

---

## 11. 风险与应对

| 风险 | 影响 | 应对 |
|------|------|------|
| **Apple FM 3B 的中文质量不够** | V1 摘要质量差 | 内测时 A/B 对比 Claude，差距大就让 V1 默认调用云端，FM 作为降级 |
| **用户的相册没开权限** | 核心场景失效 | 第一次启动有引导页解释隐私承诺，强调"数据不离开你手机" |
| **markdown 文件太多导致索引慢** | App 卡顿 | SQLite 索引层 + 增量扫描（只扫 last_modified 改变的文件） |
| **iOS 26 普及率不够** | 用户用不了 | V1 同步开发降级版本，对 iOS 18-25 用户走 Claude API（默认开云端）|
| **Claude API 成本爆炸** | 上线后亏损 | 严格的本地优先路由 + 用户量化分桶 + 免费用户每天限 5 次云端调用 |

---

## 12. 这份架构如何讲给面试官

### 30 秒电梯版
> 我做了一个 iOS 知识库 App，核心思想是把 Karpathy 的 markdown LLM 知识库架构搬到移动端，用 Apple 2025 年新的 Foundation Models 做本地分析，云端 Claude 只在用户明确开启时调用。这样既解决了女性用户对相册隐私的强烈担忧，又能在本地以零成本提供 AI 能力。

### 5 分钟深度版
> 我从一个观察出发：女性重度截图用户既想要 AI 整理，又害怕隐私泄露。市面上要么是 Notion 这种云端方案破坏隐私，要么是 Obsidian 这种本地方案没有 AI。
>
> 我的解法分四层：UI 层是 SwiftUI 原生；模型层是双轨路由——默认用 Apple Foundation Models 这个 iOS 26 内置的 3B 模型，跑在 ANE 上零成本零隐私风险，复杂任务才走云端 Claude；数据层是 Karpathy 风格的 markdown 知识库，原始文件永远在用户手机上，SQLite 只作为索引；最上面是 Agent 编排层，从 V2 的固定 pipeline 演进到 V4 的多 Agent harness。
>
> 这个架构有三个值得讲的判断：第一，我们没有用 RAG/向量库，因为在个人知识库这个规模下 Karpathy 论证了 markdown 比 RAG 节省 95% token；第二，我们没有用 React Native，因为 Apple FM 框架只支持 Swift；第三，我们的同步是 last-write-wins 而不是 CRDT，因为个人产品没有协作场景，CRDT 是过度工程化。
>
> 整个项目的迭代之路本身就是从单次 LLM 调用到 multi-agent 系统的完整成长——V1 一次 Chat，V2 固定 workflow，V3 Tool Use 动态决策，V4 多 Agent harness。每一次升级都是被真实产品场景倒逼出来的，不是为了学技术而学技术。

---

## 13. 下一步行动

- [ ] 把这份架构文档发给认识的资深 iOS 工程师（如果有），收集 3-5 条反馈
- [ ] V1 启动前，做一次 Apple Foundation Models 中文质量的真实测试（写 20 条灵感样本，对比 Apple FM 和 Claude Haiku）
- [ ] V1 启动前，画一个详细的数据流时序图（某条具体的灵感从截图到入库到出现在热力图的全过程）
- [ ] 起草一份"用户隐私承诺"页面（V1 上架时必备）

---

## 参考资料

- [Karpathy LLM Wiki Architecture (VentureBeat)](https://venturebeat.com/data/karpathy-shares-llm-knowledge-base-architecture-that-bypasses-rag-with-an)
- [Karpathy LLM Wiki Gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
- [Apple Foundation Models 2025 Updates](https://machinelearning.apple.com/research/apple-foundation-models-2025-updates)
- [Apple On-Device Llama 3.1 with Core ML](https://machinelearning.apple.com/research/core-ml-on-device-llama)
- [Notion: How we made Notion available offline](https://www.notion.com/blog/how-we-made-notion-available-offline)
- [Notion System Design (Educative)](https://www.educative.io/blog/notion-system-design)
- [LLM Wiki vs RAG: When to Use Markdown Knowledge Bases](https://www.mindstudio.ai/blog/llm-wiki-vs-rag-markdown-knowledge-base-comparison)
- [Claude Agent SDK: Modifying System Prompts (Anthropic 官方)](https://docs.claude.com/en/docs/agent-sdk/modifying-system-prompts) — V4 的 `preset: claude_code` 用法
- [Claude Code System Prompts (社区逆向)](https://github.com/Piebald-AI/claude-code-system-prompts) — Claude Code 的全部 prompt 和工具描述，理解 preset 继承了什么
- 项目内部参考：`CLAUDE_AGENT_SDK_MULTI_MODEL.md`（用户朋友的 AI CDN 智能体业务案例笔记）
