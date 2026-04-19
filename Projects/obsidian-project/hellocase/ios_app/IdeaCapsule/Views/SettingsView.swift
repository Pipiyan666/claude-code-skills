import SwiftUI
import SwiftData

// MARK: - SettingsView — 设置页面
//
// 功能：
//   - 配置智谱 API Key
//   - 查看使用统计
//   - 管理数据

struct SettingsView: View {
    @AppStorage("zhipu_api_key") private var apiKey: String = ""
    @AppStorage("use_local_ai") private var useLocalAI: Bool = true

    @Environment(\.modelContext) private var modelContext
    @Query private var insights: [Insight]

    @State private var showingClearAlert = false
    @State private var inputKey: String = ""

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    heroSection

                    Divider()
                        .padding(.vertical, Theme.Spacing.sm)

                    // API Key 配置
                    apiKeySection

                    Divider()
                        .padding(.vertical, Theme.Spacing.sm)

                    // AI 设置
                    aiSettingsSection

                    Divider()
                        .padding(.vertical, Theme.Spacing.sm)

                    // 统计信息
                    statsSection

                    Divider()
                        .padding(.vertical, Theme.Spacing.sm)

                    // 数据管理
                    dataManagementSection

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.xl)
            }
            .background(Theme.Colors.cream)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            inputKey = apiKey
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Rectangle()
                    .fill(Theme.Colors.coral)
                    .frame(width: 32, height: 2)
                Text("SETTINGS · PREFERENCES")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(Theme.Colors.coral)
            }

            Text("设置")
                .font(Theme.Typography.hero)
                .foregroundStyle(Theme.Colors.ink)

            Text("配置你的 AI 助手")
                .font(Theme.Typography.bodyEmphasis)
                .foregroundStyle(Theme.Colors.inkSoft)
        }
    }

    // MARK: - API Key 配置

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("云端 AI")
                .font(Theme.Typography.subheading)
                .foregroundStyle(Theme.Colors.ink)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("智谱 API Key")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.inkSoft)

                HStack(spacing: Theme.Spacing.sm) {
                    SecureField("请输入 API Key", text: $inputKey)
                        .font(Theme.Typography.body)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.paper)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.Colors.hairline, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    if !inputKey.isEmpty {
                        Button("保存") {
                            apiKey = inputKey
                            // 重新配置 AI 服务
                            Task {
                                await CloudAIService.shared.configure(apiKey: apiKey)
                            }
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Colors.cream)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Theme.Colors.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                // API Key 状态指示
                HStack(spacing: 6) {
                    Circle()
                        .fill(apiKey.isEmpty ? Theme.Colors.coral : Theme.Colors.jade)
                        .frame(width: 6, height: 6)

                    Text(apiKey.isEmpty ? "未配置" : "已配置")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(apiKey.isEmpty ? Theme.Colors.coral : Theme.Colors.jade)
                }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("如何获取 API Key？")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.inkMuted)

                Link(destination: URL(string: "https://open.bigmodel.cn/usercenter/apikeys")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "link.circle.fill")
                            .font(.system(size: 12))
                        Text("前往智谱开放平台")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.coral)
                    }
                }
            }
        }
    }

    // MARK: - AI 设置

    private var aiSettingsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("AI 设置")
                .font(Theme.Typography.subheading)
                .foregroundStyle(Theme.Colors.ink)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("优先使用本地 AI")
                        .font(Theme.Typography.body)
                    Text("Apple Intelligence 可用时优先使用（需要 iOS 18+）")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.inkSoft)
                }

                Spacer()

                Toggle("", isOn: $useLocalAI)
                    .labelsHidden()
            }
        }
    }

    // MARK: - 统计信息

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("使用统计")
                .font(Theme.Typography.subheading)
                .foregroundStyle(Theme.Colors.ink)

            HStack(spacing: Theme.Spacing.md) {
                StatItem(label: "灵感", value: "\(insights.count)")
                StatItem(label: "标签", value: "\(Set(insights.flatMap(\.tags)).count)")
                StatItem(label: "实体", value: "-")
            }
        }
    }

    // MARK: - 数据管理

    private var dataManagementSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("数据管理")
                .font(Theme.Typography.subheading)
                .foregroundStyle(Theme.Colors.ink)

            Button {
                showingClearAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .foregroundStyle(Theme.Colors.coral)
                    Text("清除所有数据")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.coral)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(Theme.Colors.paper)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.Colors.coral.opacity(0.3), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .alert("清除所有数据", isPresented: $showingClearAlert) {
                Button("取消", role: .cancel) { }
                Button("确认清除", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("这将删除所有已保存的灵感，此操作不可恢复。")
            }
        }
    }

    // MARK: - 辅助方法

    private func clearAllData() {
        do {
            let allInsights = try modelContext.fetch(FetchDescriptor<Insight>())
            for insight in allInsights {
                modelContext.delete(insight)
            }
            try modelContext.save()
        } catch {
            print("[Settings] 清除失败: \(error)")
        }
    }
}

// MARK: - 统计卡片

private struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(Theme.Typography.metric)
                .foregroundStyle(Theme.Colors.ink)
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.inkSoft)
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

#Preview {
    SettingsView()
        .modelContainer(for: Insight.self, inMemory: true)
}
