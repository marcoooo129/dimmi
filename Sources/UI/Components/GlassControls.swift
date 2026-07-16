// 「褪色黄昏」基础控件：主操作圆钮 / 玻璃胶囊按钮 / 文字按钮。
//
// 组件铁律：
//   - 主操作圆钮是全 App 唯一的实心元素。摆放必须 offset(y: -20)
//     压出玻璃卡/工具条的边界——层级靠重叠表达，不靠间距。这是整套语言
//     最有性格的一笔，不许"对齐整齐"。
//   - 胶囊全圆角（高度 ÷ 2），玻璃填充 + 只画上缘高光。
//   - 所有 hover / press 动画引用 Motion，不写魔法数字。
import SwiftUI
import PhosphorSwift

// MARK: - 主操作圆钮（全 App 唯一实心元素）

struct PrimaryCircleButton: View {
    let icon: Ph
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            // 圆钮内是唯一允许 .regular 字重的图标（暖白底上细线会消失）
            icon.regular
                .color(DimmiTheme.primaryFg)
                .frame(width: 23, height: 23)
                .frame(width: 56, height: 56)
                .background(Circle().fill(DimmiTheme.primaryFill))
                .shadow(color: DimmiTheme.primaryShadow, radius: 26, y: 8)
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.94 : 1)
        .animation(Motion.press, value: pressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressed = $0 }, perform: {})
    }
}

// MARK: - 玻璃胶囊按钮（次要操作）

struct GlassPillButton: View {
    let icon: Ph?
    let label: String
    let action: () -> Void
    @State private var hovered = false
    @State private var pressed = false

    init(icon: Ph? = nil, label: String, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {  // （7→6）
                if let icon {
                    icon.thin
                        .dimmiIcon(size: DimmiIconSize.pill)
                }
                Text(label)
                    .font(DimmiFont.poppins(12, .regular))   // （13→12）
                    .foregroundStyle(DimmiTheme.textBody)
            }
            .padding(.horizontal, 16)
            .frame(height: 36)
            .background(.ultraThinMaterial, in: Capsule())
            .background(
                Capsule().fill(hovered ? DimmiTheme.glassFillHover : DimmiTheme.glassFill)
            )
            .overlay(
                // 胶囊只画上缘高光：暖白 42%，1px
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: DimmiTheme.glassPillEdgeTop, location: 0.0),
                                .init(color: DimmiTheme.glassEdgeBottom, location: 0.7),
                            ],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.97 : 1)
        .animation(Motion.hover, value: hovered)
        .animation(Motion.press, value: pressed)
        .onHover { hovered = $0 }
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressed = $0 }, perform: {})
    }
}

// MARK: - 文字按钮（取消）

struct GhostTextButton: View {
    let label: String
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(DimmiFont.poppins(12, .regular))  // （13→12）
                .foregroundStyle(hovered ? DimmiTheme.textBody : DimmiTheme.textSecondary)
        }
        .buttonStyle(.plain)
        .animation(Motion.hover, value: hovered)
        .onHover { hovered = $0 }
    }
}

// MARK: - 保存按钮（毛玻璃胶囊主操作）
//
// 取代之前全 App 唯一的 PrimaryCircleButton（白色实心圆钮）。
// 设计目标：
//   - 与左下「隐私」「帮助」视觉语言统一：胶囊 + 玻璃填充 + 上缘高光
//   - 略宽、略亮，体现主操作地位
//   - 不引入新主题色：仍走暖白 + DimmiTheme.glassFill* + glassPillEdgeTop
//   - 高度 36 与 GlassPillButton 一致，靠 horizontal padding 体现「略宽」
struct SavePillButton: View {
    let title: String
    let icon: Ph?
    let action: () -> Void
    @State private var hovered = false
    @State private var pressed = false

    init(title: String = "保存", icon: Ph? = DimmiIcon.check, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {   // （8→7）
                if let icon {
                    icon.thin
                        .dimmiIcon(size: DimmiIconSize.pill)
                }
                Text(title)
                    .font(DimmiFont.poppins(12, .medium))  // （13→12）
                    .foregroundStyle(DimmiTheme.textPrimary)
            }
            .padding(.horizontal, 20)
            .frame(height: 36)
            .background(.ultraThinMaterial, in: Capsule())
            .background(
                // 比 GlassPillButton 默认 fill 略亮一档（glassFillRaised），体现主操作
                Capsule().fill(hovered ? DimmiTheme.glassFillHover : DimmiTheme.glassFillRaised)
            )
            .overlay(
                // 上缘高光比 GlassPillButton 略强（0.55 vs 0.42），体现主操作
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: DimmiTheme.glassPillEdgeTop.opacity(1.30), location: 0.0),
                                .init(color: DimmiTheme.glassEdgeBottom, location: 0.7),
                            ],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                    .blendMode(.plusLighter)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.97 : 1)
        .animation(Motion.hover, value: hovered)
        .animation(Motion.press, value: pressed)
        .onHover { hovered = $0 }
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressed = $0 }, perform: {})
    }
}
