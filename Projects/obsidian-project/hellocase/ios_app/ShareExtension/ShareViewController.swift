import UIKit
import Social
import UniformTypeIdentifiers
import SwiftData
import UserNotifications

// MARK: - ShareViewController — Share Extension 核心
//
// 从小红书/抖音/Safari/微信分享内容到『灵感胶囊』的入口。
//
// 用户操作：
//   1. 在小红书看到好笔记 → 分享菜单
//   2. 选择「灵感胶囊」
//   3. 系统弹出极简卡片（含标题和 AI 摘要预览）
//   4. 用户点「保存」→ 完成 + 通知反馈
//
// 全程不需要打开主 App。

class ShareViewController: UIViewController {

    // MARK: - UI 组件

    private let cardView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let loadingLabel = UILabel()
    private let summaryLabel = UILabel()
    private let tagsStackView = UIStackView()
    private let saveButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    // MARK: - 状态

    private var pendingInsight: Insight?
    private var insightSummary: String = ""

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        requestNotificationPermission()
        processShareItem()
    }

    // MARK: - UI 设置

    private func setupUI() {
        // 背景渐变
        view.backgroundColor = UIColor(red: 0.99, green: 0.97, blue: 0.95, alpha: 1.0)

        // 卡片容器
        cardView.backgroundColor = .white
        cardView.layer.cornerRadius = 20
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.08
        cardView.layer.shadowOffset = CGSize(width: 0, height: 4)
        cardView.layer.shadowRadius = 16
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        // App 图标
        iconImageView.image = UIImage(systemName: "sparkle")
        iconImageView.tintColor = UIColor(red: 0.94, green: 0.35, blue: 0.31, alpha: 1.0)
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(iconImageView)

        // 标题
        titleLabel.text = "灵感胶囊"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = UIColor(red: 0.10, green: 0.13, blue: 0.17, alpha: 1.0)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)

        // Loading 指示器
        activityIndicator.color = UIColor(red: 0.94, green: 0.35, blue: 0.31, alpha: 1.0)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        cardView.addSubview(activityIndicator)

        // Loading 文字
        loadingLabel.text = "AI 正在阅读..."
        loadingLabel.font = .systemFont(ofSize: 15, weight: .medium)
        loadingLabel.textColor = .secondaryLabel
        loadingLabel.textAlignment = .center
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(loadingLabel)

        // 摘要标签
        summaryLabel.numberOfLines = 0
        summaryLabel.font = .systemFont(ofSize: 16, weight: .regular)
        summaryLabel.textColor = UIColor(red: 0.37, green: 0.39, blue: 0.44, alpha: 1.0)
        summaryLabel.textAlignment = .left
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(summaryLabel)

        // 标签容器
        tagsStackView.axis = .horizontal
        tagsStackView.spacing = 8
        tagsStackView.alignment = .leading
        tagsStackView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(tagsStackView)

        // 保存按钮
        saveButton.setTitle("✨ 保存到知识库", for: .normal)
        saveButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        saveButton.backgroundColor = UIColor(red: 0.10, green: 0.13, blue: 0.17, alpha: 1.0)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 14
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.addTarget(self, action: #selector(saveAndDismiss), for: .touchUpInside)
        saveButton.isHidden = true
        cardView.addSubview(saveButton)

        // 取消按钮
        cancelButton.setTitle("取消", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        cancelButton.setTitleColor(UIColor(red: 0.10, green: 0.13, blue: 0.17, alpha: 1.0).withAlphaComponent(0.6), for: .normal)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelShare), for: .touchUpInside)
        view.addSubview(cancelButton)

        // 布局约束
        NSLayoutConstraint.activate([
            // 卡片居中
            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            // 图标
            iconImageView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 24),
            iconImageView.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 48),
            iconImageView.heightAnchor.constraint(equalToConstant: 48),

            // 标题
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 12),
            titleLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),

            // Loading 指示器
            activityIndicator.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            activityIndicator.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),

            // Loading 文字
            loadingLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 12),
            loadingLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),

            // 摘要
            summaryLabel.topAnchor.constraint(equalTo: loadingLabel.bottomAnchor, constant: 20),
            summaryLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            summaryLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),

            // 标签容器
            tagsStackView.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: 12),
            tagsStackView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            tagsStackView.trailingAnchor.constraint(lessThanOrEqualTo: cardView.trailingAnchor, constant: -20),

            // 保存按钮
            saveButton.topAnchor.constraint(equalTo: tagsStackView.bottomAnchor, constant: 20),
            saveButton.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            saveButton.widthAnchor.constraint(equalToConstant: 200),
            saveButton.heightAnchor.constraint(equalToConstant: 50),
            saveButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20),

            // 取消按钮
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
    }

    // MARK: - 通知权限

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("[ShareExtension] 通知权限已授予")
            }
        }
    }

    // MARK: - 处理分享内容

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

    // MARK: - URL 分享

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
                self.insightSummary = insight.summary
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
                self.insightSummary = insight.summary
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
                self.insightSummary = insight.summary
                self.showResult(insight)
            }
        } catch {
            await MainActor.run { self.showError(error.localizedDescription) }
        }
    }

    // MARK: - HTML 抓取

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
        var text = html
        // 使用 NSRegularExpression 处理跨行匹配
        let scriptPattern = #"<script[^>]*>.*?</script>"#
        let stylePattern = #"<style[^>]*>.*?</style>"#

        if let scriptRegex = try? NSRegularExpression(pattern: scriptPattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) {
            text = scriptRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: " ")
        }
        if let styleRegex = try? NSRegularExpression(pattern: stylePattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) {
            text = styleRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: " ")
        }

        text = text.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return String(text.prefix(2000))
    }

    // MARK: - UI 更新

    private func showResult(_ insight: Insight) {
        // 停止 Loading
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true

        // 更新标题
        loadingLabel.text = "✨ 分析完成"
        loadingLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        loadingLabel.textColor = UIColor(red: 0.42, green: 0.69, blue: 0.59, alpha: 1.0)

        // 显示摘要
        summaryLabel.text = insight.summary

        // 添加标签
        tagsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // 分类标签
        let categoryTag = createTag(insight.category, color: UIColor(red: 0.94, green: 0.35, blue: 0.31, alpha: 1.0))
        tagsStackView.addArrangedSubview(categoryTag)

        // 其他标签（最多 3 个）
        for tag in insight.tags.prefix(3) {
            let tagView = createTag("#\(tag)", color: UIColor(red: 0.42, green: 0.69, blue: 0.59, alpha: 1.0))
            tagsStackView.addArrangedSubview(tagView)
        }

        // 显示保存按钮
        saveButton.isHidden = false

        // 添加淡入动画
        summaryLabel.alpha = 0
        tagsStackView.alpha = 0
        saveButton.alpha = 0

        UIView.animate(withDuration: 0.3, delay: 0.1, options: .curveEaseOut) {
            self.summaryLabel.alpha = 1
            self.tagsStackView.alpha = 1
            self.saveButton.alpha = 1
        }
    }

    private func createTag(_ text: String, color: UIColor) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = color.withAlphaComponent(0.12)
        containerView.layer.cornerRadius = 6

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = color
        label.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 4),
            label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
            label.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -4),
        ])

        return containerView
    }

    private func showError(_ message: String) {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true

        loadingLabel.text = "❌ 出错了"
        loadingLabel.textColor = UIColor(red: 0.94, green: 0.35, blue: 0.31, alpha: 1.0)

        summaryLabel.text = message
        summaryLabel.textColor = UIColor(red: 0.94, green: 0.35, blue: 0.31, alpha: 1.0)
    }

    // MARK: - 按钮操作

    @objc private func saveAndDismiss() {
        // 发送通知
        sendSuccessNotification()

        // 完成
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    @objc private func cancelShare() {
        // 如果 pendingInsight 存在但用户取消，删除它
        if let insight = pendingInsight {
            Task {
                let store = try? await SharedStore.instance()
                try? store?.delete(insight)
            }
        }
        extensionContext?.cancelRequest(withError: NSError(
            domain: "com.ideacapsule.share",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "用户取消"]
        ))
    }

    // MARK: - 通知

    private func sendSuccessNotification() {
        let content = UNMutableNotificationContent()
        content.title = "✨ 已保存到灵感胶囊"
        content.body = insightSummary.isEmpty ? "你的灵感已安全保存" : insightSummary
        content.sound = .default

        // 点击通知跳转到主 App
        content.userInfo = ["openApp": true]

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[ShareExtension] 通知发送失败: \(error)")
            } else {
                print("[ShareExtension] ✅ 通知已发送")
            }
        }
    }
}


// MARK: - 错误类型

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
