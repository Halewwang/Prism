import Foundation
import PrismCore

enum LinkPreviewMetrics {
    static let toolbarHeight: CGFloat = 48
    static let fieldRadius: CGFloat = 10
    static let browserInset: CGFloat = 3
    static let innerRadius: CGFloat = fieldRadius - browserInset
    static let browserHeight: CGFloat = toolbarHeight - 2 * browserInset
    static let browserWidth: CGFloat = 42
    static let browserGap: CGFloat = 4
    static let compactBreakpoint: CGFloat = 560
    static let compactBrowserWidth: CGFloat = 70
    static let candidateRowHeight: CGFloat = browserHeight
    static let candidateRowSpacing: CGFloat = 10
    static let candidateInset: CGFloat = browserInset

    static func candidateFrame(windowSize: CGSize, count: Int) -> CGRect {
        guard count > 0 else { return .zero }
        let width = browserWidth + 2 * candidateInset
        let rows = min(max(0, count), 6)
        let height = CGFloat(rows) * candidateRowHeight + CGFloat(max(0, rows - 1)) * candidateRowSpacing + 2 * candidateInset
        return CGRect(
            x: max(7, windowSize.width - 7 - 64 - 6 - compactBrowserWidth), y: 61,
            width: width, height: min(height, max(0, windowSize.height - 68))
        )
    }

    static func scrollingWidth(count: Int, windowWidth: CGFloat = 600) -> CGFloat {
        let count = max(0, count)
        guard count > 0 else { return 0 }
        let contentWidth = CGFloat(count) * browserWidth + CGFloat(max(count - 1, 0)) * browserGap
        let baseline = min(CGFloat(count), 3.5) * browserWidth + CGFloat(min(max(count - 1, 0), 3)) * browserGap
        // In a single row, share added width with the address field and stop at the last browser.
        let expanded = baseline + max(0, windowWidth - 600) / 2
        let groupChrome = browserWidth + 12 + 0.5 + 2 * browserInset
        let fixedWidth: CGFloat = 14 + 75 + 64 + 15 + 120
        let available = max(0, windowWidth - fixedWidth - groupChrome)
        return min(contentWidth, expanded, available)
    }

    static func compactAddressWidth(windowWidth: CGFloat) -> CGFloat {
        max(0, windowWidth - 14 - 48 - compactBrowserWidth - 64 - 18)
    }
}

enum LinkPreviewRecommendation {
    static func ordered(
        _ browsers: [BrowserDescriptor],
        successfulBrowserIDs: [BrowserID],
        fallback: BrowserID?
    ) -> [BrowserDescriptor] {
        let counts = Dictionary(successfulBrowserIDs.map { ($0, 1) }, uniquingKeysWith: +)
        let maximum = browsers.map { counts[$0.id] ?? 0 }.max() ?? 0
        let recommended = browsers.first { (counts[$0.id] ?? 0) == maximum }
        let id = recommended.flatMap { (counts[$0.id] ?? 0) > 0 ? $0.id : nil } ?? fallback
        guard let id, let index = browsers.firstIndex(where: { $0.id == id }) else { return browsers }
        var ordered = browsers
        ordered.insert(ordered.remove(at: index), at: 0)
        return ordered
    }
}
