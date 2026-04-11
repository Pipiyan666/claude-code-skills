import SwiftUI
import SwiftData

// MARK: - RootView — 主导航 (TabView)
//
// 三个核心 Tab：
//   📸 捕获 - 拍照/选图/粘贴文字
//   📚 知识库 - 浏览所有灵感 + 搜索
//   🔮 洞察 - 跨灵感发现 + 用户画像
//
// 用 iOS 26 Liquid Glass 设计语言。

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var capsuleStore: CapsuleStore?
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if let store = capsuleStore {
                TabView(selection: $selectedTab) {
                    CaptureView()
                        .tabItem {
                            Label("捕获", systemImage: "camera.aperture")
                        }
                        .tag(0)

                    InsightListView()
                        .tabItem {
                            Label("知识库", systemImage: "books.vertical")
                        }
                        .tag(1)

                    InsightsTabView()
                        .tabItem {
                            Label("洞察", systemImage: "sparkles")
                        }
                        .tag(2)
                }
                .environment(store)
                .task {
                    // App 启动时检查相册权限
                    let granted = await PhotoMonitor.shared.requestPermission()
                    if granted {
                        PhotoMonitor.shared.startObserving()
                    }
                }
            } else {
                ProgressView("初始化…")
                    .task {
                        capsuleStore = CapsuleStore(modelContext: modelContext)
                    }
            }
        }
    }
}


#Preview {
    RootView()
        .modelContainer(for: Insight.self, inMemory: true)
}
