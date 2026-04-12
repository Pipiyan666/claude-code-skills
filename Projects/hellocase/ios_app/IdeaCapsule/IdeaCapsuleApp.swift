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

        // 配置云端 AI 降级（智谱 GLM-4）
        // 当 Apple Intelligence 不可用时自动使用
        Task {
            await CloudAIService.shared.configure(
                apiKey: "7fe411bf0c6740cea7d28cc181a81e9e.cMX697HXl0TMz1CM"
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
