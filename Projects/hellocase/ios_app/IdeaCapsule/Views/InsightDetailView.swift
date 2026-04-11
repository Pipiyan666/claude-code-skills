import SwiftUI

// MARK: - InsightDetailView — 灵感详情页

struct InsightDetailView: View {
    @Environment(CapsuleStore.self) private var store
    let insight: Insight

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    Text(insight.summary)
                        .font(.title2.bold())

                    HStack {
                        Text(insight.category)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.tint.opacity(0.2))
                            .clipShape(.capsule)

                        Spacer()

                        Text(insight.createdAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .glassEffect(.regular, in: .rect(cornerRadius: 20))

                // 标签
                if !insight.tags.isEmpty {
                    SectionHeader(title: "🏷️ 标签")
                    GlassEffectContainer(spacing: 6) {
                        FlowLayout(spacing: 8) {
                            ForEach(insight.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .glassEffect(.regular.tint(.blue.opacity(0.2)),
                                                 in: .capsule)
                            }
                        }
                    }
                }

                // 关键词
                if !insight.keywords.isEmpty {
                    SectionHeader(title: "🔑 关键词")
                    Text(insight.keywords.joined(separator: " · "))
                        .font(.callout)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassEffect(.regular, in: .rect(cornerRadius: 12))
                }

                // AI 洞察
                SectionHeader(title: "💡 AI 洞察")
                Text(insight.aiInsight)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular.tint(.yellow.opacity(0.2)),
                                 in: .rect(cornerRadius: 16))

                // 原文
                SectionHeader(title: "📄 原文")
                Text(insight.rawText)
                    .font(.callout)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
            }
            .padding()
        }
        .navigationTitle("灵感详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("导出为 Markdown", systemImage: "square.and.arrow.up") {
                        let md = store.exportMarkdown(insight)
                        UIPasteboard.general.string = md
                    }
                    Button("删除", systemImage: "trash", role: .destructive) {
                        // TODO: 实现删除
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}

private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.horizontal, 4)
    }
}

// 简易 FlowLayout（标签自动换行）
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
        let maxX = bounds.maxX

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxX {
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
