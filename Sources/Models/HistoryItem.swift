// SwiftData 实体：每条历史 = 一句原文 + 译文 + 话题 + 时间 + 方向/目标语。
import Foundation
import SwiftData

@Model
final class HistoryItem {
    /// 原文（多数情况为中文，但反向模式下可以是 \(targetLanguage)）。
    /// 之所以还叫 sourceText 而不是 userText，是因为历史 UI 的「上面那行灰色字」含义 = 「用户输入」。
    var sourceText: String

    /// 主译文。在正向（中文 → target）= 外语；反向（target → 中文）= 中文。
    /// 命名沿用以避免 SwiftData schema 破坏性变更；UI 层根据 direction 决定怎么显示。
    var italian: String

    /// 口语变体：正向 = 外语口语；反向 = 中文口语。
    var colloquial: String?

    /// 给读者的用法 / 语法小提示。
    var note: String?

    /// 存 Topic.rawValue
    var topicRaw: String

    /// 阶段 10：翻译方向 "forward" / "reverse"。
    /// 旧数据这条字段为空 → HistoryView 视为 forward（与最初行为一致）。
    /// 标可选：SwiftData 老库迁移时缺字段不会 crash。
    var directionRaw: String?

    /// 阶段 10：目标外语 isoCode（"it" / "en" / "fr" …）。空 = 没设过 → 视为 "it"。
    /// 同上：标可选，避免老库迁移失败。
    var targetISOCode: String?

    var createdAt: Date

    init(sourceText: String,
         italian: String,
         colloquial: String?,
         note: String?,
         topic: Topic,
         direction: TranslationDirection = .forward,
         target: TargetLanguage = .italian,
         createdAt: Date = .now) {
        self.sourceText = sourceText
        self.italian = italian
        self.colloquial = colloquial
        self.note = note
        self.topicRaw = topic.rawValue
        self.directionRaw = direction.rawValue
        self.targetISOCode = target.isoCode
        self.createdAt = createdAt
    }

    var topic: Topic { Topic(rawValue: topicRaw) ?? .other }

    var direction: TranslationDirection {
        directionRaw == "reverse" ? .reverse : .forward
    }

    /// 当前条对应的目标外语；老数据/空值 → 意大利语。
    var target: TargetLanguage {
        if let code = targetISOCode,
           let lang = TargetLanguage.allCases.first(where: { $0.isoCode == code }) {
            return lang
        }
        return .italian
    }
}