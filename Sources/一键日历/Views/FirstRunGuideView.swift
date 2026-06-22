import SwiftUI
import AppKit

struct FirstRunGuideView: View {
    @ObservedObject var viewModel: ReviewViewModel
    let onDismiss: () -> Void
    @State private var selectedProvider: SyncProvider = .netease163

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                    .font(.title)
                    .foregroundColor(viewModel.currentTheme.accentColor ?? .accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("first_run_guide_title", comment: ""))
                        .font(.headline)
                    Text(NSLocalizedString("first_run_guide_subtitle", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.bottom, 12)

            Picker("", selection: $selectedProvider) {
                ForEach(SyncProvider.allCases) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    guideStep(
                        index: 1,
                        title: step1Title,
                        detail: selectedProvider.step1Detail,
                        actionTitle: selectedProvider.step1ActionTitle,
                        actionURL: selectedProvider.step1URL
                    )

                    guideStep(
                        index: 2,
                        title: NSLocalizedString("first_run_guide_step2", comment: ""),
                        detail: selectedProvider.step2Detail,
                        actionTitle: NSLocalizedString("first_run_guide_open_mail_app", comment: ""),
                        openCalendar: true
                    )

                    guideStep(
                        index: 3,
                        title: NSLocalizedString("first_run_guide_step3", comment: ""),
                        detail: selectedProvider.step3Detail
                    )

                    if let tip = selectedProvider.extraTip {
                        tipView(tip)
                    }

                    Text(NSLocalizedString("first_run_guide_alternatives", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding(.vertical, 12)
            }

            Divider()

            HStack {
                Spacer()
                Button(NSLocalizedString("first_run_guide_dismiss", comment: "")) {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .tint(viewModel.currentTheme.accentColor ?? .accentColor)
            }
            .padding(.top, 12)
        }
        .padding(20)
        .frame(width: 400, height: 520)
    }

    private var step1Title: String {
        String(format: NSLocalizedString("first_run_guide_step1_provider", comment: ""), selectedProvider.displayName)
    }

    @ViewBuilder
    private func tipView(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "lightbulb")
                .foregroundColor(.orange)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(6)
    }

    @ViewBuilder
    private func guideStep(
        index: Int,
        title: String,
        detail: String,
        actionTitle: String? = nil,
        actionURL: URL? = nil,
        openCalendar: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill((viewModel.currentTheme.accentColor ?? .accentColor).opacity(0.15))
                    .frame(width: 24, height: 24)
                Text("\(index)")
                    .font(.caption.bold())
                    .foregroundColor(viewModel.currentTheme.accentColor ?? .accentColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let title = actionTitle {
                    Button {
                        if let url = actionURL {
                            NSWorkspace.shared.open(url)
                        } else if openCalendar {
                            openCalendarApp()
                        }
                    } label: {
                        Label(title, systemImage: openCalendar ? "calendar" : "safari")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func openCalendarApp() {
        let url = URL(fileURLWithPath: "/System/Applications/Calendar.app")
        NSWorkspace.shared.open(url)
    }
}

enum SyncProvider: String, CaseIterable, Identifiable {
    case netease163
    case yidong139

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .netease163: return NSLocalizedString("provider_163", comment: "")
        case .yidong139: return NSLocalizedString("provider_139", comment: "")
        }
    }

    var step1URL: URL? {
        switch self {
        case .netease163: return URL(string: "https://mail.163.com/")
        case .yidong139: return URL(string: "https://mail.10086.cn/")
        }
    }

    var step1ActionTitle: String {
        switch self {
        case .netease163: return NSLocalizedString("first_run_guide_open_163", comment: "")
        case .yidong139: return NSLocalizedString("first_run_guide_open_139", comment: "")
        }
    }

    var step1Detail: String {
        switch self {
        case .netease163:
            return NSLocalizedString("first_run_guide_step1_detail_163", comment: "")
        case .yidong139:
            return NSLocalizedString("first_run_guide_step1_detail_139", comment: "")
        }
    }

    var step2Detail: String {
        switch self {
        case .netease163:
            return NSLocalizedString("first_run_guide_step2_detail_163", comment: "")
        case .yidong139:
            return NSLocalizedString("first_run_guide_step2_detail_139", comment: "")
        }
    }

    var step3Detail: String {
        switch self {
        case .netease163:
            return NSLocalizedString("first_run_guide_step3_detail_163", comment: "")
        case .yidong139:
            return NSLocalizedString("first_run_guide_step3_detail_139", comment: "")
        }
    }

    var extraTip: String? {
        switch self {
        case .netease163:
            return nil
        case .yidong139:
            return NSLocalizedString("first_run_guide_tip_139", comment: "")
        }
    }
}
