import SwiftUI

/// 应用内统一品牌符号。Asset 保持透明底，避免在玻璃卡上出现白边或双层圆角。
struct DimmiBrandMark: View {
    let size: CGFloat

    init(size: CGFloat) {
        self.size = size
    }

    var body: some View {
        Image("DimmiBrandMark")
            .resizable()
            .renderingMode(.original)
            .interpolation(.high)
            .antialiased(true)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
