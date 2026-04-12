import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var capsuleStore: CapsuleStore?
    @State private var selectedTab: Tab = .capture

    enum Tab: String, CaseIterable, Identifiable {
        case capture  = "捕获"
        case library  = "书库"
        case insights = "洞察"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .capture:  return "sparkle"
            case .library:  return "book.closed"
            case .insights: return "compass.drawing"
            }
        }
    }

    var body: some View {
        Group {
            if let store = capsuleStore {
                ZStack(alignment: .bottom) {
                    // 背景色 — 填满整个屏幕（包括安全区）
                    Theme.Colors.cream
                        .ignoresSafeArea()

                    // 主内容区
                    VStack(spacing: 0) {
                        Group {
                            switch selectedTab {
                            case .capture:  CaptureView()
                            case .library:  InsightListView()
                            case .insights: InsightsTabView()
                            }
                        }
                        .environment(store)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    // 底部 Tab Bar（浮在内容上方）
                    VStack(spacing: 0) {
                        Spacer()
                        EditorialTabBar(selected: $selectedTab)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 8)
                    }
                    .ignoresSafeArea(.keyboard)
                }
                .preferredColorScheme(.light) // 强制浅色模式（避免 Dark Mode 黑边）
            } else {
                Theme.Colors.cream
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 16) {
                            Text("灵感胶囊")
                                .font(Theme.Typography.hero)
                                .foregroundStyle(Theme.Colors.ink)
                            ProgressView()
                                .tint(Theme.Colors.coral)
                        }
                    }
                    .task {
                        capsuleStore = CapsuleStore(modelContext: modelContext)
                    }
            }
        }
    }
}


// MARK: - Tab Bar

struct EditorialTabBar: View {
    @Binding var selected: RootView.Tab
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(RootView.Tab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selected = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: .medium))
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(selected == tab ? Theme.Colors.coral : Theme.Colors.inkSoft)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.Colors.paper)
                .shadow(color: .black.opacity(0.08), radius: 16, y: 4)
        )
    }
}


#Preview {
    RootView()
        .modelContainer(for: Insight.self, inMemory: true)
}
