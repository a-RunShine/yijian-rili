enum CanvasMode: Equatable {
    case compact
    case wide
}

enum CanvasBreakpoint {
    static func mode(forWidth width: Double) -> CanvasMode {
        width >= 1024 ? .wide : .compact
    }
}
