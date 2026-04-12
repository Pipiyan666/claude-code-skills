import SwiftUI
import SwiftData

// MARK: - InsightListView — 书库 / 列表页（Editorial 杂志目录风格）
//
// 设计哲学：像翻开一本目录，像杂志的"往期回顾"栏目。
//   - 顶部：大 serif 斜体 "The Library"
//   - 下面：每一条灵感是一个"条目"，有编号、有时间、有优雅的卡片

struct InsightListView: View {
    @Environment(CapsuleStore.self) private var store
    @Query(sort: \Insight.createdAt, order: .reverse) private var insights: [Insight]

    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var hasAppeared = false

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
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    heroHeader
                    searchBar
                    categoryFilter

                    EditorialDivider(ornament: "✦")

                    if filtered.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, insight in
                            NavigationLink {
                                InsightDetailView(insight: insight)
                            } label: {
                                LibraryEntry(insight: insight, number: idx + 1)
                            }
                            .buttonStyle(.plain)
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 20)
                            .animation(
                                Theme.Motion.stagger(idx, delay: 0.04),
                                value: hasAppeared
                            )
                        }
                    }

                    Spacer().frame(height: 120)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.xl)
            }
            .onAppear {
                withAnimation { hasAppeared = true }
            }
        }
    }

    // MARK: - Hero

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Rectangle()
                    .fill(Theme.Colors.ink)
                    .frame(width: 32, height: 2)
                Text("LIBRARY · \(insights.count) ENTRIES")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(Theme.Colors.ink)
            }

            Text("书库")
                .font(Theme.Typography.hero)
                .foregroundStyle(Theme.Colors.ink)

            Text("每一条灵感都是未来的线索。")
                .font(Theme.Typography.bodyEmphasis)
                .foregroundStyle(Theme.Colors.inkSoft)
        }
    }

    // MARK: - 搜索栏

    private var searchBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(Theme.Colors.inkSoft)
            TextField("", text: $searchText, prompt:
                Text("搜索灵感、标签、关键词…")
                    .font(Theme.Typography.bodyEmphasis)
                    .foregroundStyle(Theme.Colors.inkMuted)
            )
            .font(Theme.Typography.body)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Colors.inkMuted)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.paper)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.Colors.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 分类筛选

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                CategoryChip(
                    label: "全部",
                    count: insights.count,
                    isSelected: selectedCategory == nil
                ) {
                    withAnimation(Theme.Motion.emphasized) {
                        selectedCategory = nil
                    }
                }

                ForEach(allCategories, id: \.self) { cat in
                    let count = insights.filter { $0.category == cat }.count
                    CategoryChip(
                        label: cat,
                        count: count,
                        isSelected: selectedCategory == cat
                    ) {
                        withAnimation(Theme.Motion.emphasized) {
                            selectedCategory = cat
                        }
                    }
                }
            }
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "book.closed")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.Colors.inkMuted)
            Text("书库还是空的")
                .font(Theme.Typography.subheading)
                .foregroundStyle(Theme.Colors.ink)
            Text("去\u{201C}捕获\u{201D}Tab 记下你的第一条灵感")
                .font(Theme.Typography.bodyEmphasis)
                .foregroundStyle(Theme.Colors.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.hero)
    }
}


// MARK: - Library Entry（单条灵感卡片，编辑目录风格）

private struct LibraryEntry: View {
    let insight: Insight
    let number: Int

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            // 左侧：大号罗马数字（编号）
            VStack(spacing: 2) {
                Text(String(format: "%02d", number))
                    .font(.system(size: 22, weight: .regular, design: .serif).italic())
                    .foregroundStyle(Theme.Colors.coral)
                Rectangle()
                    .fill(Theme.Colors.coral)
                    .frame(width: 20, height: 1)
            }
            .frame(width: 36)

            // 中间：标题 + 元信息
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(insight.summary)
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .foregroundStyle(Theme.Colors.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text(insight.category)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.coral)
                    Text("·")
                        .foregroundStyle(Theme.Colors.inkMuted)
                    Text(insight.createdAt, style: .relative)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.inkSoft)
                }

                if !insight.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(insight.tags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(Theme.Typography.meta)
                                .foregroundStyle(Theme.Colors.inkMuted)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            // 右侧：来源图标
            Image(systemName: sourceIcon)
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(Theme.Colors.inkMuted)
        }
        .padding(.vertical, Theme.Spacing.md)
        .padding(.horizontal, Theme.Spacing.md)
        .background(Theme.Colors.paper)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(Theme.Colors.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .modifier(Theme.Shadows.card())
    }

    private var sourceIcon: String {
        switch insight.sourceType {
        case "image":  "photo"
        case "text":   "text.alignleft"
        case "link":   "link"
        case "voice":  "waveform"
        default:       "doc"
        }
    }
}


// MARK: - Category Chip

private struct CategoryChip: View {
    let label: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: .medium, design: .serif).italic())
                Text("\(count)")
                    .font(Theme.Typography.meta)
                    .opacity(0.6)
            }
            .foregroundStyle(isSelected ? Theme.Colors.cream : Theme.Colors.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Theme.Colors.ink : Theme.Colors.paper)
            )
            .overlay(
                Capsule()
                    .stroke(Theme.Colors.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
