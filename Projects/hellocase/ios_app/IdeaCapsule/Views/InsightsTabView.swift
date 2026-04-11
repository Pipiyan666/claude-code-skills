import SwiftUI
import SwiftData

// MARK: - InsightsTabView — 智能洞察 Tab
//
// 这是『灵感胶囊』最有吸引力的页面：
//   - 用户画像（一句话描述用户最近关注什么）
//   - 主题发现（跨灵感聚类）
//   - 下一步行动建议
//
// 全部由 Apple FoundationModels 本地生成。

struct InsightsTabView: View {
    @Environment(CapsuleStore.self) private var store
    @Query(sort: \Insight.createdAt, order: .reverse) private var insights: [Insight]

    @State private var profile: UserProfile?
    @State private var isGenerating = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if insights.count < 2 {
                        emptyState
                    } else {
                        statsRow
                        generateButton

                        if isGenerating {
                            ProgressView("Apple Intelligence 正在阅读你的全部灵感…")
                                .padding()
                        }

                        if let profile {
                            profileSection(profile)
                            themesSection(profile.themes)
                            actionsSection(profile.nextActions)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("🔮 智能洞察")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "灵感太少",
            systemImage: "sparkles",
            description: Text("至少需要 2 条灵感才能做关联分析")
        )
        .padding(.top, 80)
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            StatCard(title: "总灵感", value: "\(insights.count)", icon: "tray.full")
            StatCard(title: "分类", value: "\(Set(insights.map(\.category)).count)", icon: "folder")
            StatCard(title: "标签", value: "\(Set(insights.flatMap(\.tags)).count)", icon: "tag")
        }
    }

    private var generateButton: some View {
        Button {
            Task { await generate() }
        } label: {
            Label("🚀 生成洞察报告", systemImage: "wand.and.stars")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.glassProminent)
        .disabled(isGenerating)
    }

    private func profileSection(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("👤 你的画像", systemImage: "person.crop.circle")
                .font(.headline)
            Text(profile.summary)
                .font(.callout)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular.tint(.purple.opacity(0.15)),
                             in: .rect(cornerRadius: 16))
        }
    }

    private func themesSection(_ themes: [InsightTheme]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("🎯 主题发现", systemImage: "scope")
                .font(.headline)

            ForEach(themes, id: \.name) { theme in
                VStack(alignment: .leading, spacing: 6) {
                    Text(theme.name).font(.headline)
                    Text(theme.description).font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ForEach(theme.relatedKeywords, id: \.self) { kw in
                            Text(kw)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.tint.opacity(0.15))
                                .clipShape(.capsule)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
            }
        }
    }

    private func actionsSection(_ actions: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("🚶 下一步建议", systemImage: "arrow.forward.circle")
                .font(.headline)
            ForEach(Array(actions.enumerated()), id: \.offset) { idx, action in
                HStack(alignment: .top) {
                    Text("\(idx + 1).").bold()
                    Text(action)
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .glassEffect(.regular.tint(.green.opacity(0.15)),
                             in: .rect(cornerRadius: 12))
            }
        }
    }

    @MainActor
    private func generate() async {
        isGenerating = true
        defer { isGenerating = false }
        do {
            profile = try await store.generateUserProfile()
        } catch {
            self.error = error.localizedDescription
        }
    }
}


private struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
            Text(value).font(.title.bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }
}
