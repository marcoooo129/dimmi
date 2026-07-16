// Dimmi 翻译浮窗的"发光玻璃"装饰元素。
//
// 与 Dimmi 网页设计稿（"Luminous Glass Translation"）对应：
//   - AuroraOrbBackground：卡内极光球（粉 / 紫 / 青三色 radial gradient + 慢速浮动）
//   - SiriWave：四根 bar 上下脉动模拟 Siri 波形
//   - NoiseOverlay：SVG turbulence 等价的噪点叠层，给卡表面"颗粒感"
//
// 重要约束：aurora 球必须在 cardLayer 的 clipShape 之内，不能泄到透明窗外的网页上。
// 否则就是"粉色胶片"——浮窗禁忌。所以这里的组件都 fit 父容器，依赖外层裁剪。
import SwiftUI

// MARK: - Aurora 极光球（卡内版）

/// 三个 radial-gradient 球，慢速浮动模拟极光。
///
/// 与 HTML 版区别：球被限制在父 view 的 bounding box 内（不溢出）。
/// HTML 用 `position: absolute; top: -20%; left: -10%` 让球溢出 viewport 形成漫射光；
/// 卡内不能溢出（clipShape 会把光切掉），所以球直径缩小并居中分布，
/// blur 也从 100pt 降到 60pt（卡只有 340pt 宽，太大会糊成一片）。
struct AuroraOrbBackground: View {
    let scheme: ColorScheme

    /// 三个球的相位偏移，让它们不同步动。
    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            // 0.05 ≈ 一个 20s 周期，映射到 ±1 范围
            let f = CGFloat((t.truncatingRemainder(dividingBy: 20)) / 20.0) * 2 - 1
            ZStack {
                orb(color: DimmiTheme.auroraPink,
                    size: 220,
                    x: -30 + f * 12,
                    y: -40 + f * 8)
                orb(color: DimmiTheme.auroraPurple,
                    size: 260,
                    x: 110 - f * 10,
                    y: 80 + f * 14)
                orb(color: DimmiTheme.auroraTeal,
                    size: 180,
                    x: 50 + f * 8,
                    y: 30 - f * 10)
            }
            // 透明度：深色卡上极光更明显（深底 + 亮球 = 强对比）
            .opacity(scheme == .dark ? 0.55 : 0.30)
            .allowsHitTesting(false)
        }
    }

    private func orb(color: Color, size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        RadialGradient(
            colors: [color, color.opacity(0)],
            center: .center,
            startRadius: 0,
            endRadius: size / 2
        )
        .frame(width: size, height: size)
        .blur(radius: 60)
        .offset(x: x, y: y)
    }
}

// MARK: - Siri Wave（4 条 bar 上下脉动）

/// Dimmi logo 旁的波形指示器。设计稿里加载/活跃时持续脉动。
struct SiriWave: View {
    var height: CGFloat = 16
    var color: Color = .white

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            bar(heightRatio: 0.40, delay: 0.0)
            bar(heightRatio: 0.80, delay: 0.2)
            bar(heightRatio: 1.00, delay: 0.4)
            bar(heightRatio: 0.60, delay: 0.6)
        }
        .frame(height: height)
    }

    private func bar(heightRatio: CGFloat, delay: Double) -> some View {
        SiriWaveBar(color: color, maxHeight: height, heightRatio: heightRatio, delay: delay)
    }
}

private struct SiriWaveBar: View {
    let color: Color
    let maxHeight: CGFloat
    let heightRatio: CGFloat
    let delay: Double

    @State private var pulsing = false

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [DimmiTheme.auroraPink, DimmiTheme.auroraPurple],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 3, height: pulsing ? maxHeight * heightRatio : maxHeight * 0.30)
            .opacity(pulsing ? 1.0 : 0.5)
            .animation(
                .easeInOut(duration: 0.75)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: pulsing
            )
            .onAppear { pulsing = true }
    }
}

// MARK: - Noise Overlay（颗粒感）

/// 设计稿里那张 0.03 opacity 的 SVG turbulence 噪点。
/// SwiftUI 没有原生 turbulence，用 Canvas + 伪随机点阵近似——远处看不出差别，
/// 又不会因为引第三方包拖慢启动。
struct NoiseOverlay: View {
    var opacity: Double = 0.04
    var blendMode: BlendMode = .overlay

    var body: some View {
        Canvas { ctx, size in
            // 每像素一个伪随机点（极稀疏，肉眼看不到单个点，叠起来是颗粒感）
            let step: CGFloat = 1.5
            for x in stride(from: 0, to: size.width, by: step) {
                for y in stride(from: 0, to: size.height, by: step) {
                    let h = pseudoRandom(x: x, y: y)
                    let a = Double(h) * opacity
                    ctx.fill(
                        Path(CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(.white.opacity(a))
                    )
                }
            }
        }
        .opacity(opacity)
        .blendMode(blendMode)
        .allowsHitTesting(false)
    }

    /// 位置 → 伪随机 0-1。sin 哈希够稳，颗粒分布均匀。
    private func pseudoRandom(x: CGFloat, y: CGFloat) -> CGFloat {
        let s = sin(x * 12.9898 + y * 78.233) * 43758.5453
        return CGFloat(s - floor(s))
    }
}