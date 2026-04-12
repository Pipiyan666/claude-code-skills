import Foundation

// MARK: - ModelRouter — 双轨模型路由器
//
// 核心设计（来自 IOS_TECH_EVOLUTION.md）：
//   本地 Apple FM 可用 → 用本地（零成本、零隐私风险）
//   本地不可用 → 降级到智谱云端 GLM-4（有成本但能用）
//   用户设置"严格本地" → 强制本地，不可用就报错
//
// 对 CapsuleStore 透明：调用 ModelRouter.analyze() 不用关心背后是谁。

@MainActor
final class ModelRouter {
    static let shared = ModelRouter()

    enum Mode: String, CaseIterable, Sendable {
        case auto = "自动（优先本地）"
        case localOnly = "严格本地"
        case cloudOnly = "仅云端"
    }

    var mode: Mode = .auto

    /// 当前实际使用的引擎描述（给 UI 展示）
    var activeEngine: String {
        switch mode {
        case .localOnly: return "Apple Intelligence（本地）"
        case .cloudOnly: return "智谱 GLM-4（云端）"
        case .auto:
            return localModelAvailable
                ? "Apple Intelligence（本地）"
                : "智谱 GLM-4（云端降级）"
        }
    }

    /// 缓存本地模型可用状态（避免跨 actor 访问）
    private var localModelAvailable: Bool = false

    private init() {
        // 检查 Apple FM 是否可用
        Task {
            localModelAvailable = await AIService.shared.isAvailable
        }
    }

    /// 刷新本地模型状态
    func refreshAvailability() async {
        localModelAvailable = await AIService.shared.isAvailable
    }

    // MARK: - 截图分析（一步法）

    /// 直接把截图发给视觉模型，一步完成 OCR + 理解 + 分析
    func analyzeImage(imageData: Data) async throws -> AnalysisResult {
        // 截图场景：优先用云端 GLM-4.1V-Thinking（链式推理更强）
        // Apple FM 的视觉能力没有 GLM-4.1V-Thinking 强，所以截图默认走云端
        guard await CloudAIService.shared.isConfigured else {
            throw ModelRouterError.noCloudConfig
        }
        let result = try await CloudAIService.shared.analyzeImage(imageData: imageData)
        return AnalysisResult(
            summary: result.summary,
            category: result.category,
            tags: result.tags,
            keywords: result.keywords,
            insight: result.insight,
            engine: "GLM-4.1V-Thinking"
        )
    }

    // MARK: - 文本分析

    /// 分析一段文字 → Insight 的字段
    func analyze(rawText: String) async throws -> AnalysisResult {
        switch mode {
        case .localOnly:
            return try await analyzeLocal(rawText: rawText)
        case .cloudOnly:
            return try await analyzeCloud(rawText: rawText)
        case .auto:
            // 先试本地
            await refreshAvailability()
            if localModelAvailable {
                do {
                    return try await analyzeLocal(rawText: rawText)
                } catch {
                    // 本地失败 → 降级到云端
                    print("[ModelRouter] 本地失败，降级到云端: \(error)")
                    return try await analyzeCloud(rawText: rawText)
                }
            }
            // 本地不可用 → 直接用云端
            return try await analyzeCloud(rawText: rawText)
        }
    }

    // MARK: - 本地（Apple FoundationModels）

    private func analyzeLocal(rawText: String) async throws -> AnalysisResult {
        let analysis = try await AIService.shared.analyze(rawText: rawText)
        return AnalysisResult(
            summary: analysis.summary,
            category: analysis.category,
            tags: analysis.tags,
            keywords: analysis.keywords,
            insight: analysis.insight,
            engine: "Apple Intelligence"
        )
    }

    // MARK: - 云端（智谱 GLM-4）

    private func analyzeCloud(rawText: String) async throws -> AnalysisResult {
        guard await CloudAIService.shared.isConfigured else {
            throw ModelRouterError.noCloudConfig
        }
        let result = try await CloudAIService.shared.analyze(rawText: rawText)
        return AnalysisResult(
            summary: result.summary,
            category: result.category,
            tags: result.tags,
            keywords: result.keywords,
            insight: result.insight,
            engine: "智谱 GLM-4"
        )
    }
}


// MARK: - 统一结果类型

struct AnalysisResult: Sendable {
    let summary: String
    let category: String
    let tags: [String]
    let keywords: [String]
    let insight: String
    let engine: String  // 告诉 UI 这次用的是哪个引擎
}

enum ModelRouterError: LocalizedError {
    case noCloudConfig
    case bothFailed(local: String, cloud: String)

    var errorDescription: String? {
        switch self {
        case .noCloudConfig:
            return "本地 AI 不可用，且未配置云端 API Key。请在设置里输入智谱 API Key，或启用 Apple Intelligence。"
        case .bothFailed(let l, let c):
            return "本地(\(l)) 和云端(\(c)) 都失败了"
        }
    }
}
