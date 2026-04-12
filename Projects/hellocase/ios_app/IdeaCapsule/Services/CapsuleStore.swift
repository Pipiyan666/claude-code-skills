import Foundation
import SwiftData
import Photos
import UIKit

// MARK: - CapsuleStore — 灵感存储 + 处理 pipeline
//
// 这是把所有 Service 串起来的"管道"：
//   PhotoKit asset → OCR → AIService 分析 → SwiftData 持久化 → markdown 导出（可选）
//
// V2 多 Agent 思想的 Swift 版本：每个 step 是一个 actor 方法。

@MainActor @Observable
final class CapsuleStore {
    // SwiftData 上下文
    private let modelContext: ModelContext

    // 处理状态（用于 UI）
    var isProcessing = false
    var processedCount = 0
    var failedCount = 0

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - V2 风格的 Pipeline

    /// 从一张图片处理出一条 Insight
    /// pipeline:
    ///   1. ScreenshotAgent: Vision OCR 提取文字
    ///   2. AnalyzeAgent: Apple FoundationModels 结构化分析
    ///   3. SaveAgent: 写入 SwiftData
    func processImage(_ image: UIImage, asset: PHAsset? = nil) async throws -> Insight {
        // 一步法：直接把图片发给 GLM-4.1V-Thinking 视觉模型
        // 它会同时完成 OCR + 理解图片含义 + 生成结构化分析
        // 不再需要先 Vision OCR 再文本分析的两步法
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "CapsuleStore", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "图片转换失败"])
        }

        // 智能选择：付费模型用一步法，免费模型用两步法
        let analysis: AnalysisResult
        let rawText: String

        let isPremium = await CloudAIService.shared.visionModel.contains("thinking")
        if isPremium {
            // 一步法（GLM-4.1V-Thinking 链式推理）
            do {
                analysis = try await ModelRouter.shared.analyzeImage(imageData: imageData)
                rawText = analysis.summary
            } catch {
                // 降级到两步法
                rawText = try await OCRService.shared.extractText(from: image)
                analysis = try await ModelRouter.shared.analyze(rawText: rawText)
            }
        } else {
            // 两步法（免费模型：Vision OCR → 文本分析）
            rawText = try await OCRService.shared.extractText(from: image)
            analysis = try await ModelRouter.shared.analyze(rawText: rawText)
        }

        // 持久化
        let insight = Insight(
            summary: analysis.summary,
            rawText: rawText,
            category: analysis.category,
            tags: analysis.tags,
            keywords: analysis.keywords,
            aiInsight: analysis.insight,
            sourceType: "image",
            imageAssetIdentifier: asset?.localIdentifier
        )
        modelContext.insert(insight)
        try modelContext.save()

        return insight
    }

    /// 从一段文字处理出一条 Insight
    func processText(_ text: String) async throws -> Insight {
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

        return insight
    }

    /// 批量处理（监听到新截图时调用）
    func processBatch(assets: [PHAsset]) async {
        isProcessing = true
        defer { isProcessing = false }

        for asset in assets {
            guard let image = await PhotoMonitor.shared.loadImage(for: asset) else {
                failedCount += 1
                continue
            }
            do {
                _ = try await processImage(image, asset: asset)
                processedCount += 1
            } catch {
                failedCount += 1
                print("[CapsuleStore] failed to process asset \(asset.localIdentifier): \(error)")
            }
        }
    }

    // MARK: - 查询接口

    /// 全部灵感（按时间倒序）
    func fetchAll() throws -> [Insight] {
        let descriptor = FetchDescriptor<Insight>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// 全文搜索
    func search(_ query: String) throws -> [Insight] {
        let descriptor = FetchDescriptor<Insight>(
            predicate: #Predicate { ins in
                ins.summary.contains(query)
                    || ins.rawText.contains(query)
                    || ins.tagsRaw.contains(query)
                    || ins.keywordsRaw.contains(query)
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// 跨灵感聚类（V2 ClusterAgent 等价物）
    func generateUserProfile() async throws -> UserProfile {
        let all = try fetchAll()
        return try await AIService.shared.cluster(insights: Array(all.prefix(15)))
    }

    // MARK: - Markdown 导出（学 Karpathy）

    /// 把单条灵感导出为 markdown 字符串（带 frontmatter）
    func exportMarkdown(_ insight: Insight) -> String {
        let formatter = ISO8601DateFormatter()
        let createdISO = formatter.string(from: insight.createdAt)

        return """
        ---
        id: \(insight.id)
        created: \(createdISO)
        source: \(insight.sourceType)
        category: \(insight.category)
        tags: [\(insight.tags.joined(separator: ", "))]
        keywords: [\(insight.keywords.joined(separator: ", "))]
        ---

        # \(insight.summary)

        ## 原文

        \(insight.rawText)

        ## AI 洞察

        \(insight.aiInsight)
        """
    }

    /// 导出全部到 ~/Documents/IdeaCapsule_Export/
    func exportAllToMarkdown() throws -> URL {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "CapsuleStore", code: -1)
        }
        let exportDir = docs.appending(path: "IdeaCapsule_Export")
        try fm.createDirectory(at: exportDir, withIntermediateDirectories: true)

        let all = try fetchAll()
        for ins in all {
            let filename = "\(ins.id).md"
            let url = exportDir.appending(path: filename)
            try exportMarkdown(ins).write(to: url, atomically: true, encoding: .utf8)
        }
        return exportDir
    }
}
