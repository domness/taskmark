import SwiftUI

/// Shared, stateless welcome content. Platform shells own vault access and actions.
public struct TaskmarkWelcomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize = 112.0
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 34.0
    @ScaledMetric(relativeTo: .body) private var bodySize = 15.0
    @ScaledMetric(relativeTo: .headline) private var actionSize = 17.0
    private let isLoading: Bool
    private let openSample: () -> Void
    private let createVault: () -> Void
    private let openVault: () -> Void

    public init(
        isLoading: Bool, openSample: @escaping () -> Void,
        createVault: @escaping () -> Void, openVault: @escaping () -> Void
    ) {
        self.isLoading = isLoading
        self.openSample = openSample
        self.createVault = createVault
        self.openVault = openVault
    }

    public var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 32) {
                    heading
                    actions
                    footer
                }
                .frame(maxWidth: 540)
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(TaskmarkTheme.standard.tokens.color("--background", scheme: colorScheme, fallback: .clear))
        .tint(TaskmarkTheme.standard.tokens.color("--accent", scheme: colorScheme, fallback: .accentColor))
        .buttonBorderShape(.roundedRectangle(radius: 8))
        .font(.system(size: bodySize))
        .disabled(isLoading)
    }

    private var heading: some View {
        VStack(spacing: 24) {
            Image("TaskmarkIcon", bundle: .module)
                .resizable()
                .scaledToFit()
                .frame(width: min(iconSize, 128), height: min(iconSize, 128))
                .accessibilityHidden(true)
            Text("Your tasks. Your files.")
                .font(.system(size: titleSize, weight: .bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var actions: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Button(action: openSample) {
                    Text("Try a Sample Vault")
                        .font(.system(size: actionSize, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(TaskmarkTheme.standard.tokens.color("--accent", scheme: .light, fallback: .accentColor))
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("sample-vault")
                if isLoading {
                    ProgressView("Opening vault…")
                        .font(.system(size: bodySize))
                        .accessibilityIdentifier("opening-vault")
                } else {
                    Text("Explore example tasks. Make changes. Learn as you go.")
                        .font(.system(size: bodySize))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Divider()
            secondaryActions
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
    }

    @ViewBuilder private var secondaryActions: some View {
        #if os(macOS)
            HStack(spacing: 12) {
                createButton
                openButton
            }
        #else
            VStack(spacing: 12) {
                createButton
                openButton
            }
        #endif
    }

    private var createButton: some View {
        Button(action: createVault) {
            Text("Create a Vault")
                .font(.system(size: bodySize))
                .frame(maxWidth: .infinity, minHeight: 28)
        }
        .accessibilityIdentifier("create-vault")
    }

    private var openButton: some View {
        Button(action: openVault) {
            Text("Open Existing Vault")
                .font(.system(size: bodySize))
                .frame(maxWidth: .infinity, minHeight: 28)
        }
        .accessibilityIdentifier("open-vault")
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text("A vault is a folder that holds your tasks.")
            Text("No account needed. Sample edits stay separate from your own vault.")
        }
        .font(.system(size: bodySize))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
}
