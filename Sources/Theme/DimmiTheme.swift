// 「褪色黄昏 · 毛玻璃」design tokens —— 唯一事实来源。
//
// 任何视图文件里**不允许**出现字面量色值。
// 需要新色时来这里加 token，旧 token 不要就地改色——改 DimmiTheme 会改全局观感。
//
// 深色模式：**不做。** 这套配色本身已经是暗的、有情绪的，
// 锁定 .preferredColorScheme(.dark)，系统外观切换不影响本 App。
// （这是刻意决定，不是遗漏。）
//
// 文件后半段的 Dia / Aetheric / Luminous Glass 旧 token 是**迁移期兼容层**：
// 历史窗 / 浮窗 / Onboarding 还没换皮（阶段 2-4），删了会崩。阶段 4 收尾时整段删除。
import SwiftUI

enum DimmiTheme {

    // MARK: - 背景：褪色黄昏

    // 主渐变（近乎垂直）。饱和度极低——所有颜色接近灰，只是偏暖。
    // 中段有一条亮的沙色带，上下两端压暗成灰紫褐。
    static let bgTop     = Color(hex: "5F5359")   // 灰紫褐（暗）
    static let bgUpper   = Color(hex: "6E6058")   // 暖褐
    static let bgMid     = Color(hex: "8D7C67")   // 沙褐
    static let bgLight   = Color(hex: "B3A085")   // 亮沙（最亮的一条带）
    static let bgLower   = Color(hex: "8A7A6B")
    static let bgBottom  = Color(hex: "5C5049")   // 压暗收尾

    // 光斑（叠在渐变上，大半径模糊）。毛玻璃的质感全靠"磨"它们——
    // 光斑没了 = 玻璃变成一块死的半透明白片。
    static let blobWarm  = Color(hex: "E4D0AC").opacity(0.55)  // 暖沙光，中偏左
    static let blobSand  = Color(hex: "D4BEA6").opacity(0.40)  // 沙色，右上
    static let blobDark  = Color(hex: "605250").opacity(0.50)  // 暗紫褐，左下

    // MARK: - 玻璃（薄片，不是卡片）
    // 注意：是【暖白】不是纯白。纯白叠在沙色上会发青、发脏。

    static let glassFill        = Color(hex: "FFFBF4").opacity(0.14)
    static let glassFillRaised  = Color(hex: "FFFBF4").opacity(0.16)  // 选中行 / 强调
    static let glassFillHover   = Color(hex: "FFFBF4").opacity(0.18)  // 胶囊按钮 hover
    /// 胶囊按钮的上缘高光（比大卡的 0.52 弱一档）
    static let glassPillEdgeTop = Color(hex: "FFFBF4").opacity(0.42)
    /// 卡内 hover / 选中行的上缘高光（再弱一档）
    static let glassRowEdgeTop  = Color(hex: "FFFBF4").opacity(0.30)
    static let glassEdgeTop     = Color(hex: "FFFBF4").opacity(0.52)  // 上缘高光（最亮）
    static let glassEdgeLeading = Color(hex: "FFFBF4").opacity(0.24)  // 左缘
    static let glassEdgeTrailing = Color(hex: "FFFBF4").opacity(0.10) // 右缘（很弱）
    static let glassEdgeBottom  = Color(hex: "FFFBF4").opacity(0.07)  // 下缘（几乎没有）
    static let glassDivider     = Color(hex: "FFFBF4").opacity(0.09)

    // MARK: - 文字（全部暖白系，不用纯白）

    static let textPrimary   = Color.white                              // 标题 / 译文
    static let textBody      = Color(hex: "FFFAF2").opacity(0.88)      // 正文
    static let textSecondary = Color(hex: "FFFAF2").opacity(0.58)      // 说明
    static let textTertiary  = Color(hex: "FFFAF2").opacity(0.36)      // 元信息 / 占位
    static let textLabel     = Color(hex: "FFFAF2").opacity(0.34)      // 分组标题（全大写字距）

    // MARK: - 图标

    static let icon        = Color.white.opacity(0.85)
    static let iconMuted   = Color(hex: "FFFAF2").opacity(0.36)   // chevron 等

    // MARK: - 主操作圆钮（全 App 唯一的实心）

    static let primaryFill = Color(hex: "FFFCF7")   // 暖白，不是纯白
    static let primaryFg   = Color(hex: "6B5D52")   // 钮上的图标/文字：暖褐
    static let primaryShadow = Color(hex: "3C302A").opacity(0.28)

    // ═══════════════════════════════════════════════════════════
    // 以下全部为【迁移期兼容层】（Dia / Aetheric / Luminous Glass 旧 token）
    // 历史窗 / 浮窗 / Onboarding 换皮后（阶段 4）整段删除。
    // ═══════════════════════════════════════════════════════════

    // MARK: - 背景（设置窗 / Onboarding 窗共用）

    static let bgBaseLight      = Color(hex: "FBF7F8")    // 底色，近白微粉
    static let bgBaseDark       = Color(hex: "1E1C1E")    // 深色底，深灰
    static let bgGlowLight      = Color(hex: "F4C9D5")    // 光晕中心（浅，玫瑰）
    static let bgGlowDark       = Color(hex: "3D2A31")    // 玫瑰光晕中心（深）
    static let bgGlowEdgeLight  = Color(hex: "FAE4EA")    // 光晕外缘（浅）
    static let bgGlowEdgeDark   = Color(hex: "292328")    // 光晕外缘（深）

    /// 卡片外圈的玫瑰辉光。Dia 的白卡不是"投影"，是"发光"——
    /// 卡边缘那圈粉色不是背景透出来的，是卡自己往外晕。
    static let bloomLight       = Color(hex: "E8879F")
    static let bloomDark        = Color(hex: "8A4E60")

    // MARK: - 卡片

    static let cardBgLight      = Color.white
    static let cardBgDark       = Color(hex: "262428")
    /// 卡片 1px 描边（在白色网页 / 浅桌面上的边界感来源）
    static let cardBorderLight  = Color.black.opacity(0.04)
    static let cardBorderDark   = Color.white.opacity(0.06)

    /// 卡片圆角。注意：浮窗用 20（更紧），设置行 / Onboarding 大卡用 24
    static let cardRadius: CGFloat = 20
    /// 玻璃大卡圆角（v5 收紧规范：32 → 26）。GlassCard 的默认值读这里。
    static let pageRadius: CGFloat = 26
    static let rowRadius: CGFloat = 12
    static let pillRadius: CGFloat = 999      // 胶囊=圆角矩形（full radius）

    // MARK: - 浮窗毛玻璃（浮窗专用；设置窗 / 历史窗仍是实底白卡）

    /// 毛玻璃上的提字纱层：没有它，花哨网页上文字可读性极差。
    /// 浅色 0.55 是"能看清背后有东西、但文字清晰"的平衡点；
    /// 实测难读可升到 0.65，**不要超过 0.75**（等于回到不透明卡）。
    static let glassTintLight   = Color.white.opacity(0.55)
    static let glassTintDark    = Color.black.opacity(0.35)
    /// 毛玻璃边界描边（0.5pt）——没有它卡会融进背景，纯白网页上尤其明显
    static let glassBorderLight = Color.white.opacity(0.35)
    static let glassBorderDark  = Color.white.opacity(0.25)

    // MARK: - 文字

    static let textPrimaryLight   = Color(hex: "2A2A2E")
    static let textPrimaryDark    = Color(hex: "ECEAEB")
    static let textSecondaryLight = Color(hex: "6E6A6D")
    static let textSecondaryDark  = Color(hex: "A8A4A7")
    static let textTertiaryLight  = Color(hex: "B9B3B6")
    static let textTertiaryDark   = Color(hex: "6E6A6D")

    // MARK: - 图标（全局唯一图标色）

    static let iconLight = Color(hex: "8E8A8D")
    static let iconDark  = Color(hex: "9A969A")

    // MARK: - 按钮

    static let pillBorderLight  = Color(hex: "E8E4E6")
    static let pillBorderDark   = Color.white.opacity(0.10)
    static let pillBgHoverLight = Color(hex: "F3F0F1")
    static let pillBgHoverDark  = Color.white.opacity(0.06)
    static let tonalBgLight     = Color(hex: "EFECED")
    static let tonalBgDark      = Color.white.opacity(0.07)

    /// 主操作：浅色下近黑底白字，深色下反向（白光字）
    static let primaryBgLight   = Color(hex: "1C1B1D")
    static let primaryBgDark    = Color(hex: "ECEAEB")
    static let primaryFgLight   = Color.white
    static let primaryFgDark    = Color(hex: "1C1B1D")

    // MARK: - 分隔

    static let dividerLight = Color.black.opacity(0.06)
    static let dividerDark  = Color.white.opacity(0.06)

    // MARK: - Aetheric Surface（设置窗 shell 专用）

    static let surfaceBackgroundLight = Color(hex: "FBF7F8")
    static let surfaceBackgroundDark  = Color(hex: "1E1C1E")
    static let surfaceContainerLowLight = Color(hex: "FCF1F4")
    static let surfaceContainerLowDark  = Color(hex: "2A2628")
    static let surfaceBrightLight = Color(hex: "FFF8F8")
    static let surfaceBrightDark  = Color(hex: "252226")
    static let surfaceVariantLight = Color(hex: "EAE0E3")
    static let surfaceVariantDark  = Color(hex: "383334")
    static let outlineVariantLight = Color(hex: "D3C2C5")
    static let outlineVariantDark  = Color(hex: "4F4446")

    // MARK: - Aetheric Typography & Buttons

    static let onSurfaceLight = Color(hex: "1F1A1D")
    static let onSurfaceDark  = Color(hex: "EAE0E3")
    static let onSurfaceVariantLight = Color(hex: "4F4446")
    static let onSurfaceVariantDark  = Color(hex: "817476")
    static let onPrimaryContainerLight = Color(hex: "76515C")
    static let onPrimaryContainerDark  = Color(hex: "F8C8D4")
    static let primaryContainerLight = Color(hex: "F8C8D4")
    static let primaryContainerDark  = Color(hex: "5F3D47")
    static let inverseSurfaceLight = Color(hex: "352F31")
    static let inverseSurfaceDark  = Color(hex: "E9E0E2")
    static let inverseOnSurfaceLight = Color(hex: "F9EEF1")
    static let inverseOnSurfaceDark  = Color(hex: "352F31")
    static let onInverseSurfaceLight = Color.white
    static let onInverseSurfaceDark  = Color(hex: "1B1C1C")

    // MARK: - Luminous Glass（Dimmi 翻译浮窗专用）
    //
    // 来自 Dimmi 网页设计稿（"Luminous Glass Translation"）。
    // 设计要点：
    //   - 深底 + 高对比度毛玻璃卡（浮窗是透窗，卡内背景要自包含发光感）
    //   - 文字走白色 alpha 渐变，主译文白 → 70% 白
    //   - 强调按钮（mic）走粉 → 紫渐变 + 0.4 强度粉光晕
    //   - aurora 极光只画在卡内（z-index 隔离），不污染窗外网页
    //
    // 亮 / 暗色适配：
    //   - 亮色：卡面 = 白 + 玻璃纱；译文走深灰渐变（亮卡上白字看不清）
    //   - 暗色：卡面 = 深紫蓝 + 白 alpha 玻璃纱；译文走白色 alpha 渐变（与设计稿一致）

    /// 玻璃卡底色：浅色 = 浅暖灰白，深色 = 深紫蓝
    static let glassBgLight = Color(hex: "ECEAF1")
    static let glassBgDark  = Color(hex: "1A1326")

    /// 玻璃卡面白色 alpha 渐变（卡内纱层叠加到玻璃底色之上，给"发光"感）
    /// 浅色：白 0.30 → 0.10；深色：白 0.15 → 0.05
    static let glassOverlayLightTop    = Color.white.opacity(0.30)
    static let glassOverlayLightBottom = Color.white.opacity(0.10)
    static let glassOverlayDarkTop     = Color.white.opacity(0.15)
    static let glassOverlayDarkBottom  = Color.white.opacity(0.05)

    /// 玻璃卡 1pt 描边（白 alpha 0.20-0.30）
    static let glassStrokeLight = Color.white.opacity(0.45)
    static let glassStrokeDark  = Color.white.opacity(0.22)

    /// 玻璃卡内 inset highlight（顶部 1pt 高光，让卡有"立体感"）
    static let glassInsetHighlightLight = Color.white.opacity(0.55)
    static let glassInsetHighlightDark  = Color.white.opacity(0.18)

    // MARK: - 译文渐变文字（主译文 / 目标译文）
    //
    // 浅色卡上不能用白 → 70% 白，亮背景上根本看不见。
    // 浅色卡走深灰 → 中灰，深色卡走白 → 半透白。

    /// 主译文（Italian hero）：浅 = 深灰渐变；深 = 白渐变
    static let heroTextLightTop = Color(hex: "1F1B22")
    static let heroTextLightBottom = Color(hex: "1F1B22").opacity(0.70)
    static let heroTextDarkTop  = Color.white
    static let heroTextDarkBottom = Color.white.opacity(0.72)

    /// 目标译文（Chinese）：粉 → 紫
    static let accentTextLightTop    = Color(hex: "AC2A5D")
    static let accentTextLightBottom = Color(hex: "5C4FB5")
    static let accentTextDarkTop     = Color(hex: "FFB1C5")
    static let accentTextDarkBottom  = Color(hex: "C7BFFF")

    /// 中文拼音 / 副文本：白 alpha 0.6
    static let captionAlphaLight = Color(hex: "574146").opacity(0.65)
    static let captionAlphaDark  = Color.white.opacity(0.60)

    /// chip / label（Italian / Chinese (Simplified) 等）：白 alpha 0.5
    static let chipTextLight = Color.black.opacity(0.45)
    static let chipTextDark  = Color.white.opacity(0.55)

    // MARK: - Aurora 极光（卡内）
    //
    // 与设计稿同色：粉 #ff6b9d、紫 #5c4fb5、青 #00acd7
    // 卡内可放心使用——clipShape 会兜底，不会泄到窗外。

    static let auroraPink  = Color(hex: "FF6B9D")
    static let auroraPurple = Color(hex: "5C4FB5")
    static let auroraTeal   = Color(hex: "00ACD7")

    // MARK: - 玻璃图标色（白 alpha 0.8-1.0）
    static let glassIconLight = Color.black.opacity(0.55)
    static let glassIconDark  = Color.white.opacity(0.80)

    // MARK: - 旧 Theme 兼容
    /// 任务书不允许"旧 Theme"残留，但 RevealRenderer / 浮窗旧代码还在引用 Theme.textPrimary。
    /// 这里做一层 alias，让旧引用继续工作（暂返回浅色版，等所有 view 改造完删）。
    enum Legacy {
        static let textPrimary: Color = DimmiTheme.textPrimaryLight
        static let cardRadius: CGFloat = DimmiTheme.cardRadius
    }
}

// MARK: - ColorScheme 自动切换的 View 扩展

extension DimmiTheme {
    static func textPrimary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? textPrimaryDark : textPrimaryLight
    }
    static func textSecondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? textSecondaryDark : textSecondaryLight
    }
    static func textTertiary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? textTertiaryDark : textTertiaryLight
    }
    static func cardBg(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? cardBgDark : cardBgLight
    }
    static func cardBorder(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? cardBorderDark : cardBorderLight
    }
    static func bgBase(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? bgBaseDark : bgBaseLight
    }
    static func bgGlow(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? bgGlowDark : bgGlowLight
    }
    static func bgGlowEdge(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? bgGlowEdgeDark : bgGlowEdgeLight
    }
    static func icon(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? iconDark : iconLight
    }
    static func bloom(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? bloomDark : bloomLight
    }
    static func glassTint(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? glassTintDark : glassTintLight
    }
    static func glassBorder(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? glassBorderDark : glassBorderLight
    }
    static func divider(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? dividerDark : dividerLight
    }
    static func pillBorder(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? pillBorderDark : pillBorderLight
    }
    static func pillBgHover(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? pillBgHoverDark : pillBgHoverLight
    }
    static func tonalBg(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? tonalBgDark : tonalBgLight
    }
    static func primaryBg(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? primaryBgDark : primaryBgLight
    }
    static func primaryFg(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? primaryFgDark : primaryFgLight
    }

    // MARK: - Luminous Glass accessors

    static func glassBg(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? glassBgDark : glassBgLight
    }
    static func glassOverlayTop(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? glassOverlayDarkTop : glassOverlayLightTop
    }
    static func glassOverlayBottom(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? glassOverlayDarkBottom : glassOverlayLightBottom
    }
    static func glassStroke(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? glassStrokeDark : glassStrokeLight
    }
    static func glassInsetHighlight(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? glassInsetHighlightDark : glassInsetHighlightLight
    }
    static func heroTextTop(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? heroTextDarkTop : heroTextLightTop
    }
    static func heroTextBottom(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? heroTextDarkBottom : heroTextLightBottom
    }
    static func accentTextTop(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? accentTextDarkTop : accentTextLightTop
    }
    static func accentTextBottom(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? accentTextDarkBottom : accentTextLightBottom
    }
    static func captionAlpha(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? captionAlphaDark : captionAlphaLight
    }
    static func chipText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? chipTextDark : chipTextLight
    }
    static func glassIcon(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? glassIconDark : glassIconLight
    }

    // MARK: - Aetheric theme accessors

    static func surfaceBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? surfaceBackgroundDark : surfaceBackgroundLight
    }
    static func surfaceContainerLow(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? surfaceContainerLowDark : surfaceContainerLowLight
    }
    static func surfaceBright(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? surfaceBrightDark : surfaceBrightLight
    }
    static func surfaceVariant(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? surfaceVariantDark : surfaceVariantLight
    }
    static func outlineVariant(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? outlineVariantDark : outlineVariantLight
    }
    static func onSurface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? onSurfaceDark : onSurfaceLight
    }
    static func onSurfaceVariant(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? onSurfaceVariantDark : onSurfaceVariantLight
    }
    static func onPrimaryContainer(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? onPrimaryContainerDark : onPrimaryContainerLight
    }
    static func primaryContainer(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? primaryContainerDark : primaryContainerLight
    }
    static func inverseSurface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? inverseSurfaceDark : inverseSurfaceLight
    }
    static func inverseOnSurface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? inverseOnSurfaceDark : inverseOnSurfaceLight
    }
    static func onInverseSurface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? onInverseSurfaceDark : onInverseSurfaceLight
    }
}

// MARK: - 弥散软阴影（Dia 的灵魂：贴地 + 弥散）

extension View {
    /// 卡片 / 面板用。两层缺一不可：
    ///   - 贴地层 (radius 3, y 2)：提供边界感，白卡浮起时不被吃进背景
    ///   - 弥散层 (radius 24, y 12)：柔光漂浮感
    /// compositingGroup() 不能删：SwiftUI 的 .shadow 会往下钻到每个叶子节点，
    /// 给卡里的**每行文字**各自描一圈阴影（白卡上会看到文字后面一坨脏影）。
    /// 先压平成一层，阴影才只认卡的外轮廓。
    /// 浮窗那边碰巧有 clipShape 先压平，所以一直没暴露。
    func diaCardShadow(_ scheme: ColorScheme = .light) -> some View {
        let k = scheme == .dark ? 2.0 : 1.0
        return self
            .compositingGroup()
            .shadow(color: .black.opacity(0.04 * k), radius: 3, y: 2)
            .shadow(color: .black.opacity(0.06 * k), radius: 24, y: 12)
    }

    /// 窗口主卡用（设置 / 引导）。在 diaCardShadow 之上再加两圈玫瑰辉光。
    ///
    /// 辉光要**无偏移**（y: 0）：Dia 的粉是从卡边缘均匀往外洇的，一旦给 y 就变成
    /// "粉色投影"，卡会显得往下掉。近圈小而实提供颜色，远圈大而淡把粉推到窗边。
    ///
    /// 只给窗口卡用。浮窗（TranslationPanel）叠在任意桌面内容上，粉圈会脏，别加。
    func diaBloomShadow(_ scheme: ColorScheme = .light) -> some View {
        self
            .diaCardShadow(scheme)
            .shadow(color: DimmiTheme.bloom(scheme).opacity(0.22), radius: 28)
            .shadow(color: DimmiTheme.bloom(scheme).opacity(0.14), radius: 72)
    }

    /// Dimmi 翻译浮窗专用：Luminous Glass 卡片修饰。
    ///
    /// 三件事一气呵成：
    ///   1. 玻璃底色（深紫蓝或浅暖灰）
    ///   2. 白色 alpha 渐变 overlay（45° topLeading → bottomTrailing，给"发光"感）
    ///   3. 1pt 白 alpha 描边 + 顶部 inset highlight（立体感）
    ///
    /// 阴影：仍走 diaCardShadow 的中性软阴影，不加粉光晕（透窗禁忌）。
    /// 噪点 / aurora 由调用方在卡内叠加（clipShape 兜底）。
    func luminousGlassCard(_ scheme: ColorScheme = .light) -> some View {
        let cornerRadius = DimmiTheme.cardRadius
        return self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DimmiTheme.glassBg(scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DimmiTheme.glassOverlayTop(scheme),
                                DimmiTheme.glassOverlayBottom(scheme)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(DimmiTheme.glassStroke(scheme), lineWidth: 1)
            )
            .overlay(
                // 顶部 inset highlight：1pt 高光线，圆角矩形用 trim 拉不出干净的 1pt，
                // 用一条 rectangle 顶部贴边 + 渐隐 mask 实现。
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    DimmiTheme.glassInsetHighlight(scheme),
                                    DimmiTheme.glassInsetHighlight(scheme).opacity(0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 1)
                    Spacer(minLength: 0)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
    }
}

// MARK: - 渐变文字

extension View {
    /// Luminous Glass 设计稿里的 `text-gradient-primary`：白色 → 70% 白色。
    /// 深色卡上用，亮色卡上 heroTextTop/Bottom 已经是深灰，不会调这个。
    func textGradientPrimary(_ scheme: ColorScheme = .light) -> some View {
        self.overlay(
            LinearGradient(
                colors: [
                    DimmiTheme.heroTextTop(scheme),
                    DimmiTheme.heroTextBottom(scheme)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .mask(self)
    }

    /// 设计稿 `text-gradient-secondary`：粉 → 紫
    func textGradientSecondary(_ scheme: ColorScheme = .light) -> some View {
        self.overlay(
            LinearGradient(
                colors: [
                    DimmiTheme.accentTextTop(scheme),
                    DimmiTheme.accentTextBottom(scheme)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .mask(self)
    }
}

// MARK: - Color(hex:) 已存在（旧的 Theme.swift 里有）
// 这里不重复定义，让旧文件继续提供 extension。
