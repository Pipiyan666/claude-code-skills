import SwiftUI

// MARK: - ResultCard — AI 分析结果卡片（Editorial 杂志封面风格）
//
// 当 AI 分析完成后出现。像杂志的一张精心排版的页面。

struct ResultCard: View {
    let insight: Insight

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Header: 小装饰 + "已收入"
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.Colors.jade)
                Text("已收入书库")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(Theme.Colors.jade)
                Spacer()
                Text(insight.createdAt, style: .time)
                    .font(Theme.Typography.meta)
                    .foregroundStyle(Theme.Colors.inkMuted)
            }

            EditorialDivider(ornament: "✦")

            // 主标题（大 serif italic）
            Text(insight.summary)
                .font(.system(size: 22, weight: .medium, design: .serif))
                .foregroundStyle(Theme.Colors.ink)
                .fixedSize(horizontal: false, vertical: true)

            // 分类 + 标签
            HStack(spacing: Theme.Spacing.xs) {
                Text(insight.category.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.Colors.coral)
                    .foregroundStyle(Theme.Colors.cream)
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                ForEach(insight.tags.prefix(3), id: \.self) { tag in
                    Text(tag)
                        .editorialTag()
                }
            }

            // AI 洞察（引用块风格）
            if !insight.aiInsight.isEmpty {
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    Rectangle()
                        .fill(Theme.Colors.coral)
                        .frame(width: 2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("洞察")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(Theme.Colors.coral)
                        Text(insight.aiInsight)
                            .font(Theme.Typography.bodyEmphasis)
                            .foregroundStyle(Theme.Colors.ink)
                    }
                }
                .padding(.top, Theme.Spacing.xs)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.paper)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(Theme.Colors.jade.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .modifier(Theme.Shadows.soft(Theme.Colors.jade))
    }
}
