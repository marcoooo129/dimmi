// 全局可观察状态：菜单栏下拉、设置、浮层都从这里读 / 写。
import SwiftUI
import Combine
import SwiftData

@MainActor
final class AppState: ObservableObject {
    /// 全局单例：菜单栏 App 里 App 不是 View，@StateObject 不可用，
    /// 用单例更顺手（也跟 PanelController.shared 风格一致）。
    static let shared = AppState()

    /// SwiftData 容器：由 App 在 init 阶段注入，HistoryStore / HistoryView 拿主 context 用。
    var modelContainer: ModelContainer?

    /// 主 context（懒加载）。所有 UI 写入都走这个 context，立刻被 @Query 看到。
    var modelContext: ModelContext { modelContainer!.mainContext }

    /// 自动翻译总开关：关掉就什么都不弹，只剩手动 ⌘⇧T。
    @Published var autoTranslateEnabled: Bool {
        didSet {
            UserPrefs.autoTranslateEnabled = autoTranslateEnabled
            applySelectionMonitorState()
        }
    }

    /// 取词来源：粘贴板（默认，无 TCC）/ 选区（划词自动，需要辅助功能）。
    @Published var sourceMode: SourceMode {
        didSet {
            UserPrefs.sourceModeRaw = sourceMode.rawValue
            applySelectionMonitorState()
        }
    }

    /// 当前选中的翻译引擎（持久化在 Secrets 里）。
    /// 这里用 @Published 是为了让 SettingsView 的 Picker 实时刷新；
    /// 真值同时落 UserDefaults，避免「UI 显示但未持久化」的不一致。
    @Published var provider: TranslationProvider {
        didSet { Secrets.setProvider(provider) }
    }

    /// 辅助功能授权状态：启动时拉一次，菜单栏下拉用来提示。
    /// 「粘贴板模式」下，授权状态仅作信息展示，不再触发任何阻塞流程。
    @Published var accessibilityTrusted: Bool = false {
        didSet {
            if accessibilityTrusted != oldValue, sourceMode == .selection {
                applySelectionMonitorState()
            }
        }
    }

    /// 粘贴板监听（默认路径，无 TCC）。
    let clipboardMonitor = ClipboardMonitor()
    /// 划词监听（需要辅助功能，旧路径）。保留作为 fallback + 选了「划区」时的实际监听者。
    let selectionMonitor = SelectionMonitor()
    /// 菜单栏 App 在后台也持续跟踪辅助功能授权变化。
    /// 否则用户在系统设置勾选 dimmi 后，监听器可能直到下次重启都不会启动。
    private let accessibilityAuthorizationMonitor = AccessibilityAuthorizationMonitor()

    enum SourceMode: String, CaseIterable, Identifiable {
        case clipboard = "clipboard"
        case selection = "selection"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .clipboard: return "粘贴板（按 ⌘C 复制即触发）"
            case .selection: return "划词（需辅助功能授权）"
            }
        }
        var icon: String {
            switch self {
            case .clipboard: return "doc.on.clipboard"
            case .selection: return "text.cursor"
            }
        }
    }

    // MARK: - 用户可调参数（写入即落 UserDefaults）
    // 字符长度必须成对更新，避免 UI、UserDefaults 与两个监听器短暂拿到
    // `minimum > maximum` 的非法组合，因此只通过下面的更新方法写入。
    /// 划词/粘贴板触发最小长度
    @Published private(set) var selectionMinLength: Int
    /// 划词/粘贴板触发最大长度
    @Published private(set) var selectionMaxLength: Int
    /// 自动触发后冷却时间（秒）
    @Published var selectionCooldown: TimeInterval = UserPrefs.selectionCooldown {
        didSet {
            UserPrefs.selectionCooldown = selectionCooldown
            clipboardMonitor.applyConfig()
            selectionMonitor.applyConfig()
        }
    }
    /// 卡片成功态自动关闭秒数
    @Published var successAutoDismiss: TimeInterval = UserPrefs.successAutoDismiss {
        didSet {
            UserPrefs.successAutoDismiss = successAutoDismiss
            PanelController.shared.applyConfig()
        }
    }
    /// 卡片错误态自动关闭秒数
    @Published var errorAutoDismiss: TimeInterval = UserPrefs.errorAutoDismiss {
        didSet {
            UserPrefs.errorAutoDismiss = errorAutoDismiss
            PanelController.shared.applyConfig()
        }
    }

    /// 没配 API Key 时是否使用示例数据演示。默认 true（让你先看视觉）。
    /// 关闭后，未配 key 会真弹「请配置 API Key」错误。
    @Published var useMockWhenNoKey: Bool = UserPrefs.useMockWhenNoKey {
        didSet { UserPrefs.useMockWhenNoKey = useMockWhenNoKey }
    }

    /// 是否为译文请求语法 / 惯用表达注解。
    /// 放在 AppState 而不是让 View 直读 UserDefaults，保证设置窗、浮窗即时同步。
    @Published var showPhraseNotes: Bool {
        didSet { UserPrefs.showPhraseNotes = showPhraseNotes }
    }

    /// 多目标语：默认意大利语；UI 上由「设置 → 翻译」切换。
    @Published var targetLanguage: TargetLanguage {
        didSet { UserPrefs.targetLanguageRaw = targetLanguage.rawValue }
    }

    /// 是否启用「目标语 → 中文」反向翻译。开启后菜单栏多一个入口、全局多一个快捷键。
    @Published var reverseTranslateEnabled: Bool {
        didSet { UserPrefs.reverseTranslateEnabled = reverseTranslateEnabled }
    }

    private init() {
        let selectionLengths = UserPrefs.selectionLengths(in: .standard)
        self.selectionMinLength = selectionLengths.minimum
        self.selectionMaxLength = selectionLengths.maximum
        self.autoTranslateEnabled = UserPrefs.autoTranslateEnabled
        self.sourceMode = SourceMode(rawValue: UserPrefs.sourceModeRaw) ?? .clipboard
        self.provider = Secrets.currentProvider()
        self.showPhraseNotes = UserPrefs.showPhraseNotes
        self.targetLanguage = TargetLanguage(rawValue: UserPrefs.targetLanguageRaw) ?? .italian
        self.reverseTranslateEnabled = UserPrefs.reverseTranslateEnabled
    }

    /// 更新最小长度。若超过当前最大值，最大值会同步抬高。
    func updateSelectionMinLength(_ value: Int) {
        let minimum = UserPrefs.clampedSelectionLength(value)
        applySelectionLengths(
            minimum: minimum,
            maximum: max(selectionMaxLength, minimum)
        )
    }

    /// 更新最大长度。若低于当前最小值，最小值会同步降低。
    func updateSelectionMaxLength(_ value: Int) {
        let maximum = UserPrefs.clampedSelectionLength(value)
        applySelectionLengths(
            minimum: min(selectionMinLength, maximum),
            maximum: maximum
        )
    }

    /// 用于取消设置时恢复完整快照，也供未来批量导入偏好使用。
    func updateSelectionLengths(minimum: Int, maximum: Int) {
        let clampedMinimum = UserPrefs.clampedSelectionLength(minimum)
        let clampedMaximum = max(
            clampedMinimum,
            UserPrefs.clampedSelectionLength(maximum)
        )
        applySelectionLengths(minimum: clampedMinimum, maximum: clampedMaximum)
    }

    private func applySelectionLengths(minimum: Int, maximum: Int) {
        guard minimum != selectionMinLength || maximum != selectionMaxLength else { return }

        selectionMinLength = minimum
        selectionMaxLength = maximum
        UserPrefs.setSelectionLengths(
            minimum: minimum,
            maximum: maximum,
            in: .standard
        )
        clipboardMonitor.applyConfig()
        selectionMonitor.applyConfig()
    }

    /// 启动期检查辅助功能授权，更新到 accessibilityTrusted。
    /// 「粘贴板模式」下不弹 prompt；只在选「划词」模式且未授权时引导用户去系统设置。
    func refreshAccessibilityTrusted(prompt: Bool = false) {
        accessibilityTrusted = AccessibilityManager.isTrusted(prompt: prompt)
    }

    /// 应在 App 的主 RunLoop 启动后调用。首次立即校准，后续在后台也能
    /// 于 0.75s 内感知授权/撤权，由 `accessibilityTrusted.didSet` 自动启停划词监听。
    func startAccessibilityAuthorizationMonitoring() {
        accessibilityAuthorizationMonitor.start { [weak self] trusted in
            guard let self else { return }
            self.accessibilityTrusted = trusted
            // 首次回调时即使状态仍为 false，didSet 不会路由；
            // 显式应用一次，才能正确启动剪贴板路径或等待授权。
            self.applySelectionMonitorState()
        }
    }

    func refreshAccessibilityAuthorizationMonitoring() {
        accessibilityAuthorizationMonitor.refresh(forceNotification: true)
    }

    /// 同时管理两条触发路径，按 sourceMode 启停其中一条。
    /// 任何 path 触发时，through `onSelection` / `onClipboardChange`
    /// 走到 `triggerTranslation`，效果一致。
    func applySelectionMonitorState() {
        // 把最新参数同时 push 给两条路径
        clipboardMonitor.applyConfig()
        selectionMonitor.applyConfig()

        switch Self.monitoringRoute(
            autoTranslateEnabled: autoTranslateEnabled,
            sourceMode: sourceMode,
            accessibilityTrusted: accessibilityTrusted
        ) {
        case .disabled:
            clipboardMonitor.stop()
            selectionMonitor.stop()
        case .clipboard:
            clipboardMonitor.start()
            selectionMonitor.stop()
        case .selectionWaitingForAccessibility:
            clipboardMonitor.stop()
            selectionMonitor.stop()
        case .selection:
            clipboardMonitor.stop()
            selectionMonitor.start()
        }
    }

    enum MonitoringRoute: Equatable {
        case disabled
        case clipboard
        case selectionWaitingForAccessibility
        case selection
    }

    /// 把监听器路由判定抽成无副作用函数，防止以后再出现
    /// “UI 显示已授权，实际 monitor 还停着”的状态分叉。
    static func monitoringRoute(
        autoTranslateEnabled: Bool,
        sourceMode: SourceMode,
        accessibilityTrusted: Bool
    ) -> MonitoringRoute {
        guard autoTranslateEnabled else { return .disabled }
        switch sourceMode {
        case .clipboard:
            return .clipboard
        case .selection:
            return accessibilityTrusted ? .selection : .selectionWaitingForAccessibility
        }
    }
}
