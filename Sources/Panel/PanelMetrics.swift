// 浮窗的全部尺寸常量 —— **唯一事实来源**。
//
// 视图、PanelViewModel（离屏测高）、PanelController（开窗 / 定位 / hitTest）、
// TranslationPanelHostingView（穿透判定）四边必须读同一份，谁也不许再就地写字面量：
// 之前 view 按 308 渲染文字、ViewModel 按 276 测高，卡片底部因此长期多出一截空白。
//
// 窗口是透明的，比卡片大一圈。这圈 bloomMargin 不可见，
// 但阴影超出它就会被窗口边缘齐刷刷切断，必须 ≥ 阴影最大外扩
// （当前中性阴影 radius 28 + y 12 ≈ 40pt）。
// 注意：浮窗只允许中性阴影，不允许 diaBloomShadow ——
// 玫瑰辉光叠在透明窗下的网页上是粉色胶片，那是设置窗（实底）专属。
//
// 纯常量，不要加 @available：TranslationPanelHostingView 没有版本门，也要读这里。
import CoreGraphics

enum PanelMetrics {
    /// 卡片视觉宽度（不含外圈留白）
    static let cardWidth: CGFloat = 340
    /// 卡内 padding
    static let cardPadding: CGFloat = 16
    /// 样图采用更克制的连续圆角；所有裁切、描边共用同一个值
    static let cardCornerRadius: CGFloat = 24
    /// 文本可用宽 —— 测量与渲染共用
    static let contentWidth: CGFloat = cardWidth - 2 * cardPadding      // 308
    /// Analisi 行在 contentWidth 内被标签、间距和 padding 占掉的宽度
    static let analysisTextInset: CGFloat = 88
    /// 顶栏右侧复制/关闭按钮及间距；原生拖动区必须避开这一段
    static let headerActionsWidth: CGFloat = 88
    /// 卡片高度封顶：长译文时多给 Analisi 40pt，仍超出则内部滚动
    static let cardMaxHeight: CGFloat = 500
    /// ScrollView 最底部安全留白，避免最后一行贴住连续圆角被视觉裁切
    static let scrollBottomClearance: CGFloat = 12
    /// 新头部 + 原文预览 + 分隔线的自然加载态高度
    static let minCardHeight: CGFloat = 134
    /// 卡外留白：给阴影 + 辉光的呼吸空间
    static let bloomMargin: CGFloat = 40
    /// 窗口尺寸 = 卡片 + 两侧留白
    static let panelWidth: CGFloat = cardWidth + 2 * bloomMargin        // 420
    static let panelHeight: CGFloat = cardMaxHeight + 2 * bloomMargin + 60  // 640
}
