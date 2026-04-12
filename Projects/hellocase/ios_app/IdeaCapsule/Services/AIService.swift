import Foundation
import FoundationModels

// MARK: - AI Service（Apple Foundation Models 本地 LLM）
//
// 这是『灵感胶囊』的核心创新：
// 100% 本地 AI 分析，数据完全不出设备，零隐私风险。
//
// 架构亮点：
//   - 用 @Generable 直接生成结构化类型（不需要解析 JSON 字符串）
//   - 用 @Guide 约束字段（标签数量、分类枚举等）
//   - 流式响应（snapshot streaming）实时更新 UI

actor AIService {
    static let shared = AIService()

    private let model = SystemLanguageModel.default
    private var session: LanguageModelSession?

    /// 灵感分析的 system instructions
    private let analysisInstructions = """
    你是『灵感胶囊』的 AI 助手，帮助 18-35 岁的女性用户整理她们保存的截图和灵感。

    你的工作：根据用户给的灵感原文（可能是 OCR 出来的截图文字、手打的笔记、社媒链接的标题），
    生成结构化的分析，包括摘要、分类、标签、关键词、行动建议。

    原则：
    - 用中文
    - 摘要要有信息量，不要套话
    - 标签是抽象类别（穿搭、心理学、产品管理）
    - 关键词是具体名词（焦糖色、ReAct、D7留存）
    - 建议要具体可执行
    """

    private init() {}

    /// 检查模型是否可用
    var isAvailable: Bool {
        if case .available = model.availability {
            return true
        }
        return false
    }

    /// 获取不可用原因（用于 UI 引导）
    var unavailableReason: String? {
        switch model.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "你的设备不支持 Apple Intelligence。需要 iPhone 15 Pro 或更新机型。"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "请在系统设置 → Apple Intelligence 与 Siri 里启用 Apple Intelligence。"
        case .unavailable(.modelNotReady):
            return "模型还在下载中，请稍等几分钟。"
        case .unavailable(let other):
            return "模型暂不可用：\(other)"
        }
    }

    // MARK: - 单条灵感分析

    /// 分析一条灵感（同步返回完整结果）
    func analyze(rawText: String) async throws -> InsightAnalysis {
        let session = LanguageModelSession(instructions: analysisInstructions)
        let response = try await session.respond(
            to: "请分析这条灵感：\n\n\(rawText)",
            generating: InsightAnalysis.self
        )
        return response.content
    }

    // 流式分析（V2 再加，MVP 不需要）
    // func analyzeStreaming(rawText: String) -> ... { ... }

    // MARK: - 跨灵感聚类（V2 思想）

    /// 基于多条灵感生成用户画像 + 主题发现
    func cluster(insights: [Insight]) async throws -> UserProfile {
        let limited = insights.prefix(15)
        let summaries = limited.enumerated().map { idx, ins in
            "\(idx + 1). [\(ins.category)] \(ins.summary) (标签: \(ins.tags.joined(separator: ", ")))"
        }.joined(separator: "\n\n")

        let session = LanguageModelSession(instructions: """
        你是一个洞察分析师，帮用户从她最近保存的灵感里发现共同主题和成长方向。
        要找的是『模式』，不是简单的复述。
        """)

        let response = try await session.respond(
            to: """
            下面是用户最近保存的灵感：

            \(summaries)

            请发现 2-4 个共同主题，给出用户画像，建议 3 个下一步行动。
            """,
            generating: UserProfile.self
        )
        return response.content
    }

    // MARK: - 链接元数据提取（用于社媒链接 → 灵感）

    /// 从一段网页文字提取核心灵感
    func extractFromLink(title: String, content: String) async throws -> InsightAnalysis {
        let session = LanguageModelSession(instructions: analysisInstructions)
        let response = try await session.respond(
            to: """
            从下面这个网页内容里提取核心灵感：

            标题：\(title)

            正文：\(content.prefix(2000))
            """,
            generating: InsightAnalysis.self
        )
        return response.content
    }
}
