import AppKit
import QuartzCore

@MainActor
enum WindowPresentationAnimation {
    private static let animationKey = "prism.windowPresentation"

    static func show(
        _ window: NSWindow,
        reduceMotion: Bool = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
        orderFront: () -> Void
    ) {
        guard !window.isVisible, !window.isMiniaturized else {
            orderFront()
            return
        }

        reset(window)
        window.animationBehavior = .none
        let timing = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
        let duration = reduceMotion ? 0.08 : 0.25
        if !reduceMotion, let view = window.contentView {
            view.wantsLayer = true
            view.layoutSubtreeIfNeeded()
            if let layer = view.layer {
                var start = CATransform3DMakeScale(0.8, 0.8, 1)
                // Keep the visual center fixed without changing AppKit's layer anchor or window geometry.
                start.m41 = (0.5 - layer.anchorPoint.x) * layer.bounds.width * 0.2
                start.m42 = (0.5 - layer.anchorPoint.y) * layer.bounds.height * 0.2
                let scale = CABasicAnimation(keyPath: "transform")
                scale.fromValue = NSValue(caTransform3D: start)
                scale.toValue = NSValue(caTransform3D: layer.transform)
                scale.duration = duration
                scale.timingFunction = timing
                scale.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil)
                layer.add(scale, forKey: animationKey)
            }
        }

        orderFront()
        window.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = timing
            window.animator().alphaValue = 1
        }
    }

    static func reset(_ window: NSWindow) {
        window.contentView?.layer?.removeAnimation(forKey: animationKey)
        window.alphaValue = 1
    }
}
