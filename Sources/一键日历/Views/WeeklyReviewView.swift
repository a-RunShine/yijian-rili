import SwiftUI

/// 周末总结 sheet 页面（spec F1-F9，plan §4.2）。
struct WeeklyReviewView: View {
    @ObservedObject var viewModel: WeeklyReviewViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var theme: Theme = {
        let raw = UserDefaults.standard.string(forKey: "themeName") ?? Theme.light.rawValue
        return Theme(rawValue: raw) ?? .light
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Header：标题 + 关闭按钮
            header
            Divider()

            ScrollView {
                VStack(spacing: 14) {
                    weekNavigator
                    progressBar
                    entriesSection
                    noteEditor
                }
                .padding()
            }

            Divider()
            footer
        }
        .frame(width: 460, height: 560)
        .background(theme.windowBackgroundColor ?? Color.clear)
        .onAppear {
            viewModel.jumpToCurrentWeek()
        }
        .onDisappear {
            // 关闭前强制 commit，避免遗漏草稿
            viewModel.commitNoteDraft()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Label(NSLocalizedString("weekly_review_title", comment: ""),
                  systemImage: "calendar.badge.clock")
                .font(.headline)
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(theme.secondaryTextColor ?? .secondary)
            }
            .buttonStyle(.borderless)
            .help(NSLocalizedString("close", comment: ""))
        }
        .padding()
    }

    // MARK: - Week Navigator

    private var weekNavigator: some View {
        HStack {
            Button(action: {
                viewModel.goToPreviousWeek()
            }) {
                Label(NSLocalizedString("weekly_review_prev_week", comment: ""),
                      systemImage: "chevron.left")
            }
            .buttonStyle(.bordered)
            .help(NSLocalizedString("weekly_review_prev_week", comment: ""))

            Spacer()

            VStack(spacing: 2) {
                Text(weekRangeText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(weekRelativeText)
                    .font(.caption)
                    .foregroundColor(theme.secondaryTextColor ?? .secondary)
            }

            Spacer()

            Button(action: {
                viewModel.goToNextWeek()
            }) {
                Label(NSLocalizedString("weekly_review_next_week", comment: ""),
                      systemImage: "chevron.right")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.canGoToNextWeek)
            .help(NSLocalizedString("weekly_review_next_week", comment: ""))
        }
        .padding()
        .background(theme.cardBackgroundColor)
        .cornerRadius(10)
    }

    private var weekRangeText: String {
        let s = viewModel.currentWeekStart.formattedChinese()
        let e = viewModel.currentWeekEnd.formattedChinese()
        return "\(s) ~ \(e)"
    }

    private var weekRelativeText: String {
        let thisMonday = WeekCalculator.weekStart(for: Date())
        if viewModel.currentWeekStart == thisMonday {
            return NSLocalizedString("weekly_review_this_week", comment: "")
        }
        let diff = Calendar.current.dateComponents([.day], from: thisMonday, to: viewModel.currentWeekStart).day ?? 0
        let weeks = diff / 7
        if weeks > 0 {
            return String(format: NSLocalizedString("weekly_review_weeks_ago", comment: ""), "\(weeks)")
        } else if weeks < 0 {
            return String(format: NSLocalizedString("weekly_review_weeks_later", comment: ""), "\(-weeks)")
        }
        return ""
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        let total = viewModel.totalCount
        let reviewed = viewModel.reviewedCount
        let label = String(format: NSLocalizedString("weekly_review_progress", comment: ""),
                           "\(reviewed)", "\(total)")
        let progress: Double = total > 0 ? Double(reviewed) / Double(total) : 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }
            ProgressView(value: progress)
                .progressViewStyle(.linear)
        }
        .padding()
        .background(theme.cardBackgroundColor)
        .cornerRadius(10)
    }

    // MARK: - Entries

    @ViewBuilder
    private var entriesSection: some View {
        if viewModel.entriesInCurrentWeek.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(viewModel.entriesGroupedByCreationDate, id: \.date) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.date.formattedChinese())
                            .font(.caption)
                            .foregroundColor(theme.secondaryTextColor ?? .secondary)
                            .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            ForEach(Array(group.entries.enumerated()), id: \.element.id) { idx, entry in
                                entryRow(entry)
                                if idx < group.entries.count - 1 {
                                    Divider().padding(.leading, 44)
                                }
                            }
                        }
                        .background(theme.cardBackgroundColor)
                        .cornerRadius(10)
                    }
                }
            }
        }
    }

    private func entryRow(_ entry: WeeklyEntry) -> some View {
        let reviewed = viewModel.isReviewed(entry.id)
        return HStack(alignment: .top, spacing: 10) {
            Button(action: {
                viewModel.toggleReviewed(entry.id)
            }) {
                Image(systemName: reviewed ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18))
                    .foregroundColor(reviewed ? (theme.accentColor ?? .accentColor) : (theme.secondaryTextColor ?? .secondary))
            }
            .buttonStyle(.plain)
            .help(reviewed
                  ? NSLocalizedString("weekly_review_mark_unreviewed", comment: "")
                  : NSLocalizedString("weekly_review_mark_reviewed", comment: ""))

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(entry.title)
                        .font(.subheadline)
                        .strikethrough(reviewed, color: theme.secondaryTextColor ?? .secondary)
                        .foregroundColor(reviewed
                                         ? (theme.secondaryTextColor ?? .secondary)
                                         : (theme.primaryTextColor ?? .primary))
                        .lineLimit(2)
                    // 周末复习计划预占位标签（spec F11：UI 在条目右侧加
                    // "上周周末创建" 标签，用 .secondary 颜色区分预占位，
                    // 不改变勾选/笔记行为）
                    if entry.isPreOccupiedNextWeek {
                        Text(NSLocalizedString("weekly_review_pre_occupied_tag", comment: ""))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(4)
                    }
                    Spacer(minLength: 0)
                }

                // 副标题：
                // - 真实条目：baseDate · 类型
                // - 预占位条目（spec F11）："创建于 X · Y 所在周开始复习"
                //   X = entry.creationDate 中文格式（= 下一周周一）
                //   Y = 归档周周一（原创建所在周的周一 = 当前周一 - 7 天）
                if entry.isPreOccupiedNextWeek {
                    let creationText = entry.creationDate.formattedChinese()
                    let archivedMonday = WeekCalculator.addingWeeks(-1, to: entry.creationDate)
                    let archivedText = archivedMonday.formattedChinese()
                    let subtitle = String(
                        format: NSLocalizedString("weekly_review_pre_occupied_subtitle", comment: ""),
                        creationText, archivedText
                    )
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(theme.secondaryTextColor ?? .secondary)
                } else {
                    HStack(spacing: 6) {
                        Text(entry.baseDate.formattedChinese())
                            .font(.caption)
                            .foregroundColor(theme.secondaryTextColor ?? .secondary)
                        Text("·")
                            .font(.caption)
                            .foregroundColor(theme.secondaryTextColor ?? .secondary)
                        Text(typeText(for: entry.scheduleType))
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background((theme.accentColor ?? .accentColor).opacity(0.15))
                            .foregroundColor(theme.accentColor ?? .accentColor)
                            .cornerRadius(4)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
    }

    private func typeText(for type: HistoryEntry.ScheduleType) -> String {
        switch type {
        case .review: return NSLocalizedString("schedule_mode_review", comment: "")
        case .single: return NSLocalizedString("schedule_mode_single", comment: "")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray")
                .font(.system(size: 30))
                .foregroundColor(theme.secondaryTextColor ?? .secondary)
            Text(NSLocalizedString("weekly_review_empty_state", comment: ""))
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(theme.secondaryTextColor ?? .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding()
        .background(theme.cardBackgroundColor)
        .cornerRadius(10)
    }

    // MARK: - Note Editor

    private var noteEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(NSLocalizedString("weekly_review_note_title", comment: ""),
                      systemImage: "square.and.pencil")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(NSLocalizedString("weekly_review_note_autosave", comment: ""))
                    .font(.caption2)
                    .foregroundColor(theme.secondaryTextColor ?? .secondary)
            }
            TextEditor(text: Binding(
                get: { viewModel.noteDraft },
                set: { viewModel.updateNote($0) }
            ))
            .font(.body)
            .frame(minHeight: 90, maxHeight: 140)
            .padding(6)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.secondaryTextColor ?? .secondary, lineWidth: 0.5)
            )
        }
        .padding()
        .background(theme.cardBackgroundColor)
        .cornerRadius(10)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()
            Button(NSLocalizedString("weekly_review_jump_to_current", comment: "")) {
                viewModel.jumpToCurrentWeek()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled({
                let thisMonday = WeekCalculator.weekStart(for: Date())
                return viewModel.currentWeekStart == thisMonday
            }())
        }
        .padding(10)
        .background(theme.cardBackgroundColor)
    }
}

struct WeeklyReviewView_Previews: PreviewProvider {
    static var previews: some View {
        WeeklyReviewView(viewModel: WeeklyReviewViewModel())
    }
}
