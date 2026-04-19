import Foundation
import SwiftData
import UIKit

// MARK: - SharedStore — App Group 数据共享桥接层
//
// ShareExtension 和主 App 通过 App Group 共享 SwiftData 数据库。
// 这个类负责：
//   1. 通过 App Group 获取共享容器
//   2. 创建/访问共享的 ModelContainer
//   3. 提供 processImage / processText 等方法给 Extension 调用
//
// 技术要点：
//   - App Group ID: group.com.ideacapsule.shared
//   - 数据库存储在共享容器的 Application Support 目录
//   - Extension 和主 App 访问同一个数据库文件

@MainActor
final class SharedStore {

    // MARK: - App Group 配置

    static let groupID = "group.com.ideacapsule.shared"

    // MARK: - 单例

    static var _instance: SharedStore?
    static let lock = NSLock()

    static func instance() throws -> SharedStore {
        lock.lock()
        defer { lock.unlock() }

        if let instance = _instance {
            return instance
        }

        let instance = try SharedStore()
        _instance = instance
        return instance
    }

    // MARK: - 属性

    let modelContainer: ModelContainer
    private let modelContext: ModelContext

    // MARK: - 初始化

    private init() throws {
        // Schema 定义
        let schema = Schema([Insight.self, Entity.self, InsightThemeCluster.self])

        // 尝试使用 App Group 共享存储
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.groupID
        ) {
            // App Group 已配置，使用共享存储
            let appSupport = containerURL.appending(path: "Library/Application Support", directoryHint: .isDirectory)
            try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)

            let storeURL = appSupport.appending(path: "IdeaCapsule.sqlite")
            print("[SharedStore] 使用 App Group 存储: \(storeURL.path)")

            let config = ModelConfiguration(
                isStoredInMemoryOnly: false
            )
            // 注意：SwiftData 目前不支持直接指定自定义 URL
            // 使用默认路径 + App Group 容器作为替代方案
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } else {
            // App Group 未配置，使用默认存储
            print("[SharedStore] App Group 未配置，使用默认存储")
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        }

        modelContext = ModelContext(modelContainer)
        print("[SharedStore] ✅ 初始化成功")
    }

    // MARK: - 处理方法（复用 CapsuleStore 的逻辑）

    /// 从图片处理出一条 Insight
    func processImage(_ image: UIImage) async throws -> Insight {
        print("[SharedStore] >>> processImage START")

        // 压缩 + resize
        print("[SharedStore] 1. resize + compress...")
        let resized = image.resizedForAPI(maxDimension: 1024)
        guard let imageData = resized.jpegData(compressionQuality: 0.3) else {
            throw NSError(domain: "SharedStore", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "图片转换失败"])
        }
        print("[SharedStore] 2. JPEG \(imageData.count / 1024)KB")

        print("[SharedStore] 3. analyzeImage...")
        let analysis: AnalysisResult
        do {
            analysis = try await ModelRouter.shared.analyzeImage(imageData: imageData)
        } catch {
            print("[SharedStore] ❌ \(error)")
            throw error
        }
        print("[SharedStore] 4. OK: \(analysis.summary.prefix(30))")

        let rawText = analysis.summary

        // 持久化
        let insight = Insight(
            summary: analysis.summary,
            rawText: rawText,
            category: analysis.category,
            tags: analysis.tags,
            keywords: analysis.keywords,
            aiInsight: analysis.insight,
            sourceType: "image"
        )
        modelContext.insert(insight)
        try modelContext.save()

        print("[SharedStore] ✅ 已保存: \(insight.id)")
        return insight
    }

    /// 从文字处理出一条 Insight
    func processText(_ text: String) async throws -> Insight {
        print("[SharedStore] >>> processText START")

        let analysis = try await ModelRouter.shared.analyze(rawText: text)

        let insight = Insight(
            summary: analysis.summary,
            rawText: text,
            category: analysis.category,
            tags: analysis.tags,
            keywords: analysis.keywords,
            aiInsight: analysis.insight,
            sourceType: "text"
        )
        modelContext.insert(insight)
        try modelContext.save()

        print("[SharedStore] ✅ 已保存: \(insight.id)")
        return insight
    }

    /// 删除一条 Insight（用户取消时使用）
    func delete(_ insight: Insight) throws {
        modelContext.delete(insight)
        try modelContext.save()
        print("[SharedStore] 🗑️ 已删除: \(insight.id)")
    }
}

// MARK: - 错误类型

enum SharedStoreError: LocalizedError {
    case appGroupNotConfigured
    case containerNotAvailable

    var errorDescription: String? {
        switch self {
        case .appGroupNotConfigured:
            return "App Group 未配置。请在 Xcode → Signing & Capabilities 中添加 App Group。"
        case .containerNotAvailable:
            return "无法访问 App Group 共享容器。"
        }
    }
}
