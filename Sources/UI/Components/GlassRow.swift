// 设置首页行：hover 整行 pillBgHover 圆角 + press scale 0.985。
//
// 圆角块内缩在白卡里：padding 16 不触卡边，clipShape 保证。
// press 态：scale 0.985 + opacity 0.9，持续 0.10s（Motion.press）。
//
// 不要用 DragGesture 模拟 press（会和 Button click gesture 冲突），
// 用 Button 的 .pressAction 风格模拟，或直接去掉 press 态（hover 已经够明显）。
import SwiftUI
import PhosphorSwift

struct GlassRow: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let subtitle: String
    let icon: Ph
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            card
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var card: some View {
        HStack(spacing: 14) {
            icon.light
                .diaIcon(scheme, size: DimmiIconSize.row)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(DimmiFont.rowTitle)
                    .foregroundStyle(DimmiTheme.textPrimary(scheme))
                Text(subtitle)
                    .font(DimmiFont.rowSubtitle)
                    .foregroundStyle(DimmiTheme.textTertiary(scheme))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(hoverBg)
        .animation(Motion.hover, value: isHovered)
        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
    }

    private var hoverBg: some View {
        isHovered ? DimmiTheme.pillBgHover(scheme) : Color.clear
    }
}

typealias DiaRow = GlassRow
