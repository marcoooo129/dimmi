// 浮窗卡片的系统毛玻璃底：NSVisualEffectView 的 SwiftUI 桥。
//
// 材质选 .hudWindow（系统专为悬浮面板设计），不用 ultraThinMaterial ——
// 后者在浅色网页上会糊成一片白、边界消失（之前正是因此退回不透明白卡）。
// 若观感不满意，按顺序试 .popover（略亮）→ .menu（更实、模糊更强）；
// 不要用 .sidebar / .windowBackground（主窗口材质，浮窗上会偏色）。
//
// 两个硬性要求（都是"毛玻璃变灰板"的经典翻车点）：
//   1. state 必须钉死 .active：浮窗是 nonactivatingPanel，永远不是 key window，
//      系统会判它 inactive 并把材质降级成灰色平板。makeNSView 和
//      updateNSView 里都要设，防止任何一次更新被系统降回去。
//   2. blendingMode 必须 .behindWindow：模糊的是窗口背后的网页 / 桌面内容；
//      .withinWindow 只模糊窗口内部，对透明浮窗毫无效果。
import SwiftUI
import AppKit

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blending: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = .active
        v.isEmphasized = false
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.blendingMode = blending
        v.state = .active   // 每次更新都钉住，防系统降级为 inactive
    }
}
