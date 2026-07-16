// 粘贴板监听：100ms 轮询 NSPasteboard.changeCount，变化就读 .string。
// 这是「无 TCC」的核心：不需要辅助功能授权，
// 只读取用户已经在「菜单栏 → 编辑 → 拷贝」时由系统放进去的字符串。
//
// 关键：必须用 NSPasteboard.general.changeCount，系统级轻量 API，no entitlement。
import AppKit

@MainActor
final class ClipboardMonitor {
    /// 触发时把「粘贴板刚出现的文本 + 鼠标位置」丢出去。
    var onClipboardChange: ((String, NSPoint) -> Void)?

    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var lastText: String = ""
    private var lastTriggerAt: Date = .distantPast
    /// 自写抑制：标记一段从现在起 2.5s 内的剪贴板变化是「dimmi 自己写的」，
    /// 不应再触发翻译。否则用户点 ⌘C 复制后立刻点「复制译文」会把刚写的译文
    /// 当成新一轮源文 → panel 闪烁 + dismiss。
    private var selfWriteSuppressedUntil: Date = .distantPast
    private var selfWriteSkipOnce: Bool = false

    /// 默认值；启动时由 applyConfig() 从 AppState push。
    private var minLength: Int = 2
    private var maxLength: Int = 200
    private var cooldown: TimeInterval = 1.5

    /// 多少毫秒轮询一次。100ms = 视觉上「复制完基本立即翻译」，cpu 占用 ≈0。
    private static let pollInterval: TimeInterval = 0.1

    /// 同文去重窗口。取 6s < 浮窗自动关闭的 8s：
    /// 窗口内重复 bump 视为同一次复制；用户等浮窗关掉后再复制必然 > 6s，能重新触发。
    private static let sameTextWindow: TimeInterval = 6.0

    func start() {
        guard timer == nil else { return }
        // 启动时同步一次基线，避免「上一会话残留剪贴板」进来立刻误触发
        lastChangeCount = NSPasteboard.general.changeCount
        let t = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        NSLog("[dimmi][clip] ClipboardMonitor started")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        NSLog("[dimmi][clip] ClipboardMonitor stopped")
    }

    /// 从 AppState 同步最新参数（剪切板不会自动 pick up 配置变化）。
    func applyConfig() {
        let s = AppState.shared
        self.minLength = s.selectionMinLength
        self.maxLength = s.selectionMaxLength
        self.cooldown = s.selectionCooldown
    }

    /// 由 PanelController 在「用户点了复制按钮，dimmi 自己写粘贴板」之前调用。
    /// 让下一次 changeCount 变化被吃掉，避免把刚复制出去的译文当成新一轮源文。
    /// 窗口 2.5s 足够覆盖 ⌘C 模拟本身 + 系统 NSPasteboard 偶尔多写一两帧。
    func suppressNextChange() {
        selfWriteSkipOnce = true
        selfWriteSuppressedUntil = Date().addingTimeInterval(2.5)
        NSLog("[dimmi][clip] suppressNextChange 启用 2.5s")
    }

    private func tick() {
        let pb = NSPasteboard.general
        let cur = pb.changeCount
        guard cur != lastChangeCount else { return }
        lastChangeCount = cur

        // 吃掉 dimmi 自己写的那一次剪贴板变化。
        // skipOnce = 必吃这一次；suppressedUntil 是兜底：万一 dimmi 写出去之后
        // 系统又自动追加了一次（比如某 toolbar 在 changeCount 后又补一帧），也跳过。
        if selfWriteSkipOnce || Date() < selfWriteSuppressedUntil {
            selfWriteSkipOnce = false
            NSLog("[dimmi][clip] 跳过自写粘贴板变化（避免把刚复制的译文当作新一轮源文）")
            return
        }

        // 只在 changeCount 真变化时读 string。
        // 部分 App（PDF 阅读器 / Word 系）复制时只放富文本不放 .string，
        // 纯 .string 读取会拿到 nil → 用户按了 ⌘C 却毫无反应。
        // 兜底：降级读 NSAttributedString 再取纯文本。
        let raw: String
        if let s = pb.string(forType: .string) {
            raw = s
        } else if let attr = pb.readObjects(forClasses: [NSAttributedString.self],
                                            options: nil)?.first as? NSAttributedString {
            NSLog("[dimmi][clip] .string 为空，从富文本降级取出 len=%d", attr.string.count)
            raw = attr.string
        } else {
            NSLog("[dimmi][clip] changeCount %d 但读不到文本（可能是图片/文件粘贴）", cur)
            return
        }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // 长度过滤：太短太长都跳过
        guard text.count >= minLength, text.count <= maxLength else {
            NSLog("[dimmi][clip] 长度过滤跳过: len=\(text.count)")
            return
        }
        let now = Date()
        // 同一段文本只在短窗口内去重，**不许永久**：
        // 以前 lastText 永不过期 → 浮窗自动关闭后把同一句再 ⌘C 一次 = 死寂
        // （"有时候无响应"的最高频来源）。
        // 窗口内的重复来自同一次复制的多重写入（很多 App 一次 ⌘C 会 bump 两次
        // changeCount）；窗口外的重复复制是用户明确想再看一次。
        // 浮窗还开着时，PanelController 的同文去重会兜底，不会闪两次。
        if text == lastText, now.timeIntervalSince(lastTriggerAt) < Self.sameTextWindow { return }
        // 冷却
        if now.timeIntervalSince(lastTriggerAt) < cooldown { return }

        lastText = text
        lastTriggerAt = now
        NSLog("[dimmi][clip] 触发翻译 len=%d", text.count)
        onClipboardChange?(text, NSEvent.mouseLocation)
    }
}
