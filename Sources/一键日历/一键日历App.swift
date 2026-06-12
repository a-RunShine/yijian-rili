import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        if let window = NSApplication.shared.mainWindow {
            window.makeKeyAndOrderFront(nil)
            window.level = .floating
        }
    }
}

@main
struct 一键日历App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("themeName") private var themeName: String = Theme.light.rawValue
    
    var body: some Scene {
        Window(NSLocalizedString("app_name", comment: ""), id: "main") {
            ContentView()
                .preferredColorScheme(Theme(rawValue: themeName)?.colorScheme)
                .frame(width: 400, height: 600)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandMenu(NSLocalizedString("command_menu", comment: "")) {
                Button(NSLocalizedString("create_review_schedule", comment: "")) {
                    NotificationCenter.default.post(name: .createReviewSchedule, object: nil)
                }
                .keyboardShortcut(KeyEquivalent.return, modifiers: .command)
            }
        }
    }
}
