import SwiftUI
import SwiftData

// MARK: - 灵感胶囊 App 入口
//
// 整个 App 的依赖注入和生命周期管理。
// 用 SwiftData 自动初始化数据库，用 @Environment 注入到所有 View。

@main
struct IdeaCapsuleApp: App {
    // SwiftData container
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: Insight.self)
        } catch {
            fatalError("无法创建 SwiftData container: \(error)")
        }

        // 配置云端 AI（Kimi K2.5 中转 — 月卡）
        Task {
            await CloudAIService.shared.configure(
                apiKey: "sk-l8uV8Od8WqfCDFQyAY8OjFjNx99uslPVJ1mx42VqG5CKYn4f"
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(modelContainer)
        }
    }
}
