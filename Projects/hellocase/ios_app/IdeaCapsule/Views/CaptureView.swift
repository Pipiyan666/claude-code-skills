import SwiftUI
import PhotosUI
import SwiftData

// MARK: - CaptureView — 灵感捕获页（核心入口）
//
// 三种输入方式：
//   📷 从相册选截图（PhotosPicker）
//   📝 手打文字（TextEditor）
//   🔗 粘贴社媒链接（剪贴板检测）
//
// UI 用 iOS 26 Liquid Glass 设计：
//   - 大按钮带 .glassEffect(.regular.tint(...).interactive())
//   - GlassEffectContainer 包裹相关元素
//   - .buttonStyle(.glassProminent) 主按钮

struct CaptureView: View {
    @Environment(CapsuleStore.self) private var store
    @State private var viewModel = CaptureViewModel()
    @State private var selectedItem: PhotosPickerItem?
    @Namespace private var glassNamespace

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection

                    GlassEffectContainer(spacing: 16) {
                        VStack(spacing: 16) {
                            inputModeSelector
                            inputArea
                            actionButton
                        }
                    }

                    if viewModel.isProcessing {
                        ProgressView("AI 正在分析…")
                            .padding()
                    }

                    if let result = viewModel.lastResult {
                        ResultCard(insight: result)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding()
            }
            .navigationTitle("捕获灵感")
            .background(
                LinearGradient(
                    colors: [.pink.opacity(0.1), .purple.opacity(0.1), .blue.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .onChange(of: selectedItem) { _, item in
                Task { await viewModel.processPickedImage(item: item, store: store) }
            }
        }
    }

    // MARK: - 子视图

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("✨ 灵感胶囊")
                .font(.largeTitle.bold())
            Text("不删截图，让截图为你工作")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top)
    }

    private var inputModeSelector: some View {
        Picker("", selection: $viewModel.mode) {
            Label("截图", systemImage: "camera").tag(CaptureMode.image)
            Label("文字", systemImage: "text.alignleft").tag(CaptureMode.text)
            Label("链接", systemImage: "link").tag(CaptureMode.link)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var inputArea: some View {
        switch viewModel.mode {
        case .image:
            PhotosPicker(selection: $selectedItem, matching: .images) {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)
                    Text("从相册选择截图")
                        .font(.headline)
                    Text("点这里 → 选一张小红书/抖音截图")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 160)
                .padding()
                .glassEffect(.regular.tint(.pink.opacity(0.2)).interactive(),
                             in: .rect(cornerRadius: 20))
            }

        case .text:
            TextEditor(text: $viewModel.textInput)
                .frame(minHeight: 160)
                .padding(8)
                .glassEffect(.regular.tint(.blue.opacity(0.1)),
                             in: .rect(cornerRadius: 16))
                .overlay(alignment: .topLeading) {
                    if viewModel.textInput.isEmpty {
                        Text("粘贴小红书笔记 / 写下你的想法…")
                            .foregroundStyle(.secondary)
                            .padding(16)
                            .allowsHitTesting(false)
                    }
                }

        case .link:
            VStack(spacing: 12) {
                TextField("https://www.xiaohongshu.com/...", text: $viewModel.linkInput)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .glassEffect(.regular.tint(.purple.opacity(0.1)),
                                 in: .rect(cornerRadius: 16))

                Button {
                    viewModel.pasteFromClipboard()
                } label: {
                    Label("从剪贴板粘贴", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.glass)
            }
        }
    }

    private var actionButton: some View {
        Button {
            Task { await viewModel.processInput(store: store) }
        } label: {
            Label("✨ AI 分析", systemImage: "wand.and.stars")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.glassProminent)
        .disabled(viewModel.canSubmit == false || viewModel.isProcessing)
    }
}


// MARK: - ViewModel

enum CaptureMode {
    case image, text, link
}

@Observable
final class CaptureViewModel {
    var mode: CaptureMode = .image
    var textInput: String = ""
    var linkInput: String = ""
    var isProcessing: Bool = false
    var lastResult: Insight?
    var errorMessage: String?

    var canSubmit: Bool {
        switch mode {
        case .image: return false  // 由 PhotosPicker 触发
        case .text: return !textInput.trimmingCharacters(in: .whitespaces).isEmpty
        case .link: return !linkInput.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    @MainActor
    func processInput(store: CapsuleStore) async {
        switch mode {
        case .text where !textInput.isEmpty:
            await runProcessing { try await store.processText(self.textInput) }
            textInput = ""
        case .link where !linkInput.isEmpty:
            // V1.1: fetch URL → AIService.extractFromLink
            errorMessage = "链接解析将在 V1.1 上线"
        default:
            break
        }
    }

    @MainActor
    func processPickedImage(item: PhotosPickerItem?, store: CapsuleStore) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }

        await runProcessing { try await store.processImage(image) }
    }

    func pasteFromClipboard() {
        if let str = UIPasteboard.general.string {
            linkInput = str
        }
    }

    @MainActor
    private func runProcessing(_ action: () async throws -> Insight) async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            lastResult = try await action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
