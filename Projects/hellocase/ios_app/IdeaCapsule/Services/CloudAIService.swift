import Foundation

// MARK: - CloudAIService — 云端 AI 降级方案（智谱 GLM-4）
//
// 当 Apple FoundationModels 不可用时（未启用 / 旧设备 / 模型没下载完），
// 自动降级到智谱 GLM-4 API。用 URLSession 直接调用，不引入任何第三方 SDK。
//
// 这就是 IOS_TECH_EVOLUTION.md 里设计的"双轨模型路由器"的实现。

actor CloudAIService {
    static let shared = CloudAIService()

    // API 配置（Kimi K2.5 中转 — OpenAI 兼容格式）
    private var apiKey: String = ""
    private var baseURL = "https://kimi.a7m.com.cn/v1/chat/completions"

    // Kimi K2.5：编码和推理都极强，带 thinking（链式推理）
    var textModel = "kimi-for-coding"
    var visionModel = "kimi-for-coding"  // K2.5 也支持视觉

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
        print("[CloudAI] 视觉分析，图片 \(imageData.count / 1024)KB")

        // 纯字符串拼接 JSON（零框架依赖，彻底避免 NSNumber crash）
        let rawJSON = "{\"model\":\"\(visionModel)\",\"max_tokens\":800,\"messages\":[{\"role\":\"user\",\"content\":[{\"type\":\"text\",\"text\":\"Analyze this screenshot. Return JSON only: {\\\"summary\\\":\\\"30 char Chinese summary\\\",\\\"category\\\":\\\"other\\\",\\\"tags\\\":[\\\"tag1\\\"],\\\"keywords\\\":[\\\"kw1\\\"],\\\"insight\\\":\\\"action suggestion\\\"}. Respond in Chinese.\"},{\"type\":\"image_url\",\"image_url\":{\"url\":\"data:image/jpeg;base64,\(base64)\"}}]}]}"

        guard let bodyData = rawJSON.data(using: .utf8) else {
            throw CloudAIError.invalidResponse
        }

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = bodyData
        print("[CloudAI] 请求已发送...")

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("[CloudAI] 响应: HTTP \(code)")

        guard (200...299).contains(code) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[CloudAI] ❌ \(body.prefix(200))")
            throw CloudAIError.apiError(statusCode: code, body: body)
        }

        // 解析响应（也用手动方式，不依赖 JSONSerialization）
        guard let responseStr = String(data: data, encoding: .utf8) else {
            throw CloudAIError.invalidResponse
        }

        // 提取 content 字段
        guard let contentStart = responseStr.range(of: "\"content\":\""),
              let contentEnd = responseStr.range(of: "\"},\"logprobs\"", range: contentStart.upperBound..<responseStr.endIndex)
                ?? responseStr.range(of: "\"},\"refusal\"", range: contentStart.upperBound..<responseStr.endIndex)
                ?? responseStr.range(of: "\"}", range: contentStart.upperBound..<responseStr.endIndex)
        else {
            // Fallback: 用 JSONSerialization 解析响应（请求构建已经不用了）
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let msg = choices.first?["message"] as? [String: Any],
                  let content = msg["content"] as? String else {
                throw CloudAIError.invalidResponse
            }
            print("[CloudAI] ✅ (fallback) \(content.prefix(60))")
            return try parseInsightResult(content)
        }

        let rawContent = String(responseStr[contentStart.upperBound..<contentEnd.lowerBound])
        // unescape JSON string
        let content = rawContent
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\\\", with: "\\")

        print("[CloudAI] ✅ \(content.prefix(60))")
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
        request.timeoutInterval = 15
        print("[CloudAI] 调用 \(textModel) ...")

        // 用 Codable 构建 JSON（避免 [String: Any] 桥接 NSNumber 的 crash）
        struct APIRequest: Encodable {
            let model: String
            let max_tokens: Int
            let messages: [Message]
            struct Message: Encodable {
                let role: String
                let content: String
            }
        }
        let apiReq = APIRequest(
            model: textModel,
            max_tokens: maxTokens,
            messages: [.init(role: "user", content: prompt)]
        )
        request.httpBody = try JSONEncoder().encode(apiReq)

        let (data, response) = try await URLSession.shared.data(for: request)

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("[CloudAI] 响应: HTTP \(statusCode)")

        guard (200...299).contains(statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[CloudAI] ❌ 错误: \(body.prefix(200))")
            throw CloudAIError.apiError(statusCode: statusCode, body: body)
        }

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
