// 翻译浮窗的 NSHostingView 子类：实现「卡片下方空白区点击穿透」+ 卡片尺寸回传。
//
// 任务书第六节：
//   1. NSPanel 固定 340 × 420
//   2. 卡片常驻 SwiftUI 树，宽度 340、顶对齐
//   3. 卡片下方空白区域点击穿透到下层 App（不要 420 大的死区）
//   4. 不使用 if #available 包住整个类（hosting view 永远存在 macOS 14+ 即可）
import AppKit
import SwiftUI

/// 简单回写卡片高度到原生视图，让 hitTest 知道当前"卡片区"在哪里。
final class PanelCardHitRegion: ObservableObject {
    /// SwiftUI 测得的实际卡片高度
    @Published var cardHeight: CGFloat = 0
}

final class TranslationPanelHostingView: NSHostingView<AnyView> {
    private let region: PanelCardHitRegion

    init(region: PanelCardHitRegion, rootView: AnyView) {
        self.region = region
        super.init(rootView: rootView)
        // 用 frame-based，告诉 SwiftUI 父容器宽高都按 panel 内容区来
        self.translatesAutoresizingMaskIntoConstraints = true
        // 强制 NSHostingView 不要把自己的 layer 做背景填充
        self.layer?.backgroundColor = .clear
        self.wantsLayer = true
    }

    @MainActor required init(rootView: AnyView) {
        fatalError("init(rootView:) not supported; use init(region:rootView:)")
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    /// AppKit 坐标系（原点左下）：卡片贴窗口顶部内缩 bloomMargin，向下生长。
    /// cardHeight = 0 → 命中测试穿透整个区域（隐藏态）。
    /// cardHeight = X → 命中卡片那一块矩形。
    ///
    /// 卡片只占窗口中间一块：窗口四周留了 bloomMargin 的透明留白给辉光。
    /// 这里必须按卡片的真实矩形算——拿 bounds.width 当卡片宽会把留白也算成卡片，
    /// 点在卡片旁边就穿不下去了（这个类存在的意义就是让空白处穿透）。
    override func hitTest(_ point: NSPoint) -> NSView? {
        let h = region.cardHeight
        guard h > 0 else { return nil }   // 隐藏态：完全穿透
        let margin = PanelMetrics.bloomMargin
        let cardTop = bounds.maxY - margin - h
        // 兼容一下容差 4pt（防止用户点边缘）
        let cardRect = NSRect(x: margin - 4, y: cardTop - 4,
                              width: PanelMetrics.cardWidth + 8,
                              height: h + 8)
        guard cardRect.contains(point) else { return nil }
        // 仅当确实落在卡片内才往下走，让 SwiftUI 决定按钮 hit-test
        return super.hitTest(point)
    }
}
