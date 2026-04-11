import Foundation
import Photos
import UIKit

// MARK: - PhotoMonitor — 监听相册截图变化
//
// 用 PhotoKit 监听用户相册的新增截图。
// 这是『不删截图，让截图为你工作』的核心技术：
//   - 不复制原图（只存 PhotoKit asset identifier）
//   - 自动识别新截图，用 Vision OCR + Apple FoundationModels 分析
//   - 用户的相册保持原样，App 只是引用
//
// 隐私关键：用户首次启动时弹权限请求，明确告知"App 只读取，不会修改或上传任何照片"

@MainActor
final class PhotoMonitor: NSObject, ObservableObject {
    static let shared = PhotoMonitor()

    @Published private(set) var newScreenshots: [PHAsset] = []
    @Published private(set) var permissionStatus: PHAuthorizationStatus = .notDetermined

    private let library = PHPhotoLibrary.shared()

    override private init() {
        super.init()
        permissionStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    // MARK: - 权限请求

    func requestPermission() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            self.permissionStatus = status
        }
        return status == .authorized || status == .limited
    }

    // MARK: - 注册监听

    func startObserving() {
        guard permissionStatus == .authorized || permissionStatus == .limited else { return }
        library.register(self)
    }

    func stopObserving() {
        library.unregisterChangeObserver(self)
    }

    // MARK: - 获取所有截图

    /// 获取用户相册里的所有截图
    /// （iOS 用 PHAssetMediaSubtype.photoScreenshot 标记截图）
    func fetchAllScreenshots() async -> [PHAsset] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "(mediaSubtype & %d) != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let result = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    /// 加载某个 asset 的真实图片数据（懒加载）
    func loadImage(for asset: PHAsset, targetSize: CGSize = CGSize(width: 1024, height: 1024)) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}


// MARK: - PHPhotoLibraryChangeObserver

extension PhotoMonitor: PHPhotoLibraryChangeObserver {
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            // 检测新增的截图
            let allScreenshots = await fetchAllScreenshots()
            // TODO: diff 出新增的部分（V1.1 优化）
            self.newScreenshots = allScreenshots
        }
    }
}
