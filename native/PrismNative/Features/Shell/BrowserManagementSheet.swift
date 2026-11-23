import AppKit
import PrismCore
import SwiftUI

struct BrowserManagementRowIdentity: Hashable {
    let browserID: BrowserID
    let applicationURL: URL
}

extension BrowserDescriptor {
    var managementRowIdentity: BrowserManagementRowIdentity {
        BrowserManagementRowIdentity(browserID: id, applicationURL: applicationURL.standardizedFileURL)
    }
}

enum BrowserManagementPresentation {
    static func browsers(
        discovered: [BrowserDescriptor],
        custom: [BrowserDescriptor],
        alternateNames: [BrowserID: String]? = nil
    ) -> [BrowserDescriptor] {
        let customRows = custom.map { browser in
            let matchedDiscovered = discovered.first {
                $0.id == browser.id && $0.applicationURL.standardizedFileURL == browser.applicationURL.standardizedFileURL
            }
            let baseName = matchedDiscovered?.originalDisplayName ?? browser.originalDisplayName
            let resolvedAlternate = alternateNames != nil
                ? alternateNames?[browser.id]
                : (matchedDiscovered?.alternateName ?? browser.alternateName)
            return BrowserDescriptor(
                id: browser.id,
                bundleIdentifier: browser.bundleIdentifier,
                displayName: baseName,
                originalDisplayName: baseName,
                alternateName: resolvedAlternate,
                applicationURL: browser.applicationURL,
                securityScopedBookmark: browser.securityScopedBookmark,
                origin: .custom,
                availability: matchedDiscovered != nil ? .available : .unavailable,
                selectorOrder: browser.selectorOrder,
                profile: browser.profile
            )
        }
        let systemRows = discovered.filter { browser in
            !custom.contains {
                $0.id == browser.id && $0.applicationURL.standardizedFileURL == browser.applicationURL.standardizedFileURL
            }
        }.map { browser in
            guard let alternateNames else { return browser }
            return browser.withAlternateName(alternateNames[browser.id])
        }
        return systemRows + customRows
    }
}

private struct BrowserRenameTarget: Identifiable {
    let browser: BrowserDescriptor
    var id: BrowserManagementRowIdentity { browser.managementRowIdentity }
}

struct BrowserManagementSheet: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    let browserCatalog: any BrowserCataloging
    let addCustomBrowser: @MainActor () async -> OnboardingCustomBrowserResult

    @State private var browsers: [BrowserDescriptor] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var pendingRemoval: BrowserDescriptor?
    @State private var renameTarget: BrowserRenameTarget?
    @State private var hiddenBrowserIDs: Set<BrowserID> = []
    @State private var alternateNames: [BrowserID: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text("Available browsers")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(SettingsPalette.secondary)
                    .frame(height: 33, alignment: .leading)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13))
                        .frame(width: 24, height: 33)
                }
                    .buttonStyle(WorkspaceButtonStyle(kind: .quiet, height: 33))
                    .keyboardShortcut(.cancelAction)
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier("browsers.done")
            }
            Text("Prism discovers installed browsers. You can also add one manually.")
                .font(.system(size: 12))
                .foregroundStyle(SettingsPalette.muted)
                .frame(height: 19, alignment: .leading)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("browsers.selectorVisibilityHeader")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SettingsPalette.secondary)
                    Spacer()
                    if !browsers.isEmpty {
                        Text(String(
                            format: String(localized: "browsers.visibleCountFormat", defaultValue: "%lld of %lld shown"),
                            Int64(visibleAvailableBrowserCount),
                            Int64(availableBrowserCount)
                        ))
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(SettingsPalette.muted)
                        .accessibilityIdentifier("browsers.visibleCount")
                    }
                }
                ScrollView {
                    SettingsGroup {
                        if browsers.isEmpty {
                            VStack(spacing: 12) {
                                if isLoading {
                                    ProgressView("Scanning browsers…")
                                } else {
                                    Image(systemName: "safari")
                                        .font(.system(size: 28))
                                    Text("No browsers are ready yet")
                                        .font(.headline)
                                    Text("Rescan installed applications or add a browser manually.")
                                        .font(.system(size: 13))
                                        .foregroundStyle(SettingsPalette.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 180)
                        } else {
                            ForEach(Array(browsers.enumerated()), id: \.element.managementRowIdentity) { index, browser in
                                browserRow(browser)
                                if index < browsers.count - 1 { SettingsSeparator(color: SettingsPalette.sidebar) }
                            }
                        }
                    }
                }
                .frame(height: 292)
            }
            HStack(spacing: 10) {
                Button {
                    Task { await reload() }
                } label: {
                    Text("Rescan")
                }
                .disabled(isLoading)
                .buttonStyle(WorkspaceButtonStyle(kind: .secondary, height: 39))
                .accessibilityIdentifier("browsers.rescan")
                Button("browsers.addButton") {
                    Task {
                        isLoading = true
                        let result = await addCustomBrowser()
                        isLoading = false
                        switch result {
                        case .added: await reload()
                        case .cancelled: break
                        case .failed: errorMessage = "The browser could not be added. Choose an application that can open web links."
                        }
                    }
                }
                .buttonStyle(WorkspaceButtonStyle(kind: .primary, height: 39))
                .disabled(isLoading)
                .accessibilityIdentifier("browsers.add")
                Spacer()
            }
            Label {
                Text(LocalizedStringKey(bannerMessage))
                    .font(.system(size: 11))
                    .foregroundStyle(errorMessage == nil ? SettingsPalette.muted : SettingsPalette.danger)
            } icon: {
                Image(systemName: bannerSymbol)
                    .foregroundStyle(errorMessage == nil ? SettingsPalette.iconDefault : SettingsPalette.danger)
            }
            .padding(15)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(SettingsPalette.window, in: RoundedRectangle(cornerRadius: 8))
            .accessibilityIdentifier(errorMessage == nil ? "browsers.pickerHint" : "browsers.error")
            Text("Hidden browsers remain available to routing rules and fallback settings.")
                .font(.system(size: 11))
                .foregroundStyle(SettingsPalette.muted)
                .frame(height: 18, alignment: .leading)
        }
        .padding(28)
        .frame(width: 666, height: 630)
        .background(SettingsPalette.canvas)
        .tint(SettingsPalette.primary)
        .task { await reload() }
        .sheet(item: $renameTarget) { target in
            BrowserAlternateNameSheet(browser: target.browser) { newName in
                saveAlternateName(newName, for: target.browser)
            }
        }
        .confirmationDialog("Remove this custom browser?", isPresented: Binding(
            get: { pendingRemoval != nil },
            set: { if !$0 { pendingRemoval = nil } }
        ), titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                guard let pendingRemoval else { return }
                do {
                    try environment.browserPreferenceRepository.deleteCustomBrowser(id: pendingRemoval.id)
                    self.pendingRemoval = nil
                    Task { await reload() }
                } catch {
                    errorMessage = "The custom browser could not be removed. Try again."
                }
            }
            Button("Cancel", role: .cancel) { pendingRemoval = nil }
        } message: {
            if let pendingRemoval {
                Text(String(format: String(localized: "Remove %@ at %@?\n\nRemoving a custom entry does not uninstall the application."), pendingRemoval.displayName, pendingRemoval.applicationURL.path))
            }
        }
    }

    private var availableBrowserCount: Int {
        browsers.filter { $0.availability == .available }.count
    }

    private var visibleAvailableBrowserCount: Int {
        browsers.filter { $0.availability == .available && !hiddenBrowserIDs.contains($0.id) }.count
    }

    private var allAvailableBrowsersHidden: Bool {
        !isLoading && availableBrowserCount > 0 && visibleAvailableBrowserCount == 0
    }

    private var bannerMessage: String {
        if let errorMessage { return errorMessage }
        if allAvailableBrowsersHidden { return "browsers.allHiddenNotice" }
        return "Choose a browser .app in the macOS file picker."
    }

    private var bannerSymbol: String {
        if errorMessage != nil { return "exclamationmark.circle" }
        if allAvailableBrowsersHidden { return "info.circle" }
        return "folder"
    }

    private func browserRow(_ browser: BrowserDescriptor) -> some View {
        let isVisible = !hiddenBrowserIDs.contains(browser.id)
        let showsOriginalTag = browser.alternateName != nil && browser.alternateName != browser.originalDisplayName
        return HStack(spacing: 12) {
            BrowserVisibilityCheckbox(
                isOn: Binding(
                    get: { !hiddenBrowserIDs.contains(browser.id) },
                    set: { setVisible($0, browser: browser) }
                ),
                browserName: browser.displayName
            )
            .accessibilityIdentifier("browsers.visible.\(browser.id.rawValue)")

            ApplicationIconView(bundleIdentifier: browser.bundleIdentifier, applicationURL: browser.applicationURL, fallbackSymbol: "safari", side: 28)
                .opacity(isVisible ? 1 : 0.45)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(browser.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isVisible ? SettingsPalette.secondary : SettingsPalette.muted)
                        .lineLimit(1)
                    if showsOriginalTag {
                        Text(browser.originalDisplayName)
                            .font(.system(size: 11))
                            .foregroundStyle(SettingsPalette.muted)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(SettingsPalette.sidebar, in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                Text(browser.origin == .custom && browser.availability != .available
                     ? String(localized: "browsers.reselectApplication") : browser.applicationURL.path)
                    .font(.system(size: 11))
                    .foregroundStyle(SettingsPalette.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(Text(verbatim: browser.applicationURL.path))
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(statusText(for: browser, isVisible: isVisible))
                .font(.system(size: 11))
                .foregroundStyle(statusColor(for: browser, isVisible: isVisible))

            Button {
                renameTarget = BrowserRenameTarget(browser: browser)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 12))
                    .foregroundStyle(SettingsPalette.iconDefault)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(String(localized: "browsers.setAlternateName", defaultValue: "Set alternate name"))
            .accessibilityLabel(String(format: String(localized: "browsers.setAlternateNameFor", defaultValue: "Set alternate name for %@"), browser.displayName))
            .accessibilityIdentifier("browsers.rename.\(browser.id.rawValue)")

            Menu { browserActions(browser, includeVisibilityToggle: false) } label: {
                Image(systemName: "ellipsis").frame(width: 24, height: 24)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("More actions for \(browser.displayName)")
        }
        .padding(.horizontal, 14)
        .frame(height: 76)
        .contextMenu { browserActions(browser, includeVisibilityToggle: true) }
    }

    private func statusText(for browser: BrowserDescriptor, isVisible: Bool) -> LocalizedStringKey {
        if browser.availability != .available { return "Path unavailable" }
        return isVisible ? "browsers.available" : "browsers.hiddenInSelector"
    }

    private func statusColor(for browser: BrowserDescriptor, isVisible: Bool) -> Color {
        if browser.availability != .available { return SettingsPalette.danger }
        return isVisible ? SettingsPalette.tertiary : SettingsPalette.muted
    }

    @ViewBuilder
    private func browserActions(_ browser: BrowserDescriptor, includeVisibilityToggle: Bool) -> some View {
        if includeVisibilityToggle {
            Toggle("Show in selector", isOn: Binding(
                get: { !hiddenBrowserIDs.contains(browser.id) },
                set: { setVisible($0, browser: browser) }
            ))
            Divider()
        }
        Button(String(localized: "browsers.setAlternateNameMenu", defaultValue: "Set Alternate Name…")) {
            renameTarget = BrowserRenameTarget(browser: browser)
        }
        .accessibilityIdentifier("browsers.renameMenu.\(browser.id.rawValue)")
        if browser.hasAlternateName {
            Button(String(localized: "browsers.resetAlternateName", defaultValue: "Reset Alternate Name")) {
                _ = saveAlternateName(nil, for: browser)
            }
            .accessibilityIdentifier("browsers.resetName.\(browser.id.rawValue)")
        }
        Divider()
        Button(String(format: String(localized: "Move %@ earlier"), browser.displayName)) { move(browser, offset: -1) }
            .disabled(browsers.first?.managementRowIdentity == browser.managementRowIdentity || browser.availability != .available || isLoading)
            .accessibilityIdentifier("browsers.earlier.\(browser.id.rawValue)")
        Button(String(format: String(localized: "Move %@ later"), browser.displayName)) { move(browser, offset: 1) }
            .disabled(browsers.last?.managementRowIdentity == browser.managementRowIdentity || browser.availability != .available || isLoading)
            .accessibilityIdentifier("browsers.later.\(browser.id.rawValue)")
        if browser.origin == .custom && browser.profile == nil {
            Divider()
            Button("Remove", role: .destructive) { pendingRemoval = browser }
                .accessibilityIdentifier("browsers.remove.\(browser.id.rawValue)")
        }
    }

    private func reload() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            let discovered = try await browserCatalog.scan()
            let custom = try environment.browserPreferenceRepository.customBrowsers()
            let order = try environment.browserPreferenceRepository.orderedBrowserIDs()
            hiddenBrowserIDs = Set(try environment.browserPreferenceRepository.hiddenBrowserIDs())
            alternateNames = try environment.browserPreferenceRepository.browserAlternateNames()
            let rows = BrowserManagementPresentation.browsers(
                discovered: discovered,
                custom: custom,
                alternateNames: alternateNames
            )
            let positions = Dictionary(order.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: min)
            browsers = rows.enumerated().sorted {
                let left = positions[$0.element.id] ?? (order.count + $0.offset)
                let right = positions[$1.element.id] ?? (order.count + $1.offset)
                return left == right ? $0.offset < $1.offset : left < right
            }.map(\.element)
        } catch {
            errorMessage = "Browsers could not be loaded. Try scanning again."
        }
    }

    @discardableResult
    private func saveAlternateName(_ rawName: String?, for browser: BrowserDescriptor) -> Bool {
        do {
            var updated = try environment.browserPreferenceRepository.browserAlternateNames()
            if let normalized = BrowserDescriptor.normalizedAlternateName(rawName) {
                updated[browser.id] = normalized
            } else {
                updated.removeValue(forKey: browser.id)
            }
            try environment.browserPreferenceRepository.saveBrowserAlternateNames(updated)
            alternateNames = updated
            browsers = browsers.map { row in
                row.id == browser.id ? row.withAlternateName(updated[browser.id]) : row
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Browser choices could not be saved. Try again."
            return false
        }
    }

    private func setVisible(_ visible: Bool, browser: BrowserDescriptor) {
        do {
            var hidden = Set(try environment.browserPreferenceRepository.hiddenBrowserIDs())
            if visible { hidden.remove(browser.id) } else { hidden.insert(browser.id) }
            try environment.browserPreferenceRepository.saveHiddenBrowserIDs(hidden.sorted { $0.rawValue < $1.rawValue })
            hiddenBrowserIDs = hidden
            errorMessage = nil
        } catch { errorMessage = "Browser choices could not be saved. Try again." }
    }

    private func move(_ browser: BrowserDescriptor, offset: Int) {
        guard let index = browsers.firstIndex(where: { $0.managementRowIdentity == browser.managementRowIdentity }),
              browsers.indices.contains(index + offset) else { return }
        do {
            var reordered = browsers
            reordered.swapAt(index, index + offset)
            var seen: Set<BrowserID> = []
            let visibleIDs = reordered.map(\.id).filter { seen.insert($0).inserted }
            // Keep preferences for targets that are temporarily unavailable.
            let retained = try environment.browserPreferenceRepository.orderedBrowserIDs().filter { seen.insert($0).inserted }
            try environment.browserPreferenceRepository.saveOrder(visibleIDs + retained)
            browsers = reordered
            errorMessage = nil
        } catch { errorMessage = "Browser choices could not be saved. Try again." }
    }
}

private struct BrowserVisibilityCheckbox: View {
    @Binding var isOn: Bool
    let browserName: String

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isOn ? SettingsPalette.action : SettingsPalette.group)
                    .frame(width: 18, height: 18)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(isOn ? SettingsPalette.action : SettingsPalette.borderStrong, lineWidth: 1.5)
                    .frame(width: 18, height: 18)
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(SettingsPalette.actionText)
                }
            }
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isOn
              ? String(localized: "browsers.visibility.hideHelp", defaultValue: "Shown in selector. Click to hide.")
              : String(localized: "browsers.visibility.showHelp", defaultValue: "Hidden from selector. Click to show."))
        .accessibilityRepresentation {
            Toggle(
                String(format: String(localized: "browsers.visibility.accessibility", defaultValue: "Show %@ in selector"), browserName),
                isOn: $isOn
            )
        }
    }
}

private struct BrowserAlternateNameSheet: View {
    @Environment(\.dismiss) private var dismiss
    let browser: BrowserDescriptor
    let onSave: (String?) -> Bool

    @State private var nameText: String
    @State private var saveFailed = false
    @FocusState private var fieldFocused: Bool

    init(browser: BrowserDescriptor, onSave: @escaping (String?) -> Bool) {
        self.browser = browser
        self.onSave = onSave
        _nameText = State(initialValue: browser.alternateName ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                Text("browsers.alternateName.title")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(SettingsPalette.primary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(WorkspaceButtonStyle(kind: .quiet, height: 24))
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Close")
            }

            HStack(spacing: 10) {
                ApplicationIconView(
                    bundleIdentifier: browser.bundleIdentifier,
                    applicationURL: browser.applicationURL,
                    fallbackSymbol: "safari",
                    side: 28
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(browser.originalDisplayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(SettingsPalette.secondary)
                        .lineLimit(1)
                    Text(browser.applicationURL.path)
                        .font(.system(size: 11))
                        .foregroundStyle(SettingsPalette.muted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SettingsPalette.window, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 8) {
                Text("browsers.alternateName.fieldLabel")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SettingsPalette.tertiary)
                TextField(LocalizedStringKey("browsers.alternateName.placeholder"), text: $nameText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($fieldFocused)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(SettingsPalette.group, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(fieldFocused ? SettingsPalette.action : SettingsPalette.border, lineWidth: fieldFocused ? 2 : 1)
                    }
                    .onSubmit { commit() }
                    .accessibilityIdentifier("browsers.alternateName.input")
                Text("browsers.alternateName.hint")
                    .font(.system(size: 11))
                    .foregroundStyle(SettingsPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if saveFailed {
                Label("Browser choices could not be saved. Try again.", systemImage: "exclamationmark.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(SettingsPalette.danger)
            }

            HStack(spacing: 10) {
                if browser.hasAlternateName {
                    Button("browsers.alternateName.reset") {
                        if onSave(nil) { dismiss() } else { saveFailed = true }
                    }
                    .buttonStyle(WorkspaceButtonStyle(kind: .secondary, height: 35, horizontalPadding: 14))
                    .accessibilityIdentifier("browsers.alternateName.reset")
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(WorkspaceButtonStyle(kind: .secondary, height: 35, horizontalPadding: 16))
                    .keyboardShortcut(.cancelAction)
                Button("browsers.alternateName.save") { commit() }
                    .buttonStyle(WorkspaceButtonStyle(kind: .primary, height: 35, horizontalPadding: 16))
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("browsers.alternateName.save")
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(SettingsPalette.canvas)
        .onAppear {
            fieldFocused = true
        }
    }

    private func commit() {
        if onSave(nameText) {
            dismiss()
        } else {
            saveFailed = true
        }
    }
}
