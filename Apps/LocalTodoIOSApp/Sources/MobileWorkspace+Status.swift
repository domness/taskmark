import Foundation
import LocalTodoMarkdown

extension MobileWorkspace {
    var canUndo: Bool {
        session.canUndo
    }

    var canRedo: Bool {
        session.canRedo
    }

    func refresh() async {
        do {
            try await session.refresh()
            lastSuccessfulRefresh = Date()
            await refreshAppearance()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resolveProviderConflict(_ conflict: VaultProviderConflict, choosing content: Data) async -> Bool {
        do {
            try await session.resolveProviderConflict(conflict, choosing: content)
            lastSuccessfulRefresh = Date()
            return true
        } catch {
            errorMessage = error.localizedDescription
            await refresh()
            return false
        }
    }

    func undo() async {
        do { try await session.undo() } catch { errorMessage = error.localizedDescription }
    }

    func redo() async {
        do { try await session.redo() } catch { errorMessage = error.localizedDescription }
    }

    func configureProviderObservation(for rootURL: URL) {
        suspendProviderObservation()
        let presenter = MobileVaultPresenter(rootURL: rootURL) { [weak self] in
            Task { @MainActor in self?.scheduleProviderRefresh() }
        }
        self.presenter = presenter
        NSFileCoordinator.addFilePresenter(presenter)
    }

    func resumeProviderObservation() {
        guard let rootURL = session.rootURL else { return }
        if presenter == nil {
            configureProviderObservation(for: rootURL)
        }
        scheduleProviderRefresh()
    }

    func suspendProviderObservation() {
        refreshTask?.cancel()
        refreshTask = nil
        if let presenter {
            NSFileCoordinator.removeFilePresenter(presenter)
            self.presenter = nil
        }
    }

    func scheduleProviderRefresh(after delay: Duration = .milliseconds(250)) {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }
}
