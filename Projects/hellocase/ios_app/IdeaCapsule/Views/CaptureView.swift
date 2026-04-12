import SwiftUI
import Speech
import AVFoundation
import PhotosUI
import SwiftData

// MARK: - CaptureView — 灵感捕获页（Editorial Diary 风格）
//
// 设计哲学：像翻开一本空白日记本的第一页。
//   - 顶部 hero：大 serif 斜体标题 + 小小的装饰性 label
//   - 中间 scroll 区：三种输入方式用"卡片化"的方式呈现，每张卡片都有自己的编辑语气
//   - 底部：主 CTA 按钮是墨蓝底奶油字，大气克制
//
// 避免：
//   ❌ 生硬的 Picker + TextEditor 堆砌
//   ❌ 彩色渐变按钮
//   ❌ 圆润到有点幼稚的设计

struct CaptureView: View {
    @Environment(CapsuleStore.self) private var store
    @State private var viewModel = CaptureViewModel()
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                heroSection
                modeSelector
                inputArea

                // 已选截图预览 + 分析按钮
                if !selectedImages.isEmpty && viewModel.mode == .image {
                    selectedImagesPreview
                    analyzeImagesButton
                }

                // 文字/链接模式的按钮
                if viewModel.mode != .image {
                    actionButton
                }

                if viewModel.isProcessing {
                    ProcessingIndicator()
                        .transition(.opacity.combined(with: .offset(y: 10)))
                }

                // 错误信息（不再无限转圈）
                if let error = viewModel.errorMessage {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(Theme.Colors.coral)
                        Text(error)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.coral)
                    }
                    .padding(Theme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.coral.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if let result = viewModel.lastResult {
                    ResultCard(insight: result)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 30)),
                            removal: .opacity
                        ))
                }

                Spacer().frame(height: 120)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.xl)
        }
        .onChange(of: selectedItems) { _, items in
            Task { await loadSelectedImages(items) }
        }
    }

    /// 把 PhotosPickerItem 转成 UIImage 预览
    private func loadSelectedImages(_ items: [PhotosPickerItem]) async {
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        await MainActor.run {
            withAnimation(Theme.Motion.emphasized) {
                selectedImages = images
            }
        }
    }

    // MARK: - Hero 区

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Rectangle()
                    .fill(Theme.Colors.coral)
                    .frame(width: 32, height: 2)
                Text("INKLINGS · NO. \(Date.now.dayOfYear)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(Theme.Colors.coral)
            }

            Text("今天，有什么\n让你停下的？")
                .font(Theme.Typography.hero)
                .foregroundStyle(Theme.Colors.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("不删截图，让截图为你工作。")
                .font(Theme.Typography.bodyEmphasis)
                .foregroundStyle(Theme.Colors.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Mode 选择器（Editorial 风格）

    private var modeSelector: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(CaptureMode.allCases, id: \.self) { mode in
                ModePill(
                    mode: mode,
                    isSelected: viewModel.mode == mode
                ) {
                    withAnimation(Theme.Motion.emphasized) {
                        viewModel.mode = mode
                    }
                }
            }
        }
    }

    // MARK: - 输入区

    @ViewBuilder
    private var inputArea: some View {
        switch viewModel.mode {
        case .image:
            imageInputCard
        case .text:
            textInputCard
        case .voice:
            voiceInputCard
        case .link:
            linkInputCard
        }
    }

    private var imageInputCard: some View {
        PhotosPicker(
            selection: $selectedItems,
            maxSelectionCount: 9,
            matching: .images
        ) {
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: selectedImages.isEmpty ? "photo.stack" : "photo.badge.plus")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Theme.Colors.coral)
                Text(selectedImages.isEmpty ? "从相册选择截图" : "重新选择")
                    .font(Theme.Typography.subheading)
                    .foregroundStyle(Theme.Colors.ink)
                Text("小红书 · 会议 · PPT · 待办 · 最多 9 张")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.inkSoft)
            }
            .frame(maxWidth: .infinity, minHeight: selectedImages.isEmpty ? 180 : 100)
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.paper)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
    }

    /// 已选截图缩略图网格
    private var selectedImagesPreview: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("已选 \(selectedImages.count) 张")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.inkSoft)
                Spacer()
                Button {
                    withAnimation(Theme.Motion.emphasized) {
                        selectedItems = []
                        selectedImages = []
                    }
                } label: {
                    Text("清除")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.coral)
                }
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
            ], spacing: 8) {
                ForEach(Array(selectedImages.enumerated()), id: \.offset) { idx, image in
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Theme.Colors.hairline, lineWidth: 1)
                        )
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.paper)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    /// 分析已选截图的按钮
    private var analyzeImagesButton: some View {
        Button {
            Task { await viewModel.processSelectedImages(selectedImages, store: store) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkle")
                    .font(.system(size: 14, weight: .semibold))
                Text("分析 \(selectedImages.count) 张截图")
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
            }
            .editorialButton()
        }
        .disabled(viewModel.isProcessing)
        .opacity(viewModel.isProcessing ? 0.4 : 1)
    }

    private var textInputCard: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $viewModel.textInput)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.ink)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 180)
                .padding(Theme.Spacing.md)

            if viewModel.textInput.isEmpty {
                Text("\u{201C}写下闪过脑海的那一刻...")
                    .font(Theme.Typography.bodyEmphasis)
                    .foregroundStyle(Theme.Colors.inkMuted)
                    .padding(.top, Theme.Spacing.md + 8)
                    .padding(.leading, Theme.Spacing.md + 5)
                    .allowsHitTesting(false)
            }
        }
        .background(Theme.Colors.paper)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(Theme.Colors.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .modifier(Theme.Shadows.card())
    }

    private var voiceInputCard: some View {
        VStack(spacing: Theme.Spacing.md) {
            Button {
                if viewModel.isRecording {
                    viewModel.stopRecording()
                } else {
                    viewModel.startRecording()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(viewModel.isRecording ? Theme.Colors.coral : Theme.Colors.coral.opacity(0.12))
                        .frame(width: 88, height: 88)
                    Circle()
                        .fill(viewModel.isRecording ? Theme.Colors.ink : Theme.Colors.coral)
                        .frame(width: 64, height: 64)
                    Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Theme.Colors.cream)
                }
            }
            .buttonStyle(.plain)

            Text(viewModel.isRecording ? "点击停止" : "点击开始说话")
                .font(Theme.Typography.subheading)
                .foregroundStyle(Theme.Colors.ink)

            if !viewModel.voiceText.isEmpty {
                Text(viewModel.voiceText)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.ink)
                    .padding(Theme.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.ivory)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if let err = viewModel.voiceError {
                Text(err)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.coral)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.paper)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
    private var linkInputCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            TextField("", text: $viewModel.linkInput, prompt:
                Text("粘贴小红书 / 抖音链接")
                    .font(Theme.Typography.bodyEmphasis)
                    .foregroundStyle(Theme.Colors.inkMuted)
            )
            .font(Theme.Typography.body)
            .textContentType(.URL)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            Divider()
                .foregroundStyle(Theme.Colors.hairline)

            Button {
                viewModel.pasteFromClipboard()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 12))
                    Text("从剪贴板粘贴")
                }
            }
            .editorialButtonSecondary()
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.paper)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(Theme.Colors.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .modifier(Theme.Shadows.card())
    }

    // MARK: - CTA 按钮

    private var actionButton: some View {
        Button {
            Task { await viewModel.processInput(store: store) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkle")
                    .font(.system(size: 14, weight: .semibold))
                Text("让 AI 慢慢读")
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
            }
            .editorialButton()
        }
        .disabled(!viewModel.canSubmit || viewModel.isProcessing)
        .opacity(viewModel.canSubmit && !viewModel.isProcessing ? 1 : 0.4)
    }
}


// MARK: - Mode Pill

private struct ModePill: View {
    let mode: CaptureMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: mode.icon)
                    .font(.system(size: 14, weight: .medium))
                Text(mode.label)
                    .font(.system(size: 11, weight: .medium, design: .serif).italic())
            }
            .foregroundStyle(isSelected ? Theme.Colors.cream : Theme.Colors.ink)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Theme.Colors.ink : Theme.Colors.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.Colors.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Processing 指示器

private struct ProcessingIndicator: View {
    @State private var isAnimating = false
    @State private var elapsed: Int = 0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var statusText: String {
        if elapsed < 3 { return "AI 正在看图..." }
        if elapsed < 8 { return "正在深度理解（约 10 秒）..." }
        if elapsed < 15 { return "K2.5 在思考中... \(elapsed)s" }
        return "网络较慢，请稍等... \(elapsed)s"
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                HStack(spacing: 6) {
                    ForEach(0..<3) { idx in
                        Circle()
                            .fill(Theme.Colors.coral)
                            .frame(width: 6, height: 6)
                            .scaleEffect(isAnimating ? 1.2 : 0.6)
                            .animation(
                                .easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(idx) * 0.15),
                                value: isAnimating
                            )
                    }
                }

                Text(statusText)
                    .font(Theme.Typography.bodyEmphasis)
                    .foregroundStyle(Theme.Colors.inkSoft)
                    .contentTransition(.numericText())
            }

            // 进度条
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.Colors.ivory)
                    .frame(height: 3)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.Colors.coral)
                            .frame(width: min(geo.size.width, geo.size.width * CGFloat(elapsed) / 15.0), height: 3)
                            .animation(.linear(duration: 1), value: elapsed)
                    }
            }
            .frame(height: 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { isAnimating = true }
        .onReceive(timer) { _ in elapsed += 1 }
    }
}


// MARK: - ViewModel

enum CaptureMode: String, CaseIterable {
    case image, text, voice, link

    var label: String {
        switch self {
        case .image: "截图"
        case .text:  "文字"
        case .voice: "语音"
        case .link:  "链接"
        }
    }

    var icon: String {
        switch self {
        case .image: "photo.on.rectangle"
        case .text:  "square.and.pencil"
        case .voice: "waveform"
        case .link:  "link"
        }
    }
}


@Observable
final class CaptureViewModel {
    var mode: CaptureMode = .image
    var textInput: String = ""
    var linkInput: String = ""
    var isProcessing: Bool = false
    var lastResult: Insight?
    var errorMessage: String?

    var isRecording: Bool = false
    var voiceText: String = ""
    var voiceError: String? = nil
    private var audioEngine: AVAudioEngine?
    private var recognitionTask: SFSpeechRecognitionTask?

    var canSubmit: Bool {
        switch mode {
        case .image: return false
        case .text:  return !textInput.trimmingCharacters(in: .whitespaces).isEmpty
        case .voice: return !voiceText.trimmingCharacters(in: .whitespaces).isEmpty
        case .link:  return !linkInput.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    @MainActor func startRecording() {
        voiceError = nil
        voiceText = ""
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                if status == .authorized {
                    self.doStartRecording()
                } else {
                    self.voiceError = "请在设置里允许语音识别权限"
                }
            }
        }
    }

    @MainActor private func doStartRecording() {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")),
              recognizer.isAvailable else {
            voiceError = "语音识别不可用"
            return
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        let engine = AVAudioEngine()
        let node = engine.inputNode
        let fmt = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: fmt) { buf, _ in
            request.append(buf)
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement)
            try AVAudioSession.sharedInstance().setActive(true)
            engine.prepare()
            try engine.start()
        } catch {
            voiceError = "麦克风启动失败"
            return
        }
        self.audioEngine = engine
        self.isRecording = true
        recognitionTask = recognizer.recognitionTask(with: request) { result, err in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result { self.voiceText = result.bestTranscription.formattedString }
                if err != nil || (result?.isFinal ?? false) { self.stopRecording() }
            }
        }
    }

    @MainActor func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        audioEngine = nil
        recognitionTask = nil
        isRecording = false
    }
    @MainActor
    func processInput(store: CapsuleStore) async {
        switch mode {
        case .text where !textInput.isEmpty:
            await runProcessing { try await store.processText(self.textInput) }
            textInput = ""
        case .voice where !voiceText.isEmpty:
            await runProcessing { try await store.processText(self.voiceText) }
            voiceText = ""
        case .link where !linkInput.isEmpty:
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

    @MainActor
    func processSelectedImages(_ images: [UIImage], store: CapsuleStore) async {
        print("[VM] processSelectedImages 开始, \(images.count) 张图")
        withAnimation(Theme.Motion.emphasized) { isProcessing = true }
        errorMessage = nil

        for (idx, image) in images.enumerated() {
            print("[VM] 处理第 \(idx+1) 张, size: \(image.size)")
            do {
                let result = try await store.processImage(image)
                print("[VM] 第 \(idx+1) 张成功: \(result.summary.prefix(30))")
                if idx == images.count - 1 {
                    withAnimation(Theme.Motion.dramatic) { lastResult = result }
                }
            } catch {
                let msg = "第 \(idx + 1) 张失败: \(error.localizedDescription)"
                print("[VM] ❌ \(msg)")
                errorMessage = msg
            }
        }

        withAnimation(Theme.Motion.emphasized) { isProcessing = false }
        print("[VM] processSelectedImages 结束")
    }

    func pasteFromClipboard() {
        if let str = UIPasteboard.general.string { linkInput = str }
    }

    @MainActor
    private func runProcessing(_ action: () async throws -> Insight) async {
        withAnimation(Theme.Motion.emphasized) { isProcessing = true }
        defer { withAnimation(Theme.Motion.emphasized) { isProcessing = false } }
        do {
            let result = try await action()
            withAnimation(Theme.Motion.dramatic) { lastResult = result }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}


// MARK: - Date extension (day of year, 用于 hero 的 "INKLINGS · NO. xxx")

extension Date {
    var dayOfYear: Int {
        Calendar.current.ordinality(of: .day, in: .year, for: self) ?? 0
    }
}
