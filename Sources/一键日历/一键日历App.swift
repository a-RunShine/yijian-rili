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
    
    var body: some Scene {
        Window("一键日历", id: "main") {
            ContentView()
                .frame(width: 400, height: 500)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandMenu("操作") {
                Button("创建复习计划") {
                    NotificationCenter.default.post(name: .createReviewSchedule, object: nil)
                }
                .keyboardShortcut(KeyEquivalent.return, modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let createReviewSchedule = Notification.Name("createReviewSchedule")
}
