# 截图知识库 App 迭代路线图（V1-V4）

## 项目概述

**项目名**：截图知识库 App（暂定）

**核心概念**：随时随地捕捉灵感，AI 驱动从记录到洞察的知识库

**目标用户**：18-35 岁女性，社媒重度用户（小红书/抖音）

**个人目标**：通过这个项目完成互联网产品开发的全流程（调研→PRD→架构→迭代），积累求职作品集

---

## 产品三层架构

### 1️⃣ 输入层 — 快速捕获
- iOS 快捷指令（核心入口，最快）
- 语音口述 → 自动转文字
- 文字输入
- 拍照/截图
- 社媒链接粘贴 → 自动抓取标题/摘要

### 2️⃣ 存储层 — 知识库
- 统一存储所有灵感
- 结构化标签：时间、类型、来源
- 双向链接（参考 Obsidian）
- 全文搜索
- 分类/分组视图

### 3️⃣ 智能层 — AI 增强
- 单灵感调研（市场、竞品、可行性）
- 跨灵感关联（发现共同主题）
- 自动摘要生成
- 下一步建议

---

## V1：基础能力 + 单次 LLM 调用（Chat）

### ⏱️ 时长：3-4 周

### 产品功能
- ✅ 截图导入（相册选择 + iOS 快捷指令）
- ✅ OCR 文字提取（Vision Framework，本地）
- ✅ 手动标签系统
- ✅ 基础全文搜索
- ✅ GitHub 热力图（记录频率可视化）

### AI 能力
**单次 LLM API 调用**：对一张截图发起 chat 请求，返回：
- 内容摘要（50字）
- 自动分类标签（设计/商业/日常 等）
- 关键词提取

**使用模型**：Claude Haiku（响应快，成本低）

### 架构流程
```
截图 → OCR → [单次 LLM Chat] → 摘要 + 标签 → SQLite 存储
```

### 求职叙事
> 我从最简单的单次 API 调用开始，建立起完整的数据流管道，验证了核心场景的可行性。
> 这个阶段的关键学习：LLM 的 prompt 设计直接决定产品体验质量。

### 验收标准
- ✅ 能处理一张截图，输出摘要+标签
- ✅ 搜索能找到已保存的内容
- ✅ 热力图正确显示记录频率

---

## V2：多步骤 Workflow + 结构化 Agent 编排

### ⏱️ 时长：3-4 周

### 触发场景
V1 用了一两个月后，发现「一次调用」的问题：
- 对复杂截图（如 PPT 全页）摘要质量差
- 无法做「跨截图关联」
- 无法做「灵感深度调研」

### 产品功能（新增）
- ✅ **灵感调研**：对单个灵感点，AI 展开市场分析、竞品分析
- ✅ **跨灵感关联**：定期任务（每晚）扫描最近灵感，发现共同主题
- ✅ **GitHub 热力图**（已有，优化）

### AI 能力 — 多 Agent Workflow 编排
每个 Agent 职责单一：

```
OCRAgent         → 识别 + 清洗文字
ClassifyAgent    → 分类 + 打标签
SummaryAgent     → 生成摘要
ResearchAgent    → 对指定灵感做深度调研（用户手动触发）
ClusterAgent     → 后台定时，聚类多条灵感（每晚运行）
```

### 架构流程
```
截图 → OCRAgent → ClassifyAgent → SummaryAgent → 存储
                                                    ↓ (触发器)
                              ResearchAgent (用户手动触发)
                              ClusterAgent (定时任务，每晚)
```

### 求职叙事
> 随着产品进入内测，单次调用的局限性暴露了。我学到了 Agent 编排的核心思想：
> 把一个复杂意图拆解成多个职责清晰的 Agent，每个 Agent 只做一件事，
> 整体可以组合成更强大的能力。这让我第一次体会到 AI Workflow 的设计哲学。

### 验收标准
- ✅ 5 张截图，自动发现 2 个共同主题
- ✅ ResearchAgent 能展开市场分析
- ✅ ClusterAgent 定时任务正常运行

---

## V3：Agent 调用 N 个工具（Tool Use）

### ⏱️ 时长：3-4 周

### 触发场景
V2 的 `ResearchAgent` 只是多次 LLM 调用，内容仍然是「凭空推断」。

用户反馈：调研内容质量参差不齐。

**发现**：Agent 需要能主动检索外部信息，而不只是推理。

### 产品功能（新增）
- ✅ 调研结果引用真实数据（竞品数据、市场规模）
- ✅ 社媒链接解析（粘贴链接 → 自动抓取标题/摘要/正文）
- ✅ 知识库 Markdown 导出

### AI 能力 — Agent + Tool Use
`ResearchAgent` 配备 N 个工具：

```
web_search(query)              → 搜索竞品/市场信息
fetch_url(url)                 → 抓取社媒链接内容
read_knowledge_base()          → 读取本地已有知识
write_to_knowledge_base(...)   → 写入调研结论
generate_md_report()           → 导出 Markdown 报告
```

### 架构流程
```
用户触发「深度调研」
    ↓
ResearchAgent
    ├── web_search("小红书笔记管理 竞品")
    ├── fetch_url(用户粘贴的链接)
    ├── read_knowledge_base()
    └── 生成结构化调研报告 → write_to_knowledge_base()
```

### 求职叙事
> 这一步是质变。我理解到 LLM 真正的能力扩展不是靠更大的模型，
> 而是靠给 Agent 配备合适的工具——让它能主动获取信息、读写存储、与外部交互。
> 这时我开始真正理解 ReAct 的论文为什么重要：Reasoning + Acting 的循环才是 Agent 的本质。

### 验收标准
- ✅ 一个灵感，Agent 自动调研出含外部数据的报告
- ✅ 社媒链接能正确解析
- ✅ Markdown 报告格式规范

---

## V4：Agent + Harness（Claude Agent SDK 集成）

### ⏱️ 时长：4-6 周

### 触发场景
- V3 系统的 Agent 越来越多，需要统一管理
- 需要 Agent 之间互相调用
- 需要持久化 Agent 状态（跨 session 记忆）
- 对应「Claude Code 本身的记忆系统」的思想

### 产品功能（新增）
- ✅ **知识库自动演化**：Agent 会主动更新知识图谱，无需人工干预
- ✅ **记忆分层系统**（参考 Karpathy）：
  - Hot：近期灵感（7天）
  - Warm：近期主题（30天）
  - Cold：年度知识图谱
- ✅ **Agent 间通信**：ClusterAgent 发现新主题后，通知 ResearchAgent 展开深度分析

### AI 能力 — Claude Agent SDK / Multi-Agent Harness
```
用 SDK 定义 Agent 角色和工具
Agent 间通过 handoff 机制传递任务
持久化 session 状态（MD 文件驱动的记忆系统）
```

### 架构流程
```
Harness（任务调度器）
    ├── InboxAgent（监听新增截图）
    ├── ClassifyAgent
    ├── ClusterAgent（定时）
    │       └── 发现新主题 → 触发 ResearchAgent
    └── ResearchAgent（工具集：web_search, fetch_url, read/write KB）

记忆层：
    hot/     → 近期截图元数据（SQLite）
    warm/    → 近期主题 MD 文件
    cold/    → 年度 index.md（定时重建）
```

### 求职叙事
> V4 是整个项目的高光时刻。我用 Claude Agent SDK 搭建了一个真正自主运行的知识演化系统。
> 这时候我对 Karpathy 在 LLM OS 里讲的「记忆分层」有了具身理解——
> 不是读论文，是真的在产品里实现了。

### 验收标准
- ✅ 48 小时内，新截图入库 → 知识图谱自动更新，无需人工触发
- ✅ Agent 间通信正常
- ✅ 记忆分层系统运行稳定

---

## ⏰ 完整时间线

| 阶段 | 时长 | 里程碑 |
|------|------|--------|
| 调研 + PRD | 2周 | 调研报告 + MVP 功能清单 |
| V1 开发 | 3-4周 | 可运行的基础 App（快捷指令 + OCR + 单次 LLM） |
| V1 内测 | 2周 | 5个用户内测，收集问题 |
| V2 开发 | 3-4周 | Agent Workflow + 热力图 |
| V3 开发 | 3-4周 | Tool Use + 调研功能 |
| V4 开发 | 4-6周 | Agent SDK + 记忆分层系统 |
| **总计** | **~5个月** | **完整产品 + 求职故事** |

---

## 🛠️ 技术栈

### iOS 端
- **开发框架**：SwiftUI（现代 iOS UI）
- **数据库**：Core Data / SQLite
- **异步处理**：Swift Concurrency
- **图片识别**：Vision Framework（OCR）
- **语音处理**：Speech Framework
- **文本分析**：NaturalLanguage

### 本地模型
- **框架**：Core ML
- **LLM 候选**：
  - Llama 2（7B-13B）
  - Mistral（轻量级）
  - Phi（Microsoft，2-7B，Mobile 友好）

### 后端/编排
- **版本 1-3**：Python / Node.js（Agent 编排）
- **版本 4**：Claude Agent SDK

---

## 📌 关键约束

- ✅ **隐私优先**：所有数据本地化存储，不上云
- ✅ **本地模型**：解决隐私顾虑（相册数据不出本机）
- ✅ **先不做 RAG**：优先把基础功能做好，不过度工程化
- ✅ **记忆分层驱动**：以 MD 文件 + 定时索引为核心，不是数据库驱动

---

## 🎯 核心价值

这个项目的迭代之路本身就是**求职故事**：

1. **V1**：展示「会用 API」的能力
2. **V2**：展示「理解 Agent 编排」的深度
3. **V3**：展示「Tool Use 赋能」的创新
4. **V4**：展示「系统架构」的复杂度

每个版本都有真实的产品驱动，不是为了学技术而学技术。

---

## 📋 当前任务清单

### 阶段 0：用户调研 + PRD
- [ ] Task #2：深度访谈 5-10 个目标用户
- [ ] Task #3：竞品体验分析
- [ ] Task #4：撰写 PRD 文档

### 阶段 1：V1 开发 + 内测
- [ ] Task #5：快捷指令 + 截图导入
- [ ] Task #6：单次 LLM API + 摘要标签
- [ ] Task #7：搜索 + 可视化热力图
- [ ] Task #8：V1 内测反馈与迭代

### 阶段 2：V2 开发
- [ ] Task #9：Agent 编排架构
- [ ] Task #10：多 Agent 系统实现

### 阶段 3：V3 开发
- [ ] Task #11：Tool Use 框架 + 灵感深度调研

### 阶段 4：V4 开发
- [ ] Task #12：Claude Agent SDK 集成 + 记忆分层

---

**项目状态**：规划完成 ✅ | 等待启动用户调研 ⏳
