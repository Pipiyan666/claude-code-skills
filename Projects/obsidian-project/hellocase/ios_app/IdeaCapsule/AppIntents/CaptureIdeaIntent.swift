import AppIntents
import Foundation
import UIKit
import Photos

// MARK: - CaptureIdeaIntent — 文字灵感快捷指令
//
// 用法：
//   1. Siri："嘿 Siri，用灵感胶囊捕获..."
//   2. 快捷指令：拖拽此 Intent，输入文字
//   3. Back Tap：绑定到此快捷指令

struct CaptureIdeaIntent: AppIntent {
    static let title: LocalizedStringResource = "捕获灵感"
    static let description = IntentDescription(
        "快速添加一条灵感到灵感胶囊。"
    )

    static let openAppWhenRun = false

    @Parameter(
        title: "灵感内容",
        description: "文字内容",
        requestValueDialog: "你想记下什么？"
    )
    var text: String

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        guard !text.isEmpty else {
            return .result(
                value: "",
                dialog: "请输入要保存的内容"
            )
        }

        do {
            let store = try await SharedStore.instance()
            let insight = try await store.processText(text)

            return .result(
                value: insight.id.uuidString,
                dialog: "✅ 已保存：\(insight.summary)"
            )
        } catch {
            return .result(
                value: "",
                dialog: "❌ 保存失败：\(error.localizedDescription)"
            )
        }
    }
}


// MARK: - CaptureFromClipboardIntent — 剪贴板捕获
//
// 用法：
//   1. 复制内容后，运行此快捷指令
//   2. 可绑定到 Back Tap 或 Control Center

struct CaptureFromClipboardIntent: AppIntent {
    static let title: LocalizedStringResource = "从剪贴板捕获"
    static let description = IntentDescription(
        "把剪贴板里的内容（比如刚复制的小红书笔记）直接变成灵感"
    )

    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let pasteboardText = await MainActor.run {
            UIPasteboard.general.string ?? ""
        }

        guard !pasteboardText.isEmpty else {
            return .result(dialog: "剪贴板是空的 🤷")
        }

        do {
            let store = try await SharedStore.instance()
            let insight = try await store.processText(pasteboardText)

            return .result(
                dialog: "✅ 已从剪贴板保存：\(insight.summary)"
            )
        } catch {
            return .result(
                dialog: "❌ 保存失败：\(error.localizedDescription)"
            )
        }
    }
}


// MARK: - ProcessLatestScreenshotIntent — 处理最新截图 ⭐
//
// 这是**核心功能**：一键处理最新截图
//
// 用法：
//   1. 截图后，运行此快捷指令
//   2. 可设为自动化：截图后自动提醒
//   3. 绑定到 Back Tap：双击背面 → 处理截图

struct ProcessLatestScreenshotIntent: AppIntent {
    static let title: LocalizedStringResource = "处理最新截图"
    static let description = IntentDescription(
        "获取相册里最新的一张截图，用 AI 分析并保存到灵感胶囊"
    )

    static let openAppWhenRun = false

    /// 可选：指定最近第 N 张截图（默认 1 = 最新）
    @Parameter(
        title: "第几张",
        description: "1 = 最新截图，2 = 倒数第二张...",
        default: 1
    )
    var nth: Int

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 1. 请求照片权限
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            return .result(dialog: "需要照片权限才能读取截图")
        }

        // 2. 获取最新截图
        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit = 1
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)

        let assets = PHAsset.fetchAssets(with: fetchOptions)
        guard let asset = assets.firstObject else {
            return .result(dialog: "相册里没有图片")
        }

        // 3. 加载图片
        let image = await loadImage(from: asset)
        guard let image else {
            return .result(dialog: "无法加载图片")
        }

        // 4. 处理
        do {
            let store = try await SharedStore.instance()
            let insight = try await store.processImage(image)

            return .result(
                dialog: """
                ✅ 截图已分析

                \(insight.summary)

                标签：\(insight.tags.prefix(3).joined(separator: "、"))
                """
            )
        } catch {
            return .result(
                dialog: "❌ 处理失败：\(error.localizedDescription)"
            )
        }
    }

    private func loadImage(from asset: PHAsset) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        return await withCheckedContinuation { continuation in
            let targetSize = CGSize(width: 1024, height: 1024)
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    static var parameterSummary: some ParameterSummary {
        Summary("处理最新截图") {
            \.$nth
        }
    }
}


// MARK: - ProcessImageIntent — 接收图片参数
//
// 用法：
//   1. 快捷指令里用"选取照片"动作
//   2. 接到此 Intent，AI 分析
//   3. 支持批量处理

struct ProcessImageIntent: AppIntent {
    static let title: LocalizedStringResource = "AI 分析图片"
    static let description = IntentDescription(
        "用 AI 分析图片内容并保存到灵感胶囊"
    )

    static let openAppWhenRun = false

    @Parameter(
        title: "图片",
        description: "要分析的图片"
    )
    var images: [IntentFile]?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let images, !images.isEmpty else {
            return .result(dialog: "请选择要分析的图片")
        }

        var successCount = 0
        var failCount = 0
        var summaries: [String] = []

        for file in images {
            guard let imageData = file.data,
                  let image = UIImage(data: imageData) else {
                failCount += 1
                continue
            }

            do {
                let store = try await SharedStore.instance()
                let insight = try await store.processImage(image)
                successCount += 1
                summaries.append(insight.summary)
            } catch {
                failCount += 1
            }
        }

        if successCount == 0 {
            return .result(dialog: "❌ 所有图片都处理失败")
        }

        return .result(
            dialog: """
            ✅ 已处理 \(successCount) 张图片
            \(failCount > 0 ? "⚠️ \(failCount) 张失败" : "")

            \(summaries.first ?? "")
            """
        )
    }

    static var parameterSummary: some ParameterSummary {
        Summary("AI 分析图片") {
            \.$images
        }
    }
}


// MARK: - QuickCaptureIntent — 快速捕获（无参数）
//
// 用法：
//   1. 绑定到 Back Tap（轻点背面）
//   2. 添加到 Control Center
//   3. 添加到锁屏按钮
//   行为：自动处理最新截图

struct QuickCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "快速捕获"
    static let description = IntentDescription(
        "一键处理最新截图，无需确认"
    )

    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        // 委托给 ProcessLatestScreenshotIntent
        let intent = ProcessLatestScreenshotIntent()
        intent.nth = 1
        return try await intent.perform()
    }
}


// MARK: - IdeaCapsuleShortcuts — 快捷指令入口

struct IdeaCapsuleShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // 核心功能：快速捕获（处理最新截图）
        AppShortcut(
            intent: ProcessLatestScreenshotIntent(),
            phrases: [
                "用 \(.applicationName) 处理截图",
                "\(.applicationName) 分析截图",
                "把截图保存到 \(.applicationName)",
                "截图存胶囊",
            ],
            shortTitle: "处理截图",
            systemImageName: "photo.badge.plus"
        )

        // 文字捕获
        AppShortcut(
            intent: CaptureIdeaIntent(),
            phrases: [
                "用 \(.applicationName) 捕获灵感",
                "\(.applicationName) 记一个想法",
                "让 \(.applicationName) 记下来",
            ],
            shortTitle: "捕获灵感",
            systemImageName: "sparkles"
        )

        // 剪贴板捕获
        AppShortcut(
            intent: CaptureFromClipboardIntent(),
            phrases: [
                "\(.applicationName) 从剪贴板捕获",
                "保存剪贴板到 \(.applicationName)",
                "剪贴板内容存胶囊",
            ],
            shortTitle: "剪贴板捕获",
            systemImageName: "doc.on.clipboard"
        )
    }

    static var shortcutTileColor: ShortcutTileColor {
        .coral
    }
}
