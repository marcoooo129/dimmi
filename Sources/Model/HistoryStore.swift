// 历史写入：把一条翻译结果存进 SwiftData。
// 读由 HistoryView 直接用 @Query 完成，这里只负责写。
import Foundation
import SwiftData

@MainActor
enum HistoryStore {
    /// 在主线程把成功结果落库。失败 / 取消失效（不存）。
    /// 用 mainContext（由 .modelContainer 提供）保证 UI 立即可查。
    /// 阶段 10：direction + target 由调用方传入并跟着走历史。
    static func append(
        sourceText: String,
        result: TranslationResult,
        direction: TranslationDirection,
        target: TargetLanguage
    ) {
        let context = AppState.shared.modelContext
        let item = HistoryItem(
            sourceText: sourceText,
            italian: result.italian,
            colloquial: result.colloquial,
            note: result.note,
            topic: Topic.from(result.topic),
            direction: direction,
            target: target
        )
        context.insert(item)
        do {
            try context.save()
            NSLog("[dimmi] history appended [\(direction.rawValue)/\(target.isoCode)] len=\(sourceText.count)")
        } catch {
            NSLog("[dimmi] history save failed: \(error.localizedDescription)")
        }
    }

    /// 单条删除（HistoryView 用）
    static func delete(_ item: HistoryItem) {
        let context = AppState.shared.modelContext
        context.delete(item)
        try? context.save()
    }

    /// 清空全部
    static func clearAll() {
        let context = AppState.shared.modelContext
        let descriptor = FetchDescriptor<HistoryItem>()
        if let items = try? context.fetch(descriptor) {
            for item in items { context.delete(item) }
            try? context.save()
        }
    }
}
