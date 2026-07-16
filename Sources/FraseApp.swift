// dimmi @main 入口：菜单栏常驻 (LSUIElement)，挂 SwiftData 容器，弹出设置 / 历史 / 引导窗口。
import SwiftUI
import SwiftData

@main
struct dimmiApp: App {
    /// 全局状态：单例，避免在 App 里用 @StateObject 触发「未挂到 View」运行时问题。
    /// 所有 UI / 服务都从这里读。
    private let state = AppState.shared

    /// SwiftData 容器：历史库持久化。MVP 阶段只这一个实体。
    /// 启动期 schema 不兼容时不要 fatalError，先尝试清库重试一次。
    /// 这条路径 dev 期加字段才会触发，正式 release 永远不应发生。
    let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: HistoryItem.self)
        } catch {
            NSLog("[dimmi] SwiftData 容器失败：\(error.localizedDescription) — 清库重试")
            // 清掉 ~/Library/Application Support/.../default.store 等关联文件
            if let url = defaultStoreURL() {
                let candidates: [URL] = [
                    url,
                    url.appendingPathExtension("shm"),
                    url.appendingPathExtension("wal"),
                    url.appendingPathExtension("-shm"),
                    url.appendingPathExtension("-wal"),
                ]
                for u in candidates { try? FileManager.default.removeItem(at: u) }
            }
            do {
                return try ModelContainer(for: HistoryItem.self)
            } catch {
                NSLog("[dimmi] 清库后仍无法创建 ModelContainer：\(error)")
                // 实在不行再 fatal —— 否则历史模块会一直坏掉
                fatalError("无法创建 SwiftData 容器：\(error)")
            }
        }
    }()

    private static func defaultStoreURL() -> URL? {
        // Application Support/<bundle id>/default.store
        let fm = FileManager.default
        guard let appSupport = try? fm.url(for: .applicationSupportDirectory,
                                           in: .userDomainMask,
                                           appropriateFor: nil,
                                           create: true),
              let bundleID = Bundle.main.bundleIdentifier
        else { return nil }
        let dir = appSupport.appendingPathComponent(bundleID, isDirectory: true)
        return dir.appendingPathComponent("default.store")
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environmentObject(state)
        } label: {
            // 菜单栏使用专门为 16pt 光学加粗的单色 di 标。
            // template image 会自动适配深浅、按下与高亮状态。
            ZStack {
                if let menuImg = NSImage(named: "MenuBarIcon") {
                    Image(nsImage: {
                        menuImg.isTemplate = true
                        return menuImg
                    }())
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                } else {
                    // 资源异常时仍保留可操作的系统兜底。
                    Image(systemName: "character.bubble")
                        .frame(width: 18, height: 18)
                }
                LaunchHook()
            }
            .accessibilityLabel("dimmi")
        }
        .menuBarExtraStyle(.menu)

        // 设置窗口：500×460（v5 收紧，内容自然填满）。
        // 窗口不可缩放（.contentSize）；内容与窗口同宽（无额外响应式计算）。
        Window("dimmi 设置", id: "settings") {
            SettingsView()
                .environmentObject(state)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 500, height: 460)
        .modelContainer(modelContainer)

        // 历史窗口：720×540（v5 收紧）。
        Window("dimmi 历史", id: "history") {
            HistoryView()
        }
        .modelContainer(modelContainer)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 720, height: 540)

        // 引导窗口（与设置同款：DiaBackground + 白卡 + 隐藏标题栏）
        Window("欢迎使用 dimmi", id: "onboarding") {
            OnboardingView(onDismiss: { OnboardingController.shared.dismiss() })
                .environmentObject(state)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 540, height: 540)
    }

    init() {
        // 注入 SwiftData 容器给 AppState，HistoryStore / HistoryView 共享同一份主 context。
        // 这里直接访问 modelContainer（dimmiApp 上的 stored property）。
        AppState.shared.modelContainer = modelContainer

        // 监听应用激活事件，刷新辅助功能授权状态（仅当用户选了「划词」模式才有意义）。
        // 用户从「系统设置」授权回来后，切回 dimmi 时状态指示会刷新。
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                AppState.shared.refreshAccessibilityAuthorizationMonitoring()
            }
        }

        // 关键：AXIsProcessTrustedWithOptions 在 init() 同步调会在 Swift 6 + LSUIElement
        // 启动竞态下 SIGSEGV。所有系统服务调用都延后到主 runloop 起来之后。
        DispatchQueue.main.async { [state] in
            // 一次性字体注册验证（不影响正常逻辑，仅用于确认 Inter 已加载）
            // 静默运行即可——保留一行 NSLog 让用户首次启动能在 Console.app 看到状态。
            let fams = NSFontManager.shared.availableFontFamilies
            let interMatches = fams.filter { $0.lowercased().contains("inter") }
            if !interMatches.isEmpty {
                NSLog("[dimmi] 字体就绪，Inter family: %@", interMatches.joined(separator: ", "))
            } else {
                NSLog("[dimmi] ⚠️ Inter family 不在 font families 中，请检查 Info.plist ATSApplicationFontsPath 和 build phase。")
            }

            // 注册全局快捷键 ⌘⇧T（用 TextGrabber 兜底，模拟 ⌘C 读选区）。
            GlobalShortcut.install()

            // 挂两条触发路径：
            //   - 粘贴板路径（默认，无 TCC）：监听 NSPasteboard.changeCount
            //   - 划词路径（需要辅助功能）：监听全局 mouseDown/Up + AX 选区
            // 两条路径互斥，由 AppState.sourceMode 切换。
            state.clipboardMonitor.onClipboardChange = { text, point in
                PanelController.shared.triggerTranslation(for: text, at: point)
            }
            state.selectionMonitor.onSelection = { text, point in
                PanelController.shared.triggerTranslation(for: text, at: point)
            }

            // 主 RunLoop 就绪后再启动 TCC 跟踪。LSUIElement 可能始终不重新激活，
            // 因此不能只靠 didBecomeActive 去感知用户刚在系统设置勾选授权。
            state.startAccessibilityAuthorizationMonitoring()

            // 用户已经明确选择“划词”时，换包/重签后旧 TCC 授权可能不再匹配。
            // 主动请求当前二进制的授权，避免设置里仍显示旧条目却没有任何反馈。
            if state.sourceMode == .selection,
               !AccessibilityManager.isTrusted(prompt: false) {
                state.refreshAccessibilityTrusted(prompt: true)
            }
        }

        // 启动引导由 LaunchHook（挂在 MenuBarExtra label 上）触发：
        // status item view 常驻渲染，hasShown=false 时自动 openWindow("onboarding")。

        #if DEBUG
        // DEBUG 自检：若 DIMMI_DEMO=1，启动 2 秒后在鼠标当前位置自动演示一次浮层。
        if ProcessInfo.processInfo.environment["DIMMI_DEMO"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                let pt = NSEvent.mouseLocation
                PanelController.shared.presentWithMock(
                    for: "我今天很累",
                    at: pt == .zero ? NSPoint(x: 800, y: 600) : pt
                )
            }
        }
        #endif
    }
}

/// 菜单栏下拉内容
struct MenuContent: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) private var openWindow

    private func openSettingsWindow() {
        openWindow(id: "settings")
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openOnboardingWindow() {
        openWindow(id: "onboarding")
        NSApp.activate(ignoringOtherApps: true)
    }

    var body: some View {
        Toggle("自动划词翻译", isOn: Binding(
            get: { state.autoTranslateEnabled },
            set: { newValue in
                state.autoTranslateEnabled = newValue
                state.applySelectionMonitorState()
            }
        ))
        Divider()

        Button("打开历史…") {
            openWindow(id: "history")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut("h", modifiers: [.command])

        if state.reverseTranslateEnabled {
            Button("反向翻译 → 中文…") {
                let text = TextGrabber.selectedTextForManualTrigger()
                guard let t = text, !t.isEmpty else {
                    NSLog("[dimmi] 菜单栏「反向翻译」：未取到文本，先 ⌘C 复制再试。")
                    NSSound.beep()
                    return
                }
                PanelController.shared.triggerReverseTranslation(for: t, at: NSEvent.mouseLocation)
            }
        }

        if state.sourceMode == .selection && !state.accessibilityTrusted {
            Divider()
            // 只有“划词”模式依赖辅助功能；剪贴板模式不应该误报。
            Button {
                AccessibilityManager.openSystemSettings()
            } label: {
                Label("未授权辅助功能，点击跳转系统设置", systemImage: "exclamationmark.triangle.fill")
            }
        }

        if !Secrets.hasKeyForCurrentProvider {
            Divider()
            Button {
                NSApp.activate(ignoringOtherApps: true)
                openSettingsWindow()
            } label: {
                Label("未填写 \(state.provider.rawValue) API Key", systemImage: "key.fill")
            }
        }

        Divider()

        Button("重新看引导…") {
            openOnboardingWindow()
        }

        Button("设置…") {
            openSettingsWindow()
        }
        .keyboardShortcut(",", modifiers: [.command])

        Divider()

        Button("退出 dimmi") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: [.command])
    }
}
