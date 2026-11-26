import AppKit
import SwiftUI

@MainActor
final class InAppUpdateWindowController: NSWindowController, NSWindowDelegate {
    let session: InAppUpdateSession

    init(session: InAppUpdateSession) {
        self.session = session
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: InAppUpdateView.windowSize),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = NSLocalizedString("Update Prism", comment: "Update window")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        let hostingView = NSHostingView(rootView: InAppUpdateView(
            session: session,
            onClose: { [weak window] in window?.close() }
        ))
        hostingView.sizingOptions = []
        window.contentView = hostingView
        window.setFrame(NSRect(origin: window.frame.origin, size: InAppUpdateView.windowSize), display: false)
        super.init(window: window)
        window.delegate = self
        PrismAboutWindowController.centerOnActiveScreen(window)
    }

    required init?(coder: NSCoder) { nil }

    func present() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool { session.stage != .installing }
    func windowWillClose(_ notification: Notification) { session.dispose() }
}

struct UpdateReleaseNoteSection: Equatable, Identifiable {
    let id: Int
    let title: String?
    let items: [String]
}

enum UpdateReleaseNotesParser {
    static func parse(_ raw: String) -> [UpdateReleaseNoteSection] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var sections: [UpdateReleaseNoteSection] = []
        var currentTitle: String? = nil
        var currentItems: [String] = []

        func flush() {
            guard !currentItems.isEmpty else { return }
            sections.append(UpdateReleaseNoteSection(id: sections.count, title: currentTitle, items: currentItems))
            currentItems = []
        }

        for rawLine in trimmed.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("#") {
                flush()
                let heading = stripLeadingHashesAndDecorators(line)
                currentTitle = heading.isEmpty ? nil : heading
                continue
            }

            if let bullet = stripBulletPrefix(line) {
                let cleaned = stripInlineCodeTicks(bullet)
                if !cleaned.isEmpty { currentItems.append(cleaned) }
                continue
            }

            let cleaned = stripInlineCodeTicks(line)
            if currentTitle == nil && currentItems.isEmpty && sections.isEmpty && raw.contains("\n\n") && cleaned.count <= 42 {
                currentTitle = cleaned
            } else if !cleaned.isEmpty {
                currentItems.append(cleaned)
            }
        }
        flush()
        return sections
    }

    private static func stripLeadingHashesAndDecorators(_ line: String) -> String {
        var result = line.drop(while: { $0 == "#" || $0.isWhitespace })
        // Drop leading decorative emoji/symbols so section headings stay clean and typographic.
        while let first = result.first, first.unicodeScalars.allSatisfy({ $0.properties.isEmojiPresentation || $0.value == 0xFE0F || $0 == " " }) {
            result = result.dropFirst()
        }
        return String(result).trimmingCharacters(in: .whitespaces)
    }

    private static func stripBulletPrefix(_ line: String) -> String? {
        for prefix in ["- ", "* ", "• ", "· "] {
            if line.hasPrefix(prefix) {
                return String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private static func stripInlineCodeTicks(_ text: String) -> String {
        text.replacingOccurrences(of: "`", with: "")
    }
}

struct InAppUpdateView: View {
    static let contentInset: CGFloat = 26
    static let windowSize = NSSize(width: 472, height: 472 + WorkspaceLayout.windowControlClearance)

    let session: InAppUpdateSession
    var onClose: () -> Void = {}

    private var parsedNotes: [UpdateReleaseNoteSection] {
        UpdateReleaseNotesParser.parse(session.installer.notes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
                .padding(.bottom, 16)

            header
                .padding(.bottom, 18)

            hairline

            releaseNotes
                .padding(.vertical, 18)

            hairline

            footerZone
                .padding(.top, 16)
        }
        .padding(.horizontal, Self.contentInset)
        .padding(.bottom, Self.contentInset)
        .padding(.top, 10)
        .frame(width: Self.windowSize.width, height: Self.windowSize.height)
        .foregroundStyle(SettingsPalette.primary)
        .background(SettingsPalette.elevated)
        .ignoresSafeArea(.container, edges: .top)
        .tint(SettingsPalette.action)
    }

    private var topBar: some View {
        HStack {
            Spacer(minLength: 0)
            Link(destination: session.installer.releasePageURL) {
                Text(LocalizedStringKey("update.fullChangelog"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SettingsPalette.muted)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("update.changelogLink")
        }
        .frame(height: WorkspaceLayout.windowControlClearance)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 52, height: 52)
                .shadow(color: .black.opacity(0.22), radius: 8, y: 4)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(headlineText)
                    .font(.system(size: 17.5, weight: .semibold))
                    .tracking(-0.35)
                    .foregroundStyle(SettingsPalette.primary)
                    .lineLimit(1)
                    .accessibilityIdentifier("update.title")

                Text(metadataLine)
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(SettingsPalette.muted)
                    .lineLimit(1)
                    .accessibilityIdentifier("update.metadata")
            }
            Spacer(minLength: 0)
        }
    }

    private var headlineText: String {
        switch session.stage {
        case .available:
            String(format: NSLocalizedString("update.headline.available", comment: "Update available headline"), session.installer.version)
        case .downloading:
            String(format: NSLocalizedString("update.headline.downloading", comment: "Update downloading headline"), session.installer.version)
        case .ready, .installing:
            NSLocalizedString("update.headline.ready", comment: "Update ready headline")
        case .failed:
            NSLocalizedString("update.headline.failed", comment: "Update failed headline")
        }
    }

    private var metadataLine: String {
        var parts: [String] = [
            String(format: NSLocalizedString("update.meta.currentVersion", comment: "Current app version"), session.currentVersion)
        ]
        if session.installer.isPrerelease {
            parts.append(NSLocalizedString("Public Test", comment: "Public test channel"))
        }
        if let size = session.installer.formattedFileSize {
            parts.append(size)
        }
        return parts.joined(separator: " · ")
    }

    private var releaseNotes: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if parsedNotes.isEmpty {
                    Text(NSLocalizedString("A newer version of Prism is available.", comment: "Update notes"))
                        .font(.system(size: 12.5))
                        .lineSpacing(5)
                        .foregroundStyle(SettingsPalette.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                } else {
                    ForEach(parsedNotes) { section in
                        VStack(alignment: .leading, spacing: 7) {
                            if let title = section.title {
                                Text(title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(SettingsPalette.muted)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Circle()
                                            .fill(SettingsPalette.muted.opacity(0.6))
                                            .frame(width: 3.5, height: 3.5)
                                            .offset(y: -2.5)
                                            .accessibilityHidden(true)
                                        Text(item)
                                            .font(.system(size: 12.5))
                                            .lineSpacing(4)
                                            .foregroundStyle(SettingsPalette.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }
                    }
                    .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("update.releaseNotes")
    }

    private var footerZone: some View {
        VStack(alignment: .leading, spacing: 12) {
            statusContent

            if let message = session.message {
                ScrollView {
                    Text(message)
                        .font(.system(size: 12))
                        .lineSpacing(3)
                        .foregroundStyle(SettingsPalette.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("update.message")
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: 42)
            }

            #if PRISM_PUBLIC_TEST || DEBUG
            if session.stage == .ready {
                Toggle("Allow this unnotarized public-test update", isOn: Binding(
                    get: { session.allowUnnotarizedPublicTestUpdate },
                    set: { session.allowUnnotarizedPublicTestUpdate = $0 }
                ))
                .toggleStyle(.checkbox)
                .font(.system(size: 12))
                .foregroundStyle(SettingsPalette.secondary)
                .accessibilityIdentifier("update.allowUnnotarizedPublicTestUpdate")
            }
            #endif

            actionRow
        }
    }

    @ViewBuilder
    private var statusContent: some View {
        switch session.stage {
        case .available:
            EmptyView()
        case .downloading:
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(session.isVerifying
                         ? LocalizedStringKey("update.status.verifying")
                         : LocalizedStringKey("update.status.downloading"))
                        .font(.system(size: 11.5))
                        .foregroundStyle(SettingsPalette.muted)
                    Spacer(minLength: 8)
                    if let progressText = downloadProgressLabel {
                        Text(progressText)
                            .font(.system(size: 11.5))
                            .monospacedDigit()
                            .foregroundStyle(SettingsPalette.muted)
                    }
                }
                if let progress = session.progress {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(SettingsPalette.primary)
                        .accessibilityIdentifier("update.progress")
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityIdentifier("update.progress")
                }
            }
        case .ready:
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.green)
                    .accessibilityHidden(true)
                Text("Update verified. Ready to install.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SettingsPalette.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("update.ready")
        case .installing:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Preparing to install and restart…")
                    .font(.system(size: 12))
                    .foregroundStyle(SettingsPalette.muted)
            }
        case .failed:
            EmptyView()
        }
    }

    private var downloadProgressLabel: String? {
        guard let progress = session.progress else { return nil }
        let percent = Int((progress * 100).rounded())
        if let total = session.installer.fileByteCount, total > 0 {
            let received = Int64((Double(total) * progress).rounded())
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB, .useKB]
            formatter.countStyle = .file
            return "\(formatter.string(fromByteCount: received)) / \(formatter.string(fromByteCount: total)) · \(percent)%"
        }
        return "\(percent)%"
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            leftActions
            Spacer(minLength: 8)
            primaryAction
        }
        .frame(height: 34)
    }

    @ViewBuilder
    private var leftActions: some View {
        switch session.stage {
        case .available:
            HStack(spacing: 12) {
                Button(LocalizedStringKey("update.skipVersion")) {
                    session.skipThisVersion()
                    onClose()
                }
                .buttonStyle(WorkspaceButtonStyle(kind: .quiet, height: 32, horizontalPadding: 2, fontSize: 12.5))
                .accessibilityIdentifier("update.skip")

                Button(LocalizedStringKey("update.later"), action: onClose)
                    .buttonStyle(WorkspaceButtonStyle(kind: .quiet, height: 32, horizontalPadding: 2, fontSize: 12.5))
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("update.later")
            }
        case .downloading:
            Text("Your rules and history are kept.")
                .font(.system(size: 11.5))
                .foregroundStyle(SettingsPalette.muted)
        case .ready:
            Button("Show downloaded installer") { session.revealInstaller() }
                .buttonStyle(WorkspaceButtonStyle(kind: .quiet, height: 32, horizontalPadding: 2, fontSize: 12.5))
                .accessibilityIdentifier("update.revealInstaller")
        case .installing:
            Text("Your rules and history are kept.")
                .font(.system(size: 11.5))
                .foregroundStyle(SettingsPalette.muted)
        case .failed:
            Link(destination: session.installer.releasePageURL) {
                Text(LocalizedStringKey("update.openGitHub"))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(SettingsPalette.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("update.openGitHub")
        }
    }

    @ViewBuilder
    private var primaryAction: some View {
        switch session.stage {
        case .available:
            Button("Download update") { session.startDownload() }
                .buttonStyle(WorkspaceButtonStyle(kind: .primary, height: 34, horizontalPadding: 16, fontSize: 12.5))
                .accessibilityIdentifier("update.download")
        case .failed:
            Button("Retry download") { session.startDownload() }
                .buttonStyle(WorkspaceButtonStyle(kind: .primary, height: 34, horizontalPadding: 16, fontSize: 12.5))
                .accessibilityIdentifier("update.retry")
        case .downloading:
            Button("Cancel download") { session.cancelDownload() }
                .buttonStyle(WorkspaceButtonStyle(kind: .secondary, height: 32, horizontalPadding: 14, fontSize: 12))
                .accessibilityIdentifier("update.cancel")
        case .ready:
            Button("Install and restart") { session.startInstall() }
                .buttonStyle(WorkspaceButtonStyle(kind: .primary, height: 34, horizontalPadding: 16, fontSize: 12.5))
                .accessibilityIdentifier("update.install")
        case .installing:
            Button("Install and restart") {}
                .disabled(true)
                .buttonStyle(WorkspaceButtonStyle(kind: .primary, height: 34, horizontalPadding: 16, fontSize: 12.5))
        }
    }

    private var hairline: some View {
        Rectangle()
            .fill(SettingsPalette.border)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}
