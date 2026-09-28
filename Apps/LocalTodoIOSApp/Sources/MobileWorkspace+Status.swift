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
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
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
        startProviderPolling()
    }

    func resumeProviderObservation() {
        guard let rootURL = session.rootURL else { return }
        if presenter == nil {
            configureProviderObservation(for: rootURL)
        } else {
            startProviderPolling()
        }
        scheduleProviderRefresh()
    }

    func suspendProviderObservation() {
        refreshTask?.cancel()
        refreshTask = nil
        pollingTask?.cancel()
        pollingTask = nil
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

    private func startProviderPolling() {
        pollingTask?.cancel()
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled, let self else { return }
                await refresh()
            }
        }
    }
}
