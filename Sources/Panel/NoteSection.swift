// 惯用表达注解 UI：分隔线 + 类型标签 + breakdown + usage + 例句。
//
// 与译文解耦——独立 progress，独立层次。
//
// 重要：
//   - NoteSection 必须**常驻**在视图树里，不能 if let 包裹。
//     没有注解时让 isActive = false，整体不可见；但子视图都已 mount，
//     拿到注解时只用 opacity / progress 渐显，不会触发 mount/unmount。
//   - 例句的左侧竖线不能用 HStack 拉伸；用 overlay 贴在 leading。
//   - 文本子块走 RevealableText(noteRenderer: true)，用归一化时间线渲染
//     （更紧凑的 stagger / fade），与译文同等级别但更紧凑。
//
// 视觉规则：
//   - 整体比译文弱一级，不抢主体
//   - kind 标签统一 DimmiTheme.tonalBg 胶囊 + textSecondary
//   - 例句左侧加 2pt divider 色竖线
import SwiftUI

struct NoteSection: View {
    @Environment(\.colorScheme) private var scheme

    let note: PhraseNote
    let progress: Double
    /// 是否真正展示注解（hasNote=false 时为 false，整体隐藏）
    var isActive: Bool = true

    var body: some View {
        // progress 驱动 reveal 渐显。注解走归一化时间线（noteRenderer: true 用紧凑参数）。
        Group {
            if isActive {
                VStack(alignment: .leading, spacing: 0) {
                    // 分隔线
                    Rectangle()
                        .fill(DimmiTheme.divider(scheme))
                        .frame(height: 0.5)
                        .padding(.vertical, 14)

                    // 类型标签
                    HStack(spacing: 4) {
                        if note.kind != nil {
                            DimmiIcon.noteIdiom.light
                                .diaIcon(scheme, size: 11)
                            Text(note.kind?.label ?? "")
                                .font(DimmiFont.captionSmallMedium)
                                .foregroundStyle(DimmiTheme.textSecondary(scheme))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(DimmiTheme.tonalBg(scheme)))
                    .padding(.bottom, 8)
                    .opacity(note.kind == nil ? 0 : 1)

                    // 字面拆解（注解区走 noteRenderer：更紧凑 stagger）
                    RevealableText(
                        text: note.breakdown ?? "",
                        progress: progress,
                        font: DimmiFont.bodyMedium,
                        lineSpacing: 3,
                        foreground: DimmiTheme.textPrimary(scheme),
                        noteRenderer: true
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)
                    .opacity((note.breakdown ?? "").isEmpty ? 0 : 1)

                    // 用法说明
                    RevealableText(
                        text: note.usage ?? "",
                        progress: progress,
                        font: DimmiFont.bodyRegular,
                        lineSpacing: 4,
                        foreground: DimmiTheme.textSecondary(scheme),
                        noteRenderer: true
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 10)
                    .opacity((note.usage ?? "").isEmpty ? 0 : 1)

                    // 例句
                    let itText = note.example?.it ?? ""
                    let zhText = note.example?.zh ?? ""
                    VStack(alignment: .leading, spacing: 2) {
                        RevealableText(
                            text: itText,
                            progress: progress,
                            font: DimmiFont.exampleItalic,
                            lineSpacing: 3,
                            foreground: DimmiTheme.textPrimary(scheme),
                            noteRenderer: true
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        RevealableText(
                            text: zhText,
                            progress: progress,
                            font: DimmiFont.exampleZh,
                            lineSpacing: 3,
                            foreground: DimmiTheme.textSecondary(scheme),
                            noteRenderer: true
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                    }
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(DimmiTheme.divider(scheme))
                            .frame(width: 2)
                    }
                    .opacity((itText + zhText).isEmpty ? 0 : 1)
                }
            } else {
                Color.clear.frame(height: 0)
            }
        }
        .opacity(isActive ? progress : 0)
        .blur(radius: isActive ? (1 - progress) * 2.0 : 0)
    }
}