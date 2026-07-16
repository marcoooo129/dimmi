// 翻译浮窗下方"惯用表达注解"的数据结构。
//
// 只有 hasNote = true 时 UI 才会展开注解区。绝大多数普通词/简单动词
// 返回 false —— 不值得解释的东西就闭嘴，别硬凑。
//
// 字段约束（来自 system prompt 的对齐）：
//   - breakdown ≤ 30 字
//   - usage ≤ 45 字，必须包含语域/搭配介词等实用信息
//   - example.it 自然日常，example.zh 翻译准确
import Foundation

struct PhraseNote: Codable, Equatable {
    /// 是否值得单独解释。false → 整个注解区不显示。
    let hasNote: Bool

    /// 类型标签。nil 时不显示 chip
    let kind: Kind?

    /// 字面拆解，例："prendere(拿取) + spunto(提示、起点)"
    let breakdown: String?

    /// 一句话用法 / 语域说明
    let usage: String?

    /// 例句（意 + 中对照）
    let example: Example?

    struct Example: Codable, Equatable {
        let it: String
        let zh: String
    }

    enum Kind: String, Codable, CaseIterable {
        case idiom        // 习语     → 「习语」
        case collocation  // 固定搭配 → 「固搭」
        case pronominal   // 代词式   → 「代动」
        case falseFriend  // 假朋友   → 「易混」
        case register     // 语域     → 「语域」

        /// UI 上展示的中文短标签
        var label: String {
            switch self {
            case .idiom:       return "习语"
            case .collocation: return "固搭"
            case .pronominal:  return "代动"
            case .falseFriend: return "易混"
            case .register:    return "语域"
            }
        }
    }
}

extension PhraseNote {
    /// 显式构造一个"无注解"对象，避免到处写 PhraseNote(hasNote: false, ...)
    static let none = PhraseNote(hasNote: false, kind: nil, breakdown: nil, usage: nil, example: nil)
}