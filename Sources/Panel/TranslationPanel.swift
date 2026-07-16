// 自定义 NSPanel：拦截 mouseDown / rightMouseDown，
// 在 SwiftUI 子视图 hitTest 没拿到点击时（即「点外面」），主动 dismiss。
//
// 为什么不用 addGlobalMonitorForEvents：
//   1. addGlobal 只接收其他 App 的事件，自己 App 收不到
//   2. addLocal 接收事件在分发到 NSWindow 前 — 但 panel 自身处理后子 view 拿到之前，
//      SwiftUI 通过 hostingView 已经把 mouseDown 消费了，monitor 拿不到具体位置。
//
// 重写 sendEvent 是最稳的：所有事件先经过我们手，panel 内部 SwiftUI 子树
// 不能"提前"吃掉决定性事件。我们手动 hitTest 子视图，子视图拿到 = 卡片内；
// 子视图拿不到 = 卡片外的空白 → 关闭。
import AppKit
import SwiftUI

/// 主面板
/// macOS 15+：TextRenderer 需要 macOS 15，整个浮窗组件限定在 macOS 15+
@available(macOS 15, *)
final class TranslationPanel: NSPanel {
    /// 点击外面回调（由 PanelController 装）。覆盖 Panel 透明留白和本 App 其他窗口。
    var onOutsideClick: (() -> Void)?

    /// 我们自己 addLocalMonitor 注册的 monitor handle（用于 remove）
    private var localClickMonitor: Any?

    override var acceptsFirstResponder: Bool { true }
    /// 浮窗显示时不主动激活 App；用户点进原生文字后才按需成为 key window。
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        // 仅处理左/右键 mouseDown；其他事件原样分发
        switch event.type {
        case .leftMouseDown, .rightMouseDown:
            handleMouseDown(event)
        default:
            super.sendEvent(event)
        }
    }

    /// 装/卸 local mouseDown monitor。
    /// Local monitor 工作在 App 自己的 dispatch 链最前面，
    /// 即便 panel 是 .nonactivatingPanel 也能拿到所有 mouseDown 事件。
    func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        // 必须截获 [weak self] 防止循环
        localClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self else { return event }
            // 转成屏幕坐标
            let p = event.locationInWindow
            let screen: NSPoint = event.window?.convertPoint(toScreen: p) ?? p
            // 如果点落在 panel 内（屏幕 frame）：让 sendEvent 继续区分卡片与透明留白。
            if self.frame.contains(screen) {
                return event
            }
            // 否则：点在了「外面」→ 立即 dismiss
            DispatchQueue.main.async {
                NSLog("[dimmi][panel-monitor] dismiss: local click outside panel at %@", NSStringFromPoint(screen))
                self.onOutsideClick?()
            }
            // 让事件继续走 — 不主动吞，避免别的 App / 系统行为异常
            return event
        }
    }

    func removeOutsideClickMonitor() {
        if let m = localClickMonitor {
            NSEvent.removeMonitor(m)
            localClickMonitor = nil
        }
    }

    private func handleMouseDown(_ event: NSEvent) {
        let locationInWindow = event.locationInWindow

        // SwiftUI 的 ScrollView 覆盖了整张卡片，isMovableByWindowBackground 因而无效。
        // 直接让 NSPanel 从顶部品牌/语言区执行原生拖动；右侧 88pt 留给复制和关闭按钮。
        if event.type == .leftMouseDown, dragHandleRect.contains(locationInWindow) {
            performDrag(with: event)
            return
        }

        // 先尝试派发给子视图（SwiftUI 树），让按钮等正常响应
        let hit = contentView?.hitTest(locationInWindow)
        if hit != nil {
            // 点到了卡片内（包括按钮 / 文本 / 任何 SwiftUI view）→ 正常分发
            super.sendEvent(event)
            return
        }
        // 点到了 panel 内但 SwiftUI 子视图没拿到 → 卡片外的空白
        // 先 dismiss
        NSLog("[dimmi][panel-monitor] dismiss: click in transparent panel margin")
        onOutsideClick?()
        // 然后**不要**再 super.sendEvent —— 否则会把 mouseDown 派给 NSWindow 默认路径
        // （高亮/拖动窗口等），会让用户感觉奇怪
    }

    /// AppKit 坐标原点在窗口左下；卡片位于窗口顶部并内缩 bloomMargin。
    /// 拖动区仅覆盖品牌 + 语言方向，不覆盖右侧操作按钮，也不影响正文滚动。
    private var dragHandleRect: NSRect {
        let margin = PanelMetrics.bloomMargin
        let cardTop = frame.height - margin
        let headerBottom = cardTop - PanelMetrics.cardPadding - TextMeasurer.headerRow
        return NSRect(
            x: margin + PanelMetrics.cardPadding,
            y: headerBottom,
            width: PanelMetrics.contentWidth - PanelMetrics.headerActionsWidth,
            height: TextMeasurer.headerRow
        )
    }
}
