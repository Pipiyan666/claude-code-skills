import SwiftUI

// MARK: - 灵感胶囊 · 设计系统
//
// 美学方向：Editorial Diary（编辑型日记本）
//
// 灵感来源：
//   - The Gentlewoman 杂志的排版哲学
//   - Muji Passport 的克制
//   - Kinfolk 的静谧奶油色
//   - Le Labo 标签的 serif 感
//
// 避免的"AI slop"审美：
//   ❌ 紫色渐变 + 白底
//   ❌ 粉色系甜腻风
//   ❌ Inter / Roboto
//   ❌ Material 阴影
//   ❌ 所有角都圆的"软糯"风
//
// 我们的选择：奶油底色 + 墨蓝主色 + 珊瑚 accent
//           New York serif（系统自带）做显示标题
//           SF Pro Rounded 做正文
//           大间距 + 细线条 + 编辑感分割

enum Theme {

    // MARK: - 色板（Cream + Ink + Coral + Jade）

    enum Colors {
        /// 主背景：奶油色（几乎白，但带暖意）
        static let cream = Color(red: 253/255, green: 248/255, blue: 243/255)

        /// 次级背景：略深的象牙色
        static let ivory = Color(red: 247/255, green: 240/255, blue: 232/255)

        /// 卡片背景：近白（带微弱暖色）
        static let paper = Color(red: 255/255, green: 252/255, blue: 247/255)

        /// 主文字色：墨蓝（不用纯黑！）
        static let ink = Color(red: 26/255, green: 32/255, blue: 44/255)

        /// 次级文字色：灰墨
        static let inkSoft = Color(red: 94/255, green: 100/255, blue: 112/255)

        /// 三级文字色：淡灰
        static let inkMuted = Color(red: 166/255, green: 168/255, blue: 175/255)

        /// Accent 1：珊瑚红（不是粉红！有力度）
        static let coral = Color(red: 239/255, green: 88/255, blue: 78/255)

        /// Accent 2：薄荷绿（accent）
        static let jade = Color(red: 106/255, green: 177/255, blue: 150/255)

        /// Accent 3：灰粉色（柔和，用于背景）
        static let dustyRose = Color(red: 232/255, green: 197/255, blue: 192/255)

        /// 分割线/边框：几乎不可见的深色
        static let hairline = Color(red: 26/255, green: 32/255, blue: 44/255).opacity(0.08)

        /// 渐变网格背景（用于 hero 区域）
        static let gradientWash = LinearGradient(
            colors: [
                Color(red: 253/255, green: 248/255, blue: 243/255),
                Color(red: 247/255, green: 240/255, blue: 232/255),
                Color(red: 245/255, green: 232/255, blue: 225/255),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - 字体系统

    enum Typography {
        /// 超大标题（Hero）— New York serif italic，编辑感
        static let hero = Font.system(size: 44, weight: .regular, design: .serif)
            .italic()

        /// 大标题 — New York serif
        static let title = Font.system(size: 32, weight: .medium, design: .serif)

        /// 中标题
        static let heading = Font.system(size: 22, weight: .semibold, design: .serif)

        /// 小标题（SF Pro Rounded）
        static let subheading = Font.system(size: 17, weight: .semibold, design: .rounded)

        /// 正文
        static let body = Font.system(size: 15, weight: .regular, design: .rounded)

        /// 强调正文（引用、洞察）
        static let bodyEmphasis = Font.system(size: 15, weight: .regular, design: .serif)
            .italic()

        /// Caption
        static let caption = Font.system(size: 12, weight: .medium, design: .rounded)

        /// 超小字（meta 信息、时间戳）
        static let meta = Font.system(size: 10, weight: .medium, design: .rounded)

        /// 数字显示（Stats）
        static let metric = Font.system(size: 36, weight: .medium, design: .serif)

        /// 引号字符（装饰用）
        static let decorativeQuote = Font.system(size: 80, weight: .regular, design: .serif)
    }

    // MARK: - 间距（8pt grid but with editorial feel）

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let hero: CGFloat = 64
    }

    // MARK: - 圆角（比常规的更克制）

    enum Radius {
        static let tag: CGFloat = 4       // 标签：几乎是直角
        static let card: CGFloat = 16     // 卡片：优雅弧度
        static let sheet: CGFloat = 28    // 大 sheet：更柔和
        static let pill: CGFloat = 999    // 药丸形状
    }

    // MARK: - 阴影（柔和、有色温）

    enum Shadows {
        static func soft(_ color: Color = Theme.Colors.ink) -> some ViewModifier {
            ShadowModifier(
                color: color.opacity(0.06),
                radius: 20,
                x: 0,
                y: 8
            )
        }

        static func card() -> some ViewModifier {
            ShadowModifier(
                color: Color.black.opacity(0.04),
                radius: 16,
                x: 0,
                y: 4
            )
        }

        static func floating() -> some ViewModifier {
            ShadowModifier(
                color: Color.black.opacity(0.12),
                radius: 32,
                x: 0,
                y: 16
            )
        }
    }

    // MARK: - 动画

    enum Motion {
        static let quick = Animation.smooth(duration: 0.25)
        static let standard = Animation.smooth(duration: 0.4)
        static let emphasized = Animation.spring(response: 0.5, dampingFraction: 0.75)
        static let dramatic = Animation.spring(response: 0.8, dampingFraction: 0.7)

        /// stagger 延迟（用于列表项依次出现）
        static func stagger(_ index: Int, delay: Double = 0.05) -> Animation {
            .spring(response: 0.6, dampingFraction: 0.75)
                .delay(Double(index) * delay)
        }
    }
}


// MARK: - ViewModifiers（可复用的装饰）

struct ShadowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    func body(content: Content) -> some View {
        content.shadow(color: color, radius: radius, x: x, y: y)
    }
}


// MARK: - 通用视图组件

extension View {
    /// Editorial 卡片样式：奶油底 + 细边框 + 柔和阴影
    func editorialCard() -> some View {
        self
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.paper)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .stroke(Theme.Colors.hairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .modifier(Theme.Shadows.card())
    }

    /// Editorial 标签样式：serif italic，细边框，近直角
    func editorialTag(color: Color = Theme.Colors.ink) -> some View {
        self
            .font(.system(size: 11, weight: .medium, design: .serif).italic())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.tag)
                    .stroke(color.opacity(0.35), lineWidth: 1)
            )
            .foregroundStyle(color)
    }

    /// Primary CTA 按钮样式：墨蓝底 + 奶油字 + 柔和阴影
    func editorialButton() -> some View {
        self
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.Colors.cream)
            .padding(.vertical, 16)
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity)
            .background(Theme.Colors.ink)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .modifier(Theme.Shadows.soft(Theme.Colors.ink))
    }

    /// Secondary 按钮：透明底 + 墨蓝边框
    func editorialButtonSecondary() -> some View {
        self
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(Theme.Colors.ink)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.Colors.ink.opacity(0.25), lineWidth: 1.5)
            )
    }
}


// MARK: - 装饰性组件

/// 编辑型分隔线：细线 + 中间小符号
struct EditorialDivider: View {
    var ornament: String = "·"

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Theme.Colors.hairline)
            Text(ornament)
                .font(.system(size: 14, weight: .regular, design: .serif))
                .foregroundStyle(Theme.Colors.inkMuted)
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Theme.Colors.hairline)
        }
    }
}

/// 编辑章节标题（双线条 + serif italic 小字）
struct EditorialSectionTitle: View {
    let label: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .tracking(2.5)
                .foregroundStyle(Theme.Colors.coral)
            Text(title)
                .font(Theme.Typography.heading)
                .foregroundStyle(Theme.Colors.ink)
        }
    }
}

/// 引用块（装饰性大引号）
struct EditorialQuote: View {
    let text: String
    let source: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("\u{201C}")
                .font(Theme.Typography.decorativeQuote)
                .foregroundStyle(Theme.Colors.coral.opacity(0.3))
                .offset(y: 20)
                .frame(height: 40, alignment: .topLeading)

            Text(text)
                .font(Theme.Typography.bodyEmphasis)
                .foregroundStyle(Theme.Colors.ink)
                .padding(.leading, Theme.Spacing.md)

            if let source {
                Text("— \(source)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.inkSoft)
                    .padding(.leading, Theme.Spacing.md)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.ivory)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
}

/// 纸张纹理背景（细腻 noise overlay）
struct PaperBackground: View {
    var body: some View {
        ZStack {
            Theme.Colors.gradientWash
                .ignoresSafeArea()
            // 极淡的 noise（用 system material 模拟）
            Color.clear
                .background(.ultraThinMaterial.opacity(0.3))
                .ignoresSafeArea()
        }
    }
}
