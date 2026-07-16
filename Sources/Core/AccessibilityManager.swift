// 辅助功能授权管理：启动时检查并按需引导用户去系统设置。
import AppKit
import ApplicationServices

enum AccessibilityManager {
    /// 检查是否已授权；未授权时根据 `prompt` 决定是否弹系统引导。
    ///
    /// 注意：不要传空 dict `[String: Any]()` 然后强转 `CFDictionary`。
    /// 在 macOS 27 (SDK 26) 上，`AXIsProcessTrustedWithOptions` 内部对空 CFDictionary
    /// 会 deref `__EmptyDictionarySingleton` 的 type metadata 偏移 0x8，SIGSEGV。
    /// 官方推荐：不弹 prompt 时直接传 `nil`。
    @discardableResult
    static func isTrusted(prompt: Bool = false) -> Bool {
        if prompt {
            let key = "AXTrustedCheckOptionPrompt"
            let options = [key: true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        } else {
            return AXIsProcessTrustedWithOptions(nil)
        }
    }

    /// 打开「系统设置 → 隐私与安全性 → 辅助功能」直达页面。
    static func openSystemSettings() {
        // macOS 13+ 推荐用 privacy_advanced 锚点；老一些的 URL 仍然有效。
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

/// `LSUIElement` 菜单栏应用不能依赖 `NSApplication.didBecomeActiveNotification`
/// 感知用户从系统设置返回：用户可以授权后直接去其他 App 划词，
/// dimmi 全程都未必成为活动应用。因此用一个主 RunLoop 轻量轮询器
/// 跟踪 TCC 状态，只在状态真正变化时通知 AppState。
@MainActor
final class AccessibilityAuthorizationMonitor {
    typealias TrustCheck = () -> Bool
    typealias ChangeHandler = @MainActor (Bool) -> Void

    private let trustCheck: TrustCheck
    private var timer: Timer?
    private var lastValue: Bool?
    private var onChange: ChangeHandler?

    init(trustCheck: @escaping TrustCheck = {
        AccessibilityManager.isTrusted(prompt: false)
    }) {
        self.trustCheck = trustCheck
    }

    /// 开始持续检查。首次启动会立即回传当前状态，
    /// 之后只在 false ↔ true 变化时回传。
    func start(interval: TimeInterval = 0.75, onChange: @escaping ChangeHandler) {
        self.onChange = onChange
        refresh(forceNotification: lastValue == nil)
        guard timer == nil else { return }

        let timer = Timer(timeInterval: max(0.25, interval), repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        onChange = nil
    }

    /// 应用激活、用户点“重新检查”时可额外立即刷新，
    /// 无需等待下一个 timer tick。
    func refresh(forceNotification: Bool = false) {
        let value = trustCheck()
        guard forceNotification || value != lastValue else { return }
        lastValue = value
        onChange?(value)
    }

    var isRunning: Bool { timer != nil }
}
