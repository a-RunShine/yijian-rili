import AppKit
import SwiftUI

@MainActor
private struct PointingHandOnHover: ViewModifier {
    let enabled: Bool
    @State private var pointing = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                apply(inside: inside)
            }
            .onChange(of: enabled) { _, _ in
                pointing = false
                NSCursor.arrow.set()
            }
            .onDisappear {
                guard pointing else { return }
                pointing = false
                NSCursor.arrow.set()
            }
    }

    private func apply(inside: Bool) {
        guard enabled, inside else {
            guard pointing else { return }
            pointing = false
            NSCursor.arrow.set()
            return
        }
        guard !pointing else { return }
        pointing = true
        NSCursor.pointingHand.set()
    }
}

extension View {
    func pointingHandOnHover(_ enabled: Bool = true) -> some View {
        modifier(PointingHandOnHover(enabled: enabled))
    }
}
