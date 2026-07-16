// PanelDismissMonitor：把"点外面 / Esc / 滚轮 / 切 Space → 关闭翻译浮窗"集中到一个类。
//
// 关键背景（这次必须理解清楚）：
//   1. NSPanel 是 .nonactivatingPanel + .borderless —— 浮窗出现后 dimmi 永远不是 keyWindow，
//      也不会触发 didResignKeyNotification / didResignActiveNotification。
//   2. 之前一版的 addLocalMonitorForEvents 是错的：local monitor 只能收【本 App】事件，
//      用户点 Safari / Finder / 桌面时事件根本不到本 App，monitor 永远不触发。
//   3. addGlobalMonitorForEvents 监听【其他 App / 桌面】的点击。
//   4. 但本 App 内部点击（比如点 dimmi 的设置窗、菜单栏、自身 panel）— global 拿不到。
//   → 两条路必须都装，缺一不可。
//
// 三个必踩的坑：
//   1. 宽限期：start() 之后 250ms 内一律忽略（避免"划词 mouseUp 之后紧跟的 mouseDown
//      让刚出现的浮窗立刻自关"）。
//   2. 判定矩形必须是【卡片】，不是【窗口】：panel 固定 340×420，但卡片可能只占顶部 120pt。
//      cardScreenRect 由调用方提供 —— 拿 panel 顶边往下量 cardHeight 这一段。
//   3. 坐标系：global 事件里 event.locationInWindow 是垃圾，必须用 NSEvent.mouseLocation。
//      mouseLocation 是屏幕坐标（左下原点，y 向上），与 panel.frame 同系，NSRect.contains 直接用。
//
// 监听范围：
//   - global：左/中/右键 mouseDown（其他 App / 桌面）
//   - local：左/中/右键 mouseDown（用户点 dimmi 自身界面时）
//   - local：keyDown（Esc = keyCode 53，⌘W = keyCode 13 with .command）
//   - NSWorkspace.activeSpaceDidChangeNotification
//
// 不监听 scrollWheel：触控板惯性滚动可能在浮窗出现后继续送事件，造成“刚出现就消失”；
// 用户要求的是点击外部关闭，滚动不应被当作点击。
//
// 不监听 didActivateApplicationNotification：菜单栏 App / nonactivatingPanel 在刚显示时也可能
// 产生一次激活通知，会把新浮窗误关。真实的“鼠标点到其他 App”已经由 global monitor 覆盖。
//
// 权限：addGlobalMonitorForEvents 监听鼠标事件不需要辅助功能权限；
//       监听键盘需要 — dimmi 已经拿了 a11y 权限（划词要用），无须新增。
//
// 生命周期：只允许在浮窗【可见】期间存在。dismiss() 时立刻 stop()，绝不常驻。
//           start() 内部先 stop()，保证幂等 —— 连续划词不会装两个。
import AppKit

final class PanelDismissMonitor: @unchecked Sendable {
    // MARK: - 配置（由调用方赋值）
    /// 卡片在屏幕坐标系中的矩形（仅卡片区，不含 panel 下方的空白）
    var cardScreenRect: () -> NSRect = { .zero }
    /// 触发关闭
    var onDismiss: () -> Void = {}
    /// 用户在卡片外有点击 / 滚轮等"活动" → 供业务重置倒计时（不区分 onDismiss 路径）
    var onUserActivity: () -> Void = {}

    // MARK: - 内部状态
    private var globalClickMonitor: Any?
    private var localMouseMonitor: Any?
    private var localKeyMonitor: Any?
    private var activeSpaceObserver: NSObjectProtocol?
    private var installedAt: Date = .distantPast

    /// 宽限期：刚装上 monitor 之后这段 ms 内一律忽略（划词残留的 mouseUp/mouseDown 会误触发）
    private let gracePeriod: TimeInterval = 0.25

    deinit { stop() }

    // MARK: - 公开 API

    func start() {
        stop()  // 幂等：防止重复装导致 monitor 泄漏

        installedAt = Date()

        let clickMask: NSEvent.EventTypeMask = [
            .leftMouseDown, .rightMouseDown, .otherMouseDown
        ]
        // ---- 1. global：其他 App / 桌面的点击 ----
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: clickMask) { [weak self] _ in
            self?.handleGlobalClick()
        }

        // ---- 2. local：本 App 内部点击 + Esc/⌘W ----
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: clickMask) { [weak self] event in
            self?.handleLocalMouse(event)
            return event   // 必须原样返回，不能吞
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKey(event)
            return event
        }

        // ---- 3. 切 Space 也关 ----
        activeSpaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            NSLog("[dimmi][panel-monitor] dismiss: active Space changed")
            self?.onDismiss()
        }
    }

    func stop() {
        if let m = globalClickMonitor   { NSEvent.removeMonitor(m) }
        if let m = localMouseMonitor    { NSEvent.removeMonitor(m) }
        if let m = localKeyMonitor      { NSEvent.removeMonitor(m) }
        globalClickMonitor  = nil
        localMouseMonitor   = nil
        localKeyMonitor     = nil

        if let s = activeSpaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(s)
            activeSpaceObserver = nil
        }
    }

    // MARK: - 内部处理

    private func pastGracePeriod() -> Bool {
        Date().timeIntervalSince(installedAt) > gracePeriod
    }

    private func handleGlobalClick() {
        guard pastGracePeriod() else { return }
        // global 事件的 locationInWindow 是垃圾；用 NSEvent.mouseLocation
        let p = NSEvent.mouseLocation
        onUserActivity()   // 不管在不在卡片内，先告诉外面"用户在动"
        if !cardScreenRect().contains(p) {
            NSLog("[dimmi][panel-monitor] dismiss: global pointer event outside card at %@", NSStringFromPoint(p))
            onDismiss()
        }
    }

    private func handleLocalMouse(_ event: NSEvent) {
        guard pastGracePeriod() else { return }
        // local 事件 locationInWindow 可用，但我们统一用 mouseLocation
        // （AppKit 在 local 事件里给的 locationInWindow 是 window 坐标系，
        //   还要再转屏幕，多此一举；mouseLocation 是最直接的对的）。
        let p = NSEvent.mouseLocation
        onUserActivity()
        if !cardScreenRect().contains(p) {
            NSLog("[dimmi][panel-monitor] dismiss: local pointer event outside card at %@", NSStringFromPoint(p))
            onDismiss()
        }
    }

    private func handleKey(_ event: NSEvent) {
        // 53 = Esc, 13 = W（搭配 .command = ⌘W）
        let isEsc = event.keyCode == 53
        let isCmdW = event.keyCode == 13 &&
                     event.modifierFlags.contains(.command) &&
                     !event.modifierFlags.contains(.option) &&
                     !event.modifierFlags.contains(.control)
        if isEsc || isCmdW {
            NSLog("[dimmi][panel-monitor] dismiss: %@", isEsc ? "Esc" : "Command-W")
            onDismiss()
        }
    }
}
