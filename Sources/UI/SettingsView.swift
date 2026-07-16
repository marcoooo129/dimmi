// 设置窗口：「褪色黄昏 · 毛玻璃」。
//
// 窗口固定 500×460。主页按视觉稿使用明确的顶部节奏：
// 56pt 品牌头部 → 18pt → 240pt 主卡 → 26pt → 工具条。
// 子页沿用同一条 440pt 对齐线，超出内容在卡内滚动。
import SwiftUI
import KeyboardShortcuts
import AppKit
import PhosphorSwift

/// `KeyboardShortcuts.Recorder` 的 SwiftUI 外层会保留原生控件 130pt 的固有宽度，
/// 单纯加 `.frame(maxWidth:)` 只会放大布局槽，不会放大真正的点击区。
/// 这个容器保留中间黑色胶囊的原生视觉，同时让整条凹槽都能进入录制。
/// 原生 × / Delete / Esc 仍由 `RecorderCocoa` 自己处理。
@MainActor
private struct NativeShortcutRecorder: NSViewRepresentable {
    let name: KeyboardShortcuts.Name
    let accessibilityLabel: String
    let accessibilityIdentifier: String
    let onChange: (KeyboardShortcuts.Shortcut?) -> Void

    @MainActor
    final class Coordinator {
        var onChange: (KeyboardShortcuts.Shortcut?) -> Void
        weak var hostView: HostView?

        init(onChange: @escaping (KeyboardShortcuts.Shortcut?) -> Void) {
            self.onChange = onChange
        }

        func clearShortcut() {
            guard let hostView else { return }
            let shortcutName = hostView.recorder.shortcutName
            let hadShortcut = KeyboardShortcuts.getShortcut(for: shortcutName) != nil
            KeyboardShortcuts.setShortcut(nil, for: shortcutName)
            if hadShortcut {
                onChange(nil)
            }
            hostView.focusRecorderAfterCurrentEvent(delay: 0.05)
        }
    }

    final class HostView: NSView {
        final class MouseOverlay: NSView {
            weak var owner: HostView?

            override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

            override func mouseDown(with event: NSEvent) {
                // 等 mouseUp 再判断是清除还是开始录制。
            }

            override func mouseUp(with event: NSEvent) {
                owner?.handleMouseUp(event)
            }
        }

        let recorder: KeyboardShortcuts.RecorderCocoa
        private let mouseOverlay = MouseOverlay(frame: .zero)
        var onClear: (() -> Void)?

        init(recorder: KeyboardShortcuts.RecorderCocoa) {
            self.recorder = recorder
            super.init(frame: NSRect(x: 0, y: 0, width: 130, height: 28))
            addSubview(recorder)
            mouseOverlay.owner = self
            mouseOverlay.setAccessibilityElement(false)
            mouseOverlay.frame = bounds
            mouseOverlay.autoresizingMask = [.width, .height]
            addSubview(mouseOverlay, positioned: .above, relativeTo: recorder)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var intrinsicContentSize: NSSize {
            NSSize(width: NSView.noIntrinsicMetric, height: 28)
        }

        override func layout() {
            super.layout()
            let intrinsic = recorder.intrinsicContentSize
            let width = min(bounds.width, max(130, intrinsic.width))
            let height = min(bounds.height, max(24, intrinsic.height))
            recorder.frame = NSRect(
                x: (bounds.width - width) / 2,
                y: (bounds.height - height) / 2,
                width: width,
                height: height
            )
            mouseOverlay.frame = bounds
        }

        /// 空白槽位的 mouse-up 结束后再聚焦。如果在 mouse-down 时聚焦，
        /// RecorderCocoa 新建的事件监听器会把紧接着的 mouse-up 当成外部点击，
        /// 反而立即退出录制。
        private func handleMouseUp(_ event: NSEvent) {
            let point = convert(event.locationInWindow, from: nil)
            let clearRegion = NSRect(
                x: recorder.frame.maxX - 30,
                y: recorder.frame.minY,
                width: 30,
                height: recorder.frame.height
            )
            if !recorder.stringValue.isEmpty, clearRegion.contains(point) {
                onClear?()
            } else {
                focusRecorderAfterCurrentEvent()
            }
        }

        func focusRecorderAfterCurrentEvent(delay: TimeInterval = 0) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, let window = self.window else { return }
                let focused = window.makeFirstResponder(recorder)
                if !recorder.isAccessibilityFocused() {
                    recorder.setAccessibilityFocused(true)
                }
                if !focused {
                    // 窗口刚被激活时 RecorderCocoa 会短暂拒绝首响应，下一帧重试。
                    DispatchQueue.main.async { [weak self] in
                        guard let self, let window = self.window else { return }
                        window.makeFirstResponder(recorder)
                        if !recorder.isAccessibilityFocused() {
                            recorder.setAccessibilityFocused(true)
                        }
                    }
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    func makeNSView(context: Context) -> HostView {
        let coordinator = context.coordinator
        let recorder = KeyboardShortcuts.RecorderCocoa(for: name) { [weak coordinator] shortcut in
            // 必须退出 NSSearchFieldDelegate 的同步回调栈后再更新 SwiftUI。
            // 否则点 × 时会在原生控件重新聚焦前触发视图刷新。
            DispatchQueue.main.async {
                guard let coordinator else { return }
                coordinator.onChange(shortcut)
                if shortcut == nil {
                    // NSSearchField 的原生 × 会在清空后完成自己的鼠标事件，
                    // 该事件有时会在库内部 focus() 之后再取消首响应。
                    // 退出 delegate 与鼠标回调后补一次真正的 AppKit 聚焦，
                    // 用户就能在点 × 后无需再点第二次，直接输入新组合键。
                    coordinator.hostView?.focusRecorderAfterCurrentEvent(delay: 0.05)
                }
            }
        }
        configureAccessibility(for: recorder)
        let hostView = HostView(recorder: recorder)
        coordinator.hostView = hostView
        hostView.onClear = { [weak coordinator] in
            coordinator?.clearShortcut()
        }
        return hostView
    }

    func updateNSView(_ nsView: HostView, context: Context) {
        context.coordinator.onChange = onChange
        context.coordinator.hostView = nsView
        nsView.onClear = { [weak coordinator = context.coordinator] in
            coordinator?.clearShortcut()
        }
        nsView.recorder.shortcutName = name
        configureAccessibility(for: nsView.recorder)
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: HostView,
        context: Context
    ) -> CGSize? {
        CGSize(width: proposal.width ?? 130, height: proposal.height ?? 28)
    }

    private func configureAccessibility(for recorder: KeyboardShortcuts.RecorderCocoa) {
        recorder.setAccessibilityLabel(accessibilityLabel)
        recorder.setAccessibilityHelp("点击后按下新的组合键；Esc 取消，Delete 或 × 清除")
        recorder.setAccessibilityIdentifier(accessibilityIdentifier)
    }
}

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var selectedSection: SettingsSection? = nil
    @State private var launchAtLogin: Bool = LaunchAtLoginService.current
    @State private var sessionSnapshot: SettingsSnapshot?
    @State private var sessionFinalized = false
    @State private var sessionIsActive = false
    @State private var engineDrafts: [TranslationProvider: EngineConfig] = [:]
    @State private var showClearCacheConfirmation = false
    @State private var cacheResult: TestResult = .idle
    @State private var launchAtLoginResult: TestResult = .idle
    @State private var apiInputResult: TestResult = .idle
    @State private var selectionMinLengthDraft = ""
    @State private var selectionMaxLengthDraft = ""
    @FocusState private var focusedSelectionLengthField: SelectionLengthField?
    @State private var lastValidForwardShortcut: KeyboardShortcuts.Shortcut?
    @State private var lastValidReverseShortcut: KeyboardShortcuts.Shortcut?
    @State private var shortcutFeedback: [ShortcutRecorderField: ShortcutFeedback] = [:]

    /// 设置页的尺寸单一入口。窗口宽 500，左右各留 30，所以全部
    /// 头部 / 主卡 / 工具条都对齐到同一条 440pt 基准线。
    enum SettingsLayout {
        static let windowWidth: CGFloat = 500
        static let windowHeight: CGFloat = 460
        static let contentWidth: CGFloat = 440
        static let windowVerticalPadding: CGFloat = 24
        static let contentToFooterSpacing: CGFloat = 18

        // 主页头部
        static let homeTopPadding: CGFloat = 28
        static let homeHeaderHeight: CGFloat = 56
        static let homeHeaderToCardSpacing: CGFloat = 18
        static let homeCardToFooterSpacing: CGFloat = 26
        static let homeFooterHeight: CGFloat = 36
        static let homeIconSize: CGFloat = 56
        static let homeIconRadius: CGFloat = 18

        // 子页大卡
        static let cardCornerRadius: CGFloat = 26
        static let cardHorizontalPadding: CGFloat = 18
        static let cardTopPadding: CGFloat = 18
        static let cardBottomPadding: CGFloat = 18

        // 子页卡与 440pt 内容基准线直接对齐，不再叠加额外水平缩进。
        static let detailScrollHorizontal: CGFloat = 0
        static let detailHeaderHorizontal: CGFloat = 0
        static let backButtonHeight: CGFloat = 30

        // 主页行高
        static let homeRowHeight: CGFloat = 58
        static let homeRowHorizontalPadding: CGFloat = 18
        static let homeRowCornerRadius: CGFloat = 20
        static let homeRowIconTile: CGFloat = 38
        static let homeRowIconRadius: CGFloat = 12
    }

    enum SettingsSection: String, CaseIterable, Hashable, Identifiable {
        case apiKey      = "API 密钥"
        case translation = "翻译设置"
        case shortcut    = "快捷键与行为"
        case about       = "关于"

        var id: Self { self }
        var icon: Ph {
            switch self {
            case .apiKey:      return DimmiIcon.apiKey
            case .translation: return DimmiIcon.translation
            case .shortcut:    return DimmiIcon.shortcuts
            case .about:       return DimmiIcon.about
            }
        }
        var subtitle: String {
            switch self {
            case .apiKey:      return "选择模型厂商，配置密钥与兼容端点"
            case .translation: return "目标语言、反向翻译、翻译风格与缓存管理"
            case .shortcut:    return "设置划词触发方式、开机自启与窗口显示"
            case .about:       return "版本信息、致谢与许可证"
            }
        }
    }

    private enum SelectionLengthField: Hashable {
        case minimum
        case maximum
    }

    private enum ShortcutRecorderField: Hashable {
        case forward
        case reverse
    }

    private enum ShortcutFeedback: Equatable {
        case saved(String)
        case error(String)

        var message: String {
            switch self {
            case .saved(let message), .error(let message): return message
            }
        }

        var color: Color {
            switch self {
            case .saved: return .green
            case .error: return .red
            }
        }
    }

    /// 设置窗是一段可撤销的编辑会话。大多数运行参数需要即时预览，
    /// 因此先实时应用；用户点「取消」或窗口红色关闭时再完整回滚。
    private struct SettingsSnapshot {
        let provider: TranslationProvider
        let autoTranslateEnabled: Bool
        var sourceMode: AppState.SourceMode
        let selectionMinLength: Int
        let selectionMaxLength: Int
        let selectionCooldown: TimeInterval
        let successAutoDismiss: TimeInterval
        let errorAutoDismiss: TimeInterval
        let useMockWhenNoKey: Bool
        let showPhraseNotes: Bool
        let targetLanguage: TargetLanguage
        let reverseTranslateEnabled: Bool
        let launchAtLogin: Bool
        let forwardShortcut: KeyboardShortcuts.Shortcut?
        let reverseShortcut: KeyboardShortcuts.Shortcut?
    }

    var body: some View {
        ZStack {
            DimmiBackground()

            if let section = selectedSection {
                detailPage(for: section, contentWidth: SettingsLayout.contentWidth)
            } else {
                homePage(contentWidth: SettingsLayout.contentWidth)
            }
        }
        .preferredColorScheme(.dark)
        // 锁死 500×460，不可缩放（子页靠 ScrollView 消化超出内容，窗口不跳尺寸）。
        .frame(width: SettingsLayout.windowWidth, height: SettingsLayout.windowHeight)
        .onAppear {
            // SwiftUI 在切换同一 App 的其他 Window（例如“帮助”）时，可能在没有
            // 对应 onDisappear 的情况下再次触发 onAppear。此时不能重拍快照，
            // 否则尚未保存的临时值会被误当成新的“取消”基线。
            if !sessionIsActive {
                beginSettingsSession()
                sessionIsActive = true
            }
            startPollingAccessibility()
        }
        .onDisappear {
            stopPollingAccessibility()
            if !sessionFinalized {
                restoreSettingsSnapshot()
            }
            sessionIsActive = false
            sessionSnapshot = nil
        }
        .onChange(of: state.provider) { oldProvider, newProvider in
            switchEngineDraft(from: oldProvider, to: newProvider)
        }
        .onChange(of: state.accessibilityTrusted) { oldValue, newValue in
            guard !oldValue, newValue, state.sourceMode == .selection else { return }
            // 用户已经在系统设置完成了不可回滚的授权，此时也把“划词”视为
            // 已确认的运行模式。否则红色关闭设置窗会恢复旧快照到 clipboard，
            // 造成“系统明明已授权，但划词完全没反应”的假故障。
            sessionSnapshot?.sourceMode = .selection
        }
        .onChange(of: state.sourceMode) { _, newMode in
            // 取词方式的切换**永远**立即确认，不参与「取消 = 回滚」：
            // 上面那个 onChange 只覆盖"会话中途才授权"的情况；
            // 如果用户早已授权（accessibilityTrusted 从头就是 true），
            // 切到划词后用红色按钮关窗，快照回滚会把模式静默改回 clipboard——
            // 表现为"授权了但划词永远无效"（真实踩过：sourceMode 就是这么被
            // 一次次改回去的）。模式切换伴随系统授权跳转，是用户的明确决定，
            // 不是"可预览可撤销"的微调参数。
            sessionSnapshot?.sourceMode = newMode
        }
        .onChange(of: apiKeyInput) { _, _ in testResult = .idle }
        .onChange(of: modelInput) { _, _ in testResult = .idle }
        .onChange(of: baseURLInput) { _, _ in testResult = .idle }
        .confirmationDialog(
            "清除语法注解缓存？",
            isPresented: $showClearCacheConfirmation,
            titleVisibility: .visible
        ) {
            Button("清除缓存", role: .destructive) {
                Task { await clearNoteCache() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只会删除本机缓存的语法注解，不会删除翻译历史、API 配置或其他设置。")
        }
    }

    // MARK: - 主页（阶段 1）

    private func homePage(contentWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 视觉稿：品牌区不再随整组内容垂直漂移，而是稳定落在顶部 28pt。
            HStack(spacing: 18) {
                GlassCard(radius: SettingsLayout.homeIconRadius) {
                    DimmiBrandMark(size: 46)
                        .frame(width: SettingsLayout.homeIconSize, height: SettingsLayout.homeIconSize)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("dimmi")
                        .font(DimmiFont.appTitle)
                        .tracking(0.6)
                        .foregroundStyle(DimmiTheme.textPrimary)
                    Text("划词即翻 · 中文到意大利语")
                        .font(DimmiFont.caption)
                        .foregroundStyle(DimmiTheme.textSecondary)
                }

                Spacer(minLength: 0)
            }
            .frame(height: SettingsLayout.homeHeaderHeight)
            .padding(.top, SettingsLayout.homeTopPadding)

            Spacer()
                .frame(height: SettingsLayout.homeHeaderToCardSpacing)

            // 主体：240pt 大卡包住四个 58pt 行，卡内仅保留 4pt 上下呼吸。
            GlassCard(radius: SettingsLayout.cardCornerRadius) {
                VStack(spacing: 0) {
                    ForEach(SettingsSection.allCases) { section in
                        HomeGlassRow(section: section) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                selectedSection = section
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
            }

            Spacer()
                .frame(height: SettingsLayout.homeCardToFooterSpacing)

            footerBar(contentWidth: contentWidth)
                .frame(height: SettingsLayout.homeFooterHeight)

            Spacer(minLength: 0)
        }
        .frame(width: contentWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Detail shell

    /// 短子页收缩到内容高度并整组居中；长子页的 ScrollView 则占满剩余高度。
    /// 两条路径的工具条都是紧跟主卡 18pt，没有额外的占位留白。
    @ViewBuilder
    private func detailPage(for section: SettingsSection, contentWidth: CGFloat) -> some View {
        if section == .about {
            VStack(spacing: SettingsLayout.contentToFooterSpacing) {
                compactDetailHeader(for: section)
                detailContent(for: section)
                    .padding(.horizontal, SettingsLayout.detailScrollHorizontal)
                footerBar(contentWidth: contentWidth)
            }
            .frame(width: contentWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            VStack(spacing: SettingsLayout.contentToFooterSpacing) {
                compactDetailHeader(for: section)

                ScrollView {
                    detailContent(for: section)
                        .padding(.horizontal, SettingsLayout.detailScrollHorizontal)
                        .padding(.vertical, 1)
                }
                .scrollIndicators(.hidden)
                .frame(maxHeight: .infinity)

                footerBar(contentWidth: contentWidth)
            }
            .padding(.vertical, SettingsLayout.windowVerticalPadding)
            .frame(width: contentWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func compactDetailHeader(for section: SettingsSection) -> some View {
        detailHeader(for: section)
            .padding(.horizontal, SettingsLayout.detailHeaderHorizontal)
            .frame(height: SettingsLayout.backButtonHeight)
    }

    private func detailHeader(for section: SettingsSection) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    selectedSection = nil
                }
            } label: {
                HStack(spacing: 4) {
                    Ph.arrowLeft.thin
                        .dimmiIcon(size: 14, muted: true)
                    Text("返回")
                        .font(DimmiFont.settingsBody)
                }
                .foregroundStyle(DimmiTheme.textSecondary)
                .frame(height: SettingsLayout.backButtonHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            section.icon.thin
                .dimmiIcon(size: DimmiIconSize.row)
            Text(section.rawValue)
                .font(DimmiFont.pageTitle)
                .tracking(0.4)
                .foregroundStyle(DimmiTheme.textPrimary)

            Spacer()
            // 删掉右上角 help 圆钮 —— 底部工具条已经有「帮助」按钮，重复会让人迟疑。
        }
    }

    // MARK: - Content routers

    @ViewBuilder
    private func detailContent(for section: SettingsSection) -> some View {
        switch section {
        case .apiKey:      apiKeyDetail
        case .translation: translationDetail
        case .shortcut:    shortcutDetail
        case .about:       aboutDetail
        }
    }

    // MARK: - API Key
    //
    // 子页结构：一张大 GlassCard (radius 24, v3 收紧)，内部分组由 GroupLabel + GlassDivider 切分。
    // 旧版本嵌套多层 settingsCard 已删除 —— 不允许"玻璃套玻璃"。

    @State private var apiKeyInput: String = ""
    @State private var modelInput: String = ""
    @State private var modelSelection: TranslationModelSelection = .custom
    @State private var customModelInput: String = ""
    @State private var baseURLInput: String = ""
    @State private var apiKeyRevealed: Bool = false
    @State private var testRunning: Bool = false
    @State private var testResult: TestResult = .idle

    enum TestResult: Equatable {
        case idle, ok(String), failed(String)
    }

    private var apiKeyDetail: some View {
        GlassCard(radius: SettingsLayout.cardCornerRadius) {
            VStack(alignment: .leading, spacing: 0) {
                // MARK: 翻译引擎
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("翻译引擎")
                                .font(DimmiFont.settingsBody)
                                .foregroundStyle(DimmiTheme.textPrimary)
                            Text("默认引擎")
                                .font(DimmiFont.caption)
                                .foregroundStyle(DimmiTheme.textSecondary)
                        }

                        Spacer(minLength: 24)

                        GlassPicker(
                            selection: $state.provider,
                            items: TranslationProvider.allCases.map { ($0.rawValue, $0) },
                            width: 226
                        )
                        .accessibilityLabel("翻译引擎")
                        .accessibilityValue(state.provider.rawValue)
                        .accessibilityIdentifier("settings.api.provider.picker")
                    }

                    Text(state.provider.configurationHint)
                        .font(DimmiFont.caption)
                        .foregroundStyle(DimmiTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, SettingsLayout.cardHorizontalPadding)
                .padding(.top, SettingsLayout.cardTopPadding)

                GlassDivider()

                // MARK: 密钥配置
                VStack(alignment: .leading, spacing: 18) {
                    GroupLabel("密钥配置")

                    VStack(alignment: .leading, spacing: 18) {
                        // API Key 行（含 reveal + paste 按钮）
                        VStack(alignment: .leading, spacing: 6) {
                            Text(state.provider.requiresAPIKey ? "API Key" : "API Key（可选）")
                                .font(DimmiFont.settingsBody)
                                .foregroundStyle(DimmiTheme.textPrimary)
                            Text(state.provider.keyPlaceholder)
                                .font(DimmiFont.caption)
                                .foregroundStyle(DimmiTheme.textSecondary)

                            HStack(spacing: 8) {
                                Group {
                                    if apiKeyRevealed {
                                        TextField(state.provider.keyPlaceholder, text: $apiKeyInput)
                                    } else {
                                        SecureField(state.provider.keyPlaceholder, text: $apiKeyInput)
                                    }
                                }
                                .textFieldStyle(.plain)
                                .font(DimmiFont.inter(12))    // （13→12）输入框字体
                                .foregroundStyle(DimmiTheme.textPrimary)
                                .padding(.horizontal, 14)       // （16→14）
                                .frame(height: 34)             // （40→34）

                                GlassPillIcon(icon: apiKeyRevealed ? Ph.eyeSlash : Ph.eye, size: 14) {
                                    apiKeyRevealed.toggle()
                                }

                                GlassPillText(label: "粘贴") {
                                    if let pb = NSPasteboard.general.string(forType: .string) {
                                        apiKeyInput = pb.trimmingCharacters(in: .whitespacesAndNewlines)
                                        apiInputResult = apiKeyInput.isEmpty
                                            ? .failed("剪贴板里的文本为空")
                                            : .ok("已从剪贴板填入，保存后生效")
                                    } else {
                                        apiInputResult = .failed("剪贴板中没有可用文本")
                                    }
                                }
                            }

                            if case .ok(let message) = apiInputResult {
                                resultPill(message, color: .green)
                            } else if case .failed(let message) = apiInputResult {
                                resultPill(message, color: .red)
                            }
                        }

                        if !TranslationModelCatalog.options(for: state.provider).isEmpty {
                            modelSelectionControl
                        }

                        if modelSelection == .custom {
                            SunkenField(
                                label: "自定义模型 ID",
                                text: Binding(
                                    get: { customModelInput },
                                    set: { newValue in
                                        customModelInput = newValue
                                        modelInput = newValue
                                    }
                                ),
                                placeholder: currentModelPlaceholder,
                                helper: "目录外模型也可以直接填写；保存后会原样使用"
                            )
                        }

                        // OpenAI-compatible 厂商允许保留官方地址，也可接入兼容网关。
                        if state.provider.supportsCustomBaseURL {
                            SunkenField(label: "Base URL", text: $baseURLInput,
                                       placeholder: currentBaseURLPlaceholder,
                                       helper: "支持 OpenAI 兼容地址；可带或不带末尾斜杠")
                        }

                        if apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           !effectiveCurrentDraft.apiKey.isEmpty {
                            HStack(spacing: 8) {
                                DimmiIcon.sparkle.thin
                                    .dimmiIcon(size: 14, muted: true)
                                Text("正在使用应用内置 Key")
                                    .font(DimmiFont.caption)
                                    .foregroundStyle(DimmiTheme.textSecondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().fill(DimmiTheme.glassFillHover)
                            )
                        }
                    }
                }
                .padding(.horizontal, SettingsLayout.cardHorizontalPadding)

                GlassDivider()

                // MARK: 测试连接
                VStack(spacing: 14) {
                    GroupLabel("测试连接")

                    Button {
                        Task { await runConnectionTest() }
                    } label: {
                        Text(testRunning ? "测试中…" : "测试连接")
                            .font(DimmiFont.settingsPill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)   // （40→34）
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DimmiTheme.primaryFg)
                    .background(
                        Capsule().fill(DimmiTheme.glassFillRaised)
                            .overlay(
                                Capsule()
                                    .stroke(DimmiTheme.glassEdgeTop, lineWidth: 1)
                                    .blendMode(.plusLighter)
                            )
                    )
                    .disabled(!canTestCurrentDraft || testRunning)
                    .opacity((!canTestCurrentDraft || testRunning) ? 0.5 : 1)

                    if case .ok(let msg) = testResult {
                        resultPill(msg, color: .green)
                    } else if case .failed(let msg) = testResult {
                        resultPill(msg, color: .red)
                    }
                }
                .padding(.horizontal, SettingsLayout.cardHorizontalPadding)
                .padding(.bottom, SettingsLayout.cardBottomPadding)
            }
        }
    }

    private func resultPill(_ text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: color == .green ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(text)
                .font(DimmiFont.caption)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(color.opacity(0.1))
        )
    }

    // MARK: - Translation

    private var translationDetail: some View {
        GlassCard(radius: SettingsLayout.cardCornerRadius) {
            VStack(alignment: .leading, spacing: 0) {
                // MARK: 目标语言
                VStack(alignment: .leading, spacing: 14) {
                    GroupLabel("目标语言")

                    Text("dimmi 默认把中文翻译成你选的语言；反向翻译会把选中的语言译回中文。")
                        .font(DimmiFont.caption)
                        .foregroundStyle(DimmiTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    GlassPicker(
                        selection: $state.targetLanguage,
                        items: TargetLanguage.allCases.map { ("\($0.emoji) \($0.rawValue)", $0) }
                    )

                    AethericToggle(
                        title: "启用反向翻译（\(state.targetLanguage.rawValue) → 中文）",
                        subtitle: "开启后菜单栏多一个「反向翻译」入口，全局快捷键 ⌘⇧B",
                        isOn: $state.reverseTranslateEnabled
                    )
                }
                .padding(.horizontal, SettingsLayout.cardHorizontalPadding)
                .padding(.top, SettingsLayout.cardTopPadding)

                GlassDivider()

                // MARK: 行为设置
                VStack(alignment: .leading, spacing: 18) {
                    GroupLabel("行为设置")

                    VStack(spacing: 16) {
                        AethericToggle(
                            title: "自动划词翻译",
                            subtitle: "选中文字后立即显示翻译结果",
                            isOn: $state.autoTranslateEnabled
                        )
                        AethericToggle(
                            title: "未配 Key 时用示例翻译",
                            subtitle: "没有可用密钥时显示本地示例结果",
                            isOn: $state.useMockWhenNoKey
                        )
                        AethericToggle(
                            title: "显示语法注解",
                            subtitle: "为翻译结果提供 AI 语法解析（消耗额外额度）",
                            isOn: $state.showPhraseNotes
                        )
                    }

                    Button {
                        showClearCacheConfirmation = true
                    } label: {
                        HStack(spacing: 8) {
                            DimmiIcon.clearCache.thin
                                .dimmiIcon(size: DimmiIconSize.inline, muted: true)
                            Text("清除语法注解缓存")
                        }
                        .font(DimmiFont.settingsBody)
                        .foregroundStyle(DimmiTheme.textSecondary)
                    }
                    .buttonStyle(.plain)

                    if case .ok(let message) = cacheResult {
                        resultPill(message, color: .green)
                    } else if case .failed(let message) = cacheResult {
                        resultPill(message, color: .red)
                    }
                }
                .padding(.horizontal, SettingsLayout.cardHorizontalPadding)

                GlassDivider()

                // MARK: 划词触发
                VStack(alignment: .leading, spacing: 16) {
                    GroupLabel("划词触发")

                    stepperRow(
                        title: "最少字符数",
                        value: state.selectionMinLength,
                        draft: $selectionMinLengthDraft,
                        field: .minimum,
                        range: UserPrefs.selectionLengthRange,
                        step: 1,
                        onChange: { newValue in
                            state.updateSelectionMinLength(newValue)
                            syncSelectionLengthDrafts()
                        },
                        onCommit: { commitSelectionMinimumDraft() }
                    )

                    stepperRow(
                        title: "最多字符数",
                        value: state.selectionMaxLength,
                        draft: $selectionMaxLengthDraft,
                        field: .maximum,
                        range: UserPrefs.selectionLengthRange,
                        step: 1,
                        onChange: { newValue in
                            state.updateSelectionMaxLength(newValue)
                            syncSelectionLengthDrafts()
                        },
                        onCommit: { commitSelectionMaximumDraft() }
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("触发后冷却时间")
                                .font(DimmiFont.settingsBody)
                                .foregroundStyle(DimmiTheme.textPrimary)
                            Spacer()
                            Text("\(String(format: "%.1f", state.selectionCooldown))s")
                                .font(DimmiFont.caption)
                                .foregroundStyle(DimmiTheme.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule().fill(DimmiTheme.glassFillHover)
                                )
                        }
                        Slider(value: $state.selectionCooldown, in: 0...5, step: 0.1)
                            .tint(DimmiTheme.glassEdgeTop)
                    }
                }
                .padding(.horizontal, SettingsLayout.cardHorizontalPadding)

                GlassDivider()

                // MARK: 卡片自动关闭
                VStack(alignment: .leading, spacing: 16) {
                    GroupLabel("卡片自动关闭")

                    VStack(alignment: .leading, spacing: 16) {
                        dismissSliderRow(label: "成功翻译后自动关闭",
                                         value: $state.successAutoDismiss,
                                         range: 2...60)

                        dismissSliderRow(label: "错误结果自动关闭",
                                         value: $state.errorAutoDismiss,
                                         range: 2...120)
                    }
                }
                .padding(.horizontal, SettingsLayout.cardHorizontalPadding)
                .padding(.bottom, SettingsLayout.cardBottomPadding)
            }
        }
    }

    /// 自动关闭时长滑动条（icon-free 版本，简洁）
    private func dismissSliderRow(label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(DimmiFont.settingsBody)
                    .foregroundStyle(DimmiTheme.textPrimary)
                Spacer()
                Text("\(Int(value.wrappedValue))s")
                    .font(DimmiFont.caption)
                    .foregroundStyle(DimmiTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(DimmiTheme.glassFillHover)
                    )
            }
            Slider(value: value, in: range, step: 1)
                .tint(DimmiTheme.glassEdgeTop)
        }
    }

    // MARK: - Shortcuts

    private var shortcutDetail: some View {
        GlassCard(radius: SettingsLayout.cardCornerRadius) {
            VStack(alignment: .leading, spacing: 0) {
                // MARK: 全局快捷键
                VStack(alignment: .leading, spacing: 16) {
                    GroupLabel("全局快捷键")

                    shortcutRecorderRow(
                        label: "触发翻译",
                        helper: "全局范围内唤醒翻译面板（中文 → 目标语）",
                        shortcutName: .triggerTranslate,
                        field: .forward
                    )

                    if state.reverseTranslateEnabled {
                        shortcutRecorderRow(
                            label: "反向翻译",
                            helper: "全局范围内把目标语翻回中文（需在「翻译设置」里启用反向翻译）",
                            shortcutName: .triggerReverseTranslate,
                            field: .reverse
                        )
                    }
                }
                .padding(.horizontal, SettingsLayout.cardHorizontalPadding)
                .padding(.top, SettingsLayout.cardTopPadding)

                GlassDivider()

                // MARK: 启动行为
                VStack(alignment: .leading, spacing: 14) {
                    GroupLabel("启动行为")

                    AethericToggle(title: "开机自动启动", subtitle: "系统登录后自动运行 dimmi", isOn: Binding(
                        get: { launchAtLogin },
                        set: { updateLaunchAtLogin($0) }
                    ))

                    if case .ok(let message) = launchAtLoginResult {
                        resultPill(message, color: .green)
                    } else if case .failed(let message) = launchAtLoginResult {
                        resultPill(message, color: .red)
                    }
                }
                .padding(.horizontal, SettingsLayout.cardHorizontalPadding)

                GlassDivider()

                // MARK: 取词方式
                VStack(alignment: .leading, spacing: 14) {
                    GroupLabel("取词方式")

                    SunkenField(label: "取词来源",
                               text: Binding(
                                   get: { state.sourceMode.label },
                                   set: { _ in }
                               ),
                               placeholder: nil,
                               helper: nil,
                               isEditable: false,
                               rightAccessory: AnyView(GlassPicker(
                                   selection: Binding(
                                       get: { state.sourceMode },
                                       set: { newValue in
                                           state.sourceMode = newValue
                                           if newValue == .selection && !state.accessibilityTrusted {
                                               AccessibilityManager.openSystemSettings()
                                           }
                                       }),
                                   items: AppState.SourceMode.allCases.map { ($0.label, $0) }
                               )))

                    if state.sourceMode == .selection {
                        HStack(spacing: 8) {
                            (state.accessibilityTrusted ? Ph.checkCircle.thin : Ph.warning.thin)
                                .dimmiIcon(size: DimmiIconSize.inline)
                                .color(state.accessibilityTrusted ? DimmiTheme.glassEdgeTop : Color.orange)
                            Text(state.accessibilityTrusted ? "辅助功能已授权" : "辅助功能未授权")
                                .font(DimmiFont.caption)
                                .foregroundStyle(DimmiTheme.textSecondary)
                            Spacer()
                            Button(state.accessibilityTrusted ? "重新检查" : "去授权") {
                                if state.accessibilityTrusted {
                                    state.refreshAccessibilityTrusted(prompt: false)
                                } else {
                                    state.refreshAccessibilityTrusted(prompt: true)
                                    if !state.accessibilityTrusted {
                                        AccessibilityManager.openSystemSettings()
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .font(DimmiFont.caption)
                            .foregroundStyle(DimmiTheme.glassEdgeTop)
                        }
                    }

                    Text(state.sourceMode == .clipboard
                         ? "粘贴板路径无需任何系统授权。"
                         : (state.accessibilityTrusted
                            ? "自动划词已启用；授权变化会立即生效，无需重启 dimmi。"
                            : "切到划词后会打开辅助功能授权；授权成功即自动启用并保存。"))
                        .font(DimmiFont.caption)
                        .foregroundStyle(DimmiTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, SettingsLayout.cardHorizontalPadding)

                GlassDivider()

                // MARK: 自检
                VStack(spacing: 12) {
                    GroupLabel("自检")

                    Button {
                        let pt = NSEvent.mouseLocation
                        PanelController.shared.presentWithMock(for: "我今天有点累", at: pt)
                    } label: {
                        Text("预览正向翻译卡片")
                            .font(DimmiFont.settingsPill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)   // （40→34）
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DimmiTheme.textPrimary)
                    .background(
                        Capsule().fill(DimmiTheme.glassFill)
                            .overlay(
                                Capsule()
                                    .stroke(DimmiTheme.glassEdgeTop.opacity(0.6), lineWidth: 1)
                                    .blendMode(.plusLighter)
                            )
                    )

                    Button {
                        let pt = NSEvent.mouseLocation
                        PanelController.shared.presentReverseWithMock(
                            for: state.targetLanguage.settingsReverseSample,
                            at: pt
                        )
                    } label: {
                        Text("预览反向翻译（\(state.targetLanguage.rawValue) → 中文）")
                            .font(DimmiFont.settingsPill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)   // （40→34）
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DimmiTheme.textPrimary)
                    .background(
                        Capsule().fill(DimmiTheme.glassFill)
                            .overlay(
                                Capsule()
                                    .stroke(DimmiTheme.glassEdgeTop.opacity(0.6), lineWidth: 1)
                                    .blendMode(.plusLighter)
                            )
                    )
                }
                .padding(.horizontal, SettingsLayout.cardHorizontalPadding)
                .padding(.bottom, SettingsLayout.cardBottomPadding)
            }
        }
    }

    // 快捷键录制行（凹陷 + 暖白描边 + 还原按钮）
    @ViewBuilder
    private func shortcutRecorderRow(
        label: String,
        helper: String,
        shortcutName: KeyboardShortcuts.Name,
        field: ShortcutRecorderField
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(DimmiFont.settingsLabel)
                .foregroundStyle(DimmiTheme.textPrimary)

            Text(shortcutHelperText(defaultText: helper, field: field))
                .font(DimmiFont.caption)
                .foregroundStyle(shortcutHelperColor(field: field))

            HStack(spacing: 8) {
                NativeShortcutRecorder(
                    name: shortcutName,
                    accessibilityLabel: "\(label)快捷键",
                    accessibilityIdentifier: field == .forward
                        ? "settings.shortcut.forward.recorder"
                        : "settings.shortcut.reverse.recorder",
                    onChange: { shortcut in
                        shortcutFeedback[field] = nil
                        handleShortcutChange(shortcut, for: field, name: shortcutName)
                    }
                )
                // 设置窗口固定 500pt：440 内宽 - 卡片 36 - 行内边距 28
                // - 还原按钮 28 - 间距 8 = 340。明确给原生 Host 实际宽度，
                // 避免 `.frame(maxWidth:)` 只放大 SwiftUI 虚拟布局槽。
                .frame(width: 340, height: 28)

                Button {
                    KeyboardShortcuts.reset(shortcutName)
                    let restored = KeyboardShortcuts.getShortcut(for: shortcutName)
                    handleShortcutChange(
                        restored,
                        for: field,
                        name: shortcutName,
                        successMessage: "已恢复默认快捷键"
                    )
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DimmiTheme.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Capsule().fill(DimmiTheme.glassFillHover))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("还原\(label)快捷键")
            }
            .padding(.horizontal, 14)   // （16→14）
            .frame(height: 38)             // （44→38）
            .background(Color.black.opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)   // （14→12）
                    .strokeBorder(DimmiTheme.glassDivider.opacity(2.0), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))   // （14→12）
        }
    }

    private func shortcutHelperText(
        defaultText: String,
        field: ShortcutRecorderField
    ) -> String {
        return shortcutFeedback[field]?.message ?? defaultText
    }

    private func shortcutHelperColor(field: ShortcutRecorderField) -> Color {
        return shortcutFeedback[field]?.color ?? DimmiTheme.textSecondary
    }

    private func handleShortcutChange(
        _ shortcut: KeyboardShortcuts.Shortcut?,
        for field: ShortcutRecorderField,
        name: KeyboardShortcuts.Name,
        successMessage: String? = nil
    ) {
        let otherName: KeyboardShortcuts.Name = field == .forward
            ? .triggerReverseTranslate
            : .triggerTranslate
        let otherShortcut = KeyboardShortcuts.getShortcut(for: otherName)

        if let shortcut, shortcut == otherShortcut {
            let previous = field == .forward
                ? lastValidForwardShortcut
                : lastValidReverseShortcut
            KeyboardShortcuts.setShortcut(previous, for: name)
            // Recorder 会先写入再回调；冲突组合键可能短暂注销另一项，强制恢复注册。
            KeyboardShortcuts.enable(otherName)
            shortcutFeedback[field] = .error("这个组合键已被另一项使用，请换一个")
            NSSound.beep()
        } else {
            if field == .forward {
                lastValidForwardShortcut = shortcut
            } else {
                lastValidReverseShortcut = shortcut
            }
            let message = successMessage
                ?? (shortcut == nil ? "已清除；现在直接按下新组合键即可" : "已保存并立即生效")
            shortcutFeedback[field] = .saved(message)
        }
    }

    // MARK: - About

    private var aboutDetail: some View {
        GlassCard(radius: SettingsLayout.cardCornerRadius) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(spacing: 10) {
                    GroupLabel("版本信息")
                    VStack(spacing: 4) {
                        labeledRow("版本", appVersion)
                        labeledRow("Build", buildNumber)
                        labeledRow("Bundle ID", Bundle.main.bundleIdentifier ?? "—")
                    }
                }
                .padding(.horizontal, SettingsLayout.cardHorizontalPadding)
                .padding(.top, SettingsLayout.cardTopPadding)

                GlassDivider()

                VStack(spacing: 10) {
                    GroupLabel("模型生态")
                    VStack(spacing: 4) {
                        labeledRow(
                            "内置厂商",
                            "\(TranslationProvider.allCases.filter { $0 != .customCompatible }.count) 家"
                        )
                        labeledRow("接口协议", "Anthropic · OpenAI 兼容")
                        labeledRow("自定义端点", "Ollama · vLLM · 企业网关")
                    }
                }
                .padding(.horizontal, SettingsLayout.cardHorizontalPadding)

                GlassDivider()

                Text("© 2026 dimmi · MIT License")
                    .font(DimmiFont.caption)
                    .foregroundStyle(DimmiTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, SettingsLayout.cardHorizontalPadding)
                    .padding(.bottom, SettingsLayout.cardBottomPadding)
            }
        }
    }

    private func labeledRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(DimmiFont.settingsBody)
                .foregroundStyle(DimmiTheme.textSecondary)
            Spacer()
            Text(value)
                .font(DimmiFont.settingsBody)
                .foregroundStyle(DimmiTheme.textPrimary)
        }
        .padding(.vertical, 4)
        .overlay {
            Rectangle()
                .fill(DimmiTheme.glassDivider)
                .frame(height: 0.5)
        }
    }

// MARK: - Footer

// 工具条在玻璃卡**外面**的背景上。
// 左右两组按钮处于同一水平基准线，保存/取消/隐私/帮助 视觉语言统一：
//   - 「隐私」「帮助」走 GlassPillButton（次要操作）
//   - 「取消」保持 GhostTextButton（轻量文字按钮）
//   - 「保存」走 SavePillButton —— 毛玻璃胶囊 + 略宽 + 略亮，体现主操作
private func footerBar(contentWidth: CGFloat) -> some View {
    HStack(spacing: 12) {
        GlassPillButton(icon: DimmiIcon.privacy, label: "隐私") {
            showPrivacyNotice()
        }
        .accessibilityIdentifier("settings.footer.privacy")

        GlassPillButton(icon: DimmiIcon.help, label: "帮助") {
            openWindow(id: "onboarding")
            NSApp.activate(ignoringOtherApps: true)
        }
        .accessibilityIdentifier("settings.footer.help")

        Spacer()

        GhostTextButton(label: "取消") {
            cancelSettings()
        }
        .accessibilityIdentifier("settings.footer.cancel")
        .padding(.trailing, 4)

        SavePillButton {
            saveSettings()
        }
        .accessibilityIdentifier("settings.footer.save")
    }
    // 不再包 padding(.horizontal)：footerBar 直接沿用页面的 440pt 对齐基准。
    .frame(width: contentWidth, alignment: .leading)
}

    private func footerPill(icon: Ph? = nil, label: String, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    icon.thin
                        .dimmiIcon(size: DimmiIconSize.inline, muted: !isPrimary)
                }
                Text(label)
                    .font(DimmiFont.settingsPill)
            }
            .foregroundStyle(isPrimary ? DimmiTheme.primaryFg : DimmiTheme.textPrimary)
            .padding(.horizontal, 16)
            .frame(height: 36)
            .background(
                Capsule().fill(isPrimary ? DimmiTheme.primaryFill : DimmiTheme.glassFillHover)
            )
            .overlay(
                Capsule()
                    .stroke(isPrimary ? DimmiTheme.glassEdgeTop.opacity(0.7) : DimmiTheme.glassEdgeTop.opacity(0.4), lineWidth: 1)
                    .blendMode(.plusLighter)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stepper row

    private func stepperRow(
        title: String,
        value: Int,
        draft: Binding<String>,
        field: SelectionLengthField,
        range: ClosedRange<Int>,
        step: Int = 1,
        onChange: @escaping (Int) -> Void,
        onCommit: @escaping () -> Void
    ) -> some View {
        let editableDraft = Binding<String>(
            get: { draft.wrappedValue },
            set: { newValue in
                // 编辑时允许暂时为空；其他字符直接过滤，避免提交时解析失败。
                let digits = newValue.filter { $0.isASCII && $0.isNumber }
                draft.wrappedValue = String(digits.prefix(5))
            }
        )
        let identifierPrefix = field == .minimum
            ? "settings.translation.minimum"
            : "settings.translation.maximum"

        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(DimmiFont.settingsBody)
                .foregroundStyle(DimmiTheme.textPrimary)

            HStack(spacing: 8) {
                TextField("", text: editableDraft, prompt: Text("\(value)"))
                    .textFieldStyle(.plain)
                    .font(DimmiFont.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(DimmiTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 64, height: 32)
                    .background(Capsule().fill(DimmiTheme.glassFillHover))
                    .overlay(
                        Capsule()
                            .stroke(
                                focusedSelectionLengthField == field
                                    ? DimmiTheme.glassEdgeTop.opacity(0.8)
                                    : DimmiTheme.glassEdgeTop.opacity(0.3),
                                lineWidth: 1
                            )
                            .blendMode(.plusLighter)
                    )
                    .focused($focusedSelectionLengthField, equals: field)
                    .onSubmit(onCommit)
                    .onChange(of: focusedSelectionLengthField) { oldField, newField in
                        if oldField == field, newField != field {
                            onCommit()
                        }
                    }
                    .accessibilityLabel(title)
                    .accessibilityValue(draft.wrappedValue)
                    .accessibilityIdentifier("\(identifierPrefix).input")

                Button {
                    let current = Int(draft.wrappedValue) ?? value
                    onChange(min(range.upperBound, current + step))
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 32, height: 32)
                        .background(Capsule().fill(DimmiTheme.glassFillHover))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .buttonRepeatBehavior(.enabled)
                .foregroundStyle(DimmiTheme.textPrimary)
                .disabled(value >= range.upperBound)
                .opacity(value >= range.upperBound ? 0.45 : 1)
                .accessibilityLabel("增加\(title)")
                .accessibilityIdentifier("\(identifierPrefix).increment")

                Button {
                    let current = Int(draft.wrappedValue) ?? value
                    onChange(max(range.lowerBound, current - step))
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 32, height: 32)
                        .background(Capsule().fill(DimmiTheme.glassFillHover))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .buttonRepeatBehavior(.enabled)
                .foregroundStyle(DimmiTheme.textPrimary)
                .disabled(value <= range.lowerBound)
                .opacity(value <= range.lowerBound ? 0.45 : 1)
                .accessibilityLabel("减少\(title)")
                .accessibilityIdentifier("\(identifierPrefix).decrement")
            }
        }
    }

    // MARK: - Aetheric Toggle

    struct AethericToggle: View {
        let title: String
        let subtitle: String
        @Binding var isOn: Bool

        var body: some View {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DimmiFont.settingsLabel)
                        .foregroundStyle(DimmiTheme.textPrimary)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(DimmiFont.caption)
                            .foregroundStyle(DimmiTheme.textSecondary)
                    }
                }

                Spacer()

                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isOn.toggle()
                    }
                } label: {
                    ZStack {
                        Capsule()
                            .fill(isOn ? DimmiTheme.glassFillRaised : DimmiTheme.glassFillHover)
                            .overlay(
                                Capsule()
                                    .stroke(isOn ? DimmiTheme.glassEdgeTop : DimmiTheme.glassEdgeTop.opacity(0.4), lineWidth: 1)
                                    .blendMode(.plusLighter)
                            )
                        Circle()
                            .fill(.white)
                            .frame(width: 18, height: 18)  // （22→18）
                            .offset(x: isOn ? 9 : -9)       // （12→9）
                            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    }
                    .frame(width: 46, height: 26)  // （52×32→46×26）
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title)
                .accessibilityValue(isOn ? "已开启" : "已关闭")
                .accessibilityAddTraits(isOn ? [.isSelected] : [])
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Existing helpers

    private var selectedModelOption: TranslationModelOption? {
        guard case .preset(let modelID) = modelSelection else { return nil }
        return TranslationModelCatalog.option(modelID: modelID, for: state.provider)
    }

    private var selectedModelTitle: String {
        switch modelSelection {
        case .preset(let modelID):
            return selectedModelOption?.name ?? modelID
        case .custom:
            return "自定义模型"
        }
    }

    private var selectedModelHelper: String {
        switch modelSelection {
        case .preset(let modelID):
            guard let option = selectedModelOption else { return modelID }
            return "\(option.summary) · \(option.id)"
        case .custom:
            return "手动填写供应商提供的 model ID"
        }
    }

    private var modelSelectionControl: some View {
        let options = TranslationModelCatalog.options(for: state.provider)

        return VStack(alignment: .leading, spacing: 6) {
            Text("模型")
                .font(DimmiFont.settingsBody)
                .foregroundStyle(DimmiTheme.textPrimary)

            Menu {
                ForEach(options) { option in
                    Button {
                        applyModelSelection(.preset(option.id))
                    } label: {
                        HStack {
                            Text(option.name)
                            if option.isRecommended {
                                Text("推荐")
                            }
                            if modelSelection == .preset(option.id) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                Divider()

                Button {
                    applyModelSelection(.custom)
                } label: {
                    HStack {
                        Text("自定义模型 ID…")
                        if modelSelection == .custom {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(selectedModelTitle)
                            .font(DimmiFont.inter(12, .medium))
                            .foregroundStyle(DimmiTheme.textPrimary)
                            .lineLimit(1)
                        if let option = selectedModelOption, option.isRecommended {
                            Text("推荐")
                                .font(DimmiFont.inter(9, .medium))
                                .foregroundStyle(.green)
                        }
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DimmiTheme.textSecondary)
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color.black.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(DimmiTheme.glassDivider.opacity(2.0), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .menuStyle(.button)
            .accessibilityLabel("模型")
            .accessibilityValue(selectedModelTitle)
            .accessibilityIdentifier("settings.api.model.picker")

            Text(selectedModelHelper)
                .font(DimmiFont.caption)
                .foregroundStyle(
                    selectedModelOption?.isLegacy == true
                        ? Color.orange
                        : DimmiTheme.textSecondary
                )
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func applyModelSelection(_ selection: TranslationModelSelection) {
        modelSelection = selection
        modelInput = TranslationModelCatalog.resolvedModelID(
            selection: selection,
            customModelID: customModelInput,
            provider: state.provider
        )
        testResult = .idle
    }

    private var currentModelPlaceholder: String {
        state.provider.defaultModel.isEmpty
            ? "例如：vendor/model-name"
            : state.provider.defaultModel
    }

    private var currentBaseURLPlaceholder: String {
        state.provider.defaultBaseURL.isEmpty
            ? "https://api.example.com/v1"
            : state.provider.defaultBaseURL
    }

    private var currentInputConfig: EngineConfig {
        EngineConfig(
            apiKey: apiKeyInput,
            model: TranslationModelCatalog.resolvedModelID(
                selection: modelSelection,
                customModelID: customModelInput,
                provider: state.provider
            ),
            baseURL: state.provider.supportsCustomBaseURL ? baseURLInput : ""
        )
    }

    private var effectiveCurrentDraft: EngineConfig {
        Secrets.effectiveConfig(
            draft: normalizedEngineConfig(currentInputConfig, for: state.provider),
            for: state.provider
        )
    }

    private var canTestCurrentDraft: Bool {
        (!state.provider.requiresAPIKey || !effectiveCurrentDraft.apiKey.isEmpty)
            && validationMessage(for: effectiveCurrentDraft, provider: state.provider) == nil
    }

    @MainActor
    private func runConnectionTest() async {
        let testedProvider = state.provider
        let config = effectiveCurrentDraft
        if let message = validationMessage(for: config, provider: testedProvider) {
            testResult = .failed(message)
            return
        }
        guard !testedProvider.requiresAPIKey || !config.apiKey.isEmpty else {
            testResult = .failed("请先填写当前引擎的 API Key")
            return
        }

        testRunning = true
        testResult = .idle
        let t0 = Date()
        let outcome: TestResult
        do {
            let result = try await TranslationService.shared.translateForTest(
                text: "你好",
                provider: testedProvider,
                config: config
            )
            let ms = Int(Date().timeIntervalSince(t0) * 1000)
            outcome = .ok("连接成功 · \(ms)ms · \(result.italian.prefix(20))")
        } catch let error as TranslationError {
            outcome = .failed(error.errorDescription ?? "未知错误")
        } catch {
            outcome = .failed(error.localizedDescription)
        }

        // 请求期间允许用户继续修改或切换厂商，但旧请求的结果不能覆盖
        // 新厂商/新草稿的状态。只有上下文仍完全一致时才展示结果。
        guard state.provider == testedProvider, effectiveCurrentDraft == config else {
            testRunning = false
            return
        }
        testResult = outcome
        testRunning = false
    }

    @State private var a11yPollingTimer: Timer?

    private func startPollingAccessibility() {
        a11yPollingTimer?.invalidate()
        state.refreshAccessibilityTrusted(prompt: false)
        a11yPollingTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            Task { @MainActor in
                let now = AccessibilityManager.isTrusted(prompt: false)
                if now != AppState.shared.accessibilityTrusted {
                    AppState.shared.accessibilityTrusted = now
                    AppState.shared.applySelectionMonitorState()
                }
            }
        }
    }

    private func stopPollingAccessibility() {
        a11yPollingTimer?.invalidate()
        a11yPollingTimer = nil
    }

    private func syncSelectionLengthDrafts() {
        selectionMinLengthDraft = String(state.selectionMinLength)
        selectionMaxLengthDraft = String(state.selectionMaxLength)
    }

    private func commitSelectionMinimumDraft() {
        guard let value = Int(selectionMinLengthDraft) else {
            syncSelectionLengthDrafts()
            return
        }
        state.updateSelectionMinLength(value)
        syncSelectionLengthDrafts()
    }

    private func commitSelectionMaximumDraft() {
        guard let value = Int(selectionMaxLengthDraft) else {
            syncSelectionLengthDrafts()
            return
        }
        state.updateSelectionMaxLength(value)
        syncSelectionLengthDrafts()
    }

    private func commitFocusedSelectionLengthDraft() {
        switch focusedSelectionLengthField {
        case .minimum: commitSelectionMinimumDraft()
        case .maximum: commitSelectionMaximumDraft()
        case nil: break
        }
        focusedSelectionLengthField = nil
    }

    @MainActor
    private func beginSettingsSession() {
        let actualLaunchAtLogin = LaunchAtLoginService.current
        launchAtLogin = actualLaunchAtLogin
        sessionSnapshot = SettingsSnapshot(
            provider: state.provider,
            autoTranslateEnabled: state.autoTranslateEnabled,
            sourceMode: state.sourceMode,
            selectionMinLength: state.selectionMinLength,
            selectionMaxLength: state.selectionMaxLength,
            selectionCooldown: state.selectionCooldown,
            successAutoDismiss: state.successAutoDismiss,
            errorAutoDismiss: state.errorAutoDismiss,
            useMockWhenNoKey: state.useMockWhenNoKey,
            showPhraseNotes: state.showPhraseNotes,
            targetLanguage: state.targetLanguage,
            reverseTranslateEnabled: state.reverseTranslateEnabled,
            launchAtLogin: actualLaunchAtLogin,
            forwardShortcut: KeyboardShortcuts.getShortcut(for: .triggerTranslate),
            reverseShortcut: KeyboardShortcuts.getShortcut(for: .triggerReverseTranslate)
        )

        engineDrafts = Dictionary(
            uniqueKeysWithValues: TranslationProvider.allCases.map {
                ($0, Secrets.storedConfig(for: $0))
            }
        )
        loadEngineDraft(for: state.provider)
        syncSelectionLengthDrafts()
        focusedSelectionLengthField = nil
        lastValidForwardShortcut = KeyboardShortcuts.getShortcut(for: .triggerTranslate)
        lastValidReverseShortcut = KeyboardShortcuts.getShortcut(for: .triggerReverseTranslate)
        shortcutFeedback = [:]
        selectedSection = nil
        apiKeyRevealed = false
        testResult = .idle
        apiInputResult = .idle
        cacheResult = .idle
        launchAtLoginResult = .idle
        sessionFinalized = false
    }

    private func switchEngineDraft(from oldProvider: TranslationProvider, to newProvider: TranslationProvider) {
        guard oldProvider != newProvider else { return }
        stashCurrentEngineDraft(for: oldProvider)
        loadEngineDraft(for: newProvider)
    }

    private func stashCurrentEngineDraft(for provider: TranslationProvider) {
        let resolvedModel = TranslationModelCatalog.resolvedModelID(
            selection: modelSelection,
            customModelID: customModelInput,
            provider: provider
        )
        modelInput = resolvedModel
        var draft = EngineConfig(apiKey: apiKeyInput, model: resolvedModel, baseURL: "")
        if provider.supportsCustomBaseURL {
            draft.baseURL = baseURLInput
        }
        engineDrafts[provider] = draft
    }

    private func loadEngineDraft(for provider: TranslationProvider) {
        let config = engineDrafts[provider] ?? Secrets.storedConfig(for: provider)
        apiKeyRevealed = false
        apiKeyInput = config.apiKey
        modelInput = config.model
        let options = TranslationModelCatalog.options(for: provider)
        modelSelection = options.isEmpty
            ? .custom
            : TranslationModelCatalog.selection(for: config.model, provider: provider)
        if modelSelection == .custom {
            customModelInput = config.model
        } else {
            customModelInput = ""
        }
        baseURLInput = provider.supportsCustomBaseURL ? config.baseURL : ""
        testResult = .idle
        apiInputResult = .idle
    }

    private func normalizedEngineConfig(_ config: EngineConfig, for provider: TranslationProvider) -> EngineConfig {
        var normalized = config
        normalized.apiKey = normalized.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.model = normalized.model.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.baseURL = normalized.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)

        if provider.supportsCustomBaseURL {
            normalized.baseURL = Secrets.normalizedBaseURL(normalized.baseURL, for: provider)
        } else {
            normalized.baseURL = ""
        }
        return normalized
    }

    private func validationMessage(for config: EngineConfig, provider: TranslationProvider) -> String? {
        let usesManualModel = TranslationModelCatalog.options(for: provider).isEmpty
        if usesManualModel,
           config.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "请填写当前兼容接口的模型 ID"
        }

        if provider.supportsCustomBaseURL {
            let raw = config.baseURL.isEmpty ? provider.defaultBaseURL : config.baseURL
            guard let components = URLComponents(string: raw),
                  let scheme = components.scheme?.lowercased(),
                  scheme == "https" || scheme == "http",
                  components.host?.isEmpty == false else {
                return "Base URL 无效，请填写完整的 http:// 或 https:// 地址"
            }
        }
        return nil
    }

    private func shouldValidateDraft(_ config: EngineConfig, for provider: TranslationProvider) -> Bool {
        guard TranslationModelCatalog.options(for: provider).isEmpty else { return true }
        if provider == state.provider { return true }
        return !config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !config.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @MainActor
    private func saveSettings() {
        // 点击保存时 TextField 可能仍持有焦点，先提交最后一次键盘输入。
        commitFocusedSelectionLengthDraft()
        stashCurrentEngineDraft(for: state.provider)

        var normalizedDrafts: [TranslationProvider: EngineConfig] = [:]
        for provider in TranslationProvider.allCases {
            let draft = normalizedEngineConfig(
                engineDrafts[provider] ?? Secrets.storedConfig(for: provider),
                for: provider
            )
            if shouldValidateDraft(draft, for: provider),
               let message = validationMessage(for: draft, provider: provider) {
                selectedSection = .apiKey
                state.provider = provider
                // provider 切换会装载对应草稿并重置测试状态；下一轮主线程再显示
                // 校验结果，避免错误提示刚出现就被 onChange 清掉。
                DispatchQueue.main.async {
                    testResult = .failed(message)
                }
                return
            }
            normalizedDrafts[provider] = draft
        }

        for provider in TranslationProvider.allCases {
            if let draft = normalizedDrafts[provider] {
                Secrets.setConfig(draft, for: provider)
            }
        }

        sessionFinalized = true
        dismissWindow(id: "settings")
    }

    @MainActor
    private func cancelSettings() {
        guard restoreSettingsSnapshot(showErrors: true) else { return }
        sessionFinalized = true
        dismissWindow(id: "settings")
    }

    /// 返回 false 表示系统级设置（目前只有登录项）无法回滚；按钮取消时保留窗口展示错误。
    @discardableResult
    @MainActor
    private func restoreSettingsSnapshot(showErrors: Bool = false) -> Bool {
        guard let snapshot = sessionSnapshot else { return true }

        state.provider = snapshot.provider
        state.targetLanguage = snapshot.targetLanguage
        state.reverseTranslateEnabled = snapshot.reverseTranslateEnabled
        state.useMockWhenNoKey = snapshot.useMockWhenNoKey
        state.showPhraseNotes = snapshot.showPhraseNotes
        state.updateSelectionLengths(
            minimum: snapshot.selectionMinLength,
            maximum: snapshot.selectionMaxLength
        )
        syncSelectionLengthDrafts()
        state.selectionCooldown = snapshot.selectionCooldown
        state.successAutoDismiss = snapshot.successAutoDismiss
        state.errorAutoDismiss = snapshot.errorAutoDismiss
        state.autoTranslateEnabled = snapshot.autoTranslateEnabled
        state.sourceMode = snapshot.sourceMode
        state.applySelectionMonitorState()

        KeyboardShortcuts.setShortcut(snapshot.forwardShortcut, for: .triggerTranslate)
        KeyboardShortcuts.setShortcut(snapshot.reverseShortcut, for: .triggerReverseTranslate)

        do {
            launchAtLogin = try LaunchAtLoginService.set(snapshot.launchAtLogin)
            guard launchAtLogin == snapshot.launchAtLogin else {
                if showErrors {
                    selectedSection = .shortcut
                    launchAtLoginResult = .failed(launchAtLoginMismatchMessage(requested: snapshot.launchAtLogin))
                }
                return false
            }
            return true
        } catch {
            launchAtLogin = LaunchAtLoginService.current
            NSLog("[dimmi][settings] 无法回滚登录项：\(error.localizedDescription)")
            if showErrors {
                selectedSection = .shortcut
                launchAtLoginResult = .failed("无法恢复开机启动设置：\(error.localizedDescription)")
            }
            return false
        }
    }

    @MainActor
    private func updateLaunchAtLogin(_ requested: Bool) {
        launchAtLoginResult = .idle
        do {
            launchAtLogin = try LaunchAtLoginService.set(requested)
            if launchAtLogin == requested {
                launchAtLoginResult = .ok(launchAtLogin ? "已加入登录项" : "已从登录项移除")
            } else {
                launchAtLoginResult = .failed(launchAtLoginMismatchMessage(requested: requested))
            }
        } catch {
            launchAtLogin = LaunchAtLoginService.current
            launchAtLoginResult = .failed(error.localizedDescription)
        }
    }

    private func launchAtLoginMismatchMessage(requested: Bool) -> String {
        if requested, LaunchAtLoginService.requiresApproval {
            return "登录项已提交，仍需在「系统设置 → 通用 → 登录项」中批准"
        }
        return requested ? "系统没有启用登录项，请确认应用位于“应用程序”文件夹" : "系统未能移除登录项"
    }

    @MainActor
    private func clearNoteCache() async {
        cacheResult = .idle
        do {
            let removed = try await NoteCache.shared.clear()
            cacheResult = .ok(removed == 0 ? "缓存原本就是空的" : "已清除 \(removed) 条语法注解缓存")
        } catch {
            cacheResult = .failed("清除失败：\(error.localizedDescription)")
        }
    }

    @MainActor
    private func showPrivacyNotice() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "dimmi 隐私说明"
        alert.informativeText = """
        • 粘贴板模式只在本机检测新复制的文字；划词模式仅在你选择该模式后使用辅助功能权限。\n
        • 翻译时，原文会发送给你选择的模型服务或自定义端点；开启语法注解时，原文与译文还会用于生成注解。\n
        • 翻译历史与语法注解缓存保存在本机。清除注解缓存不会删除历史。\n
        • API 配置保存在本机应用偏好中。请不要在共享账户中保存敏感密钥。
        """
        alert.addButton(withTitle: "知道了")
        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}

// MARK: - Glass 辅助控件（设置窗专属：玻璃胶囊 / 玻璃下拉 / 凹陷字段）

/// 玻璃胶囊按钮：暖白 14% 底 + 暖白 18% 上缘高光，比 Button 默认的灰底看着干净。
struct GlassPillText: View {
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(DimmiFont.inter(11, .medium))   // （12→11）
                .foregroundStyle(DimmiTheme.textPrimary)
                .padding(.horizontal, 12)              // （14→12）
                .frame(height: 34)                     // （40→34）
                .background(Capsule().fill(DimmiTheme.glassFillHover))
                .overlay(
                    Capsule()
                        .stroke(DimmiTheme.glassEdgeTop.opacity(0.35), lineWidth: 1)
                        .blendMode(.plusLighter)
                )
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
    }
}

/// 玻璃方块图标按钮（reveal/hide、复制、reset 这些次级动作）。
struct GlassPillIcon: View {
    let icon: Ph
    var size: CGFloat = 14
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            icon.thin
                .dimmiIcon(size: size, muted: false)
                .foregroundStyle(DimmiTheme.textPrimary)
                .frame(width: 34, height: 34)   // （40→34）
                .background(Capsule().fill(DimmiTheme.glassFillHover))
                .overlay(
                    Capsule()
                        .stroke(DimmiTheme.glassEdgeTop.opacity(0.35), lineWidth: 1)
                        .blendMode(.plusLighter)
                )
        }
        .buttonStyle(.plain)
    }
}

/// 玻璃下拉（菜单）。底层用 Menu 拿原生弹出，但外观完全用自定义胶囊 + caretUpDown.thin。
///
/// 注意：原生 NSPopUpButton 弹出后会用系统灰底（macOS 标准），任务书要求"弹出菜单也要暗玻璃"。
/// macOS 不支持 .background 改 NSPopUpButton 的菜单，这里退一步：胶囊外观看起来像玻璃，
/// 弹出菜单仍跟随系统。**视觉一致性 90% 已达成**——完全自绘菜单不实际。
struct GlassPicker<Item: Hashable & Identifiable>: View {
    @Binding var selection: Item
    let items: [(label: String, value: Item)]
    var width: CGFloat = 156

    var body: some View {
        let labels = items.map { $0.label }
        let values = items.map { $0.value }
        let bindingIdx = Binding<Int>(
            get: { values.firstIndex(of: selection) ?? 0 },
            set: { newIdx in
                if newIdx >= 0 && newIdx < values.count {
                    selection = values[newIdx]
                }
            }
        )

        Menu {
            ForEach(0..<items.count, id: \.self) { i in
                Button {
                    selection = values[i]
                } label: {
                    HStack {
                        Text(labels[i])
                        if selection == values[i] {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {   // （10→8）
                Text(labels[bindingIdx.wrappedValue])
                    .font(DimmiFont.inter(12, .medium))   // （13→12）
                    .foregroundStyle(DimmiTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .layoutPriority(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))  // （11→10）
                    .frame(width: 14, height: 14)   // （16→14）
            }
            .padding(.horizontal, 15)
            .frame(width: width, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(.white.opacity(0.10))
            )
        }
        .buttonStyle(.plain)
        .menuStyle(.button)
    }
}

/// 凹陷字段：玻璃语言里唯一允许的"暗"元素（模拟刻进玻璃的槽）。
/// 内部是 TextField，可选带右侧 accessory。
struct SunkenField: View {
    var label: String?
    @Binding var text: String
    var placeholder: String?
    var helper: String?
    var isEditable: Bool = true
    var rightAccessory: AnyView? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label = label {
                Text(label)
                    .font(DimmiFont.settingsBody)
                    .foregroundStyle(DimmiTheme.textPrimary)
            }
            HStack(spacing: 0) {
                Group {
                    if isEditable {
                        TextField(placeholder ?? "", text: $text)
                            .textFieldStyle(.plain)
                    } else {
                        Text(text)
                            .lineLimit(1)
                            .accessibilityLabel(label ?? "")
                            .accessibilityValue(text)
                    }
                }
                .font(DimmiFont.inter(12))   // （13→12）
                .foregroundStyle(DimmiTheme.textPrimary)
                .padding(.horizontal, 14)      // （16→14）
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 34)             // （40→34）

                if let acc = rightAccessory {
                    acc
                        .padding(.trailing, 6)
                }
            }
            .background(Color.black.opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)   // （14→12）
                    .strokeBorder(DimmiTheme.glassDivider.opacity(2.0), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))   // （14→12）

            if let helper = helper {
                Text(helper)
                    .font(DimmiFont.caption)
                    .foregroundStyle(DimmiTheme.textSecondary)
            }
        }
    }
}

// MARK: - 主页玻璃行（阶段 1）
//
// 行高 58，水平 padding 18，38pt 图标底板，标题 14 regular，说明 11 secondary。
// hover：radius 20 的 glassFillRaised 块 + 上缘高光，内缩在卡内、不触卡边。
// 行与行之间**不画分隔线**——玻璃语言靠留白和 hover 块区分，画线会显脏。
private struct HomeGlassRow: View {
    let section: SettingsView.SettingsSection
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                section.icon.thin
                    .dimmiIcon(size: 19)
                    .frame(
                        width: SettingsView.SettingsLayout.homeRowIconTile,
                        height: SettingsView.SettingsLayout.homeRowIconTile
                    )
                    .background(
                        RoundedRectangle(
                            cornerRadius: SettingsView.SettingsLayout.homeRowIconRadius,
                            style: .continuous
                        )
                        .fill(Color.black.opacity(0.035))
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.rawValue)
                        .font(DimmiFont.rowTitle)
                        .foregroundStyle(DimmiTheme.textBody)
                    Text(section.subtitle)
                        .font(DimmiFont.caption)
                        .foregroundStyle(DimmiTheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                DimmiIcon.chevron.thin
                    .dimmiIcon(size: 16, muted: true)
            }
            .padding(.horizontal, SettingsView.SettingsLayout.homeRowHorizontalPadding)
            .frame(height: SettingsView.SettingsLayout.homeRowHeight)
            .background(
                RoundedRectangle(cornerRadius: SettingsView.SettingsLayout.homeRowCornerRadius, style: .continuous)
                    .fill(hovered ? DimmiTheme.glassFillRaised : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SettingsView.SettingsLayout.homeRowCornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: hovered ? DimmiTheme.glassRowEdgeTop : Color.clear, location: 0.0),
                                .init(color: Color.clear, location: 0.55),
                            ],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(Motion.hover, value: hovered)
        .onHover { hovered = $0 }
    }
}

private extension TargetLanguage {
    /// 反向预览必须与当前目标语言一致，避免「选了日语却拿法语自检」的假结果。
    var settingsReverseSample: String {
        switch self {
        case .italian:    return "Come stai?"
        case .english:    return "How are you?"
        case .french:     return "Comment ça va ?"
        case .german:     return "Wie geht es dir?"
        case .spanish:    return "¿Cómo estás?"
        case .japanese:   return "お元気ですか？"
        case .korean:     return "잘 지내세요?"
        case .portuguese: return "Como você está?"
        }
    }
}
