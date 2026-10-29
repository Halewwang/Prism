import Foundation

enum LinkPreviewWindowGeometry {
    static let defaultSize = CGSize(width: 600, height: 800)
    static let minimumSize = CGSize(width: 360, height: 480)

    static func isValid(_ size: CGSize) -> Bool {
        size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0
    }

    static func frame(preferredSize: CGSize?, pointer: CGPoint, visibleFrames: [CGRect]) -> CGRect {
        let preferred = preferredSize.flatMap { isValid($0) ? $0 : nil } ?? defaultSize
        var size = CGSize(
            width: max(minimumSize.width, preferred.width),
            height: max(minimumSize.height, preferred.height)
        )
        if let display = selectedFrame(for: pointer, from: visibleFrames) {
            let scale = min(1, display.width / size.width, display.height / size.height)
            size = CGSize(width: size.width * scale, height: size.height * scale)
            return CGRect(
                x: min(max(pointer.x + 12, display.minX), display.maxX - size.width),
                y: min(max(pointer.y - size.height - 12, display.minY), display.maxY - size.height),
                width: size.width,
                height: size.height
            )
        }
        return CGRect(x: pointer.x + 12, y: pointer.y - size.height - 12, width: size.width, height: size.height)
    }

    static func selectedFrame(for pointer: CGPoint, from frames: [CGRect]) -> CGRect? {
        let validFrames = frames.filter { isValid($0.size) && $0.origin.x.isFinite && $0.origin.y.isFinite }
        if let containing = validFrames.first(where: { $0.contains(pointer) }) { return containing }
        return validFrames.min { distance(from: pointer, to: $0) < distance(from: pointer, to: $1) }
    }

    private static func distance(from point: CGPoint, to frame: CGRect) -> CGFloat {
        let dx = point.x - min(max(point.x, frame.minX), frame.maxX)
        let dy = point.y - min(max(point.y, frame.minY), frame.maxY)
        return dx * dx + dy * dy
    }
}
