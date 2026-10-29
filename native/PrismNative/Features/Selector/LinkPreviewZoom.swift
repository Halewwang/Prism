import CoreGraphics

enum LinkPreviewZoomAction: Equatable, Sendable {
    case zoomIn
    case zoomOut
    case reset
}

enum LinkPreviewPageZoom {
    static let levels: [CGFloat] = [0.5, 0.67, 0.75, 0.8, 0.9, 1, 1.1, 1.25, 1.5, 1.75, 2, 2.5, 3]

    static func scale(after action: LinkPreviewZoomAction, current: CGFloat) -> CGFloat {
        let valid = current.isFinite && current > 0 ? current : 1
        switch action {
        case .zoomIn: return levels.first { $0 > valid + 0.001 } ?? max(valid, 3)
        case .zoomOut: return levels.last { $0 < valid - 0.001 } ?? min(valid, 0.5)
        case .reset: return 1
        }
    }
}
