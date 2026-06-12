import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ReviewViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Title + Theme Picker
                HStack {
                    Text(NSLocalizedString("app_name", comment: ""))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                    Menu {
                        ForEach(Theme.allCases, id: \.self) { theme in
                            Button(theme.displayName) {
                                viewModel.setTheme(theme)
                            }
                        }
                    } label: {
                        Image(systemName: "paintbrush")
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 30)
                }
                
                // Title Input
                TitleInputSection(viewModel: viewModel)
                
                // Date Picker
                DatePickerSection(viewModel: viewModel)
                
                // Review Preview
                ReviewPreviewSection(viewModel: viewModel)
                
                // History Button
                Button(action: {
                    viewModel.showHistory = true
                }) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text(NSLocalizedString("history_button", comment: ""))
                        Spacer()
                        if !viewModel.historyEntries.isEmpty {
                            Text("\(viewModel.historyEntries.count)")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor)
                                .clipShape(Capsule())
                        }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
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
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
