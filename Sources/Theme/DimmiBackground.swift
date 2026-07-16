// Dimmi 窗口背景 ——「褪色黄昏」三团光斑 + 暖色渐变。
//
// 真玻璃需要背后有内容可模糊，所以背景【必须真的画出来】这三团 Circle。
// 任意一个被省掉，玻璃就会退化成死的半透明片。
//
// 三团：
//   - 暖沙光（warm）：左上偏中，粉调
//   - 沙色光（sand）：右上，亮沙
//   - 暗紫褐光（dark）：左下，压暗收尾
//
// 背景色域 = 暖灰紫（#5F5359）渐变到亮沙（#B3A085），与浮窗深玻璃同色系但浅。
import SwiftUI

struct DimmiBackground: View {
    /// 窗的尺寸通过 GeometryReader 自适应；不能写死半径（设置 960、引导 540、
    /// 历史 820 三个窗宽差近一倍，固定半径会让大窗光晕缩中间、小窗糊满）。
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        DimmiTheme.bgTop,
                        DimmiTheme.bgUpper,
                        DimmiTheme.bgMid,
                        DimmiTheme.bgLight,
                        DimmiTheme.bgLower,
                        DimmiTheme.bgBottom
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Circle()
                    .fill(DimmiTheme.blobWarm)
                    .frame(width: 440, height: 440)
                    .offset(x: -180, y: -120)
                    .blur(radius: 70)

                Circle()
                    .fill(DimmiTheme.blobSand)
                    .frame(width: 420, height: 420)
                    .offset(x: 180, y: -60)
                    .blur(radius: 75)

                Circle()
                    .fill(DimmiTheme.blobDark)
                    .frame(width: 460, height: 460)
                    .offset(x: -120, y: 180)
                    .blur(radius: 80)
            }
            .ignoresSafeArea()
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}