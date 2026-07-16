// 用户可调参数集中地：所有写 UserDefaults 的可调项都从这里走。
// 默认值 = 阶段 8 调出的"不烦人"档位。
import Foundation

enum UserPrefs {
    // MARK: - 键
    private enum K {
        static let autoTranslateEnabled   = "dimmi.autoTranslate"
        static let sourceModeRaw          = "dimmi.sourceMode"
        static let selectionMinLength     = "dimmi.selection.minLength"
        static let selectionMaxLength     = "dimmi.selection.maxLength"
        static let selectionCooldown      = "dimmi.selection.cooldown"
        static let successAutoDismiss     = "dimmi.card.successAutoDismiss"
        static let errorAutoDismiss       = "dimmi.card.errorAutoDismiss"
        static let useMockWhenNoKey       = "dimmi.behavior.useMockWhenNoKey"
        // 阶段 9：是否显示惯用表达注解
        static let showPhraseNotes        = "dimmi.notes.show"
        // 阶段 10：多目标语 + 反向翻译
        static let targetLanguageRaw      = "dimmi.target.language"
        static let reverseTranslateEnabled = "dimmi.reverse.enabled"
    }

    // MARK: - 默认值
    static let defaultAutoTranslateEnabled = true
    static let defaultSourceModeRaw = "clipboard"
    static let defaultSelectionMinLength = 2
    static let defaultSelectionMaxLength = 200
    static let selectionLengthRange = 1...5000
    static let defaultSelectionCooldown: TimeInterval = 1.5
    static let defaultSuccessAutoDismiss: TimeInterval = 8.0
    static let defaultErrorAutoDismiss:   TimeInterval = 30.0
    static let defaultUseMockWhenNoKey = true  // 没配 key 时用示例数据演示，默认开（上手体验为先）
    static let defaultShowPhraseNotes = true   // 注解默认开
    static let defaultReverseTranslateEnabled = true // 反向翻译默认开

    // MARK: - 自动触发总开关 / 取词来源
    static var autoTranslateEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: K.autoTranslateEnabled) as? Bool
                ?? defaultAutoTranslateEnabled
        }
        set { UserDefaults.standard.set(newValue, forKey: K.autoTranslateEnabled) }
    }

    static var sourceModeRaw: String {
        get {
            UserDefaults.standard.string(forKey: K.sourceModeRaw)
                ?? defaultSourceModeRaw
        }
        set { UserDefaults.standard.set(newValue, forKey: K.sourceModeRaw) }
    }

    // MARK: - 划词长度

    struct SelectionLengths: Equatable {
        var minimum: Int
        var maximum: Int
    }

    static func clampedSelectionLength(_ value: Int) -> Int {
        min(selectionLengthRange.upperBound, max(selectionLengthRange.lowerBound, value))
    }

    /// 成对读取，避免旧偏好或外部写入留下 `minimum > maximum` 的非法状态。
    /// 两个边界相等是合法的：此时只翻译恰好该长度的文本。
    static func selectionLengths(in defaults: UserDefaults) -> SelectionLengths {
        let storedMinimum = defaults.object(forKey: K.selectionMinLength) == nil
            ? defaultSelectionMinLength
            : defaults.integer(forKey: K.selectionMinLength)
        let storedMaximum = defaults.object(forKey: K.selectionMaxLength) == nil
            ? defaultSelectionMaxLength
            : defaults.integer(forKey: K.selectionMaxLength)

        let minimum = clampedSelectionLength(storedMinimum)
        let maximum = max(minimum, clampedSelectionLength(storedMaximum))
        return SelectionLengths(minimum: minimum, maximum: maximum)
    }

    static func setSelectionLengths(
        minimum: Int,
        maximum: Int,
        in defaults: UserDefaults
    ) {
        let clampedMinimum = clampedSelectionLength(minimum)
        let clampedMaximum = max(clampedMinimum, clampedSelectionLength(maximum))
        defaults.set(clampedMinimum, forKey: K.selectionMinLength)
        defaults.set(clampedMaximum, forKey: K.selectionMaxLength)
    }

    static var selectionMinLength: Int {
        get { selectionLengths(in: .standard).minimum }
        set {
            let current = selectionLengths(in: .standard)
            let minimum = clampedSelectionLength(newValue)
            setSelectionLengths(
                minimum: minimum,
                maximum: max(current.maximum, minimum),
                in: .standard
            )
        }
    }

    static var selectionMaxLength: Int {
        get { selectionLengths(in: .standard).maximum }
        set {
            let current = selectionLengths(in: .standard)
            let maximum = clampedSelectionLength(newValue)
            setSelectionLengths(
                minimum: min(current.minimum, maximum),
                maximum: maximum,
                in: .standard
            )
        }
    }

    // MARK: - 自动划词冷却
    static var selectionCooldown: TimeInterval {
        get { selectionCooldown(in: .standard) }
        set { setSelectionCooldown(newValue, in: .standard) }
    }

    /// 带 store 的内部入口让单元测试使用隔离 suite，不触碰用户真实偏好。
    static func selectionCooldown(in defaults: UserDefaults) -> TimeInterval {
        // `0` 是 UI 允许的合法值（不冷却），不能再用 double(forKey:)
        // 返回的 0 同“未设置”混为一谈。
        guard defaults.object(forKey: K.selectionCooldown) != nil else {
            return defaultSelectionCooldown
        }
        return max(0, defaults.double(forKey: K.selectionCooldown))
    }

    static func setSelectionCooldown(_ value: TimeInterval, in defaults: UserDefaults) {
        defaults.set(max(0, value), forKey: K.selectionCooldown)
    }

    // MARK: - 卡片自动关闭
    static var successAutoDismiss: TimeInterval {
        get {
            let raw = UserDefaults.standard.double(forKey: K.successAutoDismiss)
            return raw <= 0 ? defaultSuccessAutoDismiss : raw
        }
        set {
            UserDefaults.standard.set(max(1, newValue), forKey: K.successAutoDismiss)
        }
    }

    static var errorAutoDismiss: TimeInterval {
        get {
            let raw = UserDefaults.standard.double(forKey: K.errorAutoDismiss)
            return raw <= 0 ? defaultErrorAutoDismiss : raw
        }
        set {
            UserDefaults.standard.set(max(1, newValue), forKey: K.errorAutoDismiss)
        }
    }

    // MARK: - 没配 Key 时是否使用示例翻译
    /// 真 = 没配 key 时走 mock（让用户先看视觉），假 = 弹「请配置 API Key」错误。
    /// 用户能切换；改完即生效（triggerTranslation 每次读）。
    static var useMockWhenNoKey: Bool {
        get {
            // 默认值在用户没主动设过时为 `defaultUseMockWhenNoKey`。
            UserDefaults.standard.object(forKey: K.useMockWhenNoKey) as? Bool
                ?? defaultUseMockWhenNoKey
        }
        set { UserDefaults.standard.set(newValue, forKey: K.useMockWhenNoKey) }
    }

    // MARK: - 是否显示惯用表达注解（阶段 9）
    /// 关掉 → PanelController 不发请求 B；卡片永远只有译文。
    static var showPhraseNotes: Bool {
        get {
            UserDefaults.standard.object(forKey: K.showPhraseNotes) as? Bool
                ?? defaultShowPhraseNotes
        }
        set { UserDefaults.standard.set(newValue, forKey: K.showPhraseNotes) }
    }

    // MARK: - 阶段 10：多目标语 / 反向翻译
    /// 当前目标外语（中文 → ?）。存 rawValue，空 = 没设过 → 默认意大利语。
    static var targetLanguageRaw: String {
        get {
            UserDefaults.standard.string(forKey: K.targetLanguageRaw) ?? ""
        }
        set { UserDefaults.standard.set(newValue, forKey: K.targetLanguageRaw) }
    }

    /// 反向翻译 ?→中文。默认开。
    static var reverseTranslateEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: K.reverseTranslateEnabled) as? Bool
                ?? defaultReverseTranslateEnabled
        }
        set { UserDefaults.standard.set(newValue, forKey: K.reverseTranslateEnabled) }
    }
}
