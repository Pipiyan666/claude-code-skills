import UIKit
import Social
import UniformTypeIdentifiers
import SwiftData

// MARK: - ShareViewController — Share Extension 核心
//
// 从小红书/抖音/Safari/微信分享内容到『灵感胶囊』的入口。
//
// 用户操作：
//   1. 在小红书看到好笔记 → 分享菜单
//   2. 选择「灵感胶囊」
//   3. 系统弹出极简卡片（含标题和 AI 摘要预览）
//   4. 用户点「保存」→ 完成
//
// 全程不需要打开主 App。
//
// 技术要点：
//   - 用 App Group 共享主 App 的 SwiftData container
//   - 支持 URL / Text / Image 三种分享类型
//   - 分享后静默跑 AI 分析（异步），不阻塞用户

class ShareViewController: UIViewController {

    // MARK: - UI

    private let loadingLabel = UILabel()
    private let summaryLabel = UILabel()
    private let saveButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        processShareItem()
    }

    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground

        // 标题
        let titleLabel = UILabel()
        titleLabel.text = "💡 灵感胶囊"
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // Loading
        loadingLabel.text = "正在分析..."
        loadingLabel.font = .systemFont(ofSize: 16)
        loadingLabel.textColor = .secondaryLabel
        loadingLabel.textAlignment = .center
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingLabel)

        // Summary
        summaryLabel.numberOfLines = 0
        summaryLabel.font = .systemFont(ofSize: 15)
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(summaryLabel)

        // 保存按钮
        saveButton.setTitle("✨ 保存到知识库", for: .normal)
        saveButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        saveButton.backgroundColor = .systemPink
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 14
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.addTarget(self, action: #selector(saveAndDismiss), for: .touchUpInside)
        saveButton.isHidden = true
        view.addSubview(saveButton)

        // 取消按钮
        cancelButton.setTitle("取消", for: .normal)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelShare), for: .touchUpInside)
        view.addSubview(cancelButton)

        // 约束
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            loadingLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            loadingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            summaryLabel.topAnchor.constraint(equalTo: loadingLabel.bottomAnchor, constant: 24),
            summaryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            summaryLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            saveButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            saveButton.bottomAnchor.constraint(equalTo: cancelButton.topAnchor, constant: -16),
            saveButton.widthAnchor.constraint(equalToConstant: 220),
            saveButton.heightAnchor.constraint(equalToConstant: 50),

            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
        ])
    }

    // MARK: - 处理分享内容

    private var pendingInsight: Insight?

    private func processShareItem() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else {
            cancelShare()
            return
        }

        Task {
            // 优先级：URL > Text > Image
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    await handleURL(provider: provider)
                    return
                }
            }
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    await handleText(provider: provider)
                    return
                }
            }
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    await handleImage(provider: provider)
                    return
                }
            }
        }
    }

    // MARK: - URL 分享（最常见：从小红书/微博/知乎分享链接）

    private func handleURL(provider: NSItemProvider) async {
        do {
            let url = try await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL
            guard let url else { return }

            // 抓取页面内容
            let (title, content) = try await fetchURLContent(url)
            let combined = "[\(title)]\n\(content)\n\n来源: \(url.absoluteString)"

            // 调用主 App 的 Store 处理
            let store = try await SharedStore.instance()
            let insight = try await store.processText(combined)
            insight.sourceURL = url.absoluteString

            await MainActor.run {
                self.pendingInsight = insight
                self.showResult(insight)
            }
        } catch {
            await MainActor.run { self.showError(error.localizedDescription) }
        }
    }

    // MARK: - Text 分享

    private func handleText(provider: NSItemProvider) async {
        do {
            let text = try await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String
            guard let text else { return }

            let store = try await SharedStore.instance()
            let insight = try await store.processText(text)

            await MainActor.run {
                self.pendingInsight = insight
                self.showResult(insight)
            }
        } catch {
            await MainActor.run { self.showError(error.localizedDescription) }
        }
    }

    // MARK: - Image 分享

    private func handleImage(provider: NSItemProvider) async {
        do {
            guard let url = try await provider.loadItem(forTypeIdentifier: UTType.image.identifier) as? URL,
                  let imageData = try? Data(contentsOf: url),
                  let image = UIImage(data: imageData) else {
                throw ShareError.invalidImage
            }

            let store = try await SharedStore.instance()
            let insight = try await store.processImage(image)

            await MainActor.run {
                self.pendingInsight = insight
                self.showResult(insight)
            }
        } catch {
            await MainActor.run { self.showError(error.localizedDescription) }
        }
    }

    // MARK: - 极简 HTML 抓取

    private func fetchURLContent(_ url: URL) async throws -> (title: String, content: String) {
        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X)",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else {
            return ("未知标题", "无法解析页面")
        }

        // 极简 title / 正文提取
        let title = extractTitle(from: html) ?? url.host ?? "分享内容"
        let content = extractText(from: html)
        return (title, content)
    }

    private func extractTitle(from html: String) -> String? {
        guard let range = html.range(of: #"<title[^>]*>([^<]+)</title>"#, options: .regularExpression) else {
            return nil
        }
        let titleTag = String(html[range])
        return titleTag
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractText(from html: String) -> String {
        // 去掉 script / style / tag
        var text = html
        text = text.replacingOccurrences(of: #"<script[^>]*>.*?</script>"#, with: " ", options: [.regularExpression, .dotMatchesLineSeparators, .caseInsensitive])
        text = text.replacingOccurrences(of: #"<style[^>]*>.*?</style>"#, with: " ", options: [.regularExpression, .dotMatchesLineSeparators, .caseInsensitive])
        text = text.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return String(text.prefix(2000))
    }

    // MARK: - UI 更新

    private func showResult(_ insight: Insight) {
        loadingLabel.text = "✅ 分析完成"
        summaryLabel.text = """
        📋 \(insight.summary)

        📂 \(insight.category)
        🏷️ \(insight.tags.joined(separator: "  "))

        💡 \(insight.aiInsight)
        """
        saveButton.isHidden = false
    }

    private func showError(_ message: String) {
        loadingLabel.text = "❌ 出错了"
        summaryLabel.text = message
    }

    @objc private func saveAndDismiss() {
        // 已经在 handle... 阶段保存了，这里只是 complete context
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    @objc private func cancelShare() {
        // 如果 pendingInsight 存在但用户取消，需要回滚
        if let insight = pendingInsight {
            Task {
                let store = try? await SharedStore.instance()
                // TODO: 实现 delete
                _ = store
                _ = insight
            }
        }
        extensionContext?.cancelRequest(withError: NSError(
            domain: "com.ideacapsule.share",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "用户取消"]
        ))
    }
}


enum ShareError: LocalizedError {
    case invalidImage
    case urlFetchFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "图片格式无效"
        case .urlFetchFailed: return "无法抓取页面内容"
        }
    }
}
