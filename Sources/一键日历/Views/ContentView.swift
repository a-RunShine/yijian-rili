import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: ReviewViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Title + Theme Picker + Help
                HStack {
                    Text(NSLocalizedString("app_name", comment: ""))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(viewModel.currentTheme.primaryTextColor)
                    Spacer()
                    Button(action: {
                        viewModel.openHelpGuide()
                    }) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 16))
                            .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(NSLocalizedString("help_button_tooltip", comment: ""))

                    Picker("", selection: Binding(
                        get: { viewModel.currentTheme },
                        set: { viewModel.setTheme($0) }
                    )) {
                        ForEach(Theme.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 110)
                }

                // Today Events
                TodayEventsSection(viewModel: viewModel)

                // Title Input
                TitleInputSection(viewModel: viewModel)

                // Date Picker
                DatePickerSection(viewModel: viewModel)

                // Review Preview
                ReviewPreviewSection(viewModel: viewModel)

                // Calendar Picker
                CalendarPickerSection(viewModel: viewModel)

                // History Button (card-style)
                Button(action: {
                    viewModel.showHistory = true
                }) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text(NSLocalizedString("history_button", comment: ""))
                            .font(.subheadline)
                        Spacer()
                        if !viewModel.historyEntries.isEmpty {
                            Text("\(viewModel.historyEntries.count)")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(viewModel.currentTheme.accentColor ?? Color.accentColor)
                                .clipShape(Capsule())
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding()
                .background(viewModel.currentTheme.cardBackgroundColor)
                .cornerRadius(10)

                // Interval Settings
                IntervalSettingsSection(viewModel: viewModel)

                // Actions
                ActionSection(viewModel: viewModel)
            }
            .padding()
        }
        .background(viewModel.currentTheme.windowBackgroundColor)
        .frame(width: 400, height: 600)
        .sheet(isPresented: $viewModel.showHistory) {
            HistorySection(viewModel: viewModel)
                .frame(width: 340, height: 420)
        }
        .sheet(isPresented: $viewModel.showFirstRunGuide) {
            FirstRunGuideView(viewModel: viewModel) {
                viewModel.dismissFirstRunGuide()
            }
        }
        .sheet(isPresented: $viewModel.showHelpGuide) {
            FirstRunGuideView(viewModel: viewModel) {
                viewModel.showHelpGuide = false
            }
        }
        .onAppear {
            viewModel.scheduleFirstRunGuideIfNeeded()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(ReviewViewModel())
    }
}
