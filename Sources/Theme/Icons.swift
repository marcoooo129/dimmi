// 全 App 图标唯一事实来源（Phosphor Swift）。
//
// 图标铁律（每条都曾是事故）：
//   1. 全 App 只用 `.thin` 字重（「褪色黄昏」的线条更细）。
//      唯一例外：主操作圆钮内的图标用 `.regular`（暖白底上细线会消失）。
//   2. 只用 DimmiTheme.icon / .iconMuted 两种颜色。禁止彩色图标、彩色容器方块。
//   3. 尺寸只有三档：15（胶囊内）、19（设置行）、22（浮窗操作）。
//   4. 视图里一律写 `DimmiIcon.apiKey.thin`，不直接写 `Ph.xxx`。
//   5. Phosphor 图标默认 resizable，**必须显式 .frame(width:height:)**，
//      否则撑满父容器。
//   6. 用 `.color()` 上色，不是 `.foregroundStyle()`。
//   7. 禁止 `Image(systemName:)`。改造后全局应仅剩菜单栏 NSStatusItem 一处。
import SwiftUI
import PhosphorSwift

enum DimmiIcon {
    // 核心
    nonisolated(unsafe) static let translate  = Ph.translate      // app 图标位 / 菜单栏
    nonisolated(unsafe) static let apiKey     = Ph.key
    nonisolated(unsafe) static let shortcuts  = Ph.command
    nonisolated(unsafe) static let about      = Ph.info
    nonisolated(unsafe) static let chevron    = Ph.caretRight
    nonisolated(unsafe) static let back       = Ph.arrowLeft
    nonisolated(unsafe) static let copy       = Ph.copy
    nonisolated(unsafe) static let close      = Ph.x
    nonisolated(unsafe) static let check      = Ph.check           // 主操作圆钮内
    nonisolated(unsafe) static let privacy    = Ph.lockSimple
    nonisolated(unsafe) static let help       = Ph.question
    nonisolated(unsafe) static let trash      = Ph.trash
    nonisolated(unsafe) static let search     = Ph.magnifyingGlass
    nonisolated(unsafe) static let minus      = Ph.minus
    nonisolated(unsafe) static let plus       = Ph.plus

    // 历史窗话题
    nonisolated(unsafe) static let topicAll     = Ph.tray
    nonisolated(unsafe) static let topicGreet   = Ph.handWaving
    nonisolated(unsafe) static let topicShop    = Ph.shoppingBag
    nonisolated(unsafe) static let topicEmotion = Ph.heart
    nonisolated(unsafe) static let topicOther   = Ph.dotsThree

    // ═══════════════════════════════════════════════════════════
    // 以下为【迁移期兼容层】——历史窗 / 浮窗 / Onboarding / 设置子页
    // 还在引用的旧成员。阶段 2-4 换皮时逐个消灭，最后整段删除。
    // ═══════════════════════════════════════════════════════════

    nonisolated(unsafe) static let translation   = Ph.translate
    nonisolated(unsafe) static let info          = Ph.info
    nonisolated(unsafe) static let checkOk       = Ph.checkCircle
    nonisolated(unsafe) static let checkFail     = Ph.xCircle
    nonisolated(unsafe) static let settings      = Ph.gearSix
    nonisolated(unsafe) static let clearCache    = Ph.trash
    nonisolated(unsafe) static let logout        = Ph.signOut
    nonisolated(unsafe) static let helpLarge     = Ph.question
    nonisolated(unsafe) static let settingsGear  = Ph.gearSix
    nonisolated(unsafe) static let arrowRight    = Ph.caretRight
    nonisolated(unsafe) static let checkmark     = Ph.checkCircle
    nonisolated(unsafe) static let xmark         = Ph.xCircle
    nonisolated(unsafe) static let warning       = Ph.warning
    nonisolated(unsafe) static let sparkle       = Ph.sparkle
    nonisolated(unsafe) static let eye           = Ph.eye
    nonisolated(unsafe) static let eyeSlash      = Ph.eyeSlash
    nonisolated(unsafe) static let obSelect      = Ph.cursorText
    nonisolated(unsafe) static let obTranslate   = Ph.sparkle
    nonisolated(unsafe) static let obShortcut    = Ph.keyboard
    nonisolated(unsafe) static let obDone        = Ph.checkCircle
    nonisolated(unsafe) static let noteIdiom     = Ph.bookOpen
}

// MARK: - 尺寸常量（新规范三档）

enum DimmiIconSize {
    // v5 收紧一档
    static let pill:  CGFloat = 14    // 胶囊内   （15→14）
    static let row:   CGFloat = 18    // 设置行   （19→18）
    static let panel: CGFloat = 20    // 浮窗操作 （22→20）

    /// 迁移期兼容：旧代码的行内档（阶段 4 删）
    static let inline: CGFloat = 15    // （16→15）
}

// MARK: - 快捷修饰

extension View {
    /// 新规范图标修饰：thin 线条 + 主题色 + 强制 frame（防撑满容器）。
    /// 调用方对 `DimmiIcon.xxx.thin` 使用。
    func dimmiIcon(size: CGFloat, muted: Bool = false) -> some View {
        self
            .color(muted ? DimmiTheme.iconMuted : DimmiTheme.icon)
            .frame(width: size, height: size)
    }

    /// 迁移期兼容：旧 Dia 修饰（阶段 4 删）
    func diaIcon(_ scheme: ColorScheme, size: CGFloat = DimmiIconSize.row) -> some View {
        self
            .color(DimmiTheme.icon(scheme))
            .frame(width: size, height: size)
    }
}
