import Foundation
import FoundationModels
import SwiftData

// MARK: - Insight 数据模型（SwiftData 持久化）
//
// 这是『灵感胶囊』的核心数据结构。
// 用 SwiftData 自动持久化到 ~/Library/IdeaCapsule.sqlite (App 沙盒内)
// 同时序列化成 markdown 文件（学 Karpathy 的 markdown-as-DB 思想）

@Model
final class Insight: @unchecked Sendable {
    @Attribute(.unique) var id: String
    var summary: String
    var rawText: String
    var category: String
    var tagsRaw: String      // SwiftData 不直接支持 [String]，序列化成逗号分隔
    var keywordsRaw: String
    var aiInsight: String
    var createdAt: Date
    var sourceType: String   // "text" | "image" | "voice" | "link"
    var imageAssetIdentifier: String?  // PhotoKit asset id（不复制原图）
    var sourceURL: String?

    // 计算属性
    var tags: [String] {
        get { tagsRaw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
        set { tagsRaw = newValue.joined(separator: ",") }
    }

    var keywords: [String] {
        get { keywordsRaw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
        set { keywordsRaw = newValue.joined(separator: ",") }
    }

    init(
        id: String = UUID().uuidString,
        summary: String,
        rawText: String,
        category: String = "其他",
        tags: [String] = [],
        keywords: [String] = [],
        aiInsight: String = "",
        sourceType: String = "text",
        imageAssetIdentifier: String? = nil,
        sourceURL: String? = nil
    ) {
        self.id = id
        self.summary = summary
        self.rawText = rawText
        self.category = category
        self.tagsRaw = tags.joined(separator: ",")
        self.keywordsRaw = keywords.joined(separator: ",")
        self.aiInsight = aiInsight
        self.createdAt = Date()
        self.sourceType = sourceType
        self.imageAssetIdentifier = imageAssetIdentifier
        self.sourceURL = sourceURL
    }
}


// MARK: - InsightAnalysis（@Generable 用于 Apple FoundationModels）
//
// 这是核心 — 用 @Generable 让 Apple 本地模型直接生成结构化输出。
// 比解析 JSON 字符串更可靠，类型完全安全。

@Generable(description: "对一条灵感的结构化分析结果")
struct InsightAnalysis {
    @Guide(description: "用 30-50 字总结这条灵感的核心内容")
    var summary: String

    @Guide(description: "灵感的分类类别", .anyOf(["社媒灵感", "会议记录", "产品想法", "学习笔记", "生活待办", "聊天截图", "其他"]))
    var category: String

    @Guide(description: "3-5 个分类标签，每个不超过 6 个字", .count(3...5))
    var tags: [String]

    @Guide(description: "3-5 个关键词，是从原文里提取的具体名词", .count(3...5))
    var keywords: [String]

    @Guide(description: "用 50 字给一个有用的延伸思考或下一步行动建议")
    var insight: String
}


// MARK: - 主题（用于跨灵感聚类）

@Generable(description: "基于多条灵感发现的共同主题")
struct InsightTheme {
    @Guide(description: "主题名称（5-10 字）")
    var name: String

    @Guide(description: "为什么这是一个主题（30 字描述）")
    var description: String

    @Guide(description: "相关的灵感关键词", .count(2...5))
    var relatedKeywords: [String]
}


// MARK: - 用户洞察画像

@Generable(description: "用户最近关注点的画像")
struct UserProfile {
    @Guide(description: "一句话画像")
    var summary: String

    @Guide(description: "发现的 2-4 个主题", .count(2...4))
    var themes: [InsightTheme]

    @Guide(description: "建议的下一步行动 3 个", .count(3))
    var nextActions: [String]
}
