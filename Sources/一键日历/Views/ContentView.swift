import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: ReviewViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
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

                    TodayEventsSection(viewModel: viewModel)

                    Button(action: {
                        viewModel.openWeeklyReview()
                    }) {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                            Text(NSLocalizedString("weekly_review_button", comment: ""))
                                .font(.subheadline)
                            Spacer()
                            if !viewModel.weeklyReviewViewModel.entriesInCurrentWeek.isEmpty {
                                Text("\(viewModel.weeklyReviewViewModel.entriesInCurrentWeek.count)")
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

                    TitleInputSection(viewModel: viewModel)

                    if viewModel.canUndo || viewModel.canRecreate {
                        RecreateUndoSection(viewModel: viewModel)
                    }

                    DatePickerSection(viewModel: viewModel)

                    if viewModel.scheduleMode == .review {
                        ReviewPreviewSection(viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity
                            ))
                    }

                    CalendarPickerSection(viewModel: viewModel)

                    if viewModel.scheduleMode == .review {
                        IntervalSettingsSection(viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity
                            ))
                    }

                    WindowSettingsSection(viewModel: viewModel)

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
                }
                .padding()
                .animation(.easeInOut(duration: 0.25), value: viewModel.scheduleMode)
            }
            .background(viewModel.currentTheme.windowBackgroundColor)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    Divider()
                    ActionSection(viewModel: viewModel)
                        .padding(12)
                }
                .background(viewModel.currentTheme.cardBackgroundColor)
            }
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
            .sheet(isPresented: $viewModel.showWeeklyReview) {
                WeeklyReviewView(viewModel: viewModel.weeklyReviewViewModel)
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
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(ReviewViewModel())
    }
}
