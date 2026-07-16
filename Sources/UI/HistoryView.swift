// 历史窗口：「褪色黄昏 · 毛玻璃」与 Settings / Onboarding 同源。
//
// 布局：
//   - DimmiBackground 三团光斑
//   - 顶部 toolbar：搜索胶囊 + 条数 + 清空
//   - 主区：左侧话题 sidebar + 右侧 item 列表（都用 GlassCard）
//
// 设计语言：
//   - 不允许"玻璃套玻璃"：左栏是一个 GlassCard，条目列表是另一个 GlassCard
//   - 滚动时条目卡的真玻璃会显出"上暗下沙"——真玻璃铁证
//   - 选中/hover 的 sidebar 行：fill 提到 glassFillRaised + 上缘高光 30%
import SwiftUI
import SwiftData
import AppKit
import PhosphorSwift

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \HistoryItem.createdAt, order: .reverse) private var items: [HistoryItem]

    @State private var query: String = ""
    @State private var topicFilter: Topic? = nil
    @State private var copiedID: PersistentIdentifier?
    @State private var copyResetWorkItem: DispatchWorkItem?

    private let df: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "MM-dd HH:mm"
        return f
    }()

    var body: some View {
        ZStack {
            DimmiBackground()

            VStack(spacing: 0) {
                toolbar
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                HStack(spacing: 16) {
                    sidebar
                        .frame(width: 220)

                    mainList
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 720, height: 540)
        .preferredColorScheme(.dark)
        .onDisappear { copyResetWorkItem?.cancel() }
    }

    // MARK: - 顶部 toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Ph.magnifyingGlass.thin
                    .dimmiIcon(size: DimmiIconSize.inline, muted: true)

                TextField("搜索原文 / 译文", text: $query)
                    .textFieldStyle(.plain)
                    .font(DimmiFont.inter(13))
                    .foregroundStyle(DimmiTheme.textPrimary)

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Ph.x.thin
                            .dimmiIcon(size: 11, muted: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(
                Capsule().fill(DimmiTheme.glassFillHover)
            )
            .overlay(
                Capsule()
                    .stroke(DimmiTheme.glassEdgeTop.opacity(0.4), lineWidth: 1)
                    .blendMode(.plusLighter)
            )
            .frame(maxWidth: .infinity)

            Text("\(filtered.count) 条")
                .font(DimmiFont.monoMedium11)
                .foregroundStyle(DimmiTheme.textSecondary)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(
                    Capsule().fill(DimmiTheme.glassFillHover)
                )
                .overlay(
                    Capsule()
                        .stroke(DimmiTheme.glassEdgeTop.opacity(0.4), lineWidth: 1)
                        .blendMode(.plusLighter)
                )

            Button {
                HistoryStore.clearAll()
            } label: {
                HStack(spacing: 6) {
                    DimmiIcon.clearCache.thin
                        .dimmiIcon(size: DimmiIconSize.inline)
                    Text("清空")
                        .font(DimmiFont.inter(13, .medium))
                }
                .foregroundStyle(items.isEmpty
                                  ? DimmiTheme.textSecondary
                                  : DimmiTheme.textPrimary)
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(
                    Capsule().fill(DimmiTheme.glassFillHover)
                )
                .overlay(
                    Capsule()
                        .stroke(DimmiTheme.glassEdgeTop.opacity(0.4), lineWidth: 1)
                        .blendMode(.plusLighter)
                )
            }
            .buttonStyle(.plain)
            .disabled(items.isEmpty)
            .opacity(items.isEmpty ? 0.5 : 1)
            .help("清空所有历史记录")
        }
    }

    // MARK: - 左侧：话题侧栏（真玻璃卡 — 透窗背景的光斑）

    private var sidebar: some View {
        GlassCard(radius: 24) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text("话题")
                        .font(DimmiFont.sectionEyebrow)
                        .tracking(1.2)
                        .foregroundStyle(DimmiTheme.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                ScrollView {
                    VStack(spacing: 4) {
                        sidebarRow(label: "全部", icon: Ph.tray, tagValue: Topic?.none)
                        ForEach(Topic.allCases) { topic in
                            let count = items.filter { $0.topic == topic }.count
                            if count > 0 {
                                sidebarRow(label: topic.rawValue, icon: icon(for: topic), tagValue: Topic?.some(topic))
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func sidebarRow(label: String, icon: Ph, tagValue: Topic?) -> some View {
        let isOn = topicFilter == tagValue
        let count: Int = {
            switch tagValue {
            case .none:      return items.count
            case .some(let t): return items.filter { $0.topic == t }.count
            }
        }()
        return Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                topicFilter = tagValue
            }
        } label: {
            HStack(spacing: 12) {
                icon.thin
                    .dimmiIcon(size: DimmiIconSize.row)
                Text(label)
                    .font(DimmiFont.inter(13, isOn ? .semibold : .medium))
                    .foregroundStyle(DimmiTheme.textPrimary)
                Spacer()
                Text("\(count)")
                    .font(DimmiFont.monoMedium11)
                    .foregroundStyle(DimmiTheme.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isOn ? DimmiTheme.glassFillRaised : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: isOn ? DimmiTheme.glassRowEdgeTop : Color.clear, location: 0.0),
                                .init(color: Color.clear, location: 0.55),
                            ],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                    .blendMode(.plusLighter)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private func icon(for topic: Topic) -> Ph {
        switch topic {
        case .greetings:   return Ph.handWaving
        case .food:        return Ph.forkKnife
        case .travel:      return Ph.airplane
        case .work:        return Ph.briefcase
        case .shopping:    return Ph.shoppingBag
        case .emotions:    return Ph.heart
        case .numbersTime: return Ph.clock
        case .health:      return Ph.stethoscope
        case .social:      return Ph.users
        case .other:       return Ph.question
        }
    }

    // MARK: - 右侧：item 列表（每条卡 = 真玻璃）

    @ViewBuilder
    private var mainList: some View {
        if filtered.isEmpty {
            empty
        } else {
            ScrollView {
                LazyVStack(spacing: 11) {
                    ForEach(filtered) { item in
                        HistoryRow(
                            item: item,
                            dateStr: df.string(from: item.createdAt),
                            copyState: copiedID == item.persistentModelID ? .justCopied : .idle,
                            onCopy: { copyItalian(item) }
                        )
                    }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 14)
            }
            .scrollIndicators(.hidden)
            .background(
                GlassCard(radius: 24, isRaised: false) {
                    Color.clear
                }
            )
        }
    }

    private var empty: some View {
        GlassCard(radius: 24) {
            VStack(spacing: 12) {
                (items.isEmpty ? Ph.tray.thin : Ph.magnifyingGlass.thin)
                    .dimmiIcon(size: 44, muted: true)
                    .opacity(0.6)
                Text(items.isEmpty ? "还没有历史记录" : "没有匹配的条目")
                    .font(DimmiFont.inter(14, .medium))
                    .foregroundStyle(DimmiTheme.textPrimary)
                if items.isEmpty {
                    Text("选一段中文，胶囊冒出来就自动留痕了。")
                        .font(DimmiFont.inter(12))
                        .foregroundStyle(DimmiTheme.textSecondary)
                }
            }
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - 计算
    private var filtered: [HistoryItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = items
        if let topic = topicFilter {
            result = result.filter { $0.topic == topic }
        }
        if !q.isEmpty {
            result = result.filter {
                $0.sourceText.localizedCaseInsensitiveContains(q) ||
                $0.italian.localizedCaseInsensitiveContains(q) ||
                ($0.colloquial ?? "").localizedCaseInsensitiveContains(q)
            }
        }
        return result
    }

    enum CopyUIState { case idle, justCopied }

    private func copyItalian(_ item: HistoryItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(item.italian, forType: .string)
        copiedID = item.persistentModelID
        copyResetWorkItem?.cancel()
        let work = DispatchWorkItem {
            self.copiedID = nil
        }
        copyResetWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }
}

// MARK: - 单条记录卡片（真玻璃卡 — radius 26）

private struct HistoryRow: View {
    @Bindable var item: HistoryItem
    var dateStr: String
    var copyState: HistoryView.CopyUIState
    var onCopy: () -> Void

    var body: some View {
        GlassCard(radius: 26) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    HStack(spacing: 5) {
                        actualTopicIcon.thin
                            .dimmiIcon(size: 11, muted: true)
                        // 阶段 10：根据 direction 决定展示"目标语 → 中文"或"中文 → 目标语"
                        // 老数据默认 forward；方向 + target 决定语义。
                        Text(langChipText)
                            .font(DimmiFont.captionSmallMedium)
                    }
                    .foregroundStyle(DimmiTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(DimmiTheme.glassFillHover))
                    .overlay(
                        Capsule()
                            .stroke(DimmiTheme.glassEdgeTop.opacity(0.4), lineWidth: 1)
                            .blendMode(.plusLighter)
                    )

                    Spacer()

                    Text(dateStr)
                        .font(DimmiFont.monoMedium10)
                        .foregroundStyle(DimmiTheme.textTertiary)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(item.sourceText)
                        .font(DimmiFont.caption)
                        .foregroundStyle(DimmiTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(item.italian)
                        .font(DimmiFont.inter(16, .semibold))
                        .foregroundStyle(DimmiTheme.textPrimary)
                        .textSelection(.enabled)
                        .lineLimit(2)

                    if let col = item.colloquial, !col.isEmpty {
                        Text(col)
                            .font(DimmiFont.inter(13))
                            .foregroundStyle(DimmiTheme.textPrimary.opacity(0.85))
                            .textSelection(.enabled)
                            .lineLimit(2)
                    }

                    if let note = item.note, !note.isEmpty {
                        Text(note)
                            .font(DimmiFont.captionSmall)
                            .foregroundStyle(DimmiTheme.textTertiary)
                            .lineLimit(2)
                            .padding(.top, 1)
                    }
                }

                HStack(spacing: 6) {
                    Button(action: onCopy) {
                        HStack(spacing: 6) {
                            if copyState == .justCopied {
                                DimmiIcon.obDone.thin
                                    .color(.green)
                                    .frame(width: 14, height: 14)
                            } else {
                                DimmiIcon.copy.thin
                                    .color(DimmiTheme.iconMuted)
                                    .frame(width: 14, height: 14)
                            }

                            Text(copyState == .justCopied ? "已复制" : "复制译文")
                                .font(DimmiFont.captionSmallMedium)
                        }
                        .foregroundStyle(copyState == .justCopied
                                         ? .green
                                         : DimmiTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(Capsule().fill(DimmiTheme.glassFillHover))
                        .overlay(
                            Capsule()
                                .stroke(DimmiTheme.glassEdgeTop.opacity(0.4), lineWidth: 1)
                                .blendMode(.plusLighter)
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .contentShape(Capsule())
                    .help(copyState == .justCopied ? "译文已复制" : "复制译文")

                    Button {
                        HistoryStore.delete(item)
                    } label: {
                        DimmiIcon.clearCache.thin
                            .dimmiIcon(size: 14, muted: true)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(DimmiTheme.glassFillHover))
                            .overlay(
                                Circle()
                                    .stroke(DimmiTheme.glassEdgeTop.opacity(0.4), lineWidth: 1)
                                    .blendMode(.plusLighter)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("删除")
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
    }

    private var actualTopicIcon: Ph {
        switch item.topic {
        case .greetings:   return Ph.handWaving
        case .food:        return Ph.forkKnife
        case .travel:      return Ph.airplane
        case .work:        return Ph.briefcase
        case .shopping:    return Ph.shoppingBag
        case .emotions:    return Ph.heart
        case .numbersTime: return Ph.clock
        case .health:      return Ph.stethoscope
        case .social:      return Ph.users
        case .other:       return Ph.question
        }
    }

    /// 历史卡顶 chip 文案：方向 + 目标语综合显示。
    ///   正向：目标语 / 目标语 emoji + 话题
    ///   反向：目标语 → 中文
    private var langChipText: String {
        switch item.direction {
        case .forward: return "\(item.target.emoji) \(item.topic.rawValue)"
        case .reverse: return "\(item.target.emoji) \(item.target.rawValue) → 中文"
        }
    }
}
