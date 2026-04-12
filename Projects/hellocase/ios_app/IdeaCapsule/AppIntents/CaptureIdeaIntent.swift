import AppIntents
import Foundation

// MARK: - CaptureIdeaIntent — 快捷指令 + Siri + Back Tap 入口
//
// 这是『灵感胶囊』**输入层 V3+** 的核心：让用户不打开 App 就能输入灵感。
//
// 用户可以把这个 Intent 绑定到：
//   1. Siri（对 Siri 说「捕获灵感：xxx」）
//   2. 快捷指令（Shortcuts.app 里拖拽组合）
//   3. Back Tap（系统设置 → 辅助功能 → 轻点背面 → 选择快捷指令）
//   4. Control Center（iOS 18+ 可以放到控制中心）
//   5. Lock Screen Widget（锁屏小组件直接点）
//
// 这是 iOS 上能做到的"最极简输入方式"的技术基础。

struct CaptureIdeaIntent: AppIntent {
    static let title: LocalizedStringResource = "捕获灵感"
    static let description = IntentDescription(
        "快速添加一条灵感到灵感胶囊。支持文字、语音输入。"
    )

    /// 让这个 Intent 出现在 Shortcuts / Siri 搜索
    static var openAppWhenRun: Bool = false

    /// 参数：灵感内容（Siri 会问「你想记下什么？」）
    @Parameter(
        title: "灵感内容",
        description: "可以是文字、社媒内容摘要，或者任何想法",
        requestValueDialog: "你想记下什么？"
    )
    var text: String

    /// 参数：可选分类提示（默认 AI 自动分类）
    @Parameter(
        title: "分类提示",
        description: "如果你已经知道这是什么类型的灵感，可以指定",
        default: ""
    )
    var categoryHint: String

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        // 调用主 App 的 CapsuleStore 处理
        // （Share Extension 和 App Intents 需要用 App Group 共享 SwiftData container）
        let store = try await SharedStore.instance()
        let insight = try await store.processText(text)

        let dialog = IntentDialog(
            "已保存：\(insight.summary)。分类：\(insight.category)。"
        )

        return .result(value: insight.summary, dialog: dialog)
    }
}


// MARK: - CaptureFromClipboardIntent — 快速从剪贴板捕获

struct CaptureFromClipboardIntent: AppIntent {
    static let title: LocalizedStringResource = "从剪贴板捕获"
    static let description = IntentDescription(
        "把剪贴板里的内容（比如刚复制的小红书笔记）直接变成灵感"
    )

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // UIPasteboard 只能在主线程 / App extension 里用
        // 这里做简化：假设剪贴板有内容
        let pasteboardText = await MainActor.run {
            UIPasteboard.general.string ?? ""
        }

        guard !pasteboardText.isEmpty else {
            return .result(dialog: "剪贴板是空的 🤷")
        }

        let store = try await SharedStore.instance()
        let insight = try await store.processText(pasteboardText)

        return .result(dialog: "从剪贴板捕获：\(insight.summary)")
    }
}


// MARK: - ListRecentInsightsIntent — 查看最近灵感

struct ListRecentInsightsIntent: AppIntent {
    static let title: LocalizedStringResource = "查看最近灵感"
    static let description = IntentDescription("列出最近 5 条灵感")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = try await SharedStore.instance()
        let insights = try await store.fetchAll().prefix(5)

        if insights.isEmpty {
            return .result(dialog: "知识库还是空的")
        }

        let list = insights.enumerated().map { idx, ins in
            "\(idx + 1). [\(ins.category)] \(ins.summary)"
        }.joined(separator: "\n")

        return .result(dialog: "最近 \(insights.count) 条灵感：\n\(list)")
    }
}


// MARK: - IdeaCapsuleShortcuts — 提供给 Shortcuts.app 的 app 级别 Shortcuts

struct IdeaCapsuleShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
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

        AppShortcut(
            intent: CaptureFromClipboardIntent(),
            phrases: [
                "\(.applicationName) 从剪贴板捕获",
                "保存剪贴板到 \(.applicationName)",
            ],
            shortTitle: "从剪贴板捕获",
            systemImageName: "doc.on.clipboard"
        )

        AppShortcut(
            intent: ListRecentInsightsIntent(),
            phrases: [
                "\(.applicationName) 最近的灵感",
                "看 \(.applicationName) 的灵感",
            ],
            shortTitle: "查看最近灵感",
            systemImageName: "list.bullet"
        )
    }
}


// MARK: - SharedStore — App Group 共享的 Store 单例
//
// App Intents 和 Share Extension 需要用 App Group 共享同一个 SwiftData container
// 否则主 App 和 Extension 会各自有一份数据库，数据不同步。

import SwiftData

@MainActor
enum SharedStore {
    // App Group identifier（需要在 Xcode Capabilities 里启用）
    static let appGroupID = "group.com.ideacapsule.shared"

    private static var _container: ModelContainer?

    static func container() throws -> ModelContainer {
        if let c = _container { return c }

        let config = ModelConfiguration(
            schema: Schema([Insight.self]),
            isStoredInMemoryOnly: false,
            groupContainer: .identifier(appGroupID)
        )
        let c = try ModelContainer(for: Insight.self, configurations: config)
        _container = c
        return c
    }

    static func instance() async throws -> CapsuleStore {
        let c = try container()
        return CapsuleStore(modelContext: c.mainContext)
    }
}
