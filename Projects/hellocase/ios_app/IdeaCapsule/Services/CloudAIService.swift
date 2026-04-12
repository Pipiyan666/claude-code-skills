import Foundation

// MARK: - CloudAIService — 云端 AI 降级方案（智谱 GLM-4）
//
// 当 Apple FoundationModels 不可用时（未启用 / 旧设备 / 模型没下载完），
// 自动降级到智谱 GLM-4 API。用 URLSession 直接调用，不引入任何第三方 SDK。
//
// 这就是 IOS_TECH_EVOLUTION.md 里设计的"双轨模型路由器"的实现。

actor CloudAIService {
    static let shared = CloudAIService()

    // 智谱 API 配置
    private var apiKey: String = ""
    private let baseURL = "https://open.bigmodel.cn/api/paas/v4/chat/completions"

    // 双模型分工（2026 最新最强）
    private let textModel = "glm-5.1"                         // 文本分析 + 聚类 + 调研
    private let visionModel = "glm-4.1v-thinking-flashx"      // 截图视觉理解（链式推理）

    private init() {}

    /// 配置 API Key（App 启动时或设置页调用）
    func configure(apiKey: String) {
        self.apiKey = apiKey
    }

    var isConfigured: Bool {
        !apiKey.isEmpty
    }

    // MARK: - 灵感分析（对应 AIService.analyze）

    func analyze(rawText: String) async throws -> CloudInsightResult {
        let prompt = """
        你是灵感整理助手。请为下面这条灵感生成结构化分析。
        返回严格的 JSON，不要 markdown 包裹：
        {
          "summary": "30-50 字总结核心",
          "category": "社媒灵感/会议记录/产品想法/学习笔记/生活待办/其他",
          "tags": ["3-5 个标签"],
          "keywords": ["3-5 个关键词"],
          "insight": "50 字延伸思考或行动建议"
        }
        用中文。

        灵感原文：
        \(rawText)
        """

        let json = try await callAPI(prompt: prompt, maxTokens: 800)
        return try parseInsightResult(json)
    }

    // MARK: - 跨灵感聚类

    func cluster(summaries: String) async throws -> CloudClusterResult {
        let prompt = """
        你是洞察分析师。下面是用户最近的灵感列表，请发现共同主题。
        返回严格的 JSON：
        {
          "summary": "一句话用户画像",
          "themes": [{"name": "主题名", "description": "30字描述", "relatedKeywords": ["关键词"]}],
          "nextActions": ["行动建议1", "建议2", "建议3"]
        }
        用中文。

        灵感列表：
        \(summaries)
        """

        let json = try await callAPI(prompt: prompt, maxTokens: 1200)
        return try parseClusterResult(json)
    }

    // MARK: - 截图视觉分析（一步法：GLM-4.1V-Thinking）
    //
    // 之前：Vision OCR → 拿文字 → 发给文本模型 = 2 次调用
    // 现在：直接把图片发给 GLM-4.1V-Thinking = 1 次调用
    // GLM-4.1V-Thinking 会"思考"图片内容，同时完成 OCR + 理解 + 分析

    func analyzeImage(imageData: Data) async throws -> CloudInsightResult {
        guard !apiKey.isEmpty else { throw CloudAIError.noAPIKey }

        let base64 = imageData.base64EncodedString()

        let prompt = """
        请深度分析这张截图。不仅仅是 OCR 文字，更要理解截图想表达什么。
        比如：穿搭截图 → 分析色彩搭配逻辑；会议截图 → 提炼核心结论；产品截图 → 发现设计亮点。

        返回严格的 JSON，不要 markdown 包裹：
        {
          "summary": "30-50 字总结截图的核心内容和价值",
          "category": "社媒灵感/会议记录/产品想法/学习笔记/生活待办/聊天截图/其他",
          "tags": ["3-5 个分类标签"],
          "keywords": ["3-5 个具体关键词"],
          "insight": "50 字延伸思考或行动建议（基于你对图片的深度理解）"
        }
        用中文。
        """

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60  // 视觉模型可能慢一些

        let body: [String: Any] = [
            "model": visionModel,
            "max_tokens": 1200,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "text", "text": prompt],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]]
                ]
            ]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw CloudAIError.apiError(statusCode: statusCode,
                                         body: String(data: data, encoding: .utf8) ?? "")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw CloudAIError.invalidResponse
        }

        return try parseInsightResult(content)
    }

    // MARK: - 底层 API 调用（文本）

    private func callAPI(prompt: String, maxTokens: Int) async throws -> String {
        guard !apiKey.isEmpty else {
            throw CloudAIError.noAPIKey
        }

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": textModel,
            "max_tokens": maxTokens,
            "temperature": 0.3,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw CloudAIError.apiError(statusCode: statusCode,
                                         body: String(data: data, encoding: .utf8) ?? "")
        }

        // 解析 OpenAI 兼容的响应格式
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw CloudAIError.invalidResponse
        }

        return content
    }

    // MARK: - JSON 解析

    private func parseInsightResult(_ text: String) throws -> CloudInsightResult {
        let cleaned = cleanJSON(text)
        let data = cleaned.data(using: .utf8) ?? Data()
        return try JSONDecoder().decode(CloudInsightResult.self, from: data)
    }

    private func parseClusterResult(_ text: String) throws -> CloudClusterResult {
        let cleaned = cleanJSON(text)
        let data = cleaned.data(using: .utf8) ?? Data()
        return try JSONDecoder().decode(CloudClusterResult.self, from: data)
    }

    /// 清理 LLM 返回的 JSON（移除 markdown 包裹）
    private func cleanJSON(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            let lines = s.components(separatedBy: "\n")
            let filtered = lines.dropFirst().reversed().drop(while: { $0.hasPrefix("```") }).reversed()
            s = filtered.joined(separator: "\n")
        }
        if s.hasPrefix("json") {
            s = String(s.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // 找到第一个 { 和最后一个 }
        if let start = s.firstIndex(of: "{"), let end = s.lastIndex(of: "}") {
            s = String(s[start...end])
        }
        return s
    }
}


// MARK: - 数据类型

struct CloudInsightResult: Codable, Sendable {
    let summary: String
    let category: String
    let tags: [String]
    let keywords: [String]
    let insight: String
}

struct CloudClusterResult: Codable, Sendable {
    let summary: String
    let themes: [CloudTheme]
    let nextActions: [String]
}

struct CloudTheme: Codable, Sendable {
    let name: String
    let description: String
    let relatedKeywords: [String]
}

enum CloudAIError: LocalizedError, Sendable {
    case noAPIKey
    case apiError(statusCode: Int, body: String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "未配置智谱 API Key。请在设置里输入。"
        case .apiError(let code, let body):
            return "API 错误 (\(code)): \(body.prefix(200))"
        case .invalidResponse:
            return "AI 返回格式异常"
        }
    }
}
