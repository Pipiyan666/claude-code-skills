# 灵感胶囊 iOS App (V5)

> 真正的 iOS 原生实现 — SwiftUI + Apple FoundationModels + Vision + PhotoKit + SwiftData

## 这是什么

V0-V4 是 Python web 端，是为黑客松和概念验证而做的。**V5 这个目录才是真正的产品形态**——一个生产级的 iOS App，符合用户的核心目标：
- ✅ iOS 优先
- ✅ 不复杂的技术架构（全部 Apple 原生 API）
- ✅ 流畅丝滑（用 actor + LazyVStack + glass effect 优化）
- ✅ 隐私优先（100% 本地，零云端）

## 技术栈

| 层 | 技术 | 角色 |
|----|------|------|
| **UI** | SwiftUI + iOS 26 Liquid Glass | 设计语言 |
| **AI 推理** | Apple FoundationModels (`@Generable`) | 本地 LLM，类型安全的结构化输出 |
| **OCR** | Vision Framework (`VNRecognizeTextRequest`) | 中英文混合识别，本地 |
| **图片来源** | PhotoKit (`PHPhotoLibrary`) | 监听相册截图，不复制原图 |
| **数据持久化** | SwiftData (`@Model`) | 本地 SQLite，自动同步 |
| **并发** | Swift 6.2 actor + structured concurrency | 线程安全 |

**完全没有云端 API**。完全没有自建服务器。

## 项目结构

```
ios_app/IdeaCapsule/
├── IdeaCapsuleApp.swift          App 入口 + SwiftData container
├── Models/
│   └── Insight.swift             @Model 数据 + @Generable 结构化输出
├── Services/
│   ├── OCRService.swift          actor: Vision OCR
│   ├── AIService.swift           actor: Apple FoundationModels
│   ├── PhotoMonitor.swift        @MainActor: PhotoKit 监听
│   └── CapsuleStore.swift        @Observable: pipeline + 持久化
├── Views/
│   ├── RootView.swift            TabView (捕获/知识库/洞察)
│   ├── CaptureView.swift         捕获页（PhotosPicker + TextEditor）
│   ├── InsightListView.swift     列表 + 搜索 + 分类筛选
│   ├── InsightDetailView.swift   详情页
│   ├── InsightsTabView.swift     智能洞察 (用户画像 + 主题)
│   └── ResultCard.swift          AI 结果卡片组件
└── Resources/
    └── Info.plist                权限说明 + iOS 26 minimum
```

## 在 Xcode 里打开运行

### 前置条件

- **Xcode 26.0+**（含 iOS 26 SDK 和 FoundationModels）
- **iOS 26+ 设备或模拟器**（需要支持 Apple Intelligence）
- **iPhone 15 Pro 或更新机型**（FoundationModels 设备要求）

### 步骤

```bash
# 1. 在 Xcode 里 File → New → Project → iOS → App
#    Product Name: IdeaCapsule
#    Interface: SwiftUI
#    Language: Swift
#    Storage: SwiftData

# 2. 把 ios_app/IdeaCapsule/ 目录里的文件拖到新项目里
#    保留文件夹结构（Models / Services / Views）

# 3. 替换 Info.plist 为我们的版本（含权限说明）

# 4. 添加 capabilities：
#    - Photo Library Access
#    - App Sandbox (auto)

# 5. Cmd+R 运行
```

## 核心技术亮点

### 1. `@Generable` 让 AI 直接生成 Swift 类型

**这是 V5 相比 V0-V4 最大的飞跃**。Python 版本要写 prompt + 解析 JSON 字符串。Swift 版本只需要：

```swift
@Generable(description: "对一条灵感的结构化分析结果")
struct InsightAnalysis {
    @Guide(description: "30-50 字总结核心")
    var summary: String

    @Guide(description: "分类", .anyOf(["社媒灵感", "会议记录", ...]))
    var category: String

    @Guide(description: "3-5 个标签", .count(3...5))
    var tags: [String]
}

// 调用就这一行：
let response = try await session.respond(to: rawText, generating: InsightAnalysis.self)
let analysis: InsightAnalysis = response.content  // 类型完全安全！
```

**没有 JSON 字符串解析。没有错误处理 prompt 输出格式。100% 编译时类型安全。**

### 2. PhotoKit 监听 — 不复制原图

```swift
// 不复制照片，只存 PhotoKit asset identifier
let insight = Insight(
    summary: ...,
    imageAssetIdentifier: asset.localIdentifier  // 引用，不是副本
)
```

用户的原相册保持原样，App 只是"建立一个知识索引"——这就是「不删截图，让截图为你工作」的技术实现。

### 3. Liquid Glass 设计语言（iOS 26）

```swift
// 输入框
TextEditor(text: $text)
    .glassEffect(.regular.tint(.blue.opacity(0.1)), in: .rect(cornerRadius: 16))

// 主按钮
Button("✨ AI 分析") { ... }
    .buttonStyle(.glassProminent)

// morphing 动画
GlassEffectContainer(spacing: 16) {
    // 多个 glass 元素会智能融合
}
```

### 4. Actor 模式保证线程安全

```swift
actor OCRService {
    func extractText(from image: UIImage) async throws -> String { ... }
}

actor AIService {
    func analyze(rawText: String) async throws -> InsightAnalysis { ... }
}
```

完全没有数据竞争，编译器在编译时帮你检查。

## V5 vs V0-V4 对比

| 维度 | V0-V4 (Python) | V5 (Swift) |
|------|----------------|------------|
| 平台 | Web (Streamlit) | iPhone 原生 |
| AI | 智谱 GLM-4 (云端) | Apple FoundationModels (本地) |
| OCR | GLM-4V (云端) | Vision Framework (本地) |
| 数据 | JSON 文件 / Markdown | SwiftData (SQLite) |
| 隐私 | ⚠️ 数据上云 | ✅ 100% 本地 |
| UI | 基础 Streamlit | iOS 26 Liquid Glass |
| 截图监听 | ❌ 用户手动上传 | ✅ PhotoKit 自动 |
| 性能 | 慢（HTTP 往返） | 快（本地推理） |
| 角色 | **概念验证 + 黑客松** | **生产级真实产品** |

## MVP 路线（基于这套架构）

### Phase 1 (4-6 周) — 已具备核心代码骨架 ✅
- [x] 数据模型 + SwiftData
- [x] OCR Service (Vision)
- [x] AI Service (FoundationModels)
- [x] PhotoMonitor (PhotoKit)
- [x] Capture / List / Detail / Insights 4 个核心 View
- [ ] 在真机上跑通 + 测试 OCR 准确度
- [ ] App Store 提交

### Phase 2 (4-6 周)
- [ ] 知识图谱可视化（SwiftUI Canvas）
- [ ] Share Extension（从小红书/抖音直接分享到 App）
- [ ] iOS 快捷指令支持
- [ ] Widget（首页显示今日灵感）

### Phase 3 (4-6 周)
- [ ] Markdown 导出到文件 App
- [ ] iCloud Drive 同步（可选，用户开启）
- [ ] Pro 订阅功能

## 设计哲学

1. **Local-First** — 数据永远在用户的 iPhone 上
2. **不删截图** — App 只读取，不修改原相册
3. **Apple 原生** — 不引入任何第三方依赖（包括 SDK / 网络库）
4. **类型安全** — 用 `@Generable` 替代字符串 prompt
5. **小而美** — 每个 actor / view 单一职责

---

**这套代码不能直接在 Mac 上跑** —— 它需要在 Xcode 里编译成 iOS App，在 iPhone 上运行。
但这是真正的产品形态，是 V0-V4 之后的自然终点。

完整的设计思路见 `../IOS_TECH_ARCHITECTURE.md`。
