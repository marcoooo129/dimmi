// 骨架条 + 扫光：loading 期间展示，比 ProgressView / Spinner 更克制。
//
// 铁律（任务书修复 a）：
//   - 永远是【一条】，放在统一的最小加载态卡片里。不是版式预告，不是预估行数。
//   - 不允许在译文未返回前变多条、变高。
//
// 关键：
//   - 不含 material / glass —— loading 阶段还没"已渲染"的玻璃卡片，
//     不放材质层，避免切换时闪烁。
//   - 扫光是「额外一层 LinearGradient」+ offset 动画，
//     不修改 bar 自己的 fill，避免高光带走过时遗留底色残影。
//   - 不在 withAnimation 里改 fill / frame —— 只改 offset，纯位移补动画。
import SwiftUI

// MARK: - 单条骨架（永远是 1 条，不预测长度）

struct LoadingSkeletonBar: View {
    /// 占容器宽度的比例（默认 0.65，留白让条看起来像「没写完的字」）
    var widthFraction: CGFloat = 0.65
    var height: CGFloat = 12
    var cornerRadius: CGFloat = 4

    @State private var shimmerPhase: CGFloat = -1
    private let cycleDuration: Double = 1.2

    var body: some View {
        GeometryReader { proxy in
            let barWidth = proxy.size.width
            let highlightWidth: CGFloat = 80
            let centerX = (shimmerPhase + 1) / 2
            let highlightOffset = (centerX * barWidth) - (highlightWidth / 2)

            // 浮窗自身是固定暖色玻璃，不再跟随系统浅/深色切换骨架颜色。
            let baseColor: Color = .white.opacity(0.10)
            let shimmerColor: Color = .white.opacity(0.22)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(baseColor)
                LinearGradient(
                    colors: [Color.clear, shimmerColor, Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: highlightWidth)
                .offset(x: highlightOffset)
                .mask(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
            }
            .frame(width: barWidth * widthFraction)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onAppear {
                withAnimation(.linear(duration: cycleDuration).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - 兼容别名
/// 之前的 LoadingSkeletonStack 是多条的「按预估行数」循环；
/// 已被任务书禁止。保留同名以防其他地方调用，直接路由成单条。
struct LoadingSkeletonStack: View {
    var delayMs: Int = 400
    @State private var showSkeleton: Bool = false
    var body: some View {
        LoadingSkeletonBar(widthFraction: 0.65)
            .opacity(showSkeleton ? 1 : 0)
            .task {
                try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeIn(duration: 0.2)) {
                    showSkeleton = true
                }
            }
    }
}
