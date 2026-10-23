import AppKit
import QuartzCore
import Testing
@testable import PrismNative

@Suite("Window presentation animation")
@MainActor
struct WindowPresentationAnimationTests {
    @Test func scaleKeepsTheVisualCenterAndFinalGeometryUnchanged() throws {
        let window = NSWindow(
            contentRect: CGRect(x: 30, y: 40, width: 400, height: 200),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let view = try #require(window.contentView)
        view.wantsLayer = true
        let layer = try #require(view.layer)
        let originalFrame = window.frame
        var orderedWithAnimation = false

        WindowPresentationAnimation.show(window, reduceMotion: false) {
            orderedWithAnimation = layer.animation(forKey: "prism.windowPresentation") != nil
                && window.alphaValue == 1
            window.orderFront(nil)
        }

        let animation = try #require(layer.animation(forKey: "prism.windowPresentation") as? CABasicAnimation)
        let start = try #require(animation.fromValue as? NSValue).caTransform3DValue
        let centerX = (0.5 - layer.anchorPoint.x) * layer.bounds.width
        let centerY = (0.5 - layer.anchorPoint.y) * layer.bounds.height
        #expect(abs(start.m11 * centerX + start.m41 - centerX) < 0.001)
        #expect(abs(start.m22 * centerY + start.m42 - centerY) < 0.001)
        #expect(orderedWithAnimation)
        #expect(window.frame == originalFrame)
        #expect(CATransform3DIsIdentity(layer.transform))
        #expect(waitUntil { window.alphaValue == 1 })
        #expect(window.animationBehavior == .none)
    }

    @Test func reducedMotionClearsStaleScaleAndStillShowsTheWindow() throws {
        let window = NSWindow(
            contentRect: CGRect(x: 30, y: 40, width: 400, height: 200),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        defer { window.close() }
        WindowPresentationAnimation.show(window, reduceMotion: false) { window.orderFront(nil) }
        window.orderOut(nil)

        WindowPresentationAnimation.show(window, reduceMotion: true) { window.orderFront(nil) }

        let layer = try #require(window.contentView?.layer)
        #expect(layer.animation(forKey: "prism.windowPresentation") == nil)
        #expect(CATransform3DIsIdentity(layer.transform))
        #expect(window.isVisible)
        #expect(waitUntil { window.alphaValue == 1 })
    }

    private func waitUntil(_ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(1)
        while !condition(), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        return condition()
    }
}
