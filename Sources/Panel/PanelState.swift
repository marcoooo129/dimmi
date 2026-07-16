// 翻译面板状态机：把"内容态"压平成一个枚举，让 UI 一次只 render 一棵子树。
//
// 设计原则：
//   - 不允许流式更新文本：等待完整结果再 commit，避免每帧重新布局
//   - 状态变化必须走「完整翻译文本」+「reveal 进度」两个轴配合，
//     不能让外部 UI 层偷换过渡逻辑。
//
// 五态：
//   .hidden       没有面板
//   .loading      划词/触发后立即进入，骨架条 + 扫光
//   .revealing    拿到翻译后，先扩展边框 → 80ms 后开始逐字浮现
//   .idle         完全显示（用户停留阅读）
//   .failed       错误态
//
// 阶段 10：direction + target 跟随相位走，用于 UI 上 chip / 主标题 / 历史方向记录。
import Foundation
import SwiftUI

enum PanelPhase: Equatable {
    case hidden
    case loading(sourceText: String, direction: TranslationDirection, target: TargetLanguage)
    /// 已拿到完整译文；UI 层用 revealProgress ∈ [0,1] 触发动画
    case revealing(sourceText: String, result: TranslationResult, direction: TranslationDirection, target: TargetLanguage, fromMock: Bool)
    case idle(sourceText: String, result: TranslationResult, direction: TranslationDirection, target: TargetLanguage, fromMock: Bool)
    case failed(sourceText: String, message: String, direction: TranslationDirection, target: TargetLanguage)

    var sourceText: String? {
        switch self {
        case .loading(let s, _, _):                            return s
        case .revealing(let s, _, _, _, _):                     return s
        case .idle(let s, _, _, _, _):                          return s
        case .failed(let s, _, _, _):                           return s
        case .hidden:                                           return nil
        }
    }

    var direction: TranslationDirection {
        switch self {
        case .loading(_, let d, _):                 return d
        case .revealing(_, _, let d, _, _):         return d
        case .idle(_, _, let d, _, _):              return d
        case .failed(_, _, let d, _):               return d
        case .hidden:                               return .forward
        }
    }

    var target: TargetLanguage {
        switch self {
        case .loading(_, _, let t):                 return t
        case .revealing(_, _, _, let t, _):         return t
        case .idle(_, _, _, let t, _):              return t
        case .failed(_, _, _, let t):               return t
        case .hidden:                               return .italian
        }
    }

    var isLoading: Bool {
        if case .loading = self { return true } else { return false }
    }

    var isHidden: Bool {
        if case .hidden = self { return true } else { return false }
    }
}