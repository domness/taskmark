import LocalTodoPresentation

typealias VaultAppearance = TaskmarkAppearance
typealias AppearanceError = TaskmarkAppearanceError

extension WorkspaceModel {
    var effectiveAppearance: VaultAppearance {
        let base = preferences.theme.tokens
        return usesVaultStylesheet ? base.overriding(with: vaultAppearance) : base
    }

    func refreshAppearance() async {
        guard let store else { return }
        let session = vaultSession
        do {
            let source = try await store.stylesheet()
            let appearance = try source.map(VaultAppearance.parse) ?? VaultAppearance()
            guard session == vaultSession else { return }
            vaultAppearance = appearance
            stylesheetDiagnostic = nil
        } catch {
            guard session == vaultSession else { return }
            vaultAppearance = VaultAppearance()
            stylesheetDiagnostic = error.localizedDescription
        }
    }
}
