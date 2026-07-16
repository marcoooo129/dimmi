// 离屏文本高度测量器：拿一段文字 → 给定容器宽度 → 返回需要的"自然布局高度"。
//
// 用 NSAttributedString + boundingRect 算，不是 GeometryReader。
// 任务书第四节：避免 GeometryReader 反向驱动 frame（会形成布局反馈循环）。
//
// 调用方传：
//   - text：要测的字符串
//   - font：字号（reveal 段用 Inter Semibold 17pt）
//   - lineHeightMultiple：行高倍数（reveal 段 = 1.35）
//   - maxWidth：可用宽度
//
// **字体一致性**：这里默认 / 调用方传入的 NSFont 必须和实际渲染用的
// SwiftUI.Font 同源——之前用 SF Pro，现在统一用 Inter（see DimmiFont.nsInter）。
// 测量和渲染字体不一致会差 1-2 行，导致卡片多出空白或溢出。
import AppKit
import CoreText

enum TextMeasurer {
    /// 单段文字在指定宽度下的渲染高度（pt）
    static func measure(
        text: String,
        font: NSFont = DimmiFont.nsInter(size: 17, weight: .semibold),
        lineHeightMultiple: CGFloat = 1.35,
        maxWidth: CGFloat
    ) -> CGFloat {
        guard !text.isEmpty, maxWidth > 0 else { return 0 }
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = lineHeightMultiple
        style.lineBreakMode = .byWordWrapping
        style.alignment = .natural
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: style
        ]
        let bounds = NSAttributedString(string: text, attributes: attrs).boundingRect(
            with: NSSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return ceil(bounds.height)
    }

    /// 卡片文案区总高 = 顶部 chip(28) + 原文(2 行内, 36) + 间距(12) + 译文测量值 + 间距(8)
    /// + 口语变体测量值 + 间距(8) + 小提示测量值 + 底部 padding(12)
    /// —— 这个公式由调用方决定，这里只是辅助函数。
    static func chipHeight(fraction: CGFloat = 1.0) -> CGFloat {
        // chip 本身 22pt 高 + 边距
        return 22 * fraction
    }

    /// 样图式品牌栏（品牌、方向胶囊、复制与关闭）
    static let headerRow: CGFloat = 36
    /// 单行原文预览
    static let sourceTextRow: CGFloat = 14
    /// 段间距（spacing in VStack）
    static let spacing: CGFloat = 10
}
