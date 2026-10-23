import AppKit
import SwiftUI

@MainActor
final class InAppUpdateWindowController: NSWindowController, NSWindowDelegate {
    let session: InAppUpdateSession

    init(session: InAppUpdateSession) {
        self.session = session
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: InAppUpdateView.windowSize), styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView], backing: .buffered, defer: false)
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
        window.center()
    }
    required init?(coder: NSCoder) { nil }
    func present() { showWindow(nil); window?.makeKeyAndOrderFront(nil); NSApp.activate() }
    func windowShouldClose(_ sender: NSWindow) -> Bool { session.stage != .installing }
    func windowWillClose(_ notification: Notification) { session.dispose() }
}

struct InAppUpdateView: View {
    static let windowSize = NSSize(width: 560, height: 560 + WorkspaceLayout.windowControlClearance)
    let session: InAppUpdateSession
    var onClose: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            releaseNotes
            installationStatus
            footer
        }
        .padding(WorkspaceLayout.dialogContentInset)
        .padding(.top, WorkspaceLayout.windowControlClearance)
        .frame(width: Self.windowSize.width, height: Self.windowSize.height)
        .foregroundStyle(SettingsPalette.primary)
        .background(SettingsPalette.elevated)
        .ignoresSafeArea(.container, edges: .top)
        .tint(SettingsPalette.action)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image("PrismBrand")
                .renderingMode(.original)
                .resizable().scaledToFit()
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(session.stage == .available ? LocalizedStringKey("A new version is available") : LocalizedStringKey("Update Prism"))
                    .font(.system(size: 27, weight: .medium))
                    .accessibilityIdentifier("update.title")
                Text("Prism \(session.installer.version)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SettingsPalette.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var releaseNotes: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(format: String(localized: "update.releaseNotesVersion"), session.installer.version))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SettingsPalette.tertiary)
            ScrollView {
                Text(session.installer.notes.isEmpty ? NSLocalizedString("A newer version of Prism is available.", comment: "Update notes") : session.installer.notes)
                    .font(.system(size: 13))
                    .lineSpacing(5)
                    .foregroundStyle(SettingsPalette.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .scrollBounceBehavior(.basedOnSize)
            .accessibilityIdentifier("update.releaseNotes")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var installationStatus: some View {
        VStack(alignment: .leading, spacing: 12) {
            status
            if let message = session.message {
                ScrollView {
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(SettingsPalette.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("update.message")
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: 54)
            }
            if session.stage == .ready {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Allow this unnotarized public-test update", isOn: Binding(
                        get: { session.allowUnnotarizedPublicTestUpdate },
                        set: { session.allowUnnotarizedPublicTestUpdate = $0 }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.system(size: 13))
                    .accessibilityIdentifier("update.allowUnnotarizedPublicTestUpdate")
                    Text("This update has not been notarized by Apple. Permission applies only to this verified Prism update.")
                        .font(.system(size: 12)).foregroundStyle(SettingsPalette.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your rules and history are kept.")
                .font(.system(size: 12))
                .foregroundStyle(SettingsPalette.tertiary)
            HStack(spacing: 10) {
                if session.stage == .ready {
                    Button("Show downloaded installer") { session.revealInstaller() }
                        .buttonStyle(WorkspaceButtonStyle(kind: .quiet, height: 39))
                        .accessibilityIdentifier("update.revealInstaller")
                } else if session.stage == .available {
                    Button("Remind me later", action: onClose)
                        .buttonStyle(WorkspaceButtonStyle(kind: .quiet, height: 39))
                        .keyboardShortcut(.cancelAction)
                }
                Spacer()
                action
            }
            .frame(height: 39)
            .buttonStyle(WorkspaceButtonStyle(kind: .secondary, height: 39))
        }
    }
    @ViewBuilder private var status: some View {
        switch session.stage {
        case .available, .failed:
            Text("Download and verify the update before installing.").font(.system(size: 13)).foregroundStyle(SettingsPalette.tertiary)
        case .downloading:
            VStack(alignment: .leading, spacing: 8) {
                if let progress = session.progress {
                    ProgressView(value: progress).accessibilityIdentifier("update.progress")
                } else { ProgressView().controlSize(.small) }
                Text("Downloading and verifying update…").font(.system(size: 13))
            }
        case .ready:
            Label("Update verified. Ready to install.", systemImage: "checkmark.shield")
                .font(.system(size: 13)).accessibilityIdentifier("update.ready")
        case .installing:
            HStack { ProgressView().controlSize(.small); Text("Preparing to install and restart…").font(.system(size: 13)) }
        }
    }
    @ViewBuilder private var action: some View {
        switch session.stage {
        case .available:
            Button("Download update") { session.startDownload() }.buttonStyle(WorkspaceButtonStyle(kind: .primary, height: 39)).accessibilityIdentifier("update.download")
        case .failed:
            Button("Retry download") { session.startDownload() }.buttonStyle(WorkspaceButtonStyle(kind: .primary, height: 39)).accessibilityIdentifier("update.retry")
        case .downloading:
            Button("Cancel download") { session.cancelDownload() }.accessibilityIdentifier("update.cancel")
        case .ready:
            Button("Install and restart") { session.startInstall() }.buttonStyle(WorkspaceButtonStyle(kind: .primary, height: 39)).accessibilityIdentifier("update.install")
        case .installing:
            Button("Install and restart") {}.disabled(true).buttonStyle(WorkspaceButtonStyle(kind: .primary, height: 39))
        }
    }
}
