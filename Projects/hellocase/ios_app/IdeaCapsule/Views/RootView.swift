import SwiftUI
import SwiftData

// MARK: - RootView — 自定义 Tab Bar（Editorial 风格）
//
// 放弃默认 TabView，自己画一个编辑型底部导航栏。
// 原因：系统 TabView 太"软件"，我们需要"杂志"的感觉。
//
// 灵感：像一本纸质笔记本底部的锚点标签

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var capsuleStore: CapsuleStore?
    @State private var selectedTab: Tab = .capture
    @State private var hasAppeared = false

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

        var accent: Color {
            switch self {
            case .capture:  return Theme.Colors.coral
            case .library:  return Theme.Colors.ink
            case .insights: return Theme.Colors.jade
            }
        }
    }

    var body: some View {
        Group {
            if let store = capsuleStore {
                ZStack(alignment: .bottom) {
                    // 主内容区
                    Group {
                        switch selectedTab {
                        case .capture:  CaptureView()
                        case .library:  InsightListView()
                        case .insights: InsightsTabView()
                        }
                    }
                    .environment(store)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 8)),
                        removal: .opacity
                    ))
                    .id(selectedTab)

                    // 自定义底部 Tab Bar
                    EditorialTabBar(selected: $selectedTab)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.bottom, Theme.Spacing.md)
                }
                .background(PaperBackground())
            } else {
                PaperBackground()
                    .overlay {
                        VStack(spacing: Theme.Spacing.lg) {
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
        .animation(Theme.Motion.standard, value: selectedTab)
    }
}


// MARK: - Editorial 底部导航栏

struct EditorialTabBar: View {
    @Binding var selected: RootView.Tab
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(RootView.Tab.allCases) { tab in
                TabButton(
                    tab: tab,
                    isSelected: selected == tab,
                    namespace: ns
                ) {
                    withAnimation(Theme.Motion.emphasized) {
                        selected = tab
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Theme.Colors.paper)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Theme.Colors.hairline, lineWidth: 1)
                )
        )
        .modifier(Theme.Shadows.floating())
    }
}

private struct TabButton: View {
    let tab: RootView.Tab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: .medium))
                if isSelected {
                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .italic()
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .foregroundStyle(isSelected ? Theme.Colors.cream : Theme.Colors.ink)
            .padding(.horizontal, isSelected ? 20 : 14)
            .padding(.vertical, 12)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(tab.accent)
                        .matchedGeometryEffect(id: "tab-background", in: namespace)
                }
            }
            .frame(maxWidth: isSelected ? .infinity : nil)
        }
        .buttonStyle(.plain)
    }
}


#Preview {
    RootView()
        .modelContainer(for: Insight.self, inMemory: true)
}
