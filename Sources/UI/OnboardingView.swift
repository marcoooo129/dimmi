// 4 步渐进引导：欢迎 → 使用方式 → 引擎 → 完成。
//
// 视觉与 Settings / History 同源：DimmiBackground 三团光斑 + 一张玻璃大卡。
// 内部不再嵌套多层卡片；分组靠 GroupLabel + GlassDivider 区分。
import SwiftUI
import AppKit
import PhosphorSwift

struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismissWindow

    var onDismiss: () -> Void = {}

    @State private var step: Int = 0
    private let totalSteps = 4

    var body: some View {
        ZStack {
            DimmiBackground()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 28)
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                stepContent
                    .padding(.horizontal, 24)

                footer
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 22)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - 头部

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            DimmiBrandMark(size: 38)
                .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text("欢迎使用 dimmi")
                    .font(DimmiFont.detailHeader)
                    .foregroundStyle(DimmiTheme.textPrimary)
                Text("中文母语者专用意大利语翻译助手。")
                    .font(DimmiFont.appSubtitle)
                    .foregroundStyle(DimmiTheme.textSecondary)
                    .lineSpacing(3)
            }

            Spacer()

            // 进度：4 个胶囊段，active 走暖白，其余半透明
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Capsule()
                        .fill(i == step
                              ? DimmiTheme.glassEdgeTop
                              : DimmiTheme.glassDivider)
                        .frame(width: i == step ? 22 : 8, height: 8)
                        .animation(.easeInOut(duration: 0.18), value: step)
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - 当前步骤

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: stepWelcome
        case 1: stepUsage
        case 2: stepProvider
        case 3: stepReady
        default: stepWelcome
        }
    }

    // MARK: - Step 0：欢迎

    private var stepWelcome: some View {
        OnboardingCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(title: "复制即翻译",
                              subtitle: "在任何 App 里选中一段中文，按 ⌘C 复制，dimmi 立刻弹出译文。")

                VStack(spacing: 10) {
                    featureRow(icon: DimmiIcon.obTranslate,
                               title: "复制后即时弹出",
                               subtitle: "原文 · 译文 · 口语变体 · 小提示，一次给齐。")
                    featureRow(icon: DimmiIcon.translation,
                               title: "中文母语者友好",
                               subtitle: "侧重日常口语，去翻译腔。")
                    featureRow(icon: DimmiIcon.shortcuts,
                               title: "⌘⇧T 也行",
                               subtitle: "不复制也能用，对当前鼠标位置的焦点区域取词。")
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Step 1：使用方式

    private var stepUsage: some View {
        OnboardingCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(title: "两种方式触发",
                              subtitle: "默认走「粘贴板」，无需任何系统授权。")

                VStack(spacing: 10) {
                    featureRow(icon: DimmiIcon.copy,
                               title: "复制触发（推荐）",
                               subtitle: "选中文本后按 ⌘C。无需系统授权，开箱即用。")
                    featureRow(icon: DimmiIcon.shortcuts,
                               title: "快捷键 ⌘⇧T",
                               subtitle: "不想复制时，按 ⌘⇧T 翻译当前聚焦的内容。")
                    featureRow(icon: DimmiIcon.settings,
                               title: "想要「选完就弹」？",
                               subtitle: "切到「划词」模式 + 授权辅助功能。在 设置 → 快捷键与行为 里切换。")
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Step 2：引擎

    private var stepProvider: some View {
        OnboardingCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(title: "选一个翻译引擎",
                              subtitle: "可在「设置 → 翻译」随时切换；现在选一个最常听的就行。")

                VStack(spacing: 10) {
                    providerRow(.anthropic, desc: "Claude Haiku · 中文理解好 · 推荐意大利语初学者")
                    providerRow(.openai,    desc: "GPT-4o-mini · 通用稳定 · 国内可能需代理")
                    providerRow(.deepseek,  desc: "DeepSeek-V3 · 中文语境强 · 成本极低（≈OpenAI 1/30）")
                }
                .padding(.top, 4)

                Text("没 Key 也行：默认开启示例翻译，可以先把流程跑通。")
                    .font(DimmiFont.captionSmall)
                    .foregroundStyle(DimmiTheme.textSecondary)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Step 3：完成

    private var stepReady: some View {
        OnboardingCard {
            VStack(spacing: 14) {
                DimmiIcon.obDone.thin
                    .dimmiIcon(size: 30)
                    .color(.green.opacity(0.85))
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(DimmiTheme.glassFillHover))
                    .overlay(
                        Circle()
                            .stroke(DimmiTheme.glassEdgeTop.opacity(0.5), lineWidth: 1)
                            .blendMode(.plusLighter)
                    )

                Text("准备好了")
                    .font(DimmiFont.detailHeader)
                    .foregroundStyle(DimmiTheme.textPrimary)

                Text("在任何 App 里选中一段中文，按 ⌘C 复制即会弹出译文。\n点菜单栏中的 dimmi 图标可随时打开。")
                    .font(DimmiFont.detailBody)
                    .foregroundStyle(DimmiTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 8) {
                    featureRow(icon: DimmiIcon.copy,
                               title: "默认靠粘贴板触发",
                               subtitle: "复制的内容变化即翻译，无需任何系统授权。")
                    featureRow(icon: DimmiIcon.shortcuts,
                               title: "⌘⇧T 手动触发",
                               subtitle: "不复制也能用，对当前焦点区域取词。")
                    featureRow(icon: DimmiIcon.settings,
                               title: "菜单栏 → 设置",
                               subtitle: "切换取词来源、调参、加 Key、改快捷键")
                    featureRow(icon: Ph.clock,
                               title: "菜单栏 → 打开历史",
                               subtitle: "随时翻看之前翻译过的句子")
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: - 通用组件

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(DimmiFont.settingsSectionTitle)
                .foregroundStyle(DimmiTheme.textPrimary)
            Text(subtitle)
                .font(DimmiFont.detailBody)
                .foregroundStyle(DimmiTheme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 引导窗里的功能行：透明（让背景透出），仅靠上缘高光与左侧细图标
    /// 区分；选中/激活态用 glassFillRaised 块高亮。
    /// （玻璃语言里不允许"卡片套卡片"，所以这里直接放在 OnboardingCard 里）
    private func featureRow(icon: Ph, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            icon.thin
                .dimmiIcon(size: DimmiIconSize.row)
                .foregroundStyle(DimmiTheme.glassEdgeTop)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(DimmiTheme.glassFillHover)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(DimmiTheme.glassEdgeTop.opacity(0.3), lineWidth: 1)
                        .blendMode(.plusLighter)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(DimmiFont.detailBodyMedium)
                    .foregroundStyle(DimmiTheme.textPrimary)
                Text(subtitle)
                    .font(DimmiFont.appSubtitle)
                    .foregroundStyle(DimmiTheme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func providerRow(_ p: TranslationProvider, desc: String) -> some View {
        let isOn = AppState.shared.provider == p
        return Button {
            AppState.shared.provider = p
        } label: {
            HStack(alignment: .top, spacing: 12) {
                (isOn ? DimmiIcon.obDone : Ph.circle).thin
                    .dimmiIcon(size: DimmiIconSize.row)
                    .foregroundStyle(isOn ? DimmiTheme.textPrimary : DimmiTheme.textSecondary)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle().fill(isOn
                                      ? DimmiTheme.glassFillRaised
                                      : DimmiTheme.glassFillHover)
                    )
                    .overlay(
                        Circle()
                            .stroke(isOn ? DimmiTheme.glassEdgeTop : DimmiTheme.glassDivider, lineWidth: 1)
                            .blendMode(.plusLighter)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(p.rawValue)
                        .font(DimmiFont.detailBodyMedium)
                        .foregroundStyle(DimmiTheme.textPrimary)
                    Text(desc)
                        .font(DimmiFont.captionSmall)
                        .foregroundStyle(DimmiTheme.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isOn ? DimmiTheme.glassFillRaised : DimmiTheme.glassFillHover)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isOn ? DimmiTheme.glassEdgeTop : DimmiTheme.glassDivider, lineWidth: 1)
                    .blendMode(.plusLighter)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 底部按钮栏

    private var footer: some View {
        HStack(spacing: 10) {
            OnboardingPillButton(
                icon: Ph.arrowLeft,
                label: "上一步",
                isPrimary: false,
                disabled: step == 0,
                action: goBack
            )
            .keyboardShortcut(.cancelAction)

            Spacer()

            if step < totalSteps - 1 {
                OnboardingPillButton(
                    icon: Ph.arrowRight,
                    label: "下一步",
                    isPrimary: true,
                    iconLeading: false,
                    action: goNext
                )
                .keyboardShortcut(.defaultAction)
            } else {
                OnboardingPillButton(
                    icon: DimmiIcon.obTranslate,
                    label: "开始使用",
                    isPrimary: true,
                    action: {
                        onDismiss()
                        dismissWindow()
                    }
                )
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func goNext() {
        withAnimation(.easeInOut(duration: 0.18)) {
            step = min(step + 1, totalSteps - 1)
        }
    }

    private func goBack() {
        withAnimation(.easeInOut(duration: 0.18)) {
            step = max(step - 1, 0)
        }
    }
}

// MARK: - 引导窗的玻璃大卡（包装 GlassCard 让步骤内容有一致的内边距）

private struct OnboardingCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        GlassCard(radius: 28) {
            content
                .padding(.horizontal, 22)
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: - Onboarding 专用按钮（与设置胶囊一致）

private struct OnboardingPillButton: View {
    let icon: Ph
    let label: String
    var isPrimary: Bool = false
    var iconLeading: Bool = true
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if iconLeading { icon.thin.dimmiIcon(size: DimmiIconSize.inline) }
                Text(label)
                    .font(DimmiFont.inter(13, isPrimary ? .medium : .regular))
                if !iconLeading { icon.thin.dimmiIcon(size: DimmiIconSize.inline) }
            }
            .foregroundStyle(isPrimary
                              ? DimmiTheme.primaryFg
                              : DimmiTheme.textPrimary)
            .padding(.horizontal, 16)
            .frame(height: 36)
            .background(
                Capsule().fill(isPrimary
                                 ? DimmiTheme.primaryFill
                                 : DimmiTheme.glassFillHover)
            )
            .overlay(
                Capsule()
                    .stroke(isPrimary
                              ? DimmiTheme.glassEdgeTop.opacity(0.7)
                              : DimmiTheme.glassEdgeTop.opacity(0.4),
                             lineWidth: 1)
                    .blendMode(.plusLighter)
            )
            .opacity(disabled ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}
