import AppKit
import SwiftUI

struct AppShellDestination: Identifiable {
    let route: AppRoute
    let title: String
    let systemImage: String
    let accessibilityIdentifier: String

    var id: AppRoute { route }

    static let all: [AppShellDestination] = [
        AppShellDestination(
            route: .history,
            title: "History",
            systemImage: "clock",
            accessibilityIdentifier: "appShell.sidebar.history"
        ),
        AppShellDestination(
            route: .rules,
            title: "Rules",
            systemImage: "list.bullet",
            accessibilityIdentifier: "appShell.sidebar.rules"
        ),
        AppShellDestination(
            route: .settings,
            title: "Settings",
            systemImage: "gearshape",
            accessibilityIdentifier: "appShell.sidebar.settings"
        ),
    ]
}

struct WorkspaceBrandView: View {
    let reduceTransparency: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)
            Text("Prism")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SettingsPalette.primary)
        }
        .padding(.leading, 2)
        .frame(width: 78, height: 32, alignment: .leading)
        // Extend behind the native window controls without moving them.
        .background(alignment: .trailing) {
            Color.clear
                .frame(width: 160, height: 32)
                .modifier(WorkspaceCapsule(reduceTransparency: reduceTransparency))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Prism")
        .accessibilityIdentifier("appShell.sidebar.brand")
    }
}

struct WorkspaceNavigationView: View {
    @Binding var selection: AppRoute
    let reduceTransparency: Bool
    @FocusState private var focusedRoute: AppRoute?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppShellDestination.all) { destination in
                Button {
                    selection = destination.route
                } label: {
                    Label(LocalizedStringKey(destination.title), systemImage: destination.systemImage)
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 13, weight: selection == destination.route ? .semibold : .regular))
                        .foregroundStyle(selection == destination.route ? SettingsPalette.primary : SettingsPalette.secondary)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 16)
                        .frame(height: 24)
                        .background {
                            if selection == destination.route {
                                Capsule()
                                    .fill(SettingsPalette.group)
                                    .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .focused($focusedRoute, equals: destination.route)
                .overlay {
                    if focusedRoute == destination.route {
                        Capsule().stroke(SettingsPalette.primary, lineWidth: 2).padding(2)
                    }
                }
                .accessibilityIdentifier(destination.accessibilityIdentifier)
                .accessibilityAddTraits(selection == destination.route ? .isSelected : [])
            }
        }
        .padding(4)
        .modifier(WorkspaceCapsule(reduceTransparency: reduceTransparency))
    }
}

struct WorkspaceRoutingStatusView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        HStack(spacing: 6) {
            Text(environment.settings.automaticRulesEnabled ? "Automatic routing is on" : "Automatic routing is paused")
            Text("·").accessibilityHidden(true)
            Text("Records stay on this Mac")
        }
        .font(.system(size: 11))
        .foregroundStyle(SettingsPalette.tertiary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("appShell.sidebar.routingStatus")
    }
}

private struct WorkspaceCapsule: ViewModifier {
    let reduceTransparency: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(SettingsPalette.window, in: Capsule())
                .overlay(Capsule().stroke(SettingsPalette.borderStrong, lineWidth: 1))
        } else if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().stroke(SettingsPalette.border, lineWidth: 1))
        }
    }
}
