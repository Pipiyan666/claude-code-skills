import Foundation
import Speech
import AVFoundation

// MARK: - VoiceInputService — 本地语音识别服务
//
// 基于 Apple Speech Framework，**100% 本地识别**。
// 用户说的每一个字都不会离开 iPhone。
//
// 这是『灵感胶囊』实现"拍拍手机背面就能记录灵感"的技术基础：
//   1. 用户双击手机背面 → 触发 CaptureIdeaIntent
//   2. Siri 弹出 "你想记下什么？"
//   3. 用户说话 → VoiceInputService 实时转文字
//   4. 文字 → AIService.analyze() → 保存

actor VoiceInputService {

    // MARK: - 权限管理

    /// 请求语音识别权限 + 麦克风权限
    /// - Returns: 两个权限是否都获得
    static func requestPermissions() async -> Bool {
        // Speech 权限
        let speechStatus = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else { return false }

        // 麦克风权限
        let micGranted = await AVCaptureDevice.requestAccess(for: .audio)
        return micGranted
    }

    // MARK: - 核心识别

    private let recognizer: SFSpeechRecognizer
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    init(locale: Locale = Locale(identifier: "zh-CN")) {
        guard let rec = SFSpeechRecognizer(locale: locale) else {
            fatalError("当前设备不支持 \(locale.identifier) 语音识别")
        }
        self.recognizer = rec
    }

    /// 是否支持本地识别（iOS 13+ 大部分中英文设备都支持）
    var supportsOnDeviceRecognition: Bool {
        recognizer.supportsOnDeviceRecognition
    }

    /// 开始识别，返回一个 AsyncStream 持续产出转录结果
    ///
    /// 关键参数：
    ///   - `requiresOnDeviceRecognition = true`：**强制本地识别**，文字不上传 Apple 服务器
    ///   - `shouldReportPartialResults = true`：流式返回部分结果，实时更新 UI
    func startListening() throws -> AsyncThrowingStream<TranscriptionUpdate, Error> {
        // 清理之前的任务
        recognitionTask?.cancel()
        recognitionTask = nil

        // 创建请求
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        // ⭐ 核心：强制本地识别（文字永远不出设备）
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        // 中文支持标点符号
        request.addsPunctuation = true

        recognitionRequest = request

        // 配置 audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // 配置 audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        // 启动识别任务，把结果封装成 AsyncThrowingStream
        return AsyncThrowingStream { continuation in
            self.recognitionTask = self.recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.finish(throwing: error)
                    return
                }
                if let result = result {
                    let update = TranscriptionUpdate(
                        text: result.bestTranscription.formattedString,
                        isFinal: result.isFinal
                    )
                    continuation.yield(update)
                    if result.isFinal {
                        continuation.finish()
                    }
                }
            }

            // 流被取消时清理资源
            continuation.onTermination = { @Sendable _ in
                Task { await self.stopListening() }
            }
        }
    }

    /// 停止识别
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }
}


// MARK: - 数据类型

struct TranscriptionUpdate: Sendable {
    let text: String
    let isFinal: Bool
}


// MARK: - 简易的一次性 API（给 AppIntents 用）

extension VoiceInputService {
    /// 录 N 秒音，返回最终转录（给快捷指令用）
    static func recordAndTranscribe(seconds: TimeInterval = 10) async throws -> String {
        guard await requestPermissions() else {
            throw VoiceError.permissionDenied
        }

        let service = VoiceInputService()
        let stream = try await service.startListening()

        // 用 actor-isolated 容器收集结果（避免 Sendable 警告）
        let collector = TranscriptionCollector()

        async let collection: () = collector.collect(from: stream)
        try await Task.sleep(for: .seconds(seconds))
        await service.stopListening()
        _ = try? await collection

        return await collector.text
    }
}


/// Sendable-safe 的转录结果收集器
private actor TranscriptionCollector {
    var text: String = ""

    func collect(from stream: AsyncThrowingStream<TranscriptionUpdate, Error>) async {
        do {
            for try await update in stream {
                text = update.text
                if update.isFinal { break }
            }
        } catch {
            // stream 被取消时正常结束
        }
    }
}


enum VoiceError: LocalizedError {
    case permissionDenied
    case unsupported

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "需要语音识别和麦克风权限"
        case .unsupported: return "当前设备不支持中文语音识别"
        }
    }
}
