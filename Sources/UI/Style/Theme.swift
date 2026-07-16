// 旧代码（RevealableText 默认参数等）还在引用 Theme.textPrimary。
// 这里只保留 hex 解析基础设施（DimmiTheme 也用它）。
import SwiftUI

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b, a: Double
        switch s.count {
        case 6:
            r = Double((v >> 16) & 0xFF) / 255.0
            g = Double((v >>  8) & 0xFF) / 255.0
            b = Double( v        & 0xFF) / 255.0
            a = 1.0
        case 8:
            r = Double((v >> 24) & 0xFF) / 255.0
            g = Double((v >> 16) & 0xFF) / 255.0
            b = Double((v >>  8) & 0xFF) / 255.0
            a = Double( v        & 0xFF) / 255.0
        default:
            r = 1; g = 1; b = 1; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}