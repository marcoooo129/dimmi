// 启动引导触发器：挂在 MenuBarExtra label 上（status item 视图常驻渲染）。
// 第一次启动时弹 onboarding 窗口，且只在 onAppear 触发一次。
import SwiftUI

struct LaunchHook: View {
    @Environment(\.openWindow) private var openWindow
    @State private var fired = false

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                guard !fired else { return }
                fired = true
                #if DEBUG
                // 可复现的设置窗 UI smoke 入口。仅 Debug 生效，正式包完全不包含此行为。
                if ProcessInfo.processInfo.environment["DIMMI_OPEN_SETTINGS"] == "1" {
                    DispatchQueue.main.async {
                        openWindow(id: "settings")
                        NSApp.activate(ignoringOtherApps: true)
                    }
                    return
                }
                // 单元测试宿主会启动 app 本体，但不应该弹真实引导窗干扰测试。
                if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
                    return
                }
                #endif
                if OnboardingController.shared.showIfNeeded() {
                    DispatchQueue.main.async {
                        openWindow(id: "onboarding")
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
            }
    }
}
