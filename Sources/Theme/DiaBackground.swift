// Dia 风格的窗口背景：单色径向光晕。
//
// 不再蓝橘双色块。光晕只有一个、粉调、位于上半部。
//
// 注意：RadialGradient 本身就是软的，不要再 .blur() ——会出色带。
//
// 半径跟着窗口尺寸走，不要写死：设置 640、引导 540、历史 820 三个窗宽差一倍，
// 固定半径会让大窗的光晕缩成中间一坨、小窗又糊满。用对角线长度做基准，
// 三个窗看起来才是同一套背景。
import SwiftUI

struct DiaBackground: View {
    @Environment(\.colorScheme) private var scheme

    /// 光晕中心：上半部偏中。y 再小光晕会被标题栏区域切掉一半。
    private let center = UnitPoint(x: 0.5, y: 0.28)

    var body: some View {
        GeometryReader { geo in
            let diagonal = sqrt(geo.size.width * geo.size.width
                              + geo.size.height * geo.size.height)

            ZStack {
                DimmiTheme.bgBase(scheme)

                RadialGradient(
                    colors: [
                        DimmiTheme.bgGlow(scheme),
                        DimmiTheme.bgGlowEdge(scheme),
                        .clear
                    ],
                    center: center,
                    startRadius: 0,
                    endRadius: diagonal * 0.72
                )
                // 禁止加 .blur() — RadialGradient 本身已软，blur 会起色带。
            }
            .ignoresSafeArea()
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
