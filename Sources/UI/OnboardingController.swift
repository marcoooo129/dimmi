// 引导窗口状态：第一次启动时弹一次，「看完了」写 UserDefaults 标记。
// Window scene 由 FraseApp 声明，openWindow 由调用方（菜单栏 / 启动引导）触发。
import Foundation

@MainActor
final class OnboardingController {
    static let shared = OnboardingController()

    /// UserDefaults key —— 看到 true 就再不弹。
    private let hasShownKey = "dimmi.hasShownOnboarding"
    /// 与 FraseApp 里的副 key 同步：辅助功能 prompt 自动跳系统设置要用。
    private let completedKey = "dimmi.onboardingCompleted"

    var hasShown: Bool { UserDefaults.standard.bool(forKey: hasShownKey) }

    /// 首次启动调用。已展示过就直接返回。
    func showIfNeeded() -> Bool {
        guard !hasShown else { return false }
        return true
    }

    /// 引导关闭时由 OnboardingView 调用，写 UserDefaults 标记「已看」。
    func dismiss() {
        UserDefaults.standard.set(true, forKey: hasShownKey)
        UserDefaults.standard.set(true, forKey: completedKey)
    }
}
