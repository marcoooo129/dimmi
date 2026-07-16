// GlassCard —— dimmi 的「真玻璃」基元。
//
// 设计铁律：
//   1. 填充 = 暖白 14%（FFFBF4 @ 0.14），不是任何深色。玻璃是"加光的薄片"，不是"减光的蒙版"。
//   2. 只用 .ultraThinMaterial ——regular / thick 太实，会退化成灰板。
//   3. 顺序：material → fill → clip → shadow。clip 必须在 shadow 之前。
//   4. 材质需要背后有内容可模糊。DimmiBackground 的三团光斑必须在，
//      否则 material 退化成死的半透明片。
//
// 历史卡 / 设置卡 / Onboarding 卡都用同一个 GlassCard ——
// 历史卡透设置窗自己的光斑，设置卡透 DimmiBackground。
//
// 浮窗（TranslationPanelView）【不用】GlassCard ——
// 它有独立的强模糊暖灰毛玻璃和可读性薄纱，需在任意网页上保持稳定对比度。
// 两类卡形状/字体/图标/圆角全部相同，只有材质不同。这是刻意的。
import SwiftUI

/// 真玻璃卡片：透窗背景光斑，自身只贡献"暖白 14%" 染色。
///
/// - Parameters:
///   - radius: 卡片圆角（默认 26，与 pageRadius 一致）
///   - fill: 自定义填充（默认暖白 14%，**不要传深色**，否则立即退化成不透明块）
///   - isRaised: 是否走更亮的 fill（选中态 / 强调），玻璃本身的填充比例 +0.02
struct GlassCard<Content: View>: View {
    var radius: CGFloat = DimmiTheme.pageRadius
    var fill: Color? = nil
    var isRaised: Bool = false
    @ViewBuilder var content: Content

    private var resolvedFill: Color {
        if let f = fill { return f }
        return isRaised ? DimmiTheme.glassFillRaised : DimmiTheme.glassFill
    }

    var body: some View {
        content
            // ① 模糊背后的光斑
            .background(.ultraThinMaterial)
            // ② 极淡暖白淡染（0.14 / 0.16）。暖白，不是冷白/纯白 —— 冷白叠在沙色背景上会发青。
            .background(resolvedFill)
            // ③ 兜底裁剪 + ④ 中性软阴影。
            // 不再叠加单独的顶部白色高光：它只照亮一条边，在低对比玻璃上
            // 会呈现为突兀的 1pt 白线，和其余三边不一致。
            //    clip 必须先于 shadow，否则阴影被裁掉 —— 这是之前浮窗外的卡永远"贴地"的根因。
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .compositingGroup()
            .shadow(color: .black.opacity(0.10), radius: 20, y: 10)
    }
}

// MARK: - 子页分组标题（玻璃语言里的组标识）

/// 子页分组标题：10pt medium、tracking 1.6、全大写风格、低对比度。
/// 玻璃卡片里不放嵌套容器，组与组之间靠"标题 + 极淡分隔线"区分。
struct GroupLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(DimmiFont.settingsSectionCaption)
            .tracking(1.6)
            .foregroundStyle(DimmiTheme.textLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textCase(.uppercase)
    }
}

/// 玻璃分隔线：1px 暖白 9%，上下 12 间距。
/// 玻璃语言里这是【唯一允许的】组与组之间分隔。
struct GlassDivider: View {
    var paddingV: CGFloat = 12
    var body: some View {
        Rectangle()
            .fill(DimmiTheme.glassDivider)
            .frame(height: 1)
            .padding(.vertical, paddingV)
    }
}

// MARK: - 输入框凹陷（玻璃语言里唯一的例外：可以"暗"，模拟刻进玻璃的槽）

/// 输入框 / 段控件等「凹陷」控件：
///   - 轻微压暗（Color.black.opacity(0.10)）= 凹进去的视觉
///   - 1px 暖白描边（0.18 默认）
///   - focus 态：描边提到 0.45 + 外发光暖白 12% radius 8（**不要系统蓝 focus ring**）
struct SunkenInput<Content: View>: View {
    var radius: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(Color.black.opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(DimmiTheme.glassDivider.opacity(2.0), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
