// 全局快捷键：
//   ⌘⇧T —— 正向翻译（中文 → target）
//   ⌘⇧B —— 反向翻译（target → 中文，仅当用户在设置里开启 reverseTranslateEnabled 时响应）
//
// 主路径（无 a11y）：模拟 ⌘C，读 NSPasteboard.general.string（无需任何 TCC 授权）。
// 兜底：用户授权 a11y 时优先用 AX 选区（更快更稳）。
import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// 正向：中文 → targetLanguage
    static let triggerTranslate = Self("triggerTranslate", default: .init(.t, modifiers: [.command, .shift]))
    /// 反向：targetLanguage → 中文
    static let triggerReverseTranslate = Self("triggerReverseTranslate", default: .init(.b, modifiers: [.command, .shift]))
}

@MainActor
enum GlobalShortcut {
    /// 安装快捷键回调。
    static func install() {
        KeyboardShortcuts.onKeyDown(for: .triggerTranslate) {
            runForward()
        }
        KeyboardShortcuts.onKeyDown(for: .triggerReverseTranslate) {
            runReverse()
        }
    }

    // MARK: - 内部

    private static func grabbedText() -> String? {
        TextGrabber.selectedTextForManualTrigger()
    }

    private static func runForward() {
        guard let text = grabbedText(), !text.isEmpty else {
            NSLog("[dimmi] ⌘⇧T：未取到文本，先用 ⌘C 复制要翻译的内容再试。")
            NSSound.beep()
            return
        }
        PanelController.shared.triggerTranslation(for: text, at: NSEvent.mouseLocation)
    }

    private static func runReverse() {
        // 用户在设置里关了反向 → 不响应 ⌘⇧B，给一声 NSLog 即可
        guard UserPrefs.reverseTranslateEnabled else {
            NSLog("[dimmi] ⌘⇧B：反向翻译未开启，可在「设置 → 翻译」开启。")
            return
        }
        guard let text = grabbedText(), !text.isEmpty else {
            NSLog("[dimmi] ⌘⇧B：未取到文本，先用 ⌘C 复制要翻译的内容再试。")
            NSSound.beep()
            return
        }
        PanelController.shared.triggerReverseTranslation(for: text, at: NSEvent.mouseLocation)
    }
}
