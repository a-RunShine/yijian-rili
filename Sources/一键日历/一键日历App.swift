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
                Button(NSLocalizedString("month_new_review", comment: "")) {
                    NotificationCenter.default.post(name: .newComposer, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
                Button(NSLocalizedString("create_review_schedule", comment: "")) {
                    NotificationCenter.default.post(name: .createReviewSchedule, object: nil)
                }
                .keyboardShortcut(KeyEquivalent.return, modifiers: .command)
                Button(NSLocalizedString("canvas_toggle", comment: "")) {
                    NotificationCenter.default.post(name: .toggleCanvas, object: nil)
                }
                .keyboardShortcut("l", modifiers: [.command, .option])
                closePanelCommand
            }
        }
    }

    @ViewBuilder
    private var closePanelCommand: some View {
        let button = Button(NSLocalizedString("command_close_panel", comment: "")) {
            NotificationCenter.default.post(name: .dismissTopPanel, object: nil)
        }
        if viewModel.modalSheetPresented {
            button
        } else {
            button.keyboardShortcut(.escape, modifiers: [])
        }
    }
}
