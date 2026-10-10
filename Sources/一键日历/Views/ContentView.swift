import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: ReviewViewModel

    var body: some View {
        VStack(spacing: 0) {
            segmentPicker
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Group {
                switch viewModel.selectedSegment {
                case .create:
                    createSegment
                case .today:
                    todaySegment
                case .settings:
                    settingsSegment
                }
            }
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
        .sheet(isPresented: $viewModel.showWeeklyReview) {
            WeeklyReviewView(viewModel: viewModel.weeklyReviewViewModel)
        }
        .sheet(isPresented: Binding(
            get: { viewModel.isSharedDetailSheetPresented },
            set: { if !$0 { viewModel.cancelSharedDetailEdit() } }
        )) {
            SharedDetailEditSheet(viewModel: viewModel)
                .frame(width: 380, height: 480)
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

    private var segmentPicker: some View {
        HStack(spacing: 0) {
            ForEach(ReviewViewModel.MainSegment.allCases) { segment in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedSegment = segment
                    }
                } label: {
                    Text(segment.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(
                            viewModel.selectedSegment == segment
                                ? .white
                                : (viewModel.currentTheme.secondaryTextColor ?? .secondary)
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            GeometryReader { geo in
                let count = CGFloat(ReviewViewModel.MainSegment.allCases.count)
                let segWidth = geo.size.width / count
                let index = CGFloat(
                    ReviewViewModel.MainSegment.allCases.firstIndex(of: viewModel.selectedSegment) ?? 0
                )
                RoundedRectangle(cornerRadius: 8)
                    .fill(viewModel.currentTheme.accentColor ?? Color(red: 0.106, green: 0.424, blue: 0.659))
                    .frame(width: segWidth)
                    .offset(x: index * segWidth)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.selectedSegment)
            }
        )
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill((viewModel.currentTheme.secondaryTextColor ?? .secondary).opacity(0.12))
        )
    }

    private var createSegment: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    segmentHeader(
                        title: NSLocalizedString("create_segment_title", comment: ""),
                        subtitle: NSLocalizedString("create_segment_subtitle", comment: "")
                    )

                    TitleInputSection(viewModel: viewModel)

                    DatePickerSection(viewModel: viewModel)

                    DetailInputSection(viewModel: viewModel)

                    if viewModel.scheduleMode == .review {
                        ReviewPreviewSection(viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity
                            ))
                    }

                    if viewModel.canRecreate {
                        RecreateUndoSection(viewModel: viewModel, showsUndo: false)
                    }
                }
                .padding()
                .animation(.easeInOut(duration: 0.25), value: viewModel.scheduleMode)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    Divider()
                    ActionSection(viewModel: viewModel)
                        .padding(12)
                }
                .background(viewModel.currentTheme.cardBackgroundColor)
            }
        }
    }

    private var todaySegment: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 8) {
                    Text(NSLocalizedString("today_segment_title", comment: ""))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(viewModel.currentTheme.primaryTextColor)
                    Spacer(minLength: 8)
                    weeklyReviewTitleButton
                }

                TodayEventsSection(viewModel: viewModel)

                TodayCreatedSection(viewModel: viewModel)

                Text(NSLocalizedString("today_segment_footer", comment: ""))
                    .font(.caption)
                    .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding()
        }
    }

    private var settingsSegment: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 8) {
                    Text(NSLocalizedString("settings_segment_title", comment: ""))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(viewModel.currentTheme.primaryTextColor)
                    Spacer(minLength: 8)
                    settingsChrome
                }

                CalendarPickerSection(viewModel: viewModel, forceExpanded: true)

                IntervalSettingsSection(viewModel: viewModel, forceExpanded: true)

                WindowSettingsSection(viewModel: viewModel, forceExpanded: true)

                settingsHistoryCard
            }
            .padding()
        }
    }

    private var weeklyReviewTitleButton: some View {
        Button(action: {
            viewModel.openWeeklyReview()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "calendar.badge.clock")
                    .font(.caption)
                Text(NSLocalizedString("weekly_review_button", comment: ""))
                    .font(.caption)
                    .fontWeight(.semibold)
                if !viewModel.weeklyReviewViewModel.entriesInCurrentWeek.isEmpty {
                    Text("\(viewModel.weeklyReviewViewModel.entriesInCurrentWeek.count)")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(viewModel.currentTheme.accentColor ?? Color.accentColor)
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(viewModel.currentTheme.primaryTextColor ?? .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill((viewModel.currentTheme.secondaryTextColor ?? .secondary).opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .help(NSLocalizedString("weekly_review_button", comment: ""))
    }

    private var settingsChrome: some View {
        HStack(spacing: 10) {
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
            .frame(width: 100)
        }
    }

    private var settingsHistoryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("history_title", comment: ""))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)

            Button(action: {
                viewModel.showHistory = true
            }) {
                VStack(alignment: .leading, spacing: 6) {
                    if let latest = viewModel.historyEntries.first {
                        Text("\(latest.title) · \(latest.baseDate.formattedChinese())")
                            .font(.subheadline)
                            .foregroundColor(viewModel.currentTheme.primaryTextColor ?? .primary)
                            .lineLimit(1)
                    } else {
                        Text(NSLocalizedString("empty_history_hint", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                    }
                    Text(NSLocalizedString("history_cap_hint", comment: ""))
                        .font(.caption)
                        .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(viewModel.currentTheme.cardBackgroundColor)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
    }

    private func segmentHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(viewModel.currentTheme.primaryTextColor)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(ReviewViewModel())
    }
}
