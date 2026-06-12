import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ReviewViewModel()
    
    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text(NSLocalizedString("app_name", comment: ""))
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Title Input
            TitleInputSection(viewModel: viewModel)
            
            // Date Picker
            DatePickerSection(viewModel: viewModel)
            
            // Review Preview
            ReviewPreviewSection(viewModel: viewModel)
            
            // History Section
            HistorySection(viewModel: viewModel)
            
            // Interval Settings
            IntervalSettingsSection(viewModel: viewModel)
            
            // Actions
            ActionSection(viewModel: viewModel)
            
            Spacer()
        }
        .padding()
        .frame(width: 400, height: 600)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
