// RevealRenderer：把译文文字按"行 → 字形"逐个淡入浮现。
//
// 核心（任务书 2026-07-13 修复）：
//   - **归一化时间线**：draw() 内扫 layout 算每行起点 + 总时长，progress∈[0,1] 映射到 now∈[total]。
//     数学保证 progress=1 时全部 raw≥1 → 无残留模糊。
//   - **行间接力**：lineOverlap=0.25，下一行在上一行走完 75% 时启动。
//   - **已完成字形直绘**：省渲染开销。
//
// SwiftUI 集成（macOS 15+）：
//   - RevealableText 自己实现 Animatable，animatableData = progress。
//   - body 求值时把 progress 同步到 RevealTextRenderer / NoteTextRenderer。
//   - SwiftUI 在 View diff 时看到 animatableData 变了 → 自动驱动 animation →
//     中间帧写入 progress → draw() 实时反映。

import SwiftUI
import AppKit
@preconcurrency import SwiftUI

// MARK: - 调参

enum RevealTiming {
    static let charStagger: Double = 0.014
    static let fadeDuration: Double = 0.30
    static let lineOverlap: Double = 0.25
    static let maxBlur: Double = 3.0
    static let maxOffsetY: Double = 2.0

    static func easeOut(_ t: Double) -> Double {
        let clamped = min(max(t, 0), 1)
        return 1 - pow(1 - clamped, 3)
    }
}

enum NoteRevealTiming {
    static let charStagger: Double = 0.010
    static let fadeDuration: Double = 0.24
    static let lineOverlap: Double = 0.25
    static let maxBlur: Double = 2.0
    static let maxOffsetY: Double = 1.5
}

// MARK: - macOS 15+ 主译文 TextRenderer

#if compiler(>=5.10)
@available(macOS 15, *)
final class RevealTextRenderer: TextRenderer, Animatable {
    nonisolated(unsafe) var progress: Double = 0

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    nonisolated func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        let lines = Array(layout)
        guard !lines.isEmpty else { return }

        let glyphCounts: [Int] = lines.map { line in line.reduce(0) { $0 + $1.count } }
        var lineStarts: [Double] = []
        var cursor = 0.0
        for count in glyphCounts {
            lineStarts.append(cursor)
            cursor += (Double(count) * RevealTiming.charStagger + RevealTiming.fadeDuration) * (1.0 - RevealTiming.lineOverlap)
        }
        let lastSweep = Double(glyphCounts.last ?? 0) * RevealTiming.charStagger + RevealTiming.fadeDuration
        let total = (lineStarts.last ?? 0) + lastSweep
        let p = min(max(progress, 0), 1)
        let now = p * total

        for (li, line) in lines.enumerated() {
            var gi = 0
            for run in line {
                for slice in run {
                    let t = min(max((now - lineStarts[li] - Double(gi) * RevealTiming.charStagger) / RevealTiming.fadeDuration, 0), 1)
                    gi += 1
                    if t <= 0 { continue }
                    if t >= 1 {
                        ctx.draw(slice)
                    } else {
                        let eased = RevealTiming.easeOut(t)
                        var copy = ctx
                        copy.opacity = eased
                        copy.addFilter(.blur(radius: RevealTiming.maxBlur * (1 - eased)))
                        copy.translateBy(x: 0, y: RevealTiming.maxOffsetY * (1 - eased))
                        copy.draw(slice)
                    }
                }
            }
        }
    }
}
#endif

// MARK: - macOS 15+ 注解 TextRenderer

#if compiler(>=5.10)
@available(macOS 15, *)
final class NoteTextRenderer: TextRenderer, Animatable {
    nonisolated(unsafe) var progress: Double = 0

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    nonisolated func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        let lines = Array(layout)
        guard !lines.isEmpty else { return }

        let glyphCounts: [Int] = lines.map { line in line.reduce(0) { $0 + $1.count } }
        var lineStarts: [Double] = []
        var cursor = 0.0
        for count in glyphCounts {
            lineStarts.append(cursor)
            cursor += (Double(count) * NoteRevealTiming.charStagger + NoteRevealTiming.fadeDuration) * (1.0 - NoteRevealTiming.lineOverlap)
        }
        let lastSweep = Double(glyphCounts.last ?? 0) * NoteRevealTiming.charStagger + NoteRevealTiming.fadeDuration
        let total = (lineStarts.last ?? 0) + lastSweep
        let p = min(max(progress, 0), 1)
        let now = p * total

        for (li, line) in lines.enumerated() {
            var gi = 0
            for run in line {
                for slice in run {
                    let t = min(max((now - lineStarts[li] - Double(gi) * NoteRevealTiming.charStagger) / NoteRevealTiming.fadeDuration, 0), 1)
                    gi += 1
                    if t <= 0 { continue }
                    if t >= 1 {
                        ctx.draw(slice)
                    } else {
                        let eased = RevealTiming.easeOut(t)
                        var copy = ctx
                        copy.opacity = eased
                        copy.addFilter(.blur(radius: NoteRevealTiming.maxBlur * (1 - eased)))
                        copy.translateBy(x: 0, y: NoteRevealTiming.maxOffsetY * (1 - eased))
                        copy.draw(slice)
                    }
                }
            }
        }
    }
}
#endif

// MARK: - RevealableText（macOS 15+）
//
// 关键设计（2026-07-14 彻底修复）：
//   - RevealableText 自身实现 Animatable，animatableData = progress。
//   - body 求值时把 progress 同步到内部 Renderer class 的 animatableData。
//   - SwiftUI 在 View diff 时看到 animatableData 变化 → 自动驱动 animation →
//     animatableData setter 写中间帧 → 触发 Renderer draw 重绘。
//   - 这样 phase 切换重建视图树或外部 progress 变化都走同一路径。
@available(macOS 15, *)
struct RevealableText: View, Animatable {
    let text: String
    var progress: Double
    var font: Font = .system(size: 17, weight: .semibold)
    var lineSpacing: CGFloat = 5
    var foreground: Color = DimmiTheme.textPrimaryLight
    /// 可选渐变前景色：传入后用 LinearGradient 取代纯色，用于 Luminous Glass 设计稿的渐变文字。
    /// 与 foreground 二选一；foregroundGradient 优先。
    var foregroundGradient: [Color]? = nil
    var noteRenderer: Bool = false
    /// 动画完成后切回原生 NSTextView，从而在 nonactivating NSPanel 内可靠地按字符选择。
    var selectableWhenComplete: Bool = false
    /// 原生选择态所用的 NSFont；必须与上面的 SwiftUI font token 同步。
    var selectableFont: NSFont? = nil

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    @ViewBuilder
    var body: some View {
        if noteRenderer {
            NoteTextBody(
                text: text, progress: progress, font: font, lineSpacing: lineSpacing,
                foreground: foreground, foregroundGradient: foregroundGradient,
                selectableWhenComplete: selectableWhenComplete,
                selectableFont: selectableFont
            )
        } else {
            MainTextBody(
                text: text, progress: progress, font: font, lineSpacing: lineSpacing,
                foreground: foreground, foregroundGradient: foregroundGradient,
                selectableWhenComplete: selectableWhenComplete,
                selectableFont: selectableFont
            )
        }
    }
}

@available(macOS 15, *)
private struct MainTextBody: View {
    let text: String
    let progress: Double
    let font: Font
    let lineSpacing: CGFloat
    let foreground: Color
    let foregroundGradient: [Color]?
    let selectableWhenComplete: Bool
    let selectableFont: NSFont?

    @ViewBuilder
    var body: some View {
        if selectableWhenComplete, progress >= 0.999 {
            NativeSelectableText(
                text: text,
                font: selectableFont ?? .systemFont(ofSize: 17, weight: .semibold),
                foregroundColor: NSColor(foreground),
                lineSpacing: lineSpacing
            )
        } else {
            let renderer = RevealTextRenderer()
            let _ = { renderer.animatableData = progress }()
            styledText
                .textRenderer(renderer)
        }
    }

    private var styledText: some View {
        Text(text)
            .font(font)
            .lineSpacing(lineSpacing)
            .foregroundStyle(AnyShapeStyle(gradientOrColor))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var gradientOrColor: AnyShapeStyle {
        if let g = foregroundGradient, g.count >= 2 {
            return AnyShapeStyle(
                LinearGradient(colors: g, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        }
        return AnyShapeStyle(foreground)
    }
}

@available(macOS 15, *)
private struct NoteTextBody: View {
    let text: String
    let progress: Double
    let font: Font
    let lineSpacing: CGFloat
    let foreground: Color
    let foregroundGradient: [Color]?
    let selectableWhenComplete: Bool
    let selectableFont: NSFont?

    @ViewBuilder
    var body: some View {
        if selectableWhenComplete, progress >= 0.999 {
            NativeSelectableText(
                text: text,
                font: selectableFont ?? .systemFont(ofSize: 13, weight: .regular),
                foregroundColor: NSColor(foreground),
                lineSpacing: lineSpacing
            )
        } else {
            let renderer = NoteTextRenderer()
            let _ = { renderer.animatableData = progress }()
            styledText
                .textRenderer(renderer)
        }
    }

    private var styledText: some View {
        Text(text)
            .font(font)
            .lineSpacing(lineSpacing)
            .foregroundStyle(AnyShapeStyle(gradientOrColor))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var gradientOrColor: AnyShapeStyle {
        if let g = foregroundGradient, g.count >= 2 {
            return AnyShapeStyle(
                LinearGradient(colors: g, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        }
        return AnyShapeStyle(foreground)
    }
}

// MARK: - 原生可选文字

/// SwiftUI Text 的 textSelection 在 nonactivating NSPanel 中无法稳定取得 first responder。
/// 这里使用无滚动容器的 NSTextView：外层 ScrollView 继续负责滚动，文字自身只负责排版与选择。
@available(macOS 15, *)
private struct NativeSelectableText: NSViewRepresentable {
    let text: String
    let font: NSFont
    let foregroundColor: NSColor
    let lineSpacing: CGFloat

    func makeNSView(context: Context) -> AutoSizingSelectableTextView {
        let view = AutoSizingSelectableTextView()
        view.apply(text: text, font: font, color: foregroundColor, lineSpacing: lineSpacing)
        return view
    }

    func updateNSView(_ nsView: AutoSizingSelectableTextView, context: Context) {
        nsView.apply(text: text, font: font, color: foregroundColor, lineSpacing: lineSpacing)
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: AutoSizingSelectableTextView,
        context: Context
    ) -> CGSize? {
        guard let proposedWidth = proposal.width,
              proposedWidth.isFinite,
              proposedWidth > 1 else { return nil }
        let width = proposedWidth
        return CGSize(width: width, height: nsView.requiredHeight(for: width))
    }
}

@available(macOS 15, *)
private final class AutoSizingSelectableTextView: NSTextView {
    private var appliedText = ""
    private var appliedFont: NSFont?
    private var appliedColor: NSColor?
    private var appliedLineSpacing: CGFloat = -CGFloat.greatestFiniteMagnitude

    init() {
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(
            size: NSSize(width: 1, height: CGFloat.greatestFiniteMagnitude)
        )
        container.lineFragmentPadding = 0
        container.widthTracksTextView = true
        container.heightTracksTextView = false
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        super.init(frame: .zero, textContainer: container)

        isEditable = false
        isSelectable = true
        isRichText = false
        importsGraphics = false
        drawsBackground = false
        backgroundColor = .clear
        textContainerInset = .zero
        isHorizontallyResizable = false
        isVerticallyResizable = true
        maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        focusRingType = .none
        allowsUndo = false
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { false }
    override var needsPanelToBecomeKey: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        // nonactivatingPanel 不激活背后的 App，但文字拖选仍需此窗口成为 key。
        if window?.isKeyWindow == false {
            window?.makeKey()
        }
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    func apply(text: String, font: NSFont, color: NSColor, lineSpacing: CGFloat) {
        let styleChanged = appliedFont != font || appliedColor != color || appliedLineSpacing != lineSpacing
        guard appliedText != text || styleChanged else { return }

        let oldSelection = selectedRange()
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        paragraph.lineBreakMode = .byWordWrapping
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
        textStorage?.setAttributedString(attributed)
        alignment = .left

        appliedText = text
        appliedFont = font
        appliedColor = color
        appliedLineSpacing = lineSpacing

        if oldSelection.location != NSNotFound {
            let safeLocation = min(oldSelection.location, (text as NSString).length)
            let safeLength = min(oldSelection.length, (text as NSString).length - safeLocation)
            setSelectedRange(NSRange(location: safeLocation, length: safeLength))
        }
        invalidateIntrinsicContentSize()
    }

    func requiredHeight(for width: CGFloat) -> CGFloat {
        guard let textContainer, let layoutManager else { return ceil(font?.boundingRectForFont.height ?? 1) }
        let safeWidth = max(1, width)
        if abs(frame.width - safeWidth) > 0.5 {
            frame.size.width = safeWidth
        }
        textContainer.containerSize = NSSize(
            width: safeWidth,
            height: CGFloat.greatestFiniteMagnitude
        )
        layoutManager.ensureLayout(for: textContainer)
        let used = layoutManager.usedRect(for: textContainer)
        let singleLine = font?.boundingRectForFont.height ?? 1
        return ceil(max(singleLine, used.height) + 1)
    }
}

// MARK: - macOS 14 降级

struct PerCharRevealView: View {
    let text: String
    let progress: Double
    let font: Font
    let lineSpacing: CGFloat
    let foreground: Color
    var noteRenderer: Bool = false

    private func timeline() -> (lineStarts: [Double], total: Double, charsPerLine: Int) {
        let chars = Array(text)
        guard !chars.isEmpty else { return ([], 0, 0) }
        let charsPerLine = 24
        let lineCount = max(1, Int(ceil(Double(chars.count) / Double(charsPerLine))))
        let charStagger = noteRenderer ? NoteRevealTiming.charStagger : RevealTiming.charStagger
        let fadeDur = noteRenderer ? NoteRevealTiming.fadeDuration : RevealTiming.fadeDuration
        let overlap = noteRenderer ? NoteRevealTiming.lineOverlap : RevealTiming.lineOverlap
        var starts: [Double] = []
        var cursor = 0.0
        for i in 0..<lineCount {
            starts.append(cursor)
            cursor += (Double(min(charsPerLine, chars.count - i * charsPerLine)) * charStagger + fadeDur) * (1.0 - overlap)
        }
        let lastSweep = Double(min(charsPerLine, chars.count - (lineCount - 1) * charsPerLine)) * charStagger + fadeDur
        return (starts, (starts.last ?? 0) + lastSweep, charsPerLine)
    }

    var body: some View {
        let chars = Array(text)
        let (lineStarts, total, charsPerLine) = timeline()
        let now = progress * total
        let rows = stride(from: 0, to: chars.count, by: charsPerLine).map {
            Array(chars[$0..<min($0 + charsPerLine, chars.count)])
        }
        let blurAmt = noteRenderer ? NoteRevealTiming.maxBlur : RevealTiming.maxBlur
        let offsetAmt = noteRenderer ? NoteRevealTiming.maxOffsetY : RevealTiming.maxOffsetY
        let stagger = noteRenderer ? NoteRevealTiming.charStagger : RevealTiming.charStagger
        let fadeDur = noteRenderer ? NoteRevealTiming.fadeDuration : RevealTiming.fadeDuration

        VStack(alignment: .leading, spacing: lineSpacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { li, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { gi, ch in
                        let t = min(max((now - ((lineStarts[safe: li] ?? 0) + Double(gi) * stagger)) / fadeDur, 0), 1)
                        if t <= 0 {
                            Text(String(ch)).font(font).foregroundStyle(.clear)
                        } else {
                            let eased = RevealTiming.easeOut(t)
                            Text(String(ch))
                                .font(font).foregroundStyle(foreground)
                                .opacity(eased)
                                .blur(radius: blurAmt * (1 - eased))
                                .offset(y: offsetAmt * (1 - eased))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? {
        indices.contains(i) ? self[i] : nil
    }
}

// MARK: - FlowLayout（备用）

struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var lineWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxLineHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if lineWidth + size.width > maxWidth {
                totalHeight += maxLineHeight + lineSpacing
                lineWidth = size.width + spacing
                maxLineHeight = size.height
            } else {
                lineWidth += size.width + spacing
                maxLineHeight = max(maxLineHeight, size.height)
            }
        }
        totalHeight += maxLineHeight
        return CGSize(width: maxWidth.isFinite ? maxWidth : lineWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: size.width, height: size.height))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
