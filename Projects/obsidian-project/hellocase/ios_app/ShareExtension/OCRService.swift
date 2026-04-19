import Foundation
import Vision
import UIKit

// MARK: - OCR Service（Apple Vision Framework 本地 OCR）
//
// 100% 本地，0 成本，0 隐私风险。
// 中英文混合识别，对小红书/抖音截图效果非常好。
//
// 用 actor 保证线程安全（V0+ 我们用 Python，这里用 Swift 6.2 actor 模式）

actor OCRService {
    /// 单例
    static let shared = OCRService()

    private init() {}

    /// 从一张 UIImage 提取所有文字
    /// - Parameter image: 输入图片
    /// - Returns: 识别出的文字（按行拼接）
    func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate           // 准确度优先
        request.recognitionLanguages = ["zh-Hans", "en-US"]  // 中英文
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                    let observations = request.results ?? []
                    let texts = observations.compactMap { $0.topCandidates(1).first?.string }
                    continuation.resume(returning: texts.joined(separator: "\n"))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 从图片数据提取文字（更通用）
    func extractText(from imageData: Data) async throws -> String {
        guard let image = UIImage(data: imageData) else {
            throw OCRError.invalidImage
        }
        return try await extractText(from: image)
    }

    /// 判断截图类型（截图 vs 照片 vs 文档）
    /// 用 VNClassifyImageRequest，纯本地
    func classifyImage(_ image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                    let topClass = request.results?.first?.identifier ?? "unknown"
                    continuation.resume(returning: topClass)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}


enum OCRError: LocalizedError {
    case invalidImage
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "图片格式无效"
        case .noTextFound: return "图片里没有识别到文字"
        }
    }
}
