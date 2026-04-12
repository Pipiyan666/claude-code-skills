import SwiftUI

// MARK: - InsightDetailView — 灵感详情页（杂志文章风格）
//
// 设计哲学：像杂志里的一篇 feature article。
//   - 顶部装饰：小 caption + 大 serif 斜体标题 + 分类
//   - 中间：原文（serif）+ AI 洞察（引用框）
//   - 底部：标签、关键词、元信息

struct InsightDetailView: View {
    @Environment(CapsuleStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let insight: Insight

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                articleHeader
                articleBody
                insightQuote
                metaFooter

                Spacer().frame(height: 60)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.md)
        }
        .background(PaperBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                        Text("书库")
                            .font(.system(size: 15, weight: .medium, design: .serif).italic())
                    }
                    .foregroundStyle(Theme.Colors.ink)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        let md = store.exportMarkdown(insight)
                        UIPasteboard.general.string = md
                    } label: {
                        Label("复制为 Markdown", systemImage: "doc.on.clipboard")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Theme.Colors.ink)
                }
            }
        }
    }

    // MARK: - 文章 Header

    private var articleHeader: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // 小标签
            HStack(spacing: Theme.Spacing.sm) {
                Text(insight.category.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.Colors.coral)
                    .foregroundStyle(Theme.Colors.cream)
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                Text(insight.createdAt, format: .dateTime.year().month(.wide).day())
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.inkSoft)
            }

            // 主标题（大 serif 斜体）
            Text(insight.summary)
                .font(.system(size: 32, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(Theme.Colors.ink)
                .fixedSize(horizontal: false, vertical: true)

            // 装饰线
            HStack {
                Rectangle()
                    .fill(Theme.Colors.ink)
                    .frame(width: 40, height: 2)
                Spacer()
            }
        }
    }

    // MARK: - 正文

    private var articleBody: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("ORIGINAL")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(Theme.Colors.inkMuted)

            Text(insight.rawText)
                .font(.system(size: 16, weight: .regular, design: .serif))
                .foregroundStyle(Theme.Colors.ink)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - AI 洞察引用块

    private var insightQuote: some View {
        Group {
            if !insight.aiInsight.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Rectangle().fill(Theme.Colors.coral).frame(width: 16, height: 1)
                        Text("INSIGHT")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(Theme.Colors.coral)
                    }

                    ZStack(alignment: .topLeading) {
                        Text("\u{201C}")
                            .font(.system(size: 80, weight: .regular, design: .serif))
                            .foregroundStyle(Theme.Colors.coral.opacity(0.25))
                            .offset(x: -12, y: -20)

                        Text(insight.aiInsight)
                            .font(.system(size: 17, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(Theme.Colors.ink)
                            .lineSpacing(6)
                            .padding(.leading, Theme.Spacing.md)
                            .padding(.top, Theme.Spacing.xs)
                    }
                }
                .padding(Theme.Spacing.lg)
                .background(Theme.Colors.ivory)
                .overlay(
                    Rectangle()
                        .fill(Theme.Colors.coral)
                        .frame(width: 3),
                    alignment: .leading
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            }
        }
    }

    // MARK: - Meta Footer (标签 + 关键词)

    private var metaFooter: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            EditorialDivider()

            if !insight.tags.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("TAGS")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(Theme.Colors.inkMuted)
                    FlowLayout(spacing: 6) {
                        ForEach(insight.tags, id: \.self) { tag in
                            Text(tag)
                                .editorialTag()
                        }
                    }
                }
            }

            if !insight.keywords.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("KEYWORDS")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(Theme.Colors.inkMuted)
                    Text(insight.keywords.joined(separator: " · "))
                        .font(Theme.Typography.bodyEmphasis)
                        .foregroundStyle(Theme.Colors.inkSoft)
                }
            }
        }
    }
}


// MARK: - FlowLayout (自动换行的标签容器)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var width: CGFloat = 0
        var height: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineWidth + size.width > maxWidth {
                width = max(width, lineWidth)
                height += lineHeight + spacing
                lineWidth = size.width + spacing
                lineHeight = size.height
            } else {
                lineWidth += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
        }
        width = max(width, lineWidth)
        height += lineHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
