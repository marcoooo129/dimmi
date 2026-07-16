// 面板的 SwiftUI 状态机驱动：把 PanelController 的命令（loading / result / failed / dismiss）
// 转成 SwiftUI 可观察对象，让 TranslationPanelView 一次性 refresh。
//
// 动画铁律：
//   - 加载态：cardHeight 恒等于 PanelMetrics.minCardHeight（不许在译文返回前变化）。
//   - 译文 commit 后：【一条】 .linear 时间线，把 progress 从 0 → 1。
//   - progress 同时驱动 cardHeight（用 heightEase(t) 抢先约 15%）和 revealProgress，
//     实现「边框领跑、文字跟进」连续生长。
//
// 阶段 10：direction / target 一路跟到 phase，UI 渲染 chip / 顶部主标题用。
import AppKit
import Foundation
import SwiftUI
import Combine

@MainActor
final class PanelViewModel: ObservableObject {
    // MARK: - 输入（被 SwiftUI View 读取）

    @Published var phase: PanelPhase = .hidden

    /// 0 → 1 的同轴进度，译文 commit 后推进。
    @Published var progress: Double = 0

    /// 注解独立进度（独立时间线，但同样一条 withAnimation，0 → 1）
    @Published var noteProgress: Double = 0

    @Published var phraseNote: PhraseNote? = nil

    @Published var targetHeight: CGFloat = 0

    @Published var isVisible: Bool = false
    @Published var autoDismissSeconds: Int = 0

    // MARK: - 回调（被 SwiftUI View 触发）
    var onCopy: (String) -> Void = { _ in }
    var onRetry: () -> Void = {}
    var onDismiss: () -> Void = {}

    // MARK: - 私有
    private var revealTask: Task<Void, Never>?
    private var noteTask: Task<Void, Never>?
    private var autoDismissTask: Task<Void, Never>?
    private var autoDismissCurrentSeconds: Int = 0
    private var maxAutoDismissSeconds: Int = 8

    private var textFinalHeight: CGFloat = 0
    private var pendingNote: PhraseNote? = nil

    // MARK: - 高度常量
    private let minHeight: CGFloat = PanelMetrics.minCardHeight
    private let cardMaxHeight: CGFloat = PanelMetrics.cardMaxHeight
    private let failedCardHeight: CGFloat = 160

    static let heightLead: Double = 1.15

    static func revealDuration(lineCount: Int) -> Double {
        let n = max(1, lineCount)
        return min(0.4 + 0.16 * Double(n), 2.0)
    }

    static func noteDuration(lineCount: Int) -> Double {
        let n = max(1, lineCount)
        return min(0.3 + 0.08 * Double(n), 0.9)
    }

    static func heightEase(_ t: Double) -> Double {
        let a = min(max(t, 0) * heightLead, 1.0)
        return 1 - pow(1 - a, 2.2)
    }

    // MARK: - 外部入口

    /// 进入加载态：卡片按 minHeight 出现；先做出现动画。
    func enterLoading(sourceText: String, direction: TranslationDirection, target: TargetLanguage) {
        revealTask?.cancel()
        noteTask?.cancel()
        autoDismissTask?.cancel()
        progress = 0
        noteProgress = 0
        autoDismissCurrentSeconds = 0
        autoDismissSeconds = 0
        phraseNote = nil
        pendingNote = nil
        phase = .loading(sourceText: sourceText, direction: direction, target: target)
        targetHeight = minHeight
        isVisible = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 16_000_000) // 1 frame
            self.isVisible = true
        }
    }

    /// 进入 revealing 态：先算最终高度 → 启动一条 .linear 时间线。
    func enterRevealing(
        sourceText: String,
        result: TranslationResult,
        direction: TranslationDirection,
        target: TargetLanguage,
        fromMock: Bool
    ) {
        revealTask?.cancel()
        noteTask?.cancel()
        autoDismissTask?.cancel()
        autoDismissCurrentSeconds = 0
        autoDismissSeconds = 0
        phase = .revealing(
            sourceText: sourceText,
            result: result,
            direction: direction,
            target: target,
            fromMock: fromMock
        )

        let maxW: CGFloat = PanelMetrics.contentWidth
        let italianH = TextMeasurer.measure(text: result.italian,
                                            font: DimmiFont.nsPoppins(size: DimmiFont.panelHeroSize,
                                                                      weight: .medium),
                                            lineHeightMultiple: 1.35,
                                            maxWidth: maxW)
        let fallbackNoteH: CGFloat = {
            if let note = result.note, !note.isEmpty {
                let textH = TextMeasurer.measure(
                    text: note,
                    font: DimmiFont.nsInter(size: 13, weight: .regular),
                    lineHeightMultiple: 1.35,
                    maxWidth: maxW - PanelMetrics.analysisTextInset
                )
                // section top gap + divider/title + 单行分析容器
                return 18 + 15 + 28 + max(38, textH + 20)
            }
            return 0
        }()
        // padding + 品牌栏 + 原文顶部间距/高度 + 分隔线上下间距
        let chromeH: CGFloat = PanelMetrics.cardPadding * 2
            + TextMeasurer.headerRow
            + 10
            + TextMeasurer.sourceTextRow
            + 12 + 0.5 + 16
        let contentTextH = italianH + fallbackNoteH
        var totalH = chromeH + contentTextH
        totalH = min(cardMaxHeight, max(minHeight, totalH))
        let finalH = max(minHeight, totalH)

        let lineCount = max(1, Int(ceil(contentTextH / 26)))
        let duration = Self.revealDuration(lineCount: lineCount)

        textFinalHeight = finalH
        targetHeight = finalH
        progress = 0
        NSLog("[dimmi][panel] enterRevealing [\(direction.rawValue)/\(target.isoCode)] h=\(finalH) lineCount=\(lineCount) duration=\(duration)")

        revealTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            NSLog("[dimmi][panel] reveal-start duration=\(duration)")

            withAnimation(.linear(duration: duration)) {
                self.progress = 1
            }

            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self.progress = 1
            self.noteProgress = max(self.noteProgress, 1)
            self.phase = .idle(
                sourceText: sourceText,
                result: result,
                direction: direction,
                target: target,
                fromMock: fromMock
            )
            self.startAutoDismiss()
            self.consumePendingNoteIfAny()
        }
    }

    /// 布局回报真实高度。仅在 revealing / idle 接受。
    func reportContentHeight(_ h: CGFloat) {
        switch phase {
        case .revealing, .idle:
            let clamped = min(cardMaxHeight, max(minHeight, ceil(h)))
            guard abs(clamped - targetHeight) > 0.5 else { return }
            NSLog("[dimmi][panel] 布局实测校正高度 %.0f → %.0f", targetHeight, clamped)
            targetHeight = clamped
            if phraseNote == nil { textFinalHeight = clamped }
        case .loading, .failed, .hidden:
            break
        }
    }

    private func consumePendingNoteIfAny() {
        guard let note = pendingNote else { return }
        pendingNote = nil
        applyNote(note)
    }

    /// 注解到达的统一入口。
    func applyNote(_ note: PhraseNote) {
        guard note.hasNote else { return }
        switch phase {
        case .loading, .revealing:
            pendingNote = note
        case .idle:
            expandWithNote(note)
        case .failed, .hidden:
            return
        }
    }

    private func expandWithNote(_ note: PhraseNote) {
        phraseNote = note
        let noteH = Self.measureNoteHeight(note)
        let newTarget = min(cardMaxHeight, textFinalHeight + noteH)
        targetHeight = newTarget

        let lineCount = max(1, Int(ceil(noteH / 18)))
        let duration = Self.noteDuration(lineCount: lineCount)
        NSLog("[dimmi][panel] expandWithNote newTarget=\(newTarget) duration=\(duration)")

        noteTask?.cancel()
        noteTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            withAnimation(.linear(duration: duration)) {
                self.noteProgress = 1
            }
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self.noteProgress = 1
        }
    }

    /// 注解附加高度
    static func measureNoteHeight(_ note: PhraseNote) -> CGFloat {
        let contentWidth = PanelMetrics.contentWidth - PanelMetrics.analysisTextInset
        // 与 TranslationPanelView 的 section top gap、divider、标题完全对应。
        var h: CGFloat = 18 + 15 + 28
        var rowCount = 0
        if let b = note.breakdown, !b.isEmpty {
            rowCount += 1
            h += max(38, 18 + TextMeasurer.measure(
                text: b,
                font: DimmiFont.nsInter(size: 13, weight: .medium),
                lineHeightMultiple: 1.35,
                maxWidth: contentWidth
            ))
        }
        if let u = note.usage, !u.isEmpty {
            rowCount += 1
            h += max(38, 18 + TextMeasurer.measure(
                text: u,
                font: DimmiFont.nsInter(size: 13, weight: .regular),
                lineHeightMultiple: 1.35,
                maxWidth: contentWidth
            ))
        }
        if let e = note.example {
            rowCount += 1
            let itH = TextMeasurer.measure(
                text: e.it,
                font: DimmiFont.nsInter(size: 13, weight: .regular),
                lineHeightMultiple: 1.35,
                maxWidth: contentWidth
            )
            let zhH = TextMeasurer.measure(
                text: e.zh,
                font: DimmiFont.nsInter(size: 11, weight: .regular),
                lineHeightMultiple: 1.35,
                maxWidth: contentWidth
            )
            h += max(44, 21 + itH + zhH)
        }
        h += CGFloat(max(0, rowCount - 1)) * 0.5 + 4
        return h
    }

    /// 错误态
    func enterFailed(
        sourceText: String,
        message: String,
        direction: TranslationDirection,
        target: TargetLanguage
    ) {
        revealTask?.cancel()
        noteTask?.cancel()
        autoDismissTask?.cancel()
        autoDismissCurrentSeconds = 0
        progress = 0
        noteProgress = 0
        phase = .failed(sourceText: sourceText, message: message, direction: direction, target: target)
        targetHeight = failedCardHeight
        startAutoDismiss()
    }

    func dismiss() {
        revealTask?.cancel()
        noteTask?.cancel()
        autoDismissTask?.cancel()
        progress = 0
        noteProgress = 0
        autoDismissCurrentSeconds = 0
        autoDismissSeconds = 0
        phraseNote = nil
        pendingNote = nil
        phase = .hidden
        targetHeight = 0
        isVisible = false
        onDismiss()
    }

    func setMaxAutoDismiss(_ sec: Int) {
        self.maxAutoDismissSeconds = max(1, sec)
    }

    // MARK: - 内部：高度插值

    var interpolatedCardHeight: CGFloat {
        switch phase {
        case .loading, .hidden:
            return minHeight
        case .revealing:
            let h = Self.heightEase(progress)
            return minHeight + (targetHeight - minHeight) * h
        case .idle:
            return targetHeight
        case .failed:
            return failedCardHeight
        }
    }

    // MARK: - 内部：倒计时

    private func startAutoDismiss() {
        autoDismissTask?.cancel()
        autoDismissCurrentSeconds = maxAutoDismissSeconds
        autoDismissSeconds = autoDismissCurrentSeconds
        autoDismissTask = Task { @MainActor in
            while !Task.isCancelled, autoDismissCurrentSeconds > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                autoDismissCurrentSeconds -= 1
                autoDismissSeconds = autoDismissCurrentSeconds
                if autoDismissCurrentSeconds <= 0 { break }
            }
            if !Task.isCancelled, autoDismissCurrentSeconds <= 0 {
                self.dismiss()
            }
        }
    }

    func bumpAutoDismiss() {
        if phase.isHidden { return }
        if case .idle = phase {
            autoDismissCurrentSeconds = maxAutoDismissSeconds
        }
    }

    // MARK: - SwiftUI 触发回调
    func dismissRequested() { dismiss() }
    func retryRequested() { onRetry() }
    func copyRequested(_ text: String) { onCopy(text) }
}
