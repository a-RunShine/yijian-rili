import CoreGraphics

struct CanvasWindowResize: Equatable {
    let targetContentSize: CGSize
    let contentSize: CGSize
    let windowFrame: CGRect
    let showsScreenTooNarrowHint: Bool
}

enum CanvasWindowSizing {
    static let compactContentSize = CGSize(width: 420, height: 620)
    static let wideContentSize = CGSize(width: 1180, height: 760)
    static let minimumContentSize = compactContentSize

    static func resize(
        windowFrame: CGRect,
        titlebarHeight: CGFloat,
        visibleFrame: CGRect,
        to mode: CanvasMode
    ) -> CanvasWindowResize {
        if mode == .wide, CanvasBreakpoint.mode(forWidth: visibleFrame.width) == .compact {
            let stayed = CGSize(
                width: windowFrame.width,
                height: windowFrame.height - titlebarHeight
            )
            return CanvasWindowResize(
                targetContentSize: stayed,
                contentSize: stayed,
                windowFrame: windowFrame,
                showsScreenTooNarrowHint: true
            )
        }
        let content = mode == .wide ? wideContentSize : compactContentSize
        let frameWidth = min(content.width, visibleFrame.width)
        let frameHeight = min(content.height + titlebarHeight, visibleFrame.height)
        var frame = frameKeepingTopLeft(
            of: windowFrame,
            size: CGSize(width: frameWidth, height: frameHeight)
        )
        if frame.maxX > visibleFrame.maxX {
            frame.origin.x = visibleFrame.maxX - frame.width
        }
        if frame.minX < visibleFrame.minX {
            frame.origin.x = visibleFrame.minX
        }
        if frame.maxY > visibleFrame.maxY {
            frame.origin.y = visibleFrame.maxY - frame.height
        }
        if frame.minY < visibleFrame.minY {
            frame.origin.y = visibleFrame.minY
        }
        return CanvasWindowResize(
            targetContentSize: content,
            contentSize: CGSize(width: frame.width, height: frame.height - titlebarHeight),
            windowFrame: frame,
            showsScreenTooNarrowHint: false
        )
    }

    private static func frameKeepingTopLeft(of windowFrame: CGRect, size: CGSize) -> CGRect {
        CGRect(
            x: windowFrame.minX,
            y: windowFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }
}
