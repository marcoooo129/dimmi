// 自动划词：监听全局鼠标 down / up，AX 快读优先，必要时才走异步 ⌘C 兜底。
import AppKit

@MainActor
final class SelectionMonitor {
    var onSelection: ((String, NSPoint) -> Void)?

    private var monitor: Any?
    private var lastTriggerAt: Date = .distantPast
    private var lastTriggeredText: String?
    /// stop/start 以及每次新 mouseDown 都递增，让旧回调自动失效。
    private var lifecycleGeneration: UInt = 0

    private var baselineText: String = ""
    private var mouseDownPoint: NSPoint = .zero

    private var minLength: Int = 2
    private var maxLength: Int = 200
    private var cooldown: TimeInterval = 1.5

    /// mouseUp 后仅等一帧内的 16ms，让目标 App 提交选区；不再固定等待 120ms。
    static let fastReadDelay: TimeInterval = 0.016
    /// AX 仍为空或返回旧基线时只再等 24ms，然后进入非阻塞 copy fallback。
    static let staleSelectionRetryDelay: TimeInterval = 0.024
    nonisolated static let clickDistanceThreshold: CGFloat = 3

    enum ReadDisposition: Equatable {
        case accept
        case retry
        case ignore
    }

    #if DEBUG
    private static let debugQueue = DispatchQueue(
        label: "com.frase.app.selection-debug",
        qos: .utility
    )
    #endif

    @discardableResult
    func start() -> Bool {
        guard monitor == nil else { return true }
        lifecycleGeneration &+= 1
        baselineText = ""
        lastTriggerAt = .distantPast
        lastTriggeredText = nil

        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] event in
            let eventType = event.type
            let eventPoint = NSEvent.mouseLocation
            let clickCount = event.clickCount
            let modifiers = event.modifierFlags
            DispatchQueue.main.async { [weak self] in
                self?.handleEvent(
                    type: eventType,
                    point: eventPoint,
                    clickCount: clickCount,
                    modifiers: modifiers
                )
            }
        }
        debug("SelectionMonitor started, monitor=\(monitor != nil)")
        return monitor != nil
    }

    func stop() {
        lifecycleGeneration &+= 1
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
            debug("SelectionMonitor stopped")
        }
    }

    var isRunning: Bool { monitor != nil }

    func applyConfig() {
        let state = AppState.shared
        minLength = state.selectionMinLength
        maxLength = state.selectionMaxLength
        cooldown = state.selectionCooldown
    }

    private func handleEvent(
        type: NSEvent.EventType,
        point: NSPoint,
        clickCount: Int,
        modifiers: NSEvent.ModifierFlags
    ) {
        switch type {
        case .leftMouseDown:
            // 新交互立即淘汰上一轮尚未返回的 AX/copy 回调。
            lifecycleGeneration &+= 1
            baselineText = TextGrabber.selectedTextViaAX() ?? ""
            mouseDownPoint = point
            debug("mouseDown baseline='\(baselineText.prefix(30))'")

        case .leftMouseUp:
            let generation = lifecycleGeneration
            let baseline = baselineText
            let downPoint = mouseDownPoint
            let startedAt = Date()
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.fastReadDelay) { [weak self] in
                self?.requestSelection(
                    expectedGeneration: generation,
                    baseline: baseline,
                    mouseDownPoint: downPoint,
                    mouseUpPoint: point,
                    clickCount: clickCount,
                    modifiers: modifiers,
                    startedAt: startedAt,
                    isRetry: false
                )
            }

        default:
            break
        }
    }

    private func requestSelection(
        expectedGeneration: UInt,
        baseline: String,
        mouseDownPoint: NSPoint,
        mouseUpPoint: NSPoint,
        clickCount: Int,
        modifiers: NSEvent.ModifierFlags,
        startedAt: Date,
        isRetry: Bool
    ) {
        guard monitor != nil, lifecycleGeneration == expectedGeneration else {
            debug("selection read ignored after monitor stopped/new gesture")
            return
        }

        let dragDistance = hypot(
            mouseUpPoint.x - mouseDownPoint.x,
            mouseUpPoint.y - mouseDownPoint.y
        )
        let isSelectionGesture = dragDistance >= Self.clickDistanceThreshold
            || clickCount >= 2
            || modifiers.contains(.shift)

        if let text = TextGrabber.selectedTextViaAX(), !text.isEmpty {
            switch Self.readDisposition(
                text: text,
                baseline: baseline,
                dragDistance: dragDistance,
                clickCount: clickCount,
                shiftDown: modifiers.contains(.shift),
                isRetry: isRetry
            ) {
            case .accept:
                emit(
                    text,
                    at: mouseUpPoint,
                    startedAt: startedAt,
                    source: isRetry ? "ax-retry" : "ax-fast"
                )
            case .ignore:
                debug("mouseUp skip same baseline without selection gesture")
            case .retry:
                scheduleRetry(
                    expectedGeneration: expectedGeneration,
                    baseline: baseline,
                    mouseDownPoint: mouseDownPoint,
                    mouseUpPoint: mouseUpPoint,
                    clickCount: clickCount,
                    modifiers: modifiers,
                    startedAt: startedAt
                )
            }
            return
        }

        if !isRetry {
            scheduleRetry(
                expectedGeneration: expectedGeneration,
                baseline: baseline,
                mouseDownPoint: mouseDownPoint,
                mouseUpPoint: mouseUpPoint,
                clickCount: clickCount,
                modifiers: modifiers,
                startedAt: startedAt
            )
            return
        }

        // AX 两次都拿不到时，仅对真实拖拽 / 双击 / Shift 选择走 ⌘C；
        // 普通单击不再每次都模拟复制。
        guard isSelectionGesture else {
            debug("mouseUp no AX text and no selection gesture")
            return
        }

        TextGrabber.selectedTextForAutomaticSelection { [weak self] text in
            guard let self,
                  self.monitor != nil,
                  self.lifecycleGeneration == expectedGeneration else { return }
            guard let text, !text.isEmpty else {
                self.debug("mouseUp no selection text after copy fallback")
                return
            }
            self.emit(text, at: mouseUpPoint, startedAt: startedAt, source: "copy-fallback")
        }
    }

    private func scheduleRetry(
        expectedGeneration: UInt,
        baseline: String,
        mouseDownPoint: NSPoint,
        mouseUpPoint: NSPoint,
        clickCount: Int,
        modifiers: NSEvent.ModifierFlags,
        startedAt: Date
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.staleSelectionRetryDelay) { [weak self] in
            self?.requestSelection(
                expectedGeneration: expectedGeneration,
                baseline: baseline,
                mouseDownPoint: mouseDownPoint,
                mouseUpPoint: mouseUpPoint,
                clickCount: clickCount,
                modifiers: modifiers,
                startedAt: startedAt,
                isRetry: true
            )
        }
    }

    private func emit(
        _ text: String,
        at point: NSPoint,
        startedAt: Date,
        source: String
    ) {
        guard text.count >= minLength, text.count <= maxLength else {
            debug("selection skip length=\(text.count)")
            return
        }

        let now = Date()
        if Self.shouldSuppressForCooldown(
            text: text,
            previousText: lastTriggeredText,
            elapsed: now.timeIntervalSince(lastTriggerAt),
            cooldown: cooldown
        ) {
            debug("selection suppressed duplicate text")
            return
        }

        lastTriggerAt = now
        lastTriggeredText = text
        let latencyMS = now.timeIntervalSince(startedAt) * 1_000
        debug("onSelection source=\(source) latency=\(Int(latencyMS))ms len=\(text.count)")
        onSelection?(text, point)
    }

    nonisolated static func readDisposition(
        text: String,
        baseline: String,
        dragDistance: CGFloat,
        clickCount: Int,
        shiftDown: Bool,
        isRetry: Bool
    ) -> ReadDisposition {
        guard text == baseline else { return .accept }
        let isSelectionGesture = dragDistance >= clickDistanceThreshold
            || clickCount >= 2
            || shiftDown
        guard isSelectionGesture else { return .ignore }
        return isRetry ? .accept : .retry
    }

    nonisolated static func shouldSuppressForCooldown(
        text: String,
        previousText: String?,
        elapsed: TimeInterval,
        cooldown: TimeInterval
    ) -> Bool {
        guard cooldown > 0, text == previousText else { return false }
        return elapsed < cooldown
    }

    /// Release 的鼠标热路径不再同步开关 /tmp 文件；DEBUG 才异步落盘。
    private func debug(_ message: @autoclosure () -> String) {
        #if DEBUG
        let value = message()
        NSLog("[dimmi][monitor] %@", value)
        Self.debugQueue.async {
            let path = "/tmp/dimmi-debug.log"
            let line = "[\(Date())] \(value)\n"
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: URL(fileURLWithPath: path))
            }
        }
        #endif
    }
}
