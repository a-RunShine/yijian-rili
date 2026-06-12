import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ReviewViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("一键日历")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Title Input
            VStack(alignment: .leading, spacing: 8) {
                Text("标题")
                    .font(.headline)
                TextField("输入复习内容", text: $viewModel.title)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // Date Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("日期")
                    .font(.headline)
                DatePicker("", selection: $viewModel.baseDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .onChange(of: viewModel.baseDate) { _, _ in
                        viewModel.updateReviewDates()
                    }
            }
            
            // Preview
            VStack(alignment: .leading, spacing: 8) {
                Text("复习计划")
                    .font(.headline)
                
                ForEach(Array(viewModel.reviewDates.enumerated()), id: \.element) { index, date in
                    HStack {
                        Text("第\(index + 1)次复习")
                        Spacer()
                        Text(date.formattedChinese())
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            // Create Button
            Button(action: {
                Task {
                    await viewModel.createReviewSchedule()
                }
            }) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Text("一键创建")
                        .font(.headline)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isLoading)
            
            // Result Message
            if let message = viewModel.resultMessage, let type = viewModel.resultType {
                HStack {
                    Image(systemName: type == .success ? "checkmark.circle.fill" : type == .warning ? "exclamationmark.triangle.fill" : "xmark.circle.fill")
                    Text(message)
                        .font(.callout)
                }
                .foregroundColor(type == .success ? .green : type == .warning ? .orange : .red)
                .padding()
                .background(type == .success ? Color.green.opacity(0.1) : type == .warning ? Color.orange.opacity(0.1) : Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Permission denied button
            if viewModel.authorizationStatus == .denied {
                Button("打开系统设置开启权限") {
                    viewModel.openSystemSettings()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 400, height: 500)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
