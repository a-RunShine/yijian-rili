import SwiftUI
import EventKit

struct ContentView: View {
    @EnvironmentObject var viewModel: ReviewViewModel

    var body: some View {
        ScrollViewReader { proxy in
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
                            viewModel.showSearch = true
                        }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16))
                                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                        }
                        .buttonStyle(.plain)
                        .help(NSLocalizedString("search_button_tooltip", comment: ""))

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

                    // Title Input (含模式切换 Picker)
                    TitleInputSection(viewModel: viewModel)

                    // Date Picker
                    DatePickerSection(viewModel: viewModel)

                    // Review Preview（仅复习模式显示）
                    if viewModel.scheduleMode == .review {
                        ReviewPreviewSection(viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity
                            ))
                    }

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

                    // Interval Settings（仅复习模式显示）
                    if viewModel.scheduleMode == .review {
                        IntervalSettingsSection(viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity
                            ))
                    }

                    // Window Settings
                    WindowSettingsSection(viewModel: viewModel)

                    // Actions
                    ActionSection(viewModel: viewModel)
                }
                .padding()
                .animation(.easeInOut(duration: 0.25), value: viewModel.scheduleMode)
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
            .sheet(isPresented: $viewModel.showSearch, onDismiss: {
                viewModel.resetSearch()
            }) {
                SearchSheetView(viewModel: viewModel)
                    .frame(width: 380, height: 460)
            }
            .onAppear {
                viewModel.scheduleFirstRunGuideIfNeeded()
                viewModel.applyWindowLevel()
            }
            .onChange(of: viewModel.windowFloating) { _, _ in
                viewModel.applyWindowLevel()
            }
            .onChange(of: viewModel.scheduleMode) { _, _ in
                viewModel.updateReviewDates()
            }
            .onChange(of: viewModel.scrollToInputCounter) { _, _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo("titleInput", anchor: .top)
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(ReviewViewModel())
    }
}
