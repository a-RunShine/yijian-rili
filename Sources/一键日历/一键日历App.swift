import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        if let window = NSApplication.shared.mainWindow {
            window.makeKeyAndOrderFront(nil)
        }
        NotificationCenter.default.post(name: .appDidBecomeActive, object: nil)
    }
}

@main
struct 一键日历App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = ReviewViewModel()
    
    var body: some Scene {
        Window(NSLocalizedString("app_name", comment: ""), id: "main") {
            CalendarShellView()
                .environmentObject(viewModel)
                .preferredColorScheme(viewModel.currentTheme.colorScheme)
        }
        .defaultSize(
            width: CanvasWindowSizing.compactContentSize.width,
            height: CanvasWindowSizing.compactContentSize.height
        )
        .windowResizability(.contentMinSize)
        .commands {
            CommandMenu(NSLocalizedString("command_menu", comment: "")) {
                Button(NSLocalizedString("create_review_schedule", comment: "")) {
                    NotificationCenter.default.post(name: .createReviewSchedule, object: nil)
                }
                .keyboardShortcut(KeyEquivalent.return, modifiers: .command)
                Button(NSLocalizedString("canvas_toggle", comment: "")) {
                    NotificationCenter.default.post(name: .toggleCanvas, object: nil)
                }
                .keyboardShortcut("l", modifiers: [.command, .option])
            }
        }
    }
}
