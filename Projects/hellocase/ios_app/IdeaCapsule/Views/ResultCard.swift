import SwiftUI

// MARK: - ResultCard — AI 分析结果卡片
//
// 在 CaptureView 里展示刚刚分析完的灵感。
// 用 morphing 动画从输入区"长出"这个卡片。

struct ResultCard: View {
    let insight: Insight
    @Namespace private var namespace

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("已保存到知识库")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(insight.summary)
                .font(.title3.bold())

            HStack(spacing: 6) {
                Text(insight.category)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.tint.opacity(0.2))
                    .clipShape(.capsule)

                ForEach(insight.tags.prefix(4), id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("💡 AI 洞察")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(insight.aiInsight)
                    .font(.callout)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(.green.opacity(0.1)),
                     in: .rect(cornerRadius: 20))
    }
}
