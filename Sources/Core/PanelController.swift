// 翻译浮层控制器（完全重写版）：
//
// 设计原则（任务书第一/三/四/五/六/七节）：
//   - NSPanel 创建后 = 固定 340×560，永不 resize
//   - 卡片常驻 SwiftUI 树，外壳不重建；loading ↔ content 用 opacity 切换
//   - 玻璃材质层永不参与动画；用 .transaction { $0.disablesAnimations = true } 包裹
//   - 卡片外区域点击穿透到下层 App
//   - 顶边对齐 anchor（鼠标点 + 偏移），不变
//   - 状态机：.loading → .revealing → .idle / .failed
//   - 动画只用 withAnimation 包裹；脚本定长（preStartDelay → totalDuration）
//
// 公开 API 保持兼容：
//   - presentLoading(for sourceText:at:)      → 立刻进入 .loading
//   - triggerTranslation(for sourceText:at:)  → 立刻进入 .loading + 启动翻译任务
//   - presentWithMock(for sourceText:at:)     → 进入 .loading，0.6s 后给 mock 结果
//   - updateResult(... sourceText:...)        → 进入 .revealing → .idle
//   - updateError(... sourceText:...)         → 进入 .failed
//   - dismiss()                               → 隐藏
//
// 阶段 9：注解（PhraseNote）
//   - 拿到译文后，并行发请求 B 拿注解
//   - 注解先返回 → viewModel 暂存；译文到了一起展开
//   - 注解失败 / 超时 / hasNote=false → 静默丢弃，绝不影响译文
//   - 新请求触发前 cancel 上一个 noteTask
import AppKit
import SwiftUI

@MainActor
final class PanelController: NSObject, ObservableObject {
    static let shared = PanelController()

    // MARK: - 对外状态（保持兼容）
    @Published private(set) var isShowing: Bool = false
    var currentSourceText: String = ""

    // MARK: - 自动关闭（由 AppState push 下来）
    private var successAutoDismiss: TimeInterval = 8.0
    private var errorAutoDismiss:   TimeInterval = 30.0

    // MARK: - 重复触发拦截
    private var activeSourceText: String = ""
    /// 阶段 10：当前正在展示的方向，用于决定"按 ⌘C 复制同一句"是否要再次触发
    /// （同句同方向 = 续命；同句但方向反了 = 重新走一遍反向翻译）。
    private var activeDirection: TranslationDirection = .forward

    /// 鼠标点击处相对卡片的偏移：右 +18，向下 -16（卡片顶对齐到 mouse.y + offset.y）
    private let cardOffsetFromCursor = NSPoint(x: 18, y: -16)

    /// 卡片演示文本（自检按钮用）
    static let demoText = "我今天有点累"

    // MARK: - Mock 数据池（与旧版一致）
    private static let mockPool: [String: TranslationResult] = [
        "我今天有点累": TranslationResult(
            italian: "Sono un po' stanco/a oggi.",
            colloquial: "Sono a pezzi oggi.",
            topic: Topic.emotions.rawValue,
            note: "stanco 用于男性，stanca 用于女性；a pezzi 是「累坏了」的口语。"
        ),
        "早上好": TranslationResult(
            italian: "Buongiorno.",
            colloquial: "Ciao! (熟人之间)",
            topic: Topic.greetings.rawValue,
            note: "意大利「早上好」会一直用到下午；Buonasera 才是「晚上好」。"
        ),
        "这杯咖啡多少钱？": TranslationResult(
            italian: "Quanto costa questo caffè?",
            colloquial: "Quant'è questo caffè?",
            topic: Topic.shopping.rawValue,
            note: "Quant'è 是Quanto costa的口语缩写，更地道。"
        ),
        "我们八点出发": TranslationResult(
            italian: "Partiamo alle otto.",
            colloquial: "Si parte alle otto.",
            topic: Topic.numbersTime.rawValue,
            note: "Si partire 用无人称时更自然，相当于英语「we leave at 8」。"
        ),
        "我头有点疼": TranslationResult(
            italian: "Ho un po' di mal di testa.",
            colloquial: "Mi fa male la testa.",
            topic: Topic.health.rawValue,
            note: "意大利语的「疼」常用具身动词 Mi fa male X，不需要复杂从句。"
        ),
        "周末一起吃饭吗？": TranslationResult(
            italian: "Mangiamo insieme nel fine settimana?",
            colloquial: "Mangiamo insieme nel weekend?",
            topic: Topic.social.rawValue,
            note: "周末口语直接用 weekend 也被接受，正式写作用 fine settimana。"
        ),
        "帮我订明天下午三点的高铁": TranslationResult(
            italian: "Mi prenoti un treno ad alta velocità per domani alle tre del pomeriggio?",
            colloquial: nil,
            topic: Topic.travel.rawValue,
            note: "意大利高铁叫 alta velocità，缩写是 Frecciarossa / Italo。"
        ),
        "请把文件发我邮箱": TranslationResult(
            italian: "Per favore, mandami il file via email.",
            colloquial: "Manda il file sulla mail.",
            topic: Topic.work.rawValue,
            note: "文件和文档意大利语都叫 file，发音「fei-le」。"
        ),
        "服务很棒": TranslationResult(
            italian: "Il servizio è stato eccellente.",
            colloquial: "Siete stati fantastici!",
            topic: Topic.emotions.rawValue,
            note: "对一群人夸，直接用 voi 过去时更地道。"
        ),
        "我买单": TranslationResult(
            italian: "Pago io.",
            colloquial: "Offro io.",
            topic: Topic.food.rawValue,
            note: "Offro io 更口语，意思是「我请客」。"
        )
    ]
    /// 阶段 10：反向 mock（targetLanguage → 中文），未配 key 时也能演示反向流程。
    private static func reverseMock(for text: String, target: TargetLanguage) -> TranslationResult {
        let t = text.lowercased()
        let topic: Topic = {
            if t.contains("buon") || t.contains("ciao") || t.contains("comment") || t.contains("hello")
                || t.contains("hola") || t.contains("guten") || t.contains("こんにちは") || t.contains("안녕") {
                return .greetings
            }
            if t.contains("mange") || t.contains("eat") || t.contains("come") || t.contains("食べ") {
                return .food
            }
            return .other
        }()
        let iso = target.isoCode
        let provider = AppState.shared.provider.rawValue
        let base: String = {
            switch iso {
            case "fr":  return "你好，最近怎么样？（法语反向 mock）"
            case "en":  return "你好。"
            case "de":  return "你好。（德语反向 mock）"
            case "es":  return "你好。（西语反向 mock）"
            case "ja":  return "你好。（日语反向 mock）"
            case "ko":  return "你好。（韩语反向 mock）"
            case "pt":  return "你好。（葡语反向 mock）"
            default:    return "你好。"
            }
        }()
        return TranslationResult(
            italian: "「\(text.prefix(30))」→ \(base)",
            colloquial: nil,
            topic: topic.rawValue,
            note: "这是反向 mock 示例：在「设置 → 翻译」里填 \(provider) Key 后会调用真实模型。"
        )
    }

    private static func pickMock(for text: String, target: TargetLanguage) -> TranslationResult {
        if target == .italian, let exact = mockPool[text] { return exact }

        if text == "我今天有点累" || text == "我今天很累" {
            let translated: String
            switch target {
            case .italian:    translated = "Sono un po' stanco/a oggi."
            case .english:    translated = "I'm a little tired today."
            case .french:     translated = "Je suis un peu fatigué(e) aujourd'hui."
            case .german:     translated = "Ich bin heute ein bisschen müde."
            case .spanish:    translated = "Hoy estoy un poco cansado/a."
            case .japanese:   translated = "今日は少し疲れています。"
            case .korean:     translated = "오늘은 조금 피곤해요."
            case .portuguese: translated = "Estou um pouco cansado/a hoje."
            }
            return TranslationResult(
                italian: translated,
                colloquial: nil,
                topic: Topic.emotions.rawValue,
                note: "这是 \(target.rawValue)的本地自检示例，不会写入历史或发起注解请求。"
            )
        }

        return TranslationResult(
            italian: "[\(target.nativeName) 示例] \(text.prefix(40))",
            colloquial: nil,
            topic: Topic.other.rawValue,
            note: "这是示例数据，请在「设置 → 翻译」里填 API Key 以获得真实翻译。"
        )
    }

    // MARK: - Panel + 桥接
    private let cardPanel = TranslationPanel(
        contentRect: NSRect(x: 0, y: 0,
                            width: PanelMetrics.panelWidth,
                            height: PanelMetrics.panelHeight),
        styleMask: [.nonactivatingPanel, .borderless],
        backing: .buffered, defer: false
    )
    private let viewModel = PanelViewModel()
    private let region = PanelCardHitRegion()
    private var hostingView: TranslationPanelHostingView?

    /// 顶部 Y 坐标锚点（task：loading 弹出瞬间锁定，后续 translate 不动）
    private var anchorTopY: CGFloat?

    /// 监听：用户点击卡片外 / 滑动 / 键盘
    private let dismissMonitor = PanelDismissMonitor()

    /// 翻译任务：用于取消上次未完任务，避免乱序回填
    private var currentTask: Task<Void, Never>?
    /// 本地 mock 预览也必须可取消，否则 0.6s 内又发起新请求时，
    /// 旧 asyncAfter 会把新卡片覆盖成旧示例。
    private var currentMockTask: Task<Void, Never>?
    /// 注解请求任务：用于取消上一个未完注解，避免译文是新词、注解是旧词
    private var currentNoteTask: Task<Void, Never>?

    private override init() {
        super.init()
        configure(cardPanel)
        wireUpHostingView()
        bootstrapViewModelCallbacks()
    }

    deinit { /* OS 会清理全局 monitor / Task @MainActor */ }

    // MARK: - 配置面板

    private func configure(_ panel: NSPanel) {
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false              // 任务书：阴影由 SwiftUI 卡片自己画
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        // appearance 必须留 nil = 跟随系统。
        // 写死 .darkAqua 会把浮窗里的 @Environment(\.colorScheme) 永久钉成 .dark，
        // 于是浅色系统下设置窗是白卡、浮窗却是深灰卡——两个窗不是一套配色。
        panel.appearance = nil
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        // 仅当可选文字等控件确实需要 first responder 时成为 key window，
        // 普通展示仍保持 nonactivating panel 的轻量行为。
        panel.becomesKeyOnlyIfNeeded = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
    }

    private func wireUpHostingView() {
        // 桥接：viewModel ↔ SwiftUI 视图 ↔ 原生 hitTest
        let rootView = TranslationPanelView(viewModel: viewModel, region: region)
            .environmentObject(viewModel)
        let anyView = AnyView(rootView)
        let host = TranslationPanelHostingView(region: region, rootView: anyView)
        host.frame = NSRect(x: 0, y: 0,
                            width: PanelMetrics.panelWidth,
                            height: PanelMetrics.panelHeight)
        cardPanel.contentView = host
        hostingView = host

        // Panel 内透明阴影边缘的点击不会进入 SwiftUI 子树，必须在原生窗口层关闭。
        cardPanel.onOutsideClick = { [weak self] in
            self?.dismiss()
        }
    }

    // MARK: - 公开入口

    /// DEBUG / 设置 → 自检：走 mock
    func presentWithMock(for sourceText: String, at screenPoint: NSPoint) {
        // 自检也应遵守用户设置的停留时长；否则总是退回初始化的 8 秒，视觉验收来不及完成。
        applyConfig()
        let target = AppState.shared.targetLanguage
        activeSourceText = sourceText
        activeDirection = .forward
        currentSourceText = sourceText
        currentTask?.cancel()
        currentTask = nil
        currentMockTask?.cancel()
        currentNoteTask?.cancel()
        presentLoading(for: sourceText, direction: .forward, target: target, at: screenPoint)
        currentMockTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: 600_000_000)
            } catch {
                return
            }
            guard let self, !Task.isCancelled,
                  self.activeSourceText == sourceText,
                  self.activeDirection == .forward else { return }
            let mock = Self.pickMock(for: sourceText, target: target)
            self.updateResult(mock, sourceText: sourceText, direction: .forward, target: target, fromMock: true)
            self.currentMockTask = nil
        }
    }

    /// 设置页反向翻译预览：纯本地 mock，不调 API、不写历史。
    func presentReverseWithMock(for sourceText: String, at screenPoint: NSPoint) {
        applyConfig()
        let target = AppState.shared.targetLanguage
        activeSourceText = sourceText
        activeDirection = .reverse
        currentSourceText = sourceText
        currentTask?.cancel()
        currentTask = nil
        currentMockTask?.cancel()
        currentNoteTask?.cancel()
        presentLoading(for: sourceText, direction: .reverse, target: target, at: screenPoint)
        currentMockTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: 600_000_000)
            } catch {
                return
            }
            guard let self, !Task.isCancelled,
                  self.activeSourceText == sourceText,
                  self.activeDirection == .reverse else { return }
            let mock = Self.reverseMock(for: sourceText, target: target)
            self.updateResult(mock, sourceText: sourceText, direction: .reverse, target: target, fromMock: true)
            self.currentMockTask = nil
        }
    }

    /// 主路径：进入 loading + 启动翻译任务（中文 → targetLanguage）
    func triggerTranslation(for sourceText: String, at screenPoint: NSPoint) {
        if isShowing, activeSourceText == sourceText, activeDirection == .forward {
            if case .failed = viewModel.phase {
                // 失败态下把同一句再复制一次 = 用户想重试 → 放行走正常翻译路径。
            } else {
                // 已经在展示这句 → 不重开，但视为"还在看"，给自动关闭续命
                bumpAutoDismiss()
                return
            }
        }
        activeSourceText = sourceText
        activeDirection = .forward
        currentSourceText = sourceText
        applyConfig()

        currentNoteTask?.cancel()
        currentMockTask?.cancel()
        currentMockTask = nil

        let target = AppState.shared.targetLanguage
        presentLoading(for: sourceText, direction: .forward, target: target, at: screenPoint)
        currentTask?.cancel()

        let provider = AppState.shared.provider
        let cfg = Secrets.config(for: provider)

        if provider.requiresAPIKey && cfg.apiKey.isEmpty && UserPrefs.useMockWhenNoKey {
            presentWithMock(for: sourceText, at: screenPoint)
            return
        }

        currentTask = Task { [weak self] in
            do {
                let result = try await TranslationService.shared.translate(text: sourceText)
                guard let self else { return }
                if Task.isCancelled { return }
                await MainActor.run {
                    self.updateResult(result, sourceText: sourceText, direction: .forward, target: target)
                }
            } catch is CancellationError {
                // 用户切到下一段了，正常丢弃
            } catch let error as TranslationError {
                await MainActor.run {
                    self?.updateError(error.errorDescription ?? "未知错误", sourceText: sourceText, direction: .forward, target: target)
                }
            } catch {
                await MainActor.run {
                    self?.updateError(error.localizedDescription, sourceText: sourceText, direction: .forward, target: target)
                }
            }
        }
    }

    /// 阶段 10：反向翻译入口（targetLanguage → 中文）。
    /// 由菜单栏「反向翻译…」按钮 / 全局 ⌘⇧B 触发。
    func triggerReverseTranslation(for sourceText: String, at screenPoint: NSPoint) {
        if isShowing, activeSourceText == sourceText, activeDirection == .reverse {
            if case .failed = viewModel.phase {
                // 允许失败态下重复 → 重试
            } else {
                bumpAutoDismiss()
                return
            }
        }
        activeSourceText = sourceText
        activeDirection = .reverse
        currentSourceText = sourceText
        applyConfig()

        currentNoteTask?.cancel()
        currentMockTask?.cancel()
        currentMockTask = nil

        let target = AppState.shared.targetLanguage
        presentLoading(for: sourceText, direction: .reverse, target: target, at: screenPoint)
        currentTask?.cancel()

        let provider = AppState.shared.provider
        let cfg = Secrets.config(for: provider)

        if provider.requiresAPIKey && cfg.apiKey.isEmpty && UserPrefs.useMockWhenNoKey {
            presentReverseWithMock(for: sourceText, at: screenPoint)
            return
        }

        currentTask = Task { [weak self] in
            do {
                let result = try await TranslationService.shared.reverseTranslate(text: sourceText)
                guard let self else { return }
                if Task.isCancelled { return }
                await MainActor.run {
                    self.updateResult(result, sourceText: sourceText, direction: .reverse, target: target)
                }
            } catch is CancellationError {
            } catch let error as TranslationError {
                await MainActor.run {
                    self?.updateError(error.errorDescription ?? "未知错误", sourceText: sourceText, direction: .reverse, target: target)
                }
            } catch {
                await MainActor.run {
                    self?.updateError(error.localizedDescription, sourceText: sourceText, direction: .reverse, target: target)
                }
            }
        }
    }

    /// 拿到译文后，并行请求 B 拿注解。
    /// 注解先到 → viewModel 暂存 pendingNote；后到 → 立即展开。
    /// 注解失败 / 超时 / hasNote=false → 静默。
    private func fetchNote(
        for sourceText: String,
        translatedText: String,
        target: TargetLanguage
    ) {
        // 用户在设置里关了注解 → 直接不发请求
        guard AppState.shared.showPhraseNotes else { return }
        currentNoteTask = Task { [weak self] in
            let note = await NoteService.shared.fetch(
                sourceText: sourceText,
                translatedText: translatedText,
                target: target
            )
            guard let self else { return }
            if Task.isCancelled { return }
            await MainActor.run {
                guard AppState.shared.showPhraseNotes else { return }
                self.viewModel.applyNote(note)
            }
        }
    }

    /// 进入 loading 态：把面板按锚点定位到屏幕某处
    func presentLoading(
        for sourceText: String,
        direction: TranslationDirection,
        target: TargetLanguage,
        at screenPoint: NSPoint
    ) {
        currentSourceText = sourceText
        // 任务书第七节：窗口顶边 = 卡片顶边 = screenPoint.y + cardOffsetFromCursor.y
        // 由于 NSPanel origin 在左下角，原点 Y = screenPoint.y + offset.y - panelHeight
        // 透明窗口按 PanelMetrics 最大高度预留；实际卡片仍由内容自然测高。
        let panelHeight = PanelMetrics.panelHeight
        let panelWidth = PanelMetrics.panelWidth
        // 窗口比卡片大一圈（bloomMargin），这里所有 x / yTop 都按**卡片**的边算，
        // 最后落到窗口原点时再把留白补偿回去；否则卡片会整体偏移一个 margin。
        let margin = PanelMetrics.bloomMargin
        let cardW = PanelMetrics.cardWidth
        // 屏外保护（x 方向）——按卡片宽度判断，留白是透明的不该参与
        var x = screenPoint.x + cardOffsetFromCursor.x
        var yTop = screenPoint.y + cardOffsetFromCursor.y
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(screenPoint) })
                ?? NSScreen.main {
            let frame = screen.visibleFrame
            // 顶端不能超过屏幕顶
            if yTop > frame.maxY - 24 { yTop = frame.maxY - 24 }
            // 底端不能超过屏幕底（按卡片封顶高算，别用整窗高）
            if yTop - PanelMetrics.cardMaxHeight < frame.minY {
                yTop = min(frame.minY + PanelMetrics.cardMaxHeight, frame.maxY - 24)
            }
            // x 方向
            if x + cardW > frame.maxX { x = frame.maxX - cardW - 8 }
            if x < frame.minX { x = frame.minX + 8 }
        }
        // NSPanel origin 在左下。卡片左边 = x，卡片顶边 = yTop，
        // 而卡片在窗口内缩进了 margin → 窗口要往左 / 往上各让出一个 margin。
        let origin = NSPoint(x: x - margin, y: yTop + margin - panelHeight)
        anchorTopY = yTop
        cardPanel.setFrame(NSRect(origin: origin, size: NSSize(width: panelWidth, height: panelHeight)),
                           display: false)
        cardPanel.orderFrontRegardless()

        viewModel.enterLoading(sourceText: sourceText, direction: direction, target: target)
        isShowing = true
        installOutsideDismissMonitors()
    }

    /// 翻译成功
    func updateResult(
        _ result: TranslationResult,
        sourceText: String,
        direction: TranslationDirection,
        target: TargetLanguage,
        fromMock: Bool = false
    ) {
        activeSourceText = sourceText
        activeDirection = direction
        currentSourceText = sourceText
        viewModel.enterRevealing(
            sourceText: sourceText,
            result: result,
            direction: direction,
            target: target,
            fromMock: fromMock
        )
        // mock 是自检 / 未配 key 的展示数据，不能污染用户真实历史。
        if !fromMock {
            HistoryStore.append(sourceText: sourceText, result: result, direction: direction, target: target)
        }
        viewModel.setMaxAutoDismiss(Int(successAutoDismiss))
        // 阶段 9：拿到译文后，并行发注解请求
        // 反向（? → 中文）暂时不开注解（注释策略针对正向学习场景），避免空跑。
        if direction == .forward, !fromMock {
            fetchNote(
                for: sourceText,
                translatedText: result.italian,
                target: target
            )
        }
    }

    /// 翻译失败
    func updateError(
        _ message: String,
        sourceText: String,
        direction: TranslationDirection,
        target: TargetLanguage
    ) {
        activeSourceText = sourceText
        activeDirection = direction
        currentSourceText = sourceText
        // enterFailed() 会当场启动倒计时，必须在它之前推入 error 时长。
        viewModel.setMaxAutoDismiss(Int(errorAutoDismiss))
        viewModel.enterFailed(sourceText: sourceText, message: message, direction: direction, target: target)
    }

    /// 主动或自动 dismiss
    func dismiss() {
        // 全局 monitor、本 App local monitor 和 Panel 自身可能在同一次点击里同时命中。
        // 保持关闭幂等，避免重复取消任务、重复回调和重复日志。
        guard isShowing || cardPanel.isVisible else { return }
        NSLog("[dimmi][panel] dismiss()")
        currentTask?.cancel()
        currentTask = nil
        currentMockTask?.cancel()
        currentMockTask = nil
        currentNoteTask?.cancel()
        currentNoteTask = nil
        // 防递归：dismiss() 会同步触发 viewModel.dismiss()，
        // viewModel.dismiss() 回调 onDismiss → 又回到本方法。
        // 切断循环：把 onDismiss 临时摘掉，走完 viewModel.dismiss() 再还原。
        let savedOnDismiss = viewModel.onDismiss
        viewModel.onDismiss = {}
        viewModel.dismiss()
        viewModel.onDismiss = savedOnDismiss

        cardPanel.orderOut(nil)
        isShowing = false
        activeSourceText = ""
        activeDirection = .forward
        anchorTopY = nil
        removeOutsideDismissMonitors()
    }

    /// 用户与卡片交互（鼠标进入 / 滚动），重置倒计时
    func bumpAutoDismiss() {
        viewModel.bumpAutoDismiss()
    }

    /// 从 AppState push 自动关闭参数
    func applyConfig() {
        let s = AppState.shared
        successAutoDismiss = s.successAutoDismiss
        errorAutoDismiss   = s.errorAutoDismiss
        viewModel.setMaxAutoDismiss(Int(successAutoDismiss))
    }

    // MARK: - 桥接 viewModel → PanelController 的回调
    /// SwiftUI 内部触发事件（按钮点击）通过这些 void 回到 controller。
    /// 它们的实现在 init/wire 阶段挂上去：
    private func bootstrapViewModelCallbacks() {
        // 单例 init 时挂一次
        viewModel.onCopy = { text in
            // 告诉剪贴板监听：接下来 2.5s 内出现的变化是 dimmi 自己写出去的，
            // 不要触发翻译。否则用户点「复制译文」会把刚写进去的译文当作新源文
            // → 重新翻译一次 → 当前 panel 被 dismiss 替换 → 视觉上像闪退。
            AppState.shared.clipboardMonitor.suppressNextChange()
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(text, forType: .string)
        }
        viewModel.onRetry = { [weak self] in
            guard let self else { return }
            let src = self.currentSourceText
            let pt = NSEvent.mouseLocation
            // 重试用当前 phase 的方向和目标（用户点重试时肯定想重试当前显示的内容）
            let dir = self.activeDirection
            let target = AppState.shared.targetLanguage
            self.presentLoading(for: src, direction: dir, target: target, at: pt)
            // 重试走和 triggerTranslation 一致的逻辑
            self.currentTask?.cancel()
            self.currentTask = Task { [weak self] in
                guard let self else { return }
                do {
                    let result: TranslationResult
                    switch dir {
                    case .forward:
                        result = try await TranslationService.shared.translate(text: src)
                    case .reverse:
                        result = try await TranslationService.shared.reverseTranslate(text: src)
                    }
                    await MainActor.run {
                        self.updateResult(result, sourceText: src, direction: dir, target: target)
                    }
                } catch let err as TranslationError {
                    await MainActor.run {
                        self.updateError(err.errorDescription ?? "重试失败", sourceText: src, direction: dir, target: target)
                    }
                } catch {
                    await MainActor.run {
                        self.updateError(error.localizedDescription, sourceText: src, direction: dir, target: target)
                    }
                }
            }
        }
        viewModel.onDismiss = { [weak self] in
            self?.dismiss()
        }
    }

    // MARK: - 监听

    private func installOutsideDismissMonitors() {
        removeOutsideDismissMonitors()
        // 卡片在屏幕坐标系中的矩形。
        // 窗口比卡片大一圈 bloomMargin（透明留白），所以卡片顶边 = panel.maxY - margin，
        // 左边 = panel.minX + margin，宽 = cardWidth —— 不能再拿整个 panel.frame 当卡片，
        // 否则点在留白上会被当成"点在卡内"而不关闭。
        dismissMonitor.cardScreenRect = { [weak self] in
            guard let self else { return .zero }
            let f = self.cardPanel.frame
            let margin = PanelMetrics.bloomMargin
            let h = max(self.region.cardHeight, 0)
            // 如果卡片高度还没量出来（=0），保守返回整个 panel，避免"卡片外点击穿透"误判
            guard h > 0 else { return f }
            return NSRect(x: f.minX + margin,
                          y: f.maxY - margin - h,
                          width: PanelMetrics.cardWidth,
                          height: h)
        }
        dismissMonitor.onDismiss = { [weak self] in
            Task { @MainActor in self?.dismiss() }
        }
        // 滚动到卡片外 → 关闭 + 顺便重置倒计时（同一路径）
        dismissMonitor.onUserActivity = { [weak self] in
            Task { @MainActor in self?.bumpAutoDismiss() }
        }
        dismissMonitor.start()
        // 补齐同一 App 内、Panel 窗口范围之外的点击；其他 App / 桌面由 global monitor 负责。
        cardPanel.installOutsideClickMonitor()
    }

    private func removeOutsideDismissMonitors() {
        dismissMonitor.stop()
        cardPanel.removeOutsideClickMonitor()
    }
}
