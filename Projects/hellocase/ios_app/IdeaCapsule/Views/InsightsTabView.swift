import SwiftUI
import SwiftData

// MARK: - InsightsTabView — 智能洞察 Tab（编辑报告风格）
//
// 设计哲学：像杂志的"每月报告"专栏。
//   - 顶部：大标题 + 统计数字用 serif 大字体
//   - 中间：「生成报告」按钮
//   - 下面：用户画像（引用块）+ 主题卡片 + 行动清单

struct InsightsTabView: View {
    @Environment(CapsuleStore.self) private var store
    @Query(sort: \Insight.createdAt, order: .reverse) private var insights: [Insight]

    @State private var profile: UserProfile?
    @State private var isGenerating = false
    @State private var error: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                heroHeader

                if insights.count < 2 {
                    emptyState
                } else {
                    statsGrid
                    generateButton

                    if isGenerating {
                        ProcessingState()
                    }

                    if let profile {
                        profileSection(profile)
                        themesSection(profile.themes)
                        actionsSection(profile.nextActions)
                    }
                }

                Spacer().frame(height: 120)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.xl)
        }
    }

    // MARK: - Hero

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Rectangle()
                    .fill(Theme.Colors.jade)
                    .frame(width: 32, height: 2)
                Text("THE LEDGER · MONTHLY")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(Theme.Colors.jade)
            }

            Text("洞察")
                .font(Theme.Typography.hero)
                .foregroundStyle(Theme.Colors.ink)

            Text("你的灵感在说一个怎样的故事？")
                .font(Theme.Typography.bodyEmphasis)
                .foregroundStyle(Theme.Colors.inkSoft)
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "compass.drawing")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.Colors.inkMuted)
            Text("灵感太少")
                .font(Theme.Typography.subheading)
                .foregroundStyle(Theme.Colors.ink)
            Text("至少需要 2 条灵感才能发现主题")
                .font(Theme.Typography.bodyEmphasis)
                .foregroundStyle(Theme.Colors.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.hero)
    }

    // MARK: - 统计 (Editorial 大数字)

    private var statsGrid: some View {
        HStack(spacing: Theme.Spacing.md) {
            StatTile(
                label: "灵感",
                value: "\(insights.count)",
                unit: "条"
            )
            StatTile(
                label: "分类",
                value: "\(Set(insights.map(\.category)).count)",
                unit: "个"
            )
            StatTile(
                label: "标签",
                value: "\(Set(insights.flatMap(\.tags)).count)",
                unit: "个"
            )
        }
    }

    // MARK: - 生成按钮

    private var generateButton: some View {
        Button {
            Task { await generate() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                Text("生成本期洞察报告")
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
            }
            .editorialButton()
        }
        .disabled(isGenerating)
    }

    // MARK: - 用户画像

    private func profileSection(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            EditorialSectionTitle(label: "YOUR PORTRAIT", title: "你最近关注的")

            ZStack(alignment: .topLeading) {
                Text(""")
                    .font(.system(size: 100, weight: .regular, design: .serif))
                    .foregroundStyle(Theme.Colors.jade.opacity(0.25))
                    .offset(x: -8, y: -30)

                Text(profile.summary)
                    .font(.system(size: 19, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Theme.Colors.ink)
                    .padding(.leading, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.sm)
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.ivory)
            .overlay(
                Rectangle()
                    .fill(Theme.Colors.jade)
                    .frame(width: 3),
                alignment: .leading
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
    }

    // MARK: - 主题发现

    private func themesSection(_ themes: [InsightTheme]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            EditorialSectionTitle(label: "THEMES DISCOVERED", title: "主题脉络")

            VStack(spacing: Theme.Spacing.sm) {
                ForEach(Array(themes.enumerated()), id: \.offset) { idx, theme in
                    ThemeCard(theme: theme, index: idx + 1)
                }
            }
        }
    }

    // MARK: - 行动建议

    private func actionsSection(_ actions: [String]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            EditorialSectionTitle(label: "NEXT STEPS", title: "往前走")

            VStack(spacing: Theme.Spacing.sm) {
                ForEach(Array(actions.enumerated()), id: \.offset) { idx, action in
                    ActionRow(number: idx + 1, text: action)
                }
            }
        }
    }

    @MainActor
    private func generate() async {
        withAnimation(Theme.Motion.emphasized) { isGenerating = true }
        defer { withAnimation(Theme.Motion.emphasized) { isGenerating = false } }
        do {
            let result = try await store.generateUserProfile()
            withAnimation(Theme.Motion.dramatic) { profile = result }
        } catch {
            self.error = error.localizedDescription
        }
    }
}


// MARK: - 子组件

private struct StatTile: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(Theme.Colors.inkMuted)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(Theme.Typography.metric)
                    .foregroundStyle(Theme.Colors.ink)
                Text(unit)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.paper)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(Theme.Colors.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
}

private struct ThemeCard: View {
    let theme: InsightTheme
    let index: Int

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Text(String(format: "%02d", index))
                .font(.system(size: 28, weight: .regular, design: .serif).italic())
                .foregroundStyle(Theme.Colors.coral)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(theme.name)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.Colors.ink)
                Text(theme.description)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
                    ForEach(theme.relatedKeywords, id: \.self) { kw in
                        Text(kw)
                            .editorialTag(color: Theme.Colors.coral)
                    }
                }
                .padding(.top, Theme.Spacing.xxs)
            }

            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.paper)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(Theme.Colors.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
}

private struct ActionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Text("→")
                .font(.system(size: 16, weight: .regular, design: .serif))
                .foregroundStyle(Theme.Colors.jade)
                .padding(.top, 2)

            Text(text)
                .font(Theme.Typography.bodyEmphasis)
                .foregroundStyle(Theme.Colors.ink)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.paper)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(Theme.Colors.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
}

private struct ProcessingState: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Theme.Colors.jade)
                    .frame(width: 6, height: 6)
                    .scaleEffect(isAnimating ? 1.3 : 0.6)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(i) * 0.15),
                        value: isAnimating
                    )
            }
            Text("让 Librarian 翻阅所有灵感...")
                .font(Theme.Typography.bodyEmphasis)
                .foregroundStyle(Theme.Colors.inkSoft)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.ivory)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .onAppear { isAnimating = true }
    }
}
