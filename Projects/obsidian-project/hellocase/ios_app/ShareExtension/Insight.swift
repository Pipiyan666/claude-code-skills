import Foundation
import FoundationModels
import SwiftData

// MARK: - 三层记忆分层（借鉴 OpenClaw Dreaming + Karpathy Wiki + Zep 时序模型）
//
// Hot  = 最近 7 天的原始灵感，全量注入 AI 上下文
// Warm = 30 天内经过主题聚类的灵感，按主题索引检索
// Cold = 沉淀到知识图谱的长期记忆，图遍历查询

enum MemoryTier: String, Codable, CaseIterable {
    case hot  = "hot"   // 7 天内
    case warm = "warm"  // 30 天内，已聚类
    case cold = "cold"  // 长期知识图谱
}

// MARK: - Insight 数据模型（SwiftData 持久化）

@Model
final class Insight: @unchecked Sendable {
    @Attribute(.unique) var id: String
    var summary: String
    var rawText: String
    var category: String
    var tagsRaw: String
    var keywordsRaw: String
    var aiInsight: String
    var createdAt: Date
    var sourceType: String   // "text" | "image" | "voice" | "link"
    var imageAssetIdentifier: String?
    var sourceURL: String?

    // 三层记忆（默认值确保 SwiftData 迁移不崩溃）
    var memoryTierRaw: String = "hot"
    var promotedAt: Date?
    var lastAccessedAt: Date?

    // 实体关联（知识图谱的边）
    var linkedInsightIDs: String = ""
    var entityNamesRaw: String = ""

    // 聚类信息
    var themeID: String?
    var clusterScore: Double = 0.0

    // 计算属性
    var tags: [String] {
        get { tagsRaw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
        set { tagsRaw = newValue.joined(separator: ",") }
    }

    var keywords: [String] {
        get { keywordsRaw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
        set { keywordsRaw = newValue.joined(separator: ",") }
    }

    var memoryTier: MemoryTier {
        get { MemoryTier(rawValue: memoryTierRaw) ?? .hot }
        set { memoryTierRaw = newValue.rawValue }
    }

    var linkedIDs: [String] {
        get { linkedInsightIDs.split(separator: ",").map { String($0) } }
        set { linkedInsightIDs = newValue.joined(separator: ",") }
    }

    var entityNames: [String] {
        get { entityNamesRaw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
        set { entityNamesRaw = newValue.joined(separator: ",") }
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
        self.memoryTierRaw = MemoryTier.hot.rawValue
        self.linkedInsightIDs = ""
        self.entityNamesRaw = ""
        self.clusterScore = 0.0
    }
}

// MARK: - Entity 知识图谱节点

@Model
final class Entity: @unchecked Sendable {
    @Attribute(.unique) var id: String
    var name: String
    var type: String          // "brand" | "person" | "concept" | "topic"
    var description_: String  // 避免与系统 description 冲突
    var mentionCount: Int     // 被引用次数（用于门控提升）
    var firstSeenAt: Date
    var lastSeenAt: Date      // Zep 双时间线：最近一次出现
    var relatedEntityIDs: String  // 逗号分隔

    var relatedIDs: [String] {
        get { relatedEntityIDs.split(separator: ",").map { String($0) } }
        set { relatedEntityIDs = newValue.joined(separator: ",") }
    }

    init(name: String, type: String, description: String = "") {
        self.id = UUID().uuidString
        self.name = name
        self.type = type
        self.description_ = description
        self.mentionCount = 1
        self.firstSeenAt = Date()
        self.lastSeenAt = Date()
        self.relatedEntityIDs = ""
    }
}

// MARK: - Theme 主题聚类（Warm 层）

@Model
final class InsightThemeCluster: @unchecked Sendable {
    @Attribute(.unique) var id: String
    var name: String
    var summary: String
    var insightCount: Int
    var createdAt: Date
    var updatedAt: Date
    var keywordsRaw: String

    var keywords: [String] {
        get { keywordsRaw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
        set { keywordsRaw = newValue.joined(separator: ",") }
    }

    init(name: String, summary: String, keywords: [String] = []) {
        self.id = UUID().uuidString
        self.name = name
        self.summary = summary
        self.insightCount = 0
        self.createdAt = Date()
        self.updatedAt = Date()
        self.keywordsRaw = keywords.joined(separator: ",")
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
