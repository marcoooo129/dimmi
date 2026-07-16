// dimmi 字体 token —— 唯一字体入口。
//
// 「褪色黄昏」版：西文 **Poppins**（Google Fonts，SIL OFL，商用免费），
// 中文走系统 PingFang SC 自动 fallback。
// **推翻 Inter**：Inter 是直角的、工程感的，和这套圆润几何语言冲突。
//
// 视图里**不允许**直接调 `.font(.system(...))` 或 `.custom(...)`，
// 只能引用语义 token。
//
// 字距（tracking）是这套语言的关键，在视图层配合使用：
//   - 大标题（24pt+）：.tracking(0.6) —— 刻意放松，有呼吸感
//   - 译文（20pt）：.tracking(0.3)
//   - 分组标题（11pt）：.tracking(1.6) + 全部用中文短词
//   - 正文正常，不加 tracking
//
// 中西混排：中文字重必须跟着西文走——西文 Light 时中文也要轻，
// 否则中文显得比西文重一大截（PingFang fallback 自动按 weight 匹配）。
//
// 字体注册：Info.plist 的 ATSApplicationFontsPath = "Fonts"（macOS 专用 key），
// 文件在 Resources/Fonts/Poppins-{Light,Regular,Medium,LightItalic}.ttf。
//
// 文件后半段的 inter / settings* / detail* 等旧 token 是**迁移期兼容层**
// （历史窗 / 浮窗 / Onboarding 阶段 2-4 换皮时逐个消灭，最后整段删）。
import SwiftUI
import AppKit

enum DimmiFont {

    // MARK: - Poppins 构造器

    static func poppins(_ size: CGFloat, _ w: Font.Weight = .light) -> Font {
        .custom("Poppins", size: size).weight(w)
    }
    static func poppinsItalic(_ size: CGFloat) -> Font {
        .custom("Poppins-LightItalic", size: size)
    }

    // MARK: - 语义 token（「褪色黄昏」，视图里只准用这些）

    // v5 收紧一档：窗口 500×460，内容填满不留大片空白
    static let appTitle      = poppins(23, .light)     // "dimmi"        （27→23）
    static let pageTitle     = poppins(21, .light)     // 子页标题         （24→21）
    static let display       = poppins(20, .light)     // 译文主体 / 历史卡译文
    static let rowTitle      = poppins(14, .regular)   // 设置行标题        （15→14）
    static let body          = poppins(13, .regular)  // 正文              （14→13）
    static let caption       = poppins(11, .regular)   // 说明文字         （12→11）
    static let captionSmall  = poppins(10, .regular)   // 元信息           （11→10）
    static let groupLabel    = poppins(10, .regular)   // 分组标题（配 tracking 1.6）

    // ═══════════════════════════════════════════════════════════
    // 以下为【迁移期兼容层】（Inter 旧 token），阶段 4 整段删除
    // ═══════════════════════════════════════════════════════════

    // MARK: - 构造器

    /// 西文 Inter + 中文 PingFang SC fallback。
    /// size: 字号（pt）
    /// weight: 静态字重
    ///
    /// **字体加载机制**：Bundle 里注册的是 `InterVariable.ttf`（family = "Inter Variable"），
    /// SwiftUI 的 `.custom(name, size:)` 必须给 **PostScript name** 或 family name。
    /// 经验：family name `"Inter Variable"` + `.weight(.semibold)` 在 macOS 上
    /// 会自动路由到 Inter 的 wght 变体 axis（100–900）。
    static func inter(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Inter Variable", size: size, relativeTo: .body)
            .weight(weight)
    }

    /// Inter 斜体（用于意语例句）。
    static func interItalic(_ size: CGFloat) -> Font {
        .custom("InterVariable-Italic", size: size, relativeTo: .body)
    }

    /// 中文专用：Inter 不含中文字形，用 PingFang SC 即可，
    /// 这里其实是占位 token——目前中文都用上面的 inter() 自动 fallback。
    /// 保留这个入口以便未来单独调整中文 size 时不必改所有视图。
    static func zh(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    // MARK: - 语义化 token（视图里只准用这些）

    /// 译文主体（意语大字号主显示）
    static let displayLarge  = inter(20, .semibold)

    /// 浮窗译文主体字号：参考样图的编辑式大正文，保持 340pt 卡宽下的可读密度。
    /// SwiftUI 渲染与 TextMeasurer 离屏测高**必须**共用这个数：
    /// 两边字号不一致 = 测出的行数不对 = 卡片高度错 → 译文被压出 "…"。
    static let panelHeroSize: CGFloat = 18
    /// 浮窗译文主体（渲染用）
    static let panelHero     = poppins(panelHeroSize, .medium)

    /// 正文（释义 / usage）
    static let bodyRegular   = inter(13, .regular)

    /// 正文 medium（breakdown / 标签强调）
    static let bodyMedium    = inter(13, .medium)

    // caption / captionSmall 已由上方 Poppins 语义 token 接管（同名，字号一致）

    /// 小字 medium（panel 内 chip / 类型标签）
    static let captionSmallMedium = inter(11, .medium)

    /// 例句斜体（意语例句）
    static let exampleItalic = interItalic(13)

    /// 例句中文（小一号，对齐 Inter baseline）
    static let exampleZh     = inter(11, .regular)

    /// 例句英文释义（同正文）
    static let exampleEn     = inter(12, .regular)

    // appTitle / rowTitle 已由上方 Poppins 语义 token 接管

    static let appSubtitle   = inter(11, .regular)

    static let rowSubtitle   = inter(11, .regular)

    static let detailHeader  = inter(21, .semibold)

    static let detailSection = inter(18, .semibold)

    static let detailBody    = inter(13, .regular)

    static let detailBodyMedium = inter(13, .medium)

    static let toolbarLabel  = inter(12, .regular)

    // MARK: - Aetheric 设置窗补充

    static let settingsHeroTitle = pageTitle
    static let settingsSectionTitle = inter(14, .semibold)
    static let settingsSectionCaption = inter(10, .medium) // 分组标题  （11→10）
    static let settingsBody = inter(12, .regular)         // 正文        （13→12）
    static let settingsSmall = inter(10, .medium)         // 小字        （11→10）
    static let settingsTitleLabel = inter(11, .medium)    // 标签        （12→11）
    static let settingsLabel = inter(13, .medium)        // 行标题      （14→13）
    static let settingsPill = inter(12, .medium)         // 胶囊        （13→12）

    // MARK: - 等宽数字 token（计数 / 时间戳 / Tabular figures）

    /// 13pt 等宽数字（计数 计数）
    static let monoMedium13 = mono(13, .medium)
    /// 11pt 等宽数字（XX 条 / 时间戳）
    static let monoMedium11 = mono(11, .medium)
    /// 10pt 等宽数字
    static let monoMedium10 = mono(10, .medium)

    private static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Inter", size: size, relativeTo: .body)
            .weight(weight)
            .monospaced()
    }

    /// 段落小字大写（话题分组小标题）
    static let sectionEyebrow = inter(10, .semibold).smallCaps()

    // MARK: - NSFont 入口（用于 TextMeasurer 等 AppKit 测量路径）

    /// NSFont 版 Poppins，供原生可选择文字与 SwiftUI 的 Poppins token 对齐。
    static func nsPoppins(size: CGFloat, weight: NSFont.Weight = .light) -> NSFont {
        let name: String
        if weight.rawValue >= NSFont.Weight.medium.rawValue {
            name = "Poppins-Medium"
        } else if weight.rawValue >= NSFont.Weight.regular.rawValue {
            name = "Poppins-Regular"
        } else {
            name = "Poppins-Light"
        }
        return NSFont(name: name, size: size)
            ?? .systemFont(ofSize: size, weight: weight)
    }

    /// NSFont 版 Inter（variable font，依赖 AppKit 自动应用 wght axis）。
    /// InterVariable 的 family 是 `"Inter Variable"`，PostScript 是 `"InterVariable-Regular"` 等。
    static func nsInter(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        // 用 descriptor + variation axis 控制 weight（InterVariable 是 variable font）。
        // 写法参考 Apple docs：把 wght 当 float number 注入 NSFontVariationAttribute。
        let wght = weightNumber(for: weight) // 100–900 区间
        let attrs: [NSFontDescriptor.AttributeName: Any] = [
            .family: "Inter Variable"
        ]
        let variationAttrs: [NSFontDescriptor.AttributeName: Any] = [
            NSFontDescriptor.AttributeName(rawValue: "NSFontVariationAttribute"):
                ["wght": wght]
        ]
        let descriptor = NSFontDescriptor(name: "InterVariable", size: size)
            .addingAttributes(variationAttrs)
        if let f = NSFont(descriptor: descriptor, size: size) {
            return f
        }
        // fallback：family + weight 让 AppKit 自己 axis 化
        if let f = NSFontManager.shared.font(withFamily: "Inter Variable",
                                            traits: [],
                                            weight: weightInt(for: weight),
                                            size: size) {
            return f
        }
        return .systemFont(ofSize: size, weight: weight)
    }

    /// NSFont 版 Inter 斜体
    static func nsInterItalic(size: CGFloat) -> NSFont {
        if let f = NSFont(name: "InterVariable-Italic", size: size) {
            return f
        }
        if let base = NSFont(name: "InterVariable", size: size) {
            let desc = base.fontDescriptor.withSymbolicTraits(.italic)
            return NSFont(descriptor: desc ?? base.fontDescriptor, size: size) ?? base
        }
        return NSFontManager.shared.font(withFamily: "Inter Variable",
                                         traits: .italicFontMask,
                                         weight: 5, size: size)
            ?? .systemFont(ofSize: size)
    }

    /// NSFont.Weight → InterVariable 的 wght 值（100–900）
    private static func weightNumber(for weight: NSFont.Weight) -> NSNumber {
        // AppKit 用 0–1 标度：regular ≈ 0.36, medium ≈ 0.47, semibold ≈ 0.57, bold ≈ 0.62
        // 转成 InterVariable 的实际 wght (100..900)
        // 最稳妥是用 NSFontDescriptor — 写作 wght 实际重量数值
        let raw: CGFloat
        switch weight {
        case .ultraLight: raw = 100
        case .thin:       raw = 200
        case .light:      raw = 300
        case .regular:    raw = 400
        case .medium:     raw = 500
        case .semibold:   raw = 600
        case .bold:       raw = 700
        case .heavy:      raw = 800
        case .black:      raw = 900
        default:          raw = 400
        }
        return NSNumber(value: Float(raw))
    }

    private static func weightInt(for weight: NSFont.Weight) -> Int {
        switch weight {
        case .ultraLight: return 1
        case .thin:       return 2
        case .light:      return 3
        case .regular:    return 5
        case .medium:     return 6
        case .semibold:   return 8
        case .bold:       return 9
        case .heavy:      return 10
        case .black:      return 12
        default:          return 5
        }
    }
}
