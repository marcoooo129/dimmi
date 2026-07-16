// 翻译面板 SwiftUI 根视图 —— Dimmi「褪色黄昏 · 编辑式毛玻璃」版。
//
// 设计铁律：
//   1. 卡片外壳常驻，永不销毁；用 opacity 切换 loading ↔ content
//   2. 卡片背景 = 真毛玻璃 + 暖沙/灰紫轻染 + 可读性薄纱；能感知网页颜色，但看不清网页文字
//   3. 只有一层连续玻璃表面，不叠 aurora / 噪点 / 深色实底
//   4. 不用 if/else 重建 loading ↔ content 外壳
//   5. 高度永远是 viewModel.interpolatedCardHeight 的纯函数
//
// 透明窗禁忌（浮窗 vs 设置窗的根本区别）：
//
//   历史卡 / 设置卡  = 真玻璃（透自家窗口的光斑 — GlassCard + DimmiBackground）
//   浮窗卡          = 强模糊真玻璃 + 更高一档烟色薄纱（保证任意网页上仍可读）
//
// 卡片矩形外必须完全透明。
//   - 浮窗 = 透明窗口 + 一张卡。卡外**只允许**中性阴影，绝不允许粉光晕
// 顶边对齐：frame(width: 340, height: viewModel.interpolatedCardHeight, alignment: .top)，顶边钉死。
import SwiftUI
import AppKit
import PhosphorSwift

/// 浮窗专属颜色。明确不跟随系统浅/深色，否则浅色系统会把暗卡上的文字变黑。
enum PanelEditorialGlass {
    static let tintTop       = Color(hex: "B6A38E").opacity(0.38)
    static let tintBottom    = Color(hex: "75656B").opacity(0.50)
    static let readability   = Color.black.opacity(0.10)
    static let primary       = Color(hex: "FFFBF4").opacity(0.96)
    static let secondary     = Color(hex: "FFFBF4").opacity(0.64)
    static let tertiary      = Color(hex: "FFFBF4").opacity(0.46)
    static let accent        = Color(hex: "EBC8A8").opacity(0.96)
    static let stroke        = Color(hex: "FFFBF4").opacity(0.22)
    static let divider       = Color(hex: "FFFBF4").opacity(0.13)
    static let insetFill     = Color.black.opacity(0.055)
    static let insetStroke   = Color(hex: "FFFBF4").opacity(0.16)
    static let hoverFill     = Color(hex: "FFFBF4").opacity(0.10)
}

@available(macOS 15, *)
struct TranslationPanelView: View {
    @ObservedObject var viewModel: PanelViewModel
    @ObservedObject var region: PanelCardHitRegion
    @State private var analysisExpanded = true

    private let cardWidth = PanelMetrics.cardWidth
    private let cardPadding = PanelMetrics.cardPadding
    private let panelHeight = PanelMetrics.panelHeight
    private let minCardHeight = PanelMetrics.minCardHeight

    var body: some View {
        ZStack(alignment: .top) {
            cardLayer
                .frame(width: cardWidth, height: viewModel.interpolatedCardHeight, alignment: .top)
                .padding(PanelMetrics.bloomMargin)
                .scaleEffect(viewModel.isVisible ? 1.0 : 0.97, anchor: .top)
                .opacity(viewModel.isVisible ? 1 : 0)
                .animation(.spring(response: 0.30, dampingFraction: 0.85), value: viewModel.isVisible)
        }
        .frame(width: PanelMetrics.panelWidth, height: panelHeight, alignment: .top)
        .onChange(of: viewModel.interpolatedCardHeight) { _, newH in
            region.cardHeight = newH
        }
        .onChange(of: viewModel.phase.sourceText) { _, _ in
            analysisExpanded = true
        }
    }

    // MARK: - 卡片层（常驻）

    // 结构：
    //   ZStack (alignment: .topLeading)
    //     ├── cardSurface     真毛玻璃 + 暖沙/灰紫薄染 + 完整弱描边
    //     └── ScrollView
    //         └── contentStack
    //
    // frame 在 body 那一层定死（避免遮住阴影），所以 cardLayer 不写 frame。
    private var cardLayer: some View {
        ZStack(alignment: .topLeading) {
            // 1. 单层编辑式毛玻璃表面
            cardSurface
                .frame(minHeight: minCardHeight)
                .frame(maxWidth: .infinity, alignment: .topLeading)

            // 2. 内容层（ScrollView 容纳长文本溢出）
            ScrollView(.vertical) {
                contentStack
                    .frame(width: PanelMetrics.contentWidth, alignment: .topLeading)
                    .padding(cardPadding)
                    // 长内容滚到最底时，让 Analisi 完整离开圆角裁切区。
                    .padding(.bottom, PanelMetrics.scrollBottomClearance)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { h in
                        viewModel.reportContentHeight(h)
                    }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.never)
        }
        .clipShape(RoundedRectangle(cornerRadius: PanelMetrics.cardCornerRadius, style: .continuous))
        .compositingGroup()
        .shadow(color: .black.opacity(0.18), radius: 28, y: 12)
    }

    // MARK: - 编辑式真毛玻璃表面
    private var cardSurface: some View {
        let r = RoundedRectangle(cornerRadius: PanelMetrics.cardCornerRadius, style: .continuous)
        return ZStack {
            r.fill(.ultraThinMaterial)
            r.fill(
                LinearGradient(
                    colors: [PanelEditorialGlass.tintTop, PanelEditorialGlass.tintBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            r.fill(PanelEditorialGlass.readability)
        }
        .overlay(r.strokeBorder(PanelEditorialGlass.stroke, lineWidth: 0.75))
        .allowsHitTesting(false)
    }

    // MARK: - 内容 VStack（fit 自然高度）

    private var contentStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
                .frame(height: TextMeasurer.headerRow)
            sourceTextLine
                .padding(.top, 10)
            Rectangle()
                .fill(PanelEditorialGlass.divider)
                .frame(height: 0.5)
                .padding(.top, 12)
                .padding(.bottom, 16)
            ZStack(alignment: .top) {
                LoadingSkeletonStack()
                    .opacity(viewModel.phase.isLoading ? 1 : 0)
                    .allowsHitTesting(false)
                contentArea
                    .opacity(viewModel.phase.isLoading ? 0 : 1)
                    // 正文只在加载结束后参与命中测试。这里若写成 isLoading，
                    // 会让已经显示的译文、Analisi 按钮和原生文字选择全部失去鼠标事件。
                    .allowsHitTesting(!viewModel.phase.isLoading)
            }
            .frame(maxWidth: .infinity, minHeight: viewModel.phase.isLoading ? 28 : nil, alignment: .top)
        }
    }

    // MARK: - 顶部品牌行

    private var headerRow: some View {
        HStack(spacing: 10) {
            brandMark
            directionCapsule
            Spacer(minLength: 2)
            // 复制 / 重试：仅 idle/.failed 显
            if !viewModel.phase.isLoading {
                actionButtons
            }
            PanelIconButton(icon: DimmiIcon.close, tooltip: "关闭（⌘W 或 Esc）") {
                viewModel.dismissRequested()
            }
        }
    }

    private var brandMark: some View {
        HStack(spacing: 6) {
            DimmiBrandMark(size: 18)
            Text("dimmi")
                .font(DimmiFont.poppins(20, .medium))
                .foregroundStyle(PanelEditorialGlass.primary)
                .tracking(0.2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("dimmi")
    }

    private var directionCapsule: some View {
        Text(directionLabel)
            .font(DimmiFont.poppins(11, .regular))
            .foregroundStyle(PanelEditorialGlass.secondary)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(Capsule().fill(Color.white.opacity(0.055)))
            .overlay(Capsule().strokeBorder(PanelEditorialGlass.insetStroke, lineWidth: 0.75))
    }

    private var directionLabel: String {
        switch viewModel.phase.direction {
        case .forward:
            return "中文  →  \(viewModel.phase.target.nativeName)"
        case .reverse:
            return "\(viewModel.phase.target.nativeName)  →  中文"
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch viewModel.phase {
        case .revealing(_, let r, _, _, _), .idle(_, let r, _, _, _):
            PanelIconButton(
                icon: DimmiIcon.copy,
                tooltip: "复制译文",
                flashIcon: DimmiIcon.checkOk,
                flashDuration: 1.2
            ) {
                viewModel.copyRequested(r.italian)
            }
        case .failed(_, let msg, _, _):
            HStack(spacing: 6) {
                PanelIconButton(icon: Ph.arrowClockwise, tooltip: "重试") {
                    viewModel.retryRequested()
                }
                Text(msg)
                    .font(DimmiFont.captionSmall)
                    .foregroundStyle(PanelEditorialGlass.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        case .loading, .hidden:
            EmptyView()
        }
    }

    // MARK: - 原文预览（常驻）

    private var sourceTextLine: some View {
        Text(viewModel.phase.sourceText ?? "")
            .font(DimmiFont.poppins(12, .regular))
            .foregroundStyle(PanelEditorialGlass.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 内容区（revealing / idle / failed）

    @ViewBuilder
    private var contentArea: some View {
        switch viewModel.phase {
        case .loading, .hidden:
            EmptyView()
        case .revealing(_, let r, _, _, _), .idle(_, let r, _, _, _):
            resultBody(result: r)
        case .failed(_, let msg, _, _):
            VStack(alignment: .leading, spacing: 6) {
                Text(msg)
                    .font(DimmiFont.caption)
                    .foregroundStyle(Color(hex: "FFD1D5").opacity(0.95))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 翻译正文（reveal 或 idle）

    @ViewBuilder
    private func resultBody(result: TranslationResult) -> some View {
        let progress = viewModel.progress
        let noteProgress = viewModel.noteProgress
        let realNote = viewModel.phraseNote ?? .none

        // 「fallback 注脚」是给未配 key / AI 说「无惯用表达」时用的退化版本：
        // 把翻译返回的 result.note 渲染成一行 usage，让 Analisi 栏永远不空。
        // 从 viewModel.phraseNote 走到 result.note 的视觉降级，绝不抢主译文。
        let effectiveNote: PhraseNote = {
            if realNote.hasNote { return realNote }
            if let fallback = result.note, !fallback.isEmpty {
                return PhraseNote(hasNote: true, kind: .register, breakdown: nil, usage: fallback, example: nil)
            }
            return .none
        }()
        let showNote = effectiveNote.hasNote

        VStack(alignment: .leading, spacing: 0) {
            // 主译文：样图里的编辑式大正文。固定暖白，不随系统浅/深色翻转。
            RevealableText(
                text: result.italian,
                progress: progress,
                font: DimmiFont.panelHero,
                lineSpacing: 6,
                foreground: PanelEditorialGlass.primary,
                selectableWhenComplete: true,
                selectableFont: DimmiFont.nsPoppins(
                    size: DimmiFont.panelHeroSize,
                    weight: .medium
                )
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            // Analisi 区：分隔线 + 标题 + 统一分组里的 breakdown / usage / example。
            // 有真注解 → 完整多行；只有 result.note → 同一栏退化成一行 usage。
            if showNote {
                // 真注解：noteProgress 单独驱动（reveal 完毕后晚 ~0.3s 才出现）。
                // fallback：没有 noteProgress（不会 applyNote），用主 reveal 进度同步展开，避免空白。
                let revealProgress: Double = realNote.hasNote ? noteProgress : progress
                grammarBreakdownSection(note: effectiveNote, progress: revealProgress, isFallback: !realNote.hasNote)
                    .padding(.top, 18)
            }
        }
    }

    /// 样图式 Analisi 区：标题 + 一个浅描边分组，信息密度高但不叠第二层重玻璃。
    @ViewBuilder
    private func grammarBreakdownSection(note: PhraseNote, progress: Double, isFallback: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(PanelEditorialGlass.divider)
                .frame(height: 0.5)
                .padding(.bottom, 14)

            HStack(spacing: 7) {
                Text("Analisi")
                    .font(DimmiFont.poppins(13, .medium))
                    .foregroundStyle(PanelEditorialGlass.accent)

                if !isFallback, let kind = note.kind {
                    Text("·  \(kind.label)")
                        .font(DimmiFont.poppins(10, .regular))
                        .foregroundStyle(PanelEditorialGlass.tertiary)
                }
                Spacer(minLength: 0)
                analysisToggleIcon
            }
            .frame(height: 20)
            .padding(.bottom, analysisExpanded ? 8 : 0)

            if analysisExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    if let b = note.breakdown, !b.isEmpty {
                        analysisRow(label: "拆解", text: b, progress: progress, emphasized: true)
                        if note.usage?.isEmpty == false || note.example != nil {
                            analysisDivider
                        }
                    }

                    if let u = note.usage, !u.isEmpty {
                        analysisRow(label: "用法", text: u, progress: progress)
                        if note.example != nil {
                            analysisDivider
                        }
                    }

                    if let e = note.example {
                        analysisExampleRow(example: e, progress: progress)
                    }
                }
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(PanelEditorialGlass.insetFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(PanelEditorialGlass.insetStroke, lineWidth: 0.65)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var analysisDivider: some View {
        Rectangle()
            .fill(PanelEditorialGlass.divider.opacity(0.72))
            .frame(height: 0.5)
            .padding(.leading, 12)
            .padding(.trailing, 12)
    }

    private func analysisRow(
        label: String,
        text: String,
        progress: Double,
        emphasized: Bool = false
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(DimmiFont.poppins(10, .medium))
                .foregroundStyle(PanelEditorialGlass.tertiary)
                .frame(width: 30, alignment: .leading)

            RevealableText(
                text: text,
                progress: progress,
                font: emphasized ? DimmiFont.bodyMedium : DimmiFont.bodyRegular,
                lineSpacing: 3,
                foreground: emphasized ? PanelEditorialGlass.primary : PanelEditorialGlass.secondary,
                noteRenderer: true,
                selectableWhenComplete: true,
                selectableFont: DimmiFont.nsInter(
                    size: 13,
                    weight: emphasized ? .medium : .regular
                )
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private func analysisExampleRow(example: PhraseNote.Example, progress: Double) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("例句")
                .font(DimmiFont.poppins(10, .medium))
                .foregroundStyle(PanelEditorialGlass.tertiary)
                .frame(width: 30, alignment: .leading)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                RevealableText(
                    text: example.it,
                    progress: progress,
                    font: DimmiFont.exampleItalic,
                    lineSpacing: 3,
                    foreground: PanelEditorialGlass.primary,
                    noteRenderer: true,
                    selectableWhenComplete: true,
                    selectableFont: DimmiFont.nsInterItalic(size: 13)
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                RevealableText(
                    text: example.zh,
                    progress: progress,
                    font: DimmiFont.exampleZh,
                    lineSpacing: 3,
                    foreground: PanelEditorialGlass.secondary,
                    noteRenderer: true,
                    selectableWhenComplete: true,
                    selectableFont: DimmiFont.nsInter(size: 11, weight: .regular)
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var analysisToggleIcon: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.20)) {
                analysisExpanded.toggle()
            }
            viewModel.bumpAutoDismiss()
        } label: {
            Ph.caretDown.thin
                .color(PanelEditorialGlass.primary)
                .frame(width: 14, height: 14)
                .rotationEffect(analysisExpanded ? .degrees(0) : .degrees(-90))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(analysisExpanded ? "收起解析" : "展开解析")
    }

}

// MARK: - 浮窗图标按钮（玻璃按钮：半透明白 + 白描边）

private struct PanelIconButton: View {
    let icon: Ph
    var tooltip: String = ""
    var onTap: (() -> Void)? = nil
    /// 点击后短暂替换的图标（如复制成功后 → checkmark）。
    var flashIcon: Ph? = nil
    var flashDuration: TimeInterval = 1.2
    let action: () -> Void

    @State private var isHovered = false
    @State private var isFlashing = false

    private var currentIcon: Ph {
        isFlashing ? (flashIcon ?? icon) : icon
    }

    var body: some View {
        Button(action: handleTap) {
            currentIcon.thin
                .color(PanelEditorialGlass.primary)
                .frame(width: 17, height: 17)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isHovered ? PanelEditorialGlass.hoverFill : Color.clear)
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            PanelEditorialGlass.insetStroke.opacity(isHovered ? 1 : 0.22),
                            lineWidth: 0.5
                        )
                )
                .contentTransition(.symbolEffect(.replace.downUp))
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { isHovered = $0 }
    }

    private func handleTap() {
        action()
        onTap?()
        guard flashIcon != nil else { return }
        isFlashing = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(flashDuration * 1_000_000_000))
            isFlashing = false
        }
    }
}
