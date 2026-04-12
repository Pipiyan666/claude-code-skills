# iOS 项目 · Xcode 打开 & 编译指南

> 这份文档教你把 `ios_app/IdeaCapsule/` 里的 Swift 代码**真正打开并跑起来**。

---

## 你现在处于的状态

我检查了你的 Mac：

```
Xcode:             ❌ 未安装（只有 Command Line Tools）
Swift 编译器:      ✅ 6.2.1
iOS SDK:           ❌ 需要 Xcode 才有
xcodegen:          ❌ 未安装
```

**前置条件**：你需要安装 Xcode 26+（含 iOS 26 SDK 和 FoundationModels）。

---

## Step 1 · 安装 Xcode 26（一次性，~10 GB）

### 方式 A：App Store（推荐，最简单）

```bash
# 打开 Mac App Store，搜索 "Xcode"，点下载
open -a "App Store"
```

搜索 **Xcode**，点击下载。大约 10 GB，根据网速需要 20-60 分钟。

### 方式 B：Apple Developer 官网（更快）

1. 打开 https://developer.apple.com/download/applications/
2. 登录你的 Apple ID
3. 找到 **Xcode 26** 的 .xip 文件下载
4. 解压后拖到 `/Applications/`

### 安装完成后：

```bash
# 让系统使用 Xcode 的命令行工具（而不是独立的 CLT）
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# 接受许可
sudo xcodebuild -license accept

# 首次运行会自动安装额外组件
sudo xcodebuild -runFirstLaunch

# 验证
xcodebuild -version
# 应该输出：
#   Xcode 26.x
#   Build version ...
```

---

## Step 2 · 生成 Xcode 项目文件（两种方式）

### 方式 A：用 xcodegen 一键生成（推荐）

```bash
# 安装 xcodegen
brew install xcodegen

# 进入 ios_app 目录
cd ~/Projects/hellocase/ios_app

# 一键生成 IdeaCapsule.xcodeproj
xcodegen generate

# 打开
open IdeaCapsule.xcodeproj
```

我已经帮你写好了 `project.yml`，xcodegen 会读取它自动创建完整的 Xcode 项目，**包括**：
- 所有 Swift 文件的编译配置
- Info.plist 和权限说明
- Entitlements（App Group、Photo Library 等）
- iOS 26 最低部署版本
- Swift 6.2 strict concurrency

### 方式 B：在 Xcode 里手动创建项目（如果不想装 xcodegen）

1. 打开 Xcode，选 **Create New Project**
2. 选 **iOS → App**，点 Next
3. 填写：
   - **Product Name**: `IdeaCapsule`
   - **Team**: 选你自己的 Apple Developer Team（免费账号也可以）
   - **Organization Identifier**: `com.ideacapsule`
   - **Interface**: `SwiftUI`
   - **Language**: `Swift`
   - **Storage**: `SwiftData`
   - **Include Tests**: 可以勾掉（之后再加）
4. 保存位置：**选择 `~/Projects/hellocase/ios_app/` 作为保存位置**
5. 创建后，在 Finder 里把 Xcode 自动生成的 `IdeaCapsule/IdeaCapsule.swift` 和 `IdeaCapsule/ContentView.swift` **删除**
6. 把我们的 `IdeaCapsule/` 目录下的所有文件**拖进** Xcode 的 Project Navigator（左侧）
   - 拖的时候勾选 **"Copy items if needed"** = ❌ 不勾（文件已在正确位置）
   - **"Create groups"** = ✅
   - **"Add to targets"** = ✅ 勾选 IdeaCapsule target

---

## Step 3 · 配置权限和 Capabilities（重要！）

在 Xcode 里点击项目根（最顶部蓝色图标）→ 选中 IdeaCapsule target → **Signing & Capabilities** 标签：

### 添加 Capabilities

点左上角 **+ Capability** 按钮，添加：

1. **Photos**
   - 允许 App 读相册

2. **App Groups**
   - 点 **+** 添加 `group.com.ideacapsule.shared`
   - 这是 Share Extension 和主 App 共享 SwiftData 用的

3. **Background Modes**
   - 勾选 **Background processing**

### 检查 Info.plist（Resources/Info.plist）

应该已经有这些权限说明（如果没有，添加）：

- `NSPhotoLibraryUsageDescription` - 相册权限说明
- `NSCameraUsageDescription` - 相机权限说明
- `NSMicrophoneUsageDescription` - 麦克风权限说明
- `NSSpeechRecognitionUsageDescription` - 语音识别权限说明

---

## Step 4 · 运行

### 在模拟器上跑

1. Xcode 顶部 scheme 旁边选 **iPhone 16 Pro** (需要 iOS 26+ runtime)
2. 按 **Cmd+R** 或点 ▶ 按钮
3. 首次编译会慢一些（5-10 分钟，因为下载 iOS 26 runtime）

### 在真机上跑

**需要**：
- iPhone 15 Pro 或更新机型（Apple FoundationModels 的最低要求）
- iOS 26+
- 免费或付费的 Apple Developer 账号

步骤：
1. 用数据线连接 iPhone 到 Mac
2. iPhone 上打开 **设置 → 隐私与安全性 → 开发者模式** → 打开
3. Xcode 顶部 scheme 旁边选你的 iPhone
4. Cmd+R 运行
5. iPhone 弹出"不受信任的开发者"提示时，按 **设置 → 通用 → VPN 与设备管理** 信任你的开发者证书

---

## Step 5 · 可能遇到的问题

### ❓ `FoundationModels` 模块找不到

**原因**：你的 Xcode 或模拟器不是 iOS 26+。

**修复**：
```bash
# 检查 iOS SDK 版本
xcodebuild -showsdks | grep iOS
```

确保有 iOS 26。如果没有，在 Xcode 里 **Settings → Components** 下载。

### ❓ "Team is required" 签名错误

**修复**：
- 在 Xcode 里登录你的 Apple ID（**Settings → Accounts → + Apple ID**）
- 免费账号（Apple ID）也可以签名调试，只是 App 7 天后会过期

### ❓ App Group 配置错误

**修复**：
- Apple Developer 账号需要在 https://developer.apple.com/account/resources/identifiers 手动注册 App Group ID
- 免费账号可以用，但可能需要手动同意

### ❓ `@Generable` 宏找不到

**原因**：Xcode 版本太老。

**修复**：确保 Xcode 是 26.0 或更新（因为 `@Generable` 是 iOS 26 新宏）。

---

## 项目结构（Xcode 里会看到的目录）

```
IdeaCapsule/
├── IdeaCapsuleApp.swift          # App 入口 + SwiftData container
├── DesignSystem/
│   └── Theme.swift               # ⭐ 色板/字体/间距/动画
├── Models/
│   └── Insight.swift             # @Model + @Generable
├── Services/
│   ├── OCRService.swift          # Vision OCR actor
│   ├── AIService.swift           # Apple FoundationModels actor
│   ├── PhotoMonitor.swift        # PhotoKit 监听
│   ├── CapsuleStore.swift        # @Observable store
│   └── VoiceInputService.swift   # 本地语音识别
├── Views/
│   ├── RootView.swift            # 自定义 Editorial Tab Bar
│   ├── CaptureView.swift         # ⭐ 捕获页（Editorial 风格）
│   ├── InsightListView.swift     # 书库（杂志目录）
│   ├── InsightDetailView.swift   # 详情（杂志 feature article）
│   ├── InsightsTabView.swift     # 洞察（编辑报告）
│   └── ResultCard.swift          # AI 结果卡片
├── AppIntents/
│   └── CaptureIdeaIntent.swift   # Siri / Shortcuts / Back Tap
├── ShareExtension/
│   └── ShareViewController.swift # 从小红书分享到胶囊
└── Resources/
    └── Info.plist                # 权限说明
```

---

## 预览视图（不跑 App 就能看 UI）

Xcode 的 Canvas (右侧) 可以**实时预览** SwiftUI 视图，不需要编译运行 App。

在任何 View 文件里，点右上角 **Canvas** 图标（或 Option+Cmd+Return）：

```swift
#Preview {
    RootView()
        .modelContainer(for: Insight.self, inMemory: true)
}
```

Canvas 会实时渲染这个视图，你可以边改 Swift 代码边看效果。

**这是你最快看到 Editorial Diary 设计效果的方法**——装好 Xcode 后不用打包运行，直接在 Canvas 里看每个 View 的样子。

---

## 一键命令（装好 Xcode 之后）

```bash
# 1. 安装 xcodegen
brew install xcodegen

# 2. 生成项目
cd ~/Projects/hellocase/ios_app && xcodegen generate

# 3. 打开
open IdeaCapsule.xcodeproj

# 4. 在 Xcode 里按 Cmd+R 运行（首次会下载 iOS 26 runtime，约 5-10 分钟）
```

---

## 如果你暂时不想装 Xcode（只想看代码）

所有 Swift 代码都能直接看（不需要 Xcode 也能读）。精华文件：

1. **`IdeaCapsule/DesignSystem/Theme.swift`** — 看设计系统
2. **`IdeaCapsule/Views/CaptureView.swift`** — 看捕获页的 Editorial 风格
3. **`IdeaCapsule/Views/InsightListView.swift`** — 看书库的杂志排版
4. **`IdeaCapsule/Views/InsightDetailView.swift`** — 看详情页的文章风格

即使不装 Xcode，光读这些代码也能感受设计质量。

---

**有任何 Xcode 问题，把完整错误信息发我，我帮你定位。**
