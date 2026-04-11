# 灵感胶囊 · iOS 技术架构（生产版 V5）

> 这份文档**取代** TECH_ARCHITECTURE.md 之前的 V1-V4 设计。
> 之前的设计是 Python web 端为概念验证；这一份是真正的 iOS 生产级架构。
>
> **核心修正**：技术架构必须是「不复杂、生产级、iPhone 上跑得丝滑」。
> 用户的最终目标是 iOS 真实产品，不是 web。

---

## 0. 三个不可妥协的原则

| 原则 | 含义 |
|------|------|
| **iOS 优先** | 用户用的是 iPhone，不是 Mac。所有架构决策围绕 iPhone 体验 |
| **不复杂** | 全部用 Apple 原生 API，零第三方 SDK，零自建服务器 |
| **隐私 = 100% 本地** | 数据永远不离开用户的 iPhone |

这三条不是「最好这样」，是「不这样就不要做」。

---

## 1. 架构图（一张图看懂）

```
┌─────────────────────────────────────────────────────────────┐
│                  iPhone (iOS 26+)                            │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  UI 层 (SwiftUI + iOS 26 Liquid Glass)               │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────────────┐    │   │
│  │  │ 捕获 Tab │  │ 知识库   │  │ 智能洞察 Tab     │    │   │
│  │  │ Capture  │  │ List     │  │ Insights         │    │   │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────────────┘    │   │
│  └───────┼─────────────┼─────────────┼──────────────────┘   │
│          │             │             │                       │
│          ▼             ▼             ▼                       │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  ViewModel 层 (@Observable)                          │   │
│  │  CaptureViewModel / ListViewModel / InsightsVM       │   │
│  └───────┬──────────────────────────────────────────────┘   │
│          │                                                    │
│          ▼                                                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Service 层 (actor — Swift 6.2 严格并发)             │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────┐ │   │
│  │  │OCRService│ │AIService │ │PhotoMon  │ │Capsule  │ │   │
│  │  │ Vision   │ │FoundatM. │ │PhotoKit  │ │ Store   │ │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └─────────┘ │   │
│  └───────┬──────────────────────────────────────────────┘   │
│          │                                                    │
│          ▼                                                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  数据层 (本地)                                        │   │
│  │  ┌────────────┐ ┌─────────────┐ ┌────────────────┐  │   │
│  │  │ SwiftData  │ │ PhotoKit    │ │ Markdown 导出  │  │   │
│  │  │ (SQLite)   │ │ (引用相册)  │ │ (用户 Files)   │  │   │
│  │  └────────────┘ └─────────────┘ └────────────────┘  │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  整个 App: 不发任何网络请求 (除了 V1.1 社媒链接抓取)          │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. 4 个核心 Apple 框架

### 2.1 Vision Framework — 本地 OCR

```swift
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.recognitionLanguages = ["zh-Hans", "en-US"]
request.usesLanguageCorrection = true
```

**为什么够用**：
- iOS 18 起 Vision OCR 准确度大幅提升
- 中文识别接近 99%
- 完全 on-device，0 延迟
- 免费、不限调用次数

**对比智谱 GLM-4V**：Vision 是 Apple 自家硬件加速，**比云端 OCR 快 10 倍以上**。

### 2.2 FoundationModels — 本地 LLM

```swift
import FoundationModels

let session = LanguageModelSession(instructions: "...")
let response = try await session.respond(
    to: rawText,
    generating: InsightAnalysis.self  // ← @Generable 类型
)
```

**关键创新**：`@Generable` 让模型直接生成 Swift 类型，**不用解析 JSON**。

```swift
@Generable(description: "灵感分析结果")
struct InsightAnalysis {
    @Guide(description: "30-50 字摘要")
    var summary: String

    @Guide(description: "分类", .anyOf(["社媒灵感", "学习笔记", ...]))
    var category: String

    @Guide(description: "3-5 个标签", .count(3...5))
    var tags: [String]
}
```

**对比 V0-V4 的智谱方案**：
| 维度 | V0-V4 (智谱 + 解析 JSON) | V5 (FoundationModels + @Generable) |
|------|--------------------------|--------------------------------------|
| 类型安全 | 运行时（解析失败会崩）| **编译时**（永远不会解析失败）|
| 网络 | 必须有网 | 完全离线 |
| 成本 | 按 token 计费 | **零成本** |
| 隐私 | 数据上云 | **数据不出设备** |
| 速度 | 1-5 秒 (HTTP 往返) | **<1 秒** (本地推理) |

**iOS 26 模型规格**：
- 约 3B 参数
- KV cache 共享，37.5% 内存优化
- 4096 token 上下文窗口
- 在 iPhone 15 Pro 及更新机型上原生支持

### 2.3 PhotoKit — 监听相册不复制

```swift
let options = PHFetchOptions()
options.predicate = NSPredicate(
    format: "(mediaSubtype & %d) != 0",
    PHAssetMediaSubtype.photoScreenshot.rawValue
)
```

**关键设计**：只存 `asset.localIdentifier`，**不复制原图**：

```swift
@Model
final class Insight {
    var imageAssetIdentifier: String?  // 引用，不是副本
}
```

**这是「不删截图，让截图为你工作」的技术兑现**：用户的相册保持原样，App 只是「在原相册之上加了一层知识索引」。

### 2.4 SwiftData — 本地持久化

```swift
@Model
final class Insight {
    @Attribute(.unique) var id: String
    var summary: String
    var rawText: String
    var category: String
    // ...
}
```

SwiftData 是 Apple 在 iOS 17+ 推出的现代替代品（取代 Core Data）。
- 自动 SQLite 后端
- 自动 iCloud 同步（如果用户开启）
- `@Query` 在 View 里自动响应数据变化

**为什么不用 markdown 文件作为主存储**：
- iOS sandbox 里读写文件较慢（vs SwiftData 的索引查询）
- SwiftData 支持复杂查询（按分类、标签、时间）
- 而 markdown 我们用作「**导出**」格式，不是主存储

V0-V4 用 markdown-as-DB 是因为是 Python 桌面环境；iOS 用 SwiftData 才是正解。

---

## 3. 性能优化（让 iPhone 上丝滑）

| 优化点 | 技术 | 效果 |
|--------|------|------|
| 大列表 | `LazyVStack` + `@Query` 增量 fetch | 1000+ 灵感无卡顿 |
| 图片加载 | PhotoKit 异步 + 缩略图 | 不阻塞主线程 |
| AI 推理 | actor 隔离 + 后台队列 | 滚动列表时也能跑 OCR |
| Glass 效果 | `GlassEffectContainer` 包裹 | morphing + 性能优化 |
| 状态更新 | `@Observable`（不是 ObservableObject）| 字段级追踪，最小重渲染 |
| 启动速度 | 延迟 PhotoKit 监听到首次需要时 | 冷启动 <500ms |

**关键原则**：
- ❌ 永远不要在 `body` 里做 I/O
- ✅ 用 `.task {}` 而不是 `init` 启动异步任务
- ✅ 用 `actor` 包裹所有 service，编译器帮你查数据竞争
- ✅ 用 `@Sendable` 封装跨 actor 边界的数据

---

## 4. 隐私 & 权限

### App Store 审核必填的权限说明

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>灵感胶囊需要读取你的相册，自动识别截图并用本地 AI 提取知识。
所有数据 100% 在你的 iPhone 上处理，绝不上传云端。</string>
```

### 用户首次启动的引导
1. 启动 → 显示「不删截图，让截图为你工作」slogan
2. 解释隐私承诺（一屏说清楚 "本地、不上云、不复制原图"）
3. 请求相册权限（带具体说明）
4. 用户拒绝 → 仍然可以手动添加灵感（degrade gracefully）

### 永远不做的事
- ❌ 不上传任何照片
- ❌ 不上传任何 OCR 文字
- ❌ 不上传任何用户行为数据
- ❌ 不需要登录账号
- ❌ 不需要联网（除了用户主动点「调研一下」时可选的 web search）

---

## 5. iOS 端 V1-V4 演进（取代 Python 版的 V1-V4）

| 版本 | 核心增量 | 时长 |
|------|---------|------|
| **V1 (4-6 周)** | 截图监听 + Vision OCR + FoundationModels 分析 + List/Detail 浏览 | MVP 上线 |
| **V2 (4-6 周)** | 多步骤 pipeline 拆 actor + 跨灵感聚类 + 用户画像 + 知识图谱可视化（SwiftUI Canvas） | 增强智能 |
| **V3 (4-6 周)** | Share Extension（小红书/抖音直接分享）+ Markdown 导出 + iOS 快捷指令 + Widget | 输入扩展 |
| **V4 (持续)** | iCloud Drive 同步（用户主动开启）+ Pro 订阅 + 社交分享增长 | 商业化 |

**注意**：iOS V1 实际上等价于 Python V0+V1+V2 的功能合集，因为 Apple 原生 API 让很多复杂度直接消失了。

---

## 6. 与 Python V0-V4 的关系

**Python V0-V4 的价值**：
1. ✅ 验证了「截图 → AI 分析 → 知识库」的核心体验
2. ✅ 验证了多 Agent 编排的工程价值（对应 iOS 的 actor 拆分）
3. ✅ 验证了 ReAct + Tool Use 的可行性（V1.1 社媒链接调研可以复用思路）
4. ✅ 让用户和评委能在 web 端**立即体验产品概念**（黑客松必需）
5. ⚠️ 不是最终产品，是**原型 + 概念验证**

**iOS V5 的角色**：
- ✅ 真正的产品形态
- ✅ 可上 App Store 的代码骨架
- ✅ 隐私承诺的技术兑现
- ✅ 求职作品集的「成品」

**两者并存**：Python V0-V4 在黑客松演示和远程评委 demo 时仍然有用（只需要浏览器），iOS V5 是给真实用户的产品。

---

## 7. Claude Agent SDK 多模型方案（V4 真相揭晓）

读了 `CLAUDE_AGENT_SDK_MULTI_MODEL.md` 后才知道：**Claude Agent SDK 可以接智谱**！只需要：

```python
import os
os.environ["ANTHROPIC_BASE_URL"] = "https://open.bigmodel.cn/api/anthropic"
os.environ["ANTHROPIC_API_KEY"] = "你的智谱 key"

# 然后用 Claude Agent SDK 的 preset:claude_code
from claude_agent_sdk import ClaudeAgentOptions, query

options = ClaudeAgentOptions(
    system_prompt={
        "type": "preset",
        "preset": "claude_code",  # 继承 24 个内置工具
        "append": LIBRARIAN_PROMPT,
    },
)
```

**这意味着 Python V4 的 LibrarianAgent 可以从「自己模拟 harness」升级为「真正用 Claude Agent SDK + 智谱后端」**。

但这是 Python 版的事情。**iOS V5 不需要 Claude Agent SDK**，因为 Apple 的 FoundationModels 已经提供了等价能力（@Generable + Tool 协议）。

---

## 8. 一句话总结

> **灵感胶囊 iOS 版 = SwiftUI + Apple FoundationModels (@Generable) + Vision Framework (OCR) + PhotoKit (引用相册) + SwiftData (持久化)**
>
> 0 个第三方依赖。0 个云端 API。100% 本地。
>
> 这是一个真正的「iPhone 上跑得丝滑、隐私零顾虑、技术架构不复杂」的生产级 App。

完整代码骨架在 `ios_app/IdeaCapsule/` 目录。打开 Xcode → 拖文件进去 → Cmd+R 运行。
