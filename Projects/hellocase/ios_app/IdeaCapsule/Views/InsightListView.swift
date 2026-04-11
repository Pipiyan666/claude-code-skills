import SwiftUI
import SwiftData

// MARK: - InsightListView — 知识库浏览页
//
// 列出所有灵感，支持：
//   - 搜索（全文）
//   - 按分类筛选
//   - 点击进入详情
//
// 用 LazyVStack 保证大列表性能（V2 性能要求）

struct InsightListView: View {
    @Environment(CapsuleStore.self) private var store
    @Query(sort: \Insight.createdAt, order: .reverse) private var insights: [Insight]

    @State private var searchText = ""
    @State private var selectedCategory: String? = nil

    var filtered: [Insight] {
        var result = insights
        if let cat = selectedCategory {
            result = result.filter { $0.category == cat }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.summary.localizedCaseInsensitiveContains(searchText)
                    || $0.rawText.localizedCaseInsensitiveContains(searchText)
                    || $0.tagsRaw.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var allCategories: [String] {
        Array(Set(insights.map { $0.category })).sorted()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    categoryFilter

                    ForEach(filtered) { insight in
                        NavigationLink {
                            InsightDetailView(insight: insight)
                        } label: {
                            InsightCard(insight: insight)
                        }
                        .buttonStyle(.plain)
                    }

                    if filtered.isEmpty {
                        ContentUnavailableView(
                            "还没有灵感",
                            systemImage: "tray",
                            description: Text("去『捕获』Tab 添加你的第一条灵感吧")
                        )
                        .padding(.top, 60)
                    }
                }
                .padding()
            }
            .searchable(text: $searchText, prompt: "搜索灵感、标签、关键词")
            .navigationTitle("📚 知识库 (\(insights.count))")
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Button {
                        selectedCategory = nil
                    } label: {
                        Text("全部")
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(selectedCategory == nil ? .glassProminent : .glass)

                    ForEach(allCategories, id: \.self) { cat in
                        Button {
                            selectedCategory = cat
                        } label: {
                            Text(cat)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(selectedCategory == cat ? .glassProminent : .glass)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}


// MARK: - InsightCard 子组件

struct InsightCard: View {
    let insight: Insight

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(insight.summary)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: sourceIcon)
                    .foregroundStyle(.tint)
            }

            HStack(spacing: 4) {
                Text(insight.category)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.tint.opacity(0.15))
                    .clipShape(.capsule)

                ForEach(insight.tags.prefix(3), id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(insight.aiInsight)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(insight.createdAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    private var sourceIcon: String {
        switch insight.sourceType {
        case "image": return "photo"
        case "text": return "text.alignleft"
        case "link": return "link"
        case "voice": return "mic"
        default: return "doc"
        }
    }
}
