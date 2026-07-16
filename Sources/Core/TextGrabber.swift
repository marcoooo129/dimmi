// 取词：首选读焦点元素的 AX 选区；拿不到再走 ⌘C 剪贴板兜底（并完整还原）。
import AppKit
import ApplicationServices

enum TextGrabber {
    /// 自动划词的 ⌘C 兜底采用短间隔自适应轮询：常见 App 在 4–20ms
    /// 内写好剪贴板，最慢仍保留约 110ms 的兼容窗口。
    static let copyPollingIntervals: [TimeInterval] = [
        0.004, 0.006, 0.010, 0.014, 0.020, 0.026, 0.030
    ]

    enum CopyPollingDecision: Equatable {
        case wait
        case complete(String?)
    }

    private struct PasteboardSnapshot {
        let string: String?
        let types: [NSPasteboard.PasteboardType]
        let data: [NSPasteboard.PasteboardType: Data]
        let changeCount: Int
    }

    /// 首选：不碰剪贴板，直接读焦点元素的选中文本。
    /// 多数原生 App（Safari、备忘录、TextEdit、PDF）都能拿到。
    static func selectedTextViaAX() -> String? {
        let system = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        guard AXUIElementCopyAttributeValue(
                system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused else { return nil }
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(
                element as! AXUIElement, kAXSelectedTextAttribute as CFString, &value) == .success
        else { return nil }
        return (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 兜底：模拟 ⌘C 读剪贴板，读完完整还原剪贴板原内容。
    /// 部分 Electron 应用 / 老浏览器拿不到 AX 选区时走这里。
    ///
    /// 关键：必须备份**所有类型**（图片/文件/URL/...），不能只备份 .string。
    /// 用户截图后如果只备份字符串，会丢截图。
    static func selectedTextViaCopy(fallbackToExistingClipboard: Bool = false) -> String? {
        let pb = NSPasteboard.general
        let snapshot = capturePasteboard(pb)
        NSLog("[dimmi][clipboard] types before=%@ count=%d",
              snapshot.types.map { $0.rawValue }, snapshot.types.count)

        simulateCmdC()

        var result: String?
        var completed = false
        for (index, interval) in copyPollingIntervals.enumerated() {
            usleep(useconds_t(interval * 1_000_000))
            let decision = copyPollingDecision(
                savedString: snapshot.string,
                copiedString: readText(from: pb),
                pasteboardChanged: pb.changeCount != snapshot.changeCount,
                fallbackToExistingClipboard: fallbackToExistingClipboard,
                attempt: index + 1
            )
            switch decision {
            case .wait:
                continue
            case .complete(let value):
                result = value
                completed = true
            }
            if completed { break }
        }

        if !completed {
            result = resolvedCopyResult(
                savedString: snapshot.string,
                copiedString: readText(from: pb),
                pasteboardChanged: pb.changeCount != snapshot.changeCount,
                fallbackToExistingClipboard: fallbackToExistingClipboard
            )
        }

        NSLog("[dimmi][clipboard] simulate success=%@ len=%d changeCount=%d->%d",
              result == nil ? "false" : "true",
              result?.count ?? 0,
              snapshot.changeCount, pb.changeCount)
        restorePasteboard(snapshot, to: pb)
        return result
    }

    /// 自动划词专用的非阻塞兜底。AX 命中会在当前主线程回调；AX 不支持时
    /// 模拟 ⌘C 并用 Task.sleep 短轮询，绝不再用 usleep 卡住浮窗主线程。
    @MainActor
    static func selectedTextForAutomaticSelection(
        completion: @escaping (String?) -> Void
    ) {
        if let text = selectedTextViaAX(), !text.isEmpty {
            completion(text)
            return
        }

        let pb = NSPasteboard.general
        let snapshot = capturePasteboard(pb)
        simulateCmdC()

        Task { @MainActor in
            var result: String?
            var copiedChangeCount: Int?
            var completed = false

            for (index, interval) in copyPollingIntervals.enumerated() {
                do {
                    try await Task.sleep(
                        nanoseconds: UInt64(interval * 1_000_000_000)
                    )
                } catch {
                    return
                }

                let changed = pb.changeCount != snapshot.changeCount
                if changed { copiedChangeCount = pb.changeCount }
                let decision = copyPollingDecision(
                    savedString: snapshot.string,
                    copiedString: readText(from: pb),
                    pasteboardChanged: changed,
                    fallbackToExistingClipboard: false,
                    attempt: index + 1
                )
                switch decision {
                case .wait:
                    continue
                case .complete(let value):
                    result = value
                    completed = true
                }
                if completed { break }
            }

            if !completed {
                result = resolvedCopyResult(
                    savedString: snapshot.string,
                    copiedString: readText(from: pb),
                    pasteboardChanged: pb.changeCount != snapshot.changeCount,
                    fallbackToExistingClipboard: false
                )
            }

            // 先让调用方弹出 loading 卡；剪贴板恢复放到下一主循环，不挡住首帧。
            completion(result)
            guard let expectedChangeCount = copiedChangeCount else { return }
            DispatchQueue.main.async {
                // 用户若在这期间主动复制了新内容，绝不能再用旧快照覆盖它。
                guard pb.changeCount == expectedChangeCount else { return }
                restorePasteboard(snapshot, to: pb)
            }
        }
    }

    /// 轮询是否继续的纯逻辑，供回归测试覆盖“新值立刻完成 / 超时不误用旧值”。
    static func copyPollingDecision(
        savedString: String?,
        copiedString: String?,
        pasteboardChanged: Bool,
        fallbackToExistingClipboard: Bool,
        attempt: Int
    ) -> CopyPollingDecision {
        if pasteboardChanged,
           let copiedString,
           !copiedString.isEmpty {
            return .complete(copiedString)
        }
        if attempt < copyPollingIntervals.count {
            return .wait
        }
        return .complete(
            resolvedCopyResult(
                savedString: savedString,
                copiedString: copiedString,
                pasteboardChanged: pasteboardChanged,
                fallbackToExistingClipboard: fallbackToExistingClipboard
            )
        )
    }

    /// 把剪贴板变化判定抽成无副作用函数，便于回归测试。
    /// 自动划词仅接受这次合成 ⌘C 产生的新内容；手动入口才能选择旧剪贴板兜底。
    static func resolvedCopyResult(
        savedString: String?,
        copiedString: String?,
        pasteboardChanged: Bool,
        fallbackToExistingClipboard: Bool
    ) -> String? {
        if pasteboardChanged, let copiedString, !copiedString.isEmpty {
            return copiedString
        }
        guard fallbackToExistingClipboard, let savedString, !savedString.isEmpty else {
            return nil
        }
        return savedString
    }

    /// 手动入口（菜单 / 全局快捷键）：AX 优先，只在必须合成 ⌘C 时
    /// 拒绝 ClipboardMonitor 的下一次变化，避免手动翻译同时又触发自动翻译。
    @MainActor
    static func selectedTextForManualTrigger() -> String? {
        if let s = selectedTextViaAX(), !s.isEmpty { return s }
        AppState.shared.clipboardMonitor.suppressNextChange()
        return selectedTextViaCopy(fallbackToExistingClipboard: true)
    }

    /// 兼容旧调用：AX 优先，nil 时同步兜底。
    static func selectedText() -> String? {
        if let s = selectedTextViaAX(), !s.isEmpty { return s }
        if let s = selectedTextViaCopy(fallbackToExistingClipboard: false), !s.isEmpty { return s }
        return nil
    }

    private static func capturePasteboard(_ pb: NSPasteboard) -> PasteboardSnapshot {
        let types = pb.types ?? []
        var data: [NSPasteboard.PasteboardType: Data] = [:]
        for type in types {
            if let value = pb.data(forType: type) {
                data[type] = value
            }
        }
        return PasteboardSnapshot(
            string: readText(from: pb),
            types: types,
            data: data,
            changeCount: pb.changeCount
        )
    }

    private static func readText(from pb: NSPasteboard) -> String? {
        let raw: String?
        if let string = pb.string(forType: .string) {
            raw = string
        } else if let attributed = pb.readObjects(
            forClasses: [NSAttributedString.self],
            options: nil
        )?.first as? NSAttributedString {
            raw = attributed.string
        } else {
            raw = nil
        }
        return raw?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func restorePasteboard(
        _ snapshot: PasteboardSnapshot,
        to pb: NSPasteboard
    ) {
        if snapshot.data.isEmpty {
            pb.clearContents()
            NSLog("[dimmi][clipboard] restored: clipboard was empty, cleared")
            return
        }
        pb.declareTypes(snapshot.types, owner: nil)
        for type in snapshot.types {
            if let data = snapshot.data[type] {
                pb.setData(data, forType: type)
            }
        }
        NSLog("[dimmi][clipboard] restored: %d types %@",
              snapshot.data.count, snapshot.types.map { $0.rawValue })
    }

    private static func simulateCmdC() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let loc = CGEventTapLocation.cghidEventTap
        let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: 0x37, keyDown: true)
        let cDown   = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: true)
        cDown?.flags = .maskCommand
        let cUp     = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: false)
        cUp?.flags = .maskCommand
        let cmdUp   = CGEvent(keyboardEventSource: src, virtualKey: 0x37, keyDown: false)
        cmdDown?.post(tap: loc)
        cDown?.post(tap: loc)
        cUp?.post(tap: loc)
        cmdUp?.post(tap: loc)
    }
}
