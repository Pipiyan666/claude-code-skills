# Karpathy LLM Knowledge Base 深度调研报告

> 调研时间：2026-04-12
> 调研目的：为灵感胶囊 iOS App 寻找可复用的架构模式和技术方案
> 调研范围：Karpathy 原始推文/Gist + 四个开源项目

---

## 1. Karpathy 原始思想精华

### 1.1 核心推文内容

Karpathy 于 2026 年 4 月初发布了一条关于 "LLM Knowledge Bases" 的推文（16M+ 阅读，Gist 5000+ star），核心观点：

> "Something I'm finding very useful recently: using LLMs to build personal knowledge bases for various topics of research interest. A large fraction of my recent token throughput is going less into manipulating code, and more into manipulating knowledge (stored as markdown and images)."

> "The LLM writes and maintains all of the data of the wiki. I rarely touch it directly."

### 1.2 三层架构（Raw / Wiki / Schema）

| 层 | 内容 | 特性 |
|---|------|------|
| **Raw Sources** | 文章、论文、代码库、数据集、图片 | 不可变，LLM 只读不写 |
| **The Wiki** | LLM 生成的 markdown 文件集合 | LLM 全权维护：摘要、实体页、概念页、交叉引用 |
| **The Schema** | CLAUDE.md 配置文件 | 定义 wiki 结构、命名规范、工作流 |

### 1.3 三个核心操作（Ingest / Query / Lint）

| 操作 | 做什么 | 关键细节 |
|------|--------|---------|
| **Ingest** | 处理新源文件，更新 wiki | 每次处理更新 10-15 个相关页面，维护交叉引用，追加到 log.md |
| **Query** | 搜索 wiki 回答问题 | 不从原始文档重新发现知识，而是读已编译的 wiki 页；好的答案可归档回 wiki |
| **Lint** | 健康检查 | 查找矛盾、过时声明、孤立页面、缺失概念、缺少交叉引用 |

### 1.4 关键数据点

- 个人 wiki 规模：约 **100 篇文章、40 万字**
- 实测：3 本商业书（15.5 万字）→ 生成 **210 个概念页 + 4600+ 交叉引用**
- 甜点：个人/团队知识库 100-200 篇源文档以内
- 在此规模下 **不需要 RAG / 向量数据库**，index.md + LLM 上下文窗口足够

### 1.5 核心洞察（对灵感胶囊的启示）

1. **LLM 是编译器，不是搜索引擎** — 把原始内容编译成结构化的 wiki，而非每次查询都重新处理
2. **查询结果反哺系统** — 好的分析、比较、发现可以归档为新 wiki 页面，知识持续复利
3. **Markdown 是最优格式** — LLM 最友好、用户可读、迁移零成本
4. **健康检查是必需的** — 知识库需要定期 lint，就像代码需要 linter
5. **令人苦恼的不是阅读和思考，而是簿记** — LLM 擅长的恰好是人类不擅长的交叉引用维护

### 1.6 目录结构（Karpathy 原版）

```
my-research/
├── raw/                    # 不可变源文件
│   ├── articles/
│   ├── papers/
│   ├── repos/
│   ├── data/
│   └── images/
├── wiki/                   # LLM 生成的 markdown
│   ├── index.md            # 内容目录
│   ├── log.md              # 仅追加的操作日志
│   ├── overview.md
│   ├── concepts/
│   ├── entities/
│   ├── sources/
│   └── comparisons/
├── outputs/                # 报告、PPT、图表
├── CLAUDE.md               # Schema 配置
└── .gitignore
```

---

## 2. 四个开源项目架构对比

### 2.1 对比总表

| 维度 | toolboxmd/karpathy-wiki | safishamsi/graphify | karpathy/autoresearch | forrestchang/andrej-karpathy-skills |
|------|------------------------|--------------------|-----------------------|-------------------------------------|
| **定位** | Claude Code 技能插件 | 知识图谱生成器 | 自主 ML 研究 | Claude Code 编码准则 |
| **核心思想** | 三层 wiki + 三操作 | AST + 语义图 + 社区检测 | Idea File（program.md） | 四原则编码纪律 |
| **存储** | Markdown wiki | NetworkX graph.json | train.py + program.md | CLAUDE.md |
| **LLM 角色** | 研究图书管理员 | 语义提取 subagent | 自主实验 agent | 编码行为约束 |
| **多模态** | 否 | 是（20+ 语言 + 视频/音频/图片） | 否 | 否 |
| **可视化** | 无 | vis.js 交互式 HTML 图 | Jupyter | 无 |
| **Claude 集成** | 原生 skill 插件 | 跨平台（Claude/GPT-4/Codex） | 任意 agent | 原生 CLAUDE.md |
| **GitHub 星数** | 新项目 | 活跃 | Karpathy 官方 | 14.3k |
| **对灵感胶囊价值** | ⭐⭐⭐⭐⭐ 架构直接复用 | ⭐⭐⭐⭐ 图谱可视化方案 | ⭐⭐⭐ Idea File 模式 | ⭐⭐ 编码纪律参考 |

### 2.2 各项目核心架构详解

#### toolboxmd/karpathy-wiki

两个独立 skill：
- **karpathy-wiki**：通用研究 wiki（raw/ → wiki）
- **karpathy-project-wiki**：代码库活文档（随代码变化自动更新）

关键特性：
- **hooks.json**：Stop hook（每次任务后检查）+ SessionStart hook（检测文档漂移）
- **自动触发**：添加源文件 → 自动 ingest；问综合问题 → 自动 query；请求健康检查 → 自动 lint
- **Schema 驱动**：SKILL.md 定义所有约定，确保跨 session 一致性

#### safishamsi/graphify

三遍处理架构：
1. **Pass 1（确定性 AST）**：tree-sitter 提取代码结构（类、函数、导入、调用图）
2. **Pass 2（本地转录）**：faster-whisper 转录视频/音频
3. **Pass 3（语义提取）**：Claude subagent 并行提取概念和关系

关键特性：
- **Leiden 社区检测**：基于图拓扑聚类，不依赖 embedding
- **置信度标签**：EXTRACTED（直接）/ INFERRED（推断）/ AMBIGUOUS（待确认）
- **71.5x token 节省**：查询 graph.json 而非重读源文件
- **多格式输出**：HTML 图 / SVG / GraphML / Cypher / Obsidian vault / MCP server
- **Wiki 导出**：`--wiki` flag 按社区生成维基百科风格文章

#### karpathy/autoresearch

- **program.md 模式**：用 Markdown 编程 AI agent 的行为（而非直接写 Python）
- **5 分钟实验预算**：固定时间框，每小时约 12 次实验
- **自主迭代**：agent 修改 → 训练 → 评估 → 接受/拒绝，overnight 跑 ~100 实验
- 对灵感胶囊的启示：用户的 "灵感" 就是 "idea file"，AI 自主探索和扩展

#### forrestchang/andrej-karpathy-skills

四原则：
1. **Think Before Coding** — 有歧义时先问，不猜
2. **Simplicity First** — 200 行能变 50 行就重写
3. **Surgical Changes** — 只改需要改的
4. **Goal-Driven Execution** — 声明目标 + 验证循环

---

## 3. 灵感胶囊可直接复用的 10 个具体方案

### 方案 1：三层存储映射（Karpathy → 灵感胶囊）

**是什么**：将 Karpathy 的 raw/wiki/schema 三层直接映射到灵感胶囊的存储架构。

**怎么映射**：

| Karpathy 层 | 灵感胶囊层 | 存储路径 | 内容 |
|-------------|-----------|---------|------|
| raw/ | inbox/ | ~/Library/IdeaCapsule/inbox/ | 截图 OCR 文本、粘贴内容、语音转录 |
| wiki/ (entity/concept) | processed/ + wiki/ | .../processed/ + .../wiki/ | AI 加工的灵感 + AI 编译的主题文章 |
| schema (CLAUDE.md) | App 内配置 | Bundle + UserDefaults | wiki 结构规范、标签体系、处理规则 |
| index.md | index.md | .../index.md | 全局索引，ClusterAgent 每日重建 |
| log.md | log.md | .../log.md | 仅追加操作日志 |

**对应版本**：V1 基础存储 → V5 iOS 原生实现

---

### 方案 2：Ingest/Query/Lint 三操作对应 V1-V4

**是什么**：Karpathy 的三个核心操作直接映射到灵感胶囊的版本迭代。

| Karpathy 操作 | 灵感胶囊版本 | 实现方式 |
|--------------|-------------|---------|
| **Ingest** | V1（单次 LLM）+ V2（多 Agent Workflow） | 截图 → OCR → 摘要/标签/关键词 → 更新相关 wiki 页 |
| **Query** | V3（Agent + Tool Use） | 用户提问 → ResearchAgent 搜索 wiki → 综合回答 → 好答案归档 |
| **Lint** | V4（Multi-Agent Harness） | LibrarianAgent 定期扫描 → 发现矛盾/孤立/缺失 → 自主修复 |

**怎么用**：V5 iOS 版本保留这三个操作作为核心 Agent 行为，通过 Apple Foundation Models 本地执行 Ingest 和简单 Query，云端 Claude 处理复杂 Query 和 Lint。

---

### 方案 3：查询结果反哺系统（Query-to-Wiki Feedback Loop）

**是什么**：用户的每次 AI 查询，好的答案可以自动或手动归档为新 wiki 页面。

**怎么用**：
1. 用户问 "我收藏的穿搭笔记有什么共同趋势？"
2. AI 综合 5 条相关灵感，生成趋势分析
3. 底部显示 "保存为知识卡片" 按钮
4. 点击后归档到 wiki/topics/2026秋冬穿搭趋势.md，自动建立反向链接

**对应版本**：V3（Query）→ V5 iOS 原生

---

### 方案 4：知识图谱可视化（借鉴 Graphify）

**是什么**：用 Graphify 的图拓扑聚类思路，在 iOS 上用 SwiftUI Canvas 渲染知识图谱。

**技术方案**：

```swift
// 核心数据结构
struct KnowledgeNode: Identifiable {
    let id: String
    let title: String
    let type: NodeType  // .inbox / .processed / .wiki / .person / .topic
    let connections: [String]  // 链接的其他节点 ID
    let community: Int  // Leiden 社区编号（用于着色）
}

// SwiftUI Canvas 渲染
struct KnowledgeGraphView: View {
    @State private var nodes: [KnowledgeNode]
    @State private var selectedNode: KnowledgeNode?
    
    var body: some View {
        Canvas { context, size in
            // 力导向布局（ForceDirectedLayout）
            for node in nodes {
                let position = layoutEngine.position(for: node)
                // 按 community 着色
                let color = communityColor(node.community)
                context.fill(Circle().path(in: CGRect(...)), with: .color(color))
            }
            // 绘制连接线
            for edge in edges {
                context.stroke(Path { path in
                    path.move(to: edge.from)
                    path.addLine(to: edge.to)
                }, with: .color(.gray.opacity(0.3)))
            }
        }
        .gesture(MagnifyGesture().onChanged { ... })  // 缩放
        .gesture(DragGesture().onChanged { ... })      // 拖拽
    }
}
```

**简化版 vs Graphify 完整版**：

| Graphify | 灵感胶囊 iOS 版 |
|----------|----------------|
| NetworkX + Leiden | 轻量 Swift 图算法（无需 Python） |
| vis.js HTML | SwiftUI Canvas（原生流畅） |
| 20+ 语言 AST | 仅 Markdown 解析（[[link]] 提取） |
| graph.json | .meta.sqlite + 内存图 |
| 并行 Claude subagent | Apple FM 3B 本地提取 |

**对应版本**：V5 iOS 原生

---

### 方案 5：Schema 驱动的 Wiki 规范（借鉴 karpathy-wiki）

**是什么**：用一个配置文件定义 wiki 的所有约定（命名、结构、标签体系），AI agent 严格遵循。

**怎么用**：在 App Bundle 中预置 wiki-schema.json：

```json
{
  "storage": {
    "base_path": "~/Library/IdeaCapsule/",
    "layers": ["inbox", "processed", "wiki"],
    "retention": { "inbox": "7d", "processed": "30d", "wiki": "forever" }
  },
  "frontmatter": {
    "required": ["id", "created", "source", "tags"],
    "optional": ["category", "keywords", "links", "processed_by"]
  },
  "wiki_structure": {
    "directories": ["topics", "people", "sources", "comparisons"],
    "special_files": ["index.md", "log.md", "overview.md"]
  },
  "operations": {
    "ingest": { "max_related_pages_update": 15 },
    "lint": { "schedule": "daily", "checks": ["orphans", "contradictions", "stale"] }
  }
}
```

**对应版本**：V1 存储层 → 所有后续版本

---

### 方案 6：漂移检测 Hook（借鉴 karpathy-wiki 的 SessionStart Hook）

**是什么**：每次 App 启动时检测 wiki 是否与最新灵感脱节。

**怎么用**：
1. App 冷启动 → 检查 inbox/ 中未处理的灵感数量
2. 如果 > 5 条未处理 → 提示 "有 N 条新灵感待整理"
3. 如果 wiki/index.md 超过 3 天未更新 → 自动触发 Lint 操作
4. 如果 processed/ 中灵感引用了不存在的 wiki 页 → 标记为 "建议创建"

**对应版本**：V4 Harness 的 LibrarianAgent → V5 iOS 后台任务

---

### 方案 7：Idea File 模式（借鉴 autoresearch 的 program.md）

**是什么**：用户的每条灵感都是一个 "Idea File"，AI 可以自主扩展和研究。

**怎么用**：
1. 用户粘贴一条灵感："看到一个用 AI 清理相册的 App，好像很有潜力"
2. AI 不仅生成摘要和标签，还自主判断是否需要深入研究
3. 如果判断需要 → 启动 ResearchAgent，搜索相关产品、市场数据
4. 生成一份简短调研报告，归档到 wiki/sources/

这就是 autoresearch 的 "program.md → 自主迭代" 在灵感管理场景的映射。

**对应版本**：V3 ResearchAgent → V5 iOS

---

### 方案 8：置信度标签系统（借鉴 Graphify）

**是什么**：对 AI 生成的关系和洞察标注置信度等级。

**怎么用**：

```markdown
## AI 洞察
- 🟢 EXTRACTED: 原文明确提到"焦糖色是今年秋冬主色调"
- 🟡 INFERRED: 根据 3 条相关灵感推断"你对暖色系穿搭感兴趣"（置信度 0.78）
- 🔴 AMBIGUOUS: 不确定这条笔记是关于"个人穿搭"还是"穿搭内容创作"
```

用户可以一键确认或修正 AMBIGUOUS 标签，反馈用于改进后续分析。

**对应版本**：V2 ClassifyAgent → V5 iOS

---

### 方案 9：仅追加日志（log.md）

**是什么**：所有 AI 操作记录在一个仅追加的日志文件中，用户可随时审查 AI 做了什么。

**怎么用**：

```markdown
# 操作日志

## 2026-04-12

### 14:30 | INGEST | apple-fm-3b
- 处理了截图 "秋冬穿搭色彩"
- 生成摘要 + 3 个标签
- 更新了 wiki/topics/穿搭与色彩心理学.md（新增段落）
- 更新了 index.md

### 22:00 | LINT | apple-fm-3b
- 扫描 23 条灵感 + 5 篇 wiki
- 发现 1 个孤立页面（wiki/topics/深度工作方法论.md 无引用）
- 建议：关联到 processed/2026-04-10-1430.md
```

这解决了用户对 "AI 到底在后台做了什么" 的信任焦虑。

**对应版本**：V1 基础功能 → 所有版本

---

### 方案 10：Claude Agent SDK preset:claude_code 集成

**是什么**：V5 iOS 版的云端 Agent 调用使用 Claude Agent SDK 的 preset:claude_code 模式。

**集成方案**：

```
┌─────────────────────────────────────────┐
│           iOS App (SwiftUI)              │
│                                         │
│  本地路径（默认）     云端路径（可选）      │
│  Apple FM 3B        Claude Agent SDK    │
│  ├─ Ingest          ├─ Deep Research    │
│  ├─ Simple Query    ├─ Complex Query    │
│  └─ Classify        └─ Lint            │
│                                         │
│  统一接口：IdeaCapsuleLLM protocol      │
└─────────────────────────────────────────┘
           │ 云端调用时 │
           ▼
┌─────────────────────────────────────────┐
│     后端 API（轻量 Python/Node）         │
│                                         │
│  from agents import Agent               │
│                                         │
│  research_agent = Agent(                │
│      name="ResearchAgent",              │
│      model="claude-sonnet-4-20250514",  │
│      instructions="""                   │
│        你是灵感胶囊的深度调研助手。       │
│        用户的知识库结构：inbox/processed/ │
│        wiki/。搜索 wiki 回答问题，        │
│        好的发现归档为新 wiki 页面。       │
│      """,                               │
│      tools=[                            │
│          read_wiki,      # 读 wiki 页面 │
│          write_wiki,     # 写/更新 wiki │
│          web_search,     # 网络搜索     │
│          fetch_url,      # 抓取网页     │
│      ]                                  │
│  )                                      │
└─────────────────────────────────────────┘
```

**关键设计决策**：
- 本地 Agent（Apple FM 3B）处理 80%+ 的日常操作（Ingest、简单 Query、Classify）
- 云端 Agent（Claude SDK）仅在用户明确请求"深度调研"或系统触发"每周 Lint"时启用
- 用户数据**不上传到云端** — 云端 Agent 收到的是已脱敏的摘要和查询，不是原始截图

**对应版本**：V4 Harness（Python 原型）→ V5 iOS + 后端 API

---

## 4. 知识库存储层最终设计建议

### 推荐架构

```
~/Library/IdeaCapsule/
├── inbox/                          # Hot（7 天）→ 对应 Karpathy raw/
│   └── YYYY-MM-DD/
│       └── HHMM-{标题缩写}.md     # OCR 原文 + 元数据
│
├── processed/                      # Warm（30 天）→ 对应 Karpathy wiki/ 的源摘要
│   └── YYYY-MM-DD-HHMM.md         # frontmatter + 摘要 + 标签 + AI 洞察
│
├── wiki/                           # Cold（永久）→ 对应 Karpathy wiki/ 的概念文章
│   ├── topics/                     # 主题聚类文章
│   ├── people/                     # 提及的人物/博主
│   ├── sources/                    # 调研报告
│   └── comparisons/                # 比较分析（Query 结果归档）
│
├── index.md                        # 全局索引（每日重建）
├── log.md                          # 仅追加操作日志
├── overview.md                     # 知识库总览（Lint 时更新）
├── .meta.sqlite                    # 查询加速索引（可重建）
└── .schema.json                    # Wiki 结构规范
```

### 与 Karpathy 原版的关键差异

| 维度 | Karpathy 原版 | 灵感胶囊适配 | 理由 |
|------|-------------|------------|------|
| 源文件格式 | 文章/论文/代码 | 截图 OCR + 社媒链接 | 目标用户不写论文 |
| 处理触发 | 手动 "ingest this" | 自动（截图入库即处理） | 18-35 岁用户不会手动触发 |
| Lint 频率 | 手动 "lint the wiki" | 自动（每日后台、App 启动时） | 用户不知道什么是 lint |
| 编辑器 | Obsidian / VS Code | SwiftUI 原生界面 | 用户不用桌面编辑器 |
| 可视化 | 无 | 知识图谱 Canvas | 核心差异化特性 |
| 隐私 | 个人电脑 | 手机本地 + 可选云端 | 隐私是核心承诺 |

---

## 5. 知识图谱可视化技术方案（SwiftUI Canvas）

### 5.1 技术选型

| 方案 | 优点 | 缺点 | 推荐度 |
|------|------|------|--------|
| **SwiftUI Canvas** | 原生性能、手势集成好 | 需手写力导向布局 | ⭐⭐⭐⭐⭐ |
| SceneKit 3D | 视觉震撼 | 过于复杂、耗电 | ⭐⭐ |
| WebView + vis.js | 成熟的图可视化 | 非原生、内存开销大 | ⭐⭐⭐ |
| SpriteKit | 物理引擎内置 | 游戏框架，偏重 | ⭐⭐⭐ |

### 5.2 推荐实现：SwiftUI Canvas + 力导向布局

**核心算法**：简化版 Force-Directed Layout（Barnes-Hut 优化）

```swift
class ForceDirectedLayout: ObservableObject {
    @Published var positions: [String: CGPoint] = [:]
    
    // 三种力
    func tick() {
        applyRepulsion()      // 节点间斥力（库仑力）
        applyAttraction()     // 连接边的引力（弹簧力）
        applyCentering()      // 整体居中力
        applyDamping(0.95)    // 阻尼衰减
    }
}
```

**社区检测**（简化版 Leiden → 适合 iOS）：
- 不使用 Graphify 的完整 Leiden 算法（太重）
- 使用 **标签传播算法**（Label Propagation）：O(n) 复杂度，适合手机
- 输入：[[link]] 双向链接构成的邻接表
- 输出：每个节点的社区编号 → 用于着色

**交互设计**：
- 双指缩放 → MagnifyGesture
- 单指拖拽 → DragGesture  
- 点击节点 → 弹出灵感卡片预览
- 长按节点 → 显示所有连接路径
- 社区着色 → 同一主题的灵感自动聚在一起

### 5.3 性能预估

| 节点数 | 帧率（iPhone 15） | 可行性 |
|--------|-----------------|--------|
| < 100 | 60 FPS | 完全流畅 |
| 100-500 | 30-60 FPS | 可用 |
| 500-1000 | 需要 LOD 优化 | 需简化远处节点 |
| > 1000 | 建议分页或子图 | 不在 V5 范围 |

灵感胶囊目标用户的典型知识库规模：50-300 条灵感 → **完全在 Canvas 性能范围内**。

---

## 6. 与 Claude Agent SDK preset:claude_code 的集成方案

### 6.1 当前状态（V4 Python 原型）

灵感胶囊 V4 已在 Python 中实现了完整的 Multi-Agent Harness：
- `harness.py`：事件驱动的 agent 编排
- `librarian.py`：LibrarianAgent 自主生成 wiki 报告
- `events.py`：事件总线

### 6.2 V5 iOS 版集成路径

```
                    ┌──────────────┐
                    │   iOS App    │
                    │  (SwiftUI)   │
                    └──────┬───────┘
                           │
              ┌────────────┴────────────┐
              │                         │
       本地 Agent 层              云端 Agent 层
    (Apple FM 3B)           (Claude Agent SDK)
              │                         │
    ┌─────────┤                ┌────────┤
    │         │                │        │
  Ingest   Classify      Research   Librarian
  Agent     Agent         Agent      Agent
    │         │                │        │
    └─────────┤                └────────┤
              │                         │
              └────────────┬────────────┘
                           │
                    ┌──────┴───────┐
                    │ Markdown KB  │
                    │  (本地存储)   │
                    └──────────────┘
```

### 6.3 后端 Agent 服务设计

```python
# 后端 API 接口示例（FastAPI + Claude Agent SDK）
from agents import Agent, Runner

# 深度调研 Agent
research_agent = Agent(
    name="IdeaCapsule-Research",
    model="claude-sonnet-4-20250514",
    instructions="""你是灵感胶囊的深度调研助手。
    用户会发送一条灵感的摘要，你需要：
    1. 搜索相关信息（市场、竞品、趋势）
    2. 生成一份 200 字以内的调研报告
    3. 输出 markdown 格式，包含标题、要点、来源链接
    注意：不要请求任何用户个人信息。""",
    tools=[web_search, fetch_url]
)

# 知识库管理 Agent（Lint 操作）
librarian_agent = Agent(
    name="IdeaCapsule-Librarian",
    model="claude-haiku-4-20250514",
    instructions="""你是灵感胶囊的知识库管理员。
    你会收到 wiki 的 index.md 和部分页面内容。
    执行健康检查：
    1. 找出孤立页面（无引用）
    2. 找出缺失的概念页（被多次提到但没有专页）
    3. 找出过时信息
    4. 输出修改建议列表""",
    tools=[read_wiki, suggest_edits]
)

@app.post("/api/research")
async def deep_research(request: ResearchRequest):
    result = await Runner.run(research_agent, request.summary)
    return {"report": result.final_output}

@app.post("/api/lint")
async def lint_wiki(request: LintRequest):
    result = await Runner.run(librarian_agent, request.wiki_index)
    return {"suggestions": result.final_output}
```

### 6.4 数据流保护

```
用户截图 → [本地 OCR + 摘要] → 仅摘要上传 → 云端 Agent 处理 → 结果下载 → 本地归档
                ↑                                                         ↓
          原始截图永远                                              调研报告存入
          不离开手机                                              wiki/sources/
```

**隐私保证**：云端 Agent 只收到 AI 生成的摘要（50 字），不是原始截图或 OCR 全文。

---

## 7. 关键结论和下一步建议

### 7.1 核心结论

1. **Karpathy 的三层架构（raw/wiki/schema）与灵感胶囊的三层存储（inbox/processed/wiki）天然对齐**，只需微调命名和触发机制
2. **不需要 RAG** — 在个人知识库规模（< 500 条）下，markdown + index.md + 上下文窗口完全足够
3. **Graphify 的知识图谱方案可以大幅简化后移植到 iOS** — 用标签传播替代 Leiden，用 SwiftUI Canvas 替代 vis.js
4. **karpathy-wiki 的 Hook 机制是实现"无感维护"的关键** — 用户不需要手动触发 ingest/lint，App 后台自动完成
5. **Claude Agent SDK 作为云端增强层，而非核心依赖** — 80% 操作走本地 Apple FM，保持隐私承诺

### 7.2 建议的 V5 实现优先级

| 优先级 | 功能 | 来源 | 预估工作量 |
|--------|------|------|-----------|
| P0 | 三层 Markdown 存储 + frontmatter | Karpathy wiki | 1 周 |
| P0 | 本地 Ingest（OCR → 摘要 → 标签） | Karpathy Ingest + Apple FM | 2 周 |
| P1 | index.md 自动重建 | Karpathy wiki | 3 天 |
| P1 | log.md 操作日志 | Karpathy wiki | 2 天 |
| P1 | 漂移检测（启动时检查） | karpathy-wiki hooks | 3 天 |
| P2 | 知识图谱可视化 | Graphify + SwiftUI Canvas | 2 周 |
| P2 | 查询结果反哺系统 | Karpathy Query | 1 周 |
| P3 | 云端深度调研 | Claude Agent SDK | 2 周 |
| P3 | 自动 Lint | Karpathy Lint | 1 周 |
| P3 | 置信度标签 | Graphify | 3 天 |

---

## 参考来源

- [Karpathy LLM Knowledge Bases 推文](https://x.com/karpathy/status/2039805659525644595)
- [Karpathy LLM Wiki Gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
- [toolboxmd/karpathy-wiki](https://github.com/toolboxmd/karpathy-wiki)
- [safishamsi/graphify](https://github.com/safishamsi/graphify)
- [karpathy/autoresearch](https://github.com/karpathy/autoresearch)
- [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills)
- [VentureBeat: Karpathy LLM Knowledge Base Architecture](https://venturebeat.com/data/karpathy-shares-llm-knowledge-base-architecture-that-bypasses-rag-with-an)
- [MindStudio: How to Build Karpathy's LLM Wiki](https://www.mindstudio.ai/blog/andrej-karpathy-llm-wiki-knowledge-base-claude-code)
- [DAIR.AI: LLM Knowledge Bases](https://academy.dair.ai/blog/llm-knowledge-bases-karpathy)
- [Starmorph: Complete Guide to AI-Maintained Knowledge Bases](https://blog.starmorph.com/blog/karpathy-llm-wiki-knowledge-base-guide)
