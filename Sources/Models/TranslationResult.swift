// API 返回的解码结构：译文 + 口语变体 + 话题 + 小提示。
//
// 阶段 10 字段含义：
//   - italian 字段名沿用向后兼容，但在多目标语场景下"含义"已经变了：
//       1) 正向（中文 → ?）：存目标外语（意大利语 / 法语 / ...）
//       2) 反向（? → 中文）：存中文译文
//     UI 层根据 direction 决定这个字段是「原文」还是「译文」。
//
// 命名沿用理由：避免历史库 SwiftData 迁移；调用方（PanelView / HistoryRow）
// 在 visual 上根据 direction 选择字段，无需关心 target 实际是哪种语言。
import Foundation

struct TranslationResult: Codable, Equatable {
    let italian: String
    let colloquial: String?
    let topic: String      // 必须是 Topic.rawValue 之一
    let note: String?
}