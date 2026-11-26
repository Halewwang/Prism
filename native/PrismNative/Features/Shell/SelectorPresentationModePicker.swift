import AppKit
import PrismCore
import SwiftUI

struct SelectorPresentationModeOption: Equatable, Identifiable, Sendable {
    let mode: SelectorPresentationMode
    let title: String
    let accessibilityIdentifier: String

    var id: SelectorPresentationMode { mode }

    static let all: [SelectorPresentationModeOption] = [
        SelectorPresentationModeOption(
            mode: .compact,
            title: "selector.presentation.compact",
            accessibilityIdentifier: "settings.selectorPresentationMode.compact"
        ),
        SelectorPresentationModeOption(
            mode: .preview,
            title: "selector.presentation.preview",
            accessibilityIdentifier: "settings.selectorPresentationMode.preview"
        ),
    ]
}

struct SelectorPresentationModePicker: View {
    @Binding var selection: SelectorPresentationMode
    @Environment(\.colorSchemeContrast) private var contrast
    @FocusState private var focusedMode: SelectorPresentationMode?

    var body: some View {
        HStack(spacing: 12) {
            ForEach(SelectorPresentationModeOption.all) { option in
                SelectorPresentationModeCard(
                    option: option,
                    isSelected: selection == option.mode,
                    isFocused: focusedMode == option.mode,
                    increasedContrast: contrast == .increased
                ) {
                    selection = option.mode
                }
                .focused($focusedMode, equals: option.mode)
            }
        }
        .onKeyPress(.leftArrow) {
            selection = .compact
            focusedMode = .compact
            return .handled
        }
        .onKeyPress(.rightArrow) {
            selection = .preview
            focusedMode = .preview
            return .handled
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(LocalizedStringKey("selector.presentation.title"))
        .accessibilityIdentifier("settings.selectorPresentationMode")
    }
}

private struct SelectorPresentationModeCard: View {
    let option: SelectorPresentationModeOption
    let isSelected: Bool
    let isFocused: Bool
    let increasedContrast: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                SelectorPresentationWireframeStage(
                    mode: option.mode,
                    isSelected: isSelected
                )
                .frame(maxWidth: .infinity)
                .frame(height: 152)

                HStack(spacing: 8) {
                    Text(LocalizedStringKey(option.title))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? SettingsPalette.primary : SettingsPalette.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    selectionIndicator
                }
                .padding(.horizontal, 2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .focusable()
        .focusEffectDisabled()
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(LocalizedStringKey(option.title))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
        .accessibilityIdentifier(option.accessibilityIdentifier)
    }

    private var cardBackground: Color {
        if isSelected { return WireframePalette.cardSelectedBackground }
        if isHovered { return WireframePalette.cardHoverBackground }
        return SettingsPalette.group
    }

    private var borderColor: Color {
        if isSelected {
            return increasedContrast ? SettingsPalette.action : WireframePalette.selectedBorder
        }
        if isFocused || isHovered || increasedContrast {
            return SettingsPalette.borderStrong
        }
        return SettingsPalette.border
    }

    private var borderWidth: CGFloat {
        isSelected && increasedContrast ? 1.5 : 1
    }

    private var selectionIndicator: some View {
        ZStack {
            Circle()
                .fill(isSelected ? SettingsPalette.action : .clear)
            Circle()
                .stroke(
                    isSelected ? SettingsPalette.action : SettingsPalette.borderStrong,
                    lineWidth: 1.25
                )
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(SettingsPalette.actionText)
            }
        }
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
    }
}

private struct SelectorPresentationWireframeStage: View {
    let mode: SelectorPresentationMode
    let isSelected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? WireframePalette.stageSelectedBackground : WireframePalette.stageBackground)

            Canvas { context, size in
                drawDotGrid(in: &context, size: size)
                switch mode {
                case .compact:
                    drawCompactSelectorWireframe(in: &context, size: size)
                case .preview:
                    drawLinkPreviewWireframe(in: &context, size: size)
                }
            }
            .opacity(isSelected ? 1 : 0.78)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? SettingsPalette.border : SettingsPalette.borderSubtle, lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    private func drawDotGrid(in context: inout GraphicsContext, size: CGSize) {
        let step: CGFloat = 12
        let dotColor = SettingsPalette.borderStrong.opacity(0.22)
        var y: CGFloat = step / 2
        while y < size.height {
            var x: CGFloat = step / 2
            while x < size.width {
                let dotRect = CGRect(x: x - 0.75, y: y - 0.75, width: 1.5, height: 1.5)
                context.fill(Path(ellipseIn: dotRect), with: .color(dotColor))
                x += step
            }
            y += step
        }
    }

    private func drawCompactSelectorWireframe(in context: inout GraphicsContext, size: CGSize) {
        let verticalInset: CGFloat = 30
        let horizontalInset = max(28, min(42, size.width * 0.12))
        let windowRect = CGRect(
            x: horizontalInset,
            y: verticalInset,
            width: max(140, size.width - horizontalInset * 2),
            height: max(76, size.height - verticalInset * 2)
        )

        drawWindowShell(in: &context, rect: windowRect)

        let pad: CGFloat = 7
        let innerWidth = windowRect.width - pad * 2
        let headerY = windowRect.minY + pad
        let headerH: CGFloat = 15
        let gap: CGFloat = 4

        let sourceW = max(38, innerWidth * 0.20)
        let cancelW = max(32, innerWidth * 0.16)
        let urlW = max(40, innerWidth - sourceW - cancelW - gap * 2)

        // Source pill
        let sourceRect = CGRect(x: windowRect.minX + pad, y: headerY, width: sourceW, height: headerH)
        fillRounded(in: &context, rect: sourceRect, radius: 4.5, color: WireframePalette.pill)
        fillCircle(in: &context, center: CGPoint(x: sourceRect.minX + 7.5, y: sourceRect.midY), radius: 3, color: WireframePalette.lineStrong)
        fillRounded(
            in: &context,
            rect: CGRect(x: sourceRect.minX + 13.5, y: sourceRect.midY - 1.5, width: max(8, sourceW - 19), height: 3),
            radius: 1.5,
            color: WireframePalette.lineSoft
        )

        // URL pill
        let urlRect = CGRect(x: sourceRect.maxX + gap, y: headerY, width: urlW, height: headerH)
        fillRounded(in: &context, rect: urlRect, radius: 4.5, color: WireframePalette.pill)
        fillRounded(
            in: &context,
            rect: CGRect(x: urlRect.minX + 7, y: urlRect.midY - 1.5, width: urlW * 0.56, height: 3),
            radius: 1.5,
            color: WireframePalette.lineSoft
        )

        // Cancel pill
        let cancelRect = CGRect(x: urlRect.maxX + gap, y: headerY, width: cancelW, height: headerH)
        fillRounded(in: &context, rect: cancelRect, radius: 4.5, color: WireframePalette.pill)
        let cancelLineW = cancelW * 0.48
        fillRounded(
            in: &context,
            rect: CGRect(x: cancelRect.midX - cancelLineW / 2, y: cancelRect.midY - 1.5, width: cancelLineW, height: 3),
            radius: 1.5,
            color: WireframePalette.lineSoft
        )

        // Browser strip container
        let stripY = headerY + headerH + 5
        let stripRect = CGRect(
            x: windowRect.minX + pad,
            y: stripY,
            width: innerWidth,
            height: windowRect.maxY - pad - stripY
        )
        fillRounded(in: &context, rect: stripRect, radius: 7, color: WireframePalette.pill.opacity(0.5))

        // 3 equal browser tiles
        let tileInset: CGFloat = 4
        let tileGap: CGFloat = 5
        let tileW = (stripRect.width - tileInset * 2 - tileGap * 2) / 3
        let tileH = stripRect.height - tileInset * 2
        let tileOpacities: [Double] = [1.0, 0.72, 0.48]

        for index in 0 ..< 3 {
            let tileRect = CGRect(
                x: stripRect.minX + tileInset + CGFloat(index) * (tileW + tileGap),
                y: stripRect.minY + tileInset,
                width: tileW,
                height: tileH
            )
            let isFirst = index == 0
            fillRounded(
                in: &context,
                rect: tileRect,
                radius: 6,
                color: isFirst ? WireframePalette.tileActive : WireframePalette.tileBackground
            )
            if isFirst {
                strokeRounded(in: &context, rect: tileRect, radius: 6, color: WireframePalette.tileActiveBorder, lineWidth: 1)
            }

            // Browser icon dot
            let iconCenter = CGPoint(x: tileRect.midX, y: tileRect.minY + tileH * 0.34)
            fillCircle(
                in: &context,
                center: iconCenter,
                radius: 7.5,
                color: isFirst ? WireframePalette.accentDot : WireframePalette.lineStrong.opacity(tileOpacities[index])
            )

            // Browser label bar
            let labelW = tileW * (isFirst ? 0.48 : 0.44)
            fillRounded(
                in: &context,
                rect: CGRect(x: tileRect.midX - labelW / 2, y: tileRect.minY + tileH * 0.62, width: labelW, height: 3),
                radius: 1.5,
                color: isFirst ? WireframePalette.lineStrong : WireframePalette.lineSoft
            )

            // Shortcut keycap (1 / 2 / 3)
            let keycapRect = CGRect(x: tileRect.midX - 5.5, y: tileRect.maxY - 11.5, width: 11, height: 8)
            fillRounded(in: &context, rect: keycapRect, radius: 2.2, color: WireframePalette.windowBackground)
            strokeRounded(in: &context, rect: keycapRect, radius: 2.2, color: WireframePalette.windowBorder, lineWidth: 0.8)
            context.draw(
                Text("\(index + 1)")
                    .font(.system(size: 6, weight: .semibold).monospacedDigit())
                    .foregroundStyle(WireframePalette.lineStrong),
                at: CGPoint(x: keycapRect.midX, y: keycapRect.midY)
            )
        }
    }

    private func drawLinkPreviewWireframe(in context: inout GraphicsContext, size: CGSize) {
        let inset: CGFloat = 20
        let windowRect = CGRect(
            x: inset,
            y: inset,
            width: max(160, size.width - inset * 2),
            height: max(84, size.height - inset * 2)
        )

        drawWindowShell(in: &context, rect: windowRect)

        let pad: CGFloat = 7
        let innerWidth = windowRect.width - pad * 2
        let barY = windowRect.minY + pad
        let barH: CGFloat = 16
        let gap: CGFloat = 4

        let sourceW: CGFloat = 19
        let browserGroupW: CGFloat = 67
        let cancelW: CGFloat = 26
        let urlW = max(50, innerWidth - sourceW - browserGroupW - cancelW - gap * 3)

        // Source icon pill
        let sourceRect = CGRect(x: windowRect.minX + pad, y: barY, width: sourceW, height: barH)
        fillRounded(in: &context, rect: sourceRect, radius: 4.5, color: WireframePalette.pill)
        fillCircle(in: &context, center: CGPoint(x: sourceRect.midX, y: sourceRect.midY), radius: 3.3, color: WireframePalette.lineStrong)

        // Navigation + URL + reload bar
        let urlRect = CGRect(x: sourceRect.maxX + gap, y: barY, width: urlW, height: barH)
        fillRounded(in: &context, rect: urlRect, radius: 4.5, color: WireframePalette.pill)

        var chevrons = Path()
        let midY = urlRect.midY
        chevrons.move(to: CGPoint(x: urlRect.minX + 7.2, y: midY - 2.2))
        chevrons.addLine(to: CGPoint(x: urlRect.minX + 5.0, y: midY))
        chevrons.addLine(to: CGPoint(x: urlRect.minX + 7.2, y: midY + 2.2))
        chevrons.move(to: CGPoint(x: urlRect.minX + 12.2, y: midY - 2.2))
        chevrons.addLine(to: CGPoint(x: urlRect.minX + 14.4, y: midY))
        chevrons.addLine(to: CGPoint(x: urlRect.minX + 12.2, y: midY + 2.2))
        context.stroke(
            chevrons,
            with: .color(WireframePalette.lineStrong),
            style: StrokeStyle(lineWidth: 1.15, lineCap: .round, lineJoin: .round)
        )

        fillRounded(
            in: &context,
            rect: CGRect(x: urlRect.minX + 20, y: midY - 1.5, width: max(20, (urlW - 34) * 0.68), height: 3),
            radius: 1.5,
            color: WireframePalette.lineSoft
        )
        let reloadRect = CGRect(x: urlRect.maxX - 10.2, y: midY - 2.7, width: 5.4, height: 5.4)
        context.stroke(Path(ellipseIn: reloadRect), with: .color(WireframePalette.lineStrong), lineWidth: 1.05)

        // Compact browser switcher strip in toolbar
        let groupRect = CGRect(x: urlRect.maxX + gap, y: barY, width: browserGroupW, height: barH)
        fillRounded(in: &context, rect: groupRect, radius: 4.5, color: WireframePalette.pill)

        let activeTileRect = CGRect(x: groupRect.minX + 3, y: groupRect.minY + 2.3, width: 16, height: barH - 4.6)
        fillRounded(in: &context, rect: activeTileRect, radius: 2.8, color: WireframePalette.tileActive)
        strokeRounded(in: &context, rect: activeTileRect, radius: 2.8, color: WireframePalette.tileActiveBorder, lineWidth: 0.7)
        fillCircle(in: &context, center: CGPoint(x: activeTileRect.midX, y: activeTileRect.midY), radius: 3.1, color: WireframePalette.accentDot)

        var divider = Path()
        let dividerX = activeTileRect.maxX + 3.5
        divider.move(to: CGPoint(x: dividerX, y: groupRect.minY + 2.8))
        divider.addLine(to: CGPoint(x: dividerX, y: groupRect.maxY - 2.8))
        context.stroke(divider, with: .color(WireframePalette.windowBorder), lineWidth: 0.9)

        let secondaryOpacities: [Double] = [0.75, 0.50, 0.35]
        for (offset, opacity) in secondaryOpacities.enumerated() {
            let cx = dividerX + 8.5 + CGFloat(offset) * 13
            fillCircle(in: &context, center: CGPoint(x: cx, y: groupRect.midY), radius: 3.1, color: WireframePalette.lineStrong.opacity(opacity))
        }

        // Cancel / Esc pill
        let cancelRect = CGRect(x: groupRect.maxX + gap, y: barY, width: cancelW, height: barH)
        fillRounded(in: &context, rect: cancelRect, radius: 4.5, color: WireframePalette.pill)
        fillRounded(
            in: &context,
            rect: CGRect(x: cancelRect.midX - 6.5, y: cancelRect.midY - 1.5, width: 13, height: 3),
            radius: 1.5,
            color: WireframePalette.lineSoft
        )

        // Webpage preview canvas
        let webY = barY + barH + 5
        let webRect = CGRect(
            x: windowRect.minX + pad,
            y: webY,
            width: innerWidth,
            height: windowRect.maxY - pad - webY
        )
        fillRounded(in: &context, rect: webRect, radius: 7, color: WireframePalette.tileBackground)
        strokeRounded(in: &context, rect: webRect, radius: 7, color: WireframePalette.windowBorder, lineWidth: 0.8)

        // Webpage hero block
        let contentInset: CGFloat = 9
        let contentW = webRect.width - contentInset * 2
        let heroRect = CGRect(x: webRect.minX + contentInset, y: webRect.minY + 7.5, width: contentW, height: 22)
        fillRounded(in: &context, rect: heroRect, radius: 4.5, color: WireframePalette.webHero)
        fillRounded(
            in: &context,
            rect: CGRect(x: heroRect.minX + 8, y: heroRect.minY + 6, width: contentW * 0.32, height: 4),
            radius: 2,
            color: WireframePalette.lineStrong
        )
        fillRounded(
            in: &context,
            rect: CGRect(x: heroRect.minX + 8, y: heroRect.minY + 13, width: contentW * 0.52, height: 3),
            radius: 1.5,
            color: WireframePalette.lineSoft
        )

        // Webpage body: left text lines + right media thumbnail
        let bodyY = heroRect.maxY + 7
        let mediaW = max(68, contentW * 0.37)
        let textAreaW = contentW - mediaW - 10
        let textX = webRect.minX + contentInset

        fillRounded(in: &context, rect: CGRect(x: textX, y: bodyY, width: textAreaW * 0.66, height: 4), radius: 2, color: WireframePalette.lineStrong)
        let lineFractions: [CGFloat] = [1.0, 0.92, 0.95, 0.62]
        for (lineIndex, fraction) in lineFractions.enumerated() {
            let ly = bodyY + 8.5 + CGFloat(lineIndex) * 7.2
            guard ly + 3 <= webRect.maxY - 5 else { break }
            fillRounded(
                in: &context,
                rect: CGRect(x: textX, y: ly, width: textAreaW * fraction, height: 3),
                radius: 1.5,
                color: WireframePalette.lineSoft
            )
        }

        let mediaRect = CGRect(
            x: webRect.maxX - contentInset - mediaW,
            y: bodyY,
            width: mediaW,
            height: max(24, webRect.maxY - bodyY - 7)
        )
        fillRounded(in: &context, rect: mediaRect, radius: 4.5, color: WireframePalette.webMedia)
        fillCircle(
            in: &context,
            center: CGPoint(x: mediaRect.minX + mediaRect.width * 0.22, y: mediaRect.minY + mediaRect.height * 0.32),
            radius: 3.5,
            color: WireframePalette.lineStrong.opacity(0.55)
        )

        var hills = Path()
        let baseY = mediaRect.maxY - 6
        hills.move(to: CGPoint(x: mediaRect.minX + 8, y: baseY))
        hills.addLine(to: CGPoint(x: mediaRect.minX + mediaRect.width * 0.30, y: mediaRect.minY + mediaRect.height * 0.48))
        hills.addLine(to: CGPoint(x: mediaRect.minX + mediaRect.width * 0.48, y: mediaRect.minY + mediaRect.height * 0.74))
        hills.addLine(to: CGPoint(x: mediaRect.minX + mediaRect.width * 0.65, y: mediaRect.minY + mediaRect.height * 0.52))
        hills.addLine(to: CGPoint(x: mediaRect.maxX - 8, y: baseY))
        context.stroke(
            hills,
            with: .color(WireframePalette.lineStrong.opacity(0.65)),
            style: StrokeStyle(lineWidth: 1.35, lineCap: .round, lineJoin: .round)
        )
    }

    private func drawWindowShell(in context: inout GraphicsContext, rect: CGRect) {
        let shell = Path(roundedRect: rect, cornerRadius: 11, style: .continuous)
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: Color.black.opacity(0.11), radius: 3.5, x: 0, y: 2.5))
            layer.fill(shell, with: .color(WireframePalette.windowBackground))
        }
        context.stroke(shell, with: .color(WireframePalette.windowBorder), lineWidth: 1.1)
    }

    private func fillRounded(in context: inout GraphicsContext, rect: CGRect, radius: CGFloat, color: Color) {
        context.fill(Path(roundedRect: rect, cornerRadius: radius, style: .continuous), with: .color(color))
    }

    private func strokeRounded(in context: inout GraphicsContext, rect: CGRect, radius: CGFloat, color: Color, lineWidth: CGFloat) {
        context.stroke(Path(roundedRect: rect, cornerRadius: radius, style: .continuous), with: .color(color), lineWidth: lineWidth)
    }

    private func fillCircle(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat, color: Color) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .color(color))
    }
}

private enum WireframePalette {
    static let selectedBorder = adaptive(light: 0x525258, dark: 0x9E9EA8)
    static let cardSelectedBackground = adaptive(light: 0xFAFAFB, dark: 0x323236)
    static let cardHoverBackground = adaptive(light: 0xFCFCFD, dark: 0x2E2E31)
    static let stageBackground = adaptive(light: 0xF4F4F5, dark: 0x222225)
    static let stageSelectedBackground = adaptive(light: 0xEFEFF2, dark: 0x1E1E22)
    static let windowBackground = adaptive(light: 0xFFFFFF, dark: 0x2C2C30)
    static let windowBorder = adaptive(light: 0xDADAE0, dark: 0x48484E)
    static let pill = adaptive(light: 0xF1F1F4, dark: 0x3A3A40)
    static let tileBackground = adaptive(light: 0xF7F7F9, dark: 0x35353B)
    static let tileActive = adaptive(light: 0xE8E8ED, dark: 0x47474F)
    static let tileActiveBorder = adaptive(light: 0xBCBCC6, dark: 0x7A7A85)
    static let lineStrong = adaptive(light: 0xA6A6B0, dark: 0x92929C)
    static let lineSoft = adaptive(light: 0xDCDCE2, dark: 0x4B4B53)
    static let accentDot = adaptive(light: 0x2E2E32, dark: 0xE6E6EC)
    static let webHero = adaptive(light: 0xEBEBF0, dark: 0x3A3A41)
    static let webMedia = adaptive(light: 0xE4E4EA, dark: 0x42424A)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let value = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(
                red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        }))
    }
}
