import Foundation

extension WorkspaceModel {
    /// Presentation reads depend on this day marker, while actions always use the current injected clock.
    var presentationNow: Date {
        _ = presentationDay
        return clock()
    }

    func startVaultObservation(fallbackInterval: Duration = .seconds(60), tolerance: Duration = .seconds(5)) {
        stopVaultObservation()
        guard let rootURL else { return }
        let observation = observationID
        let session = vaultSession
        let requestRefresh: @Sendable () -> Void = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, vaultSession == session, observationID == observation else { return }
                scheduleExternalRefresh()
            }
        }
        do {
            vaultObserver = try VaultChangeObserver(root: rootURL, onChange: requestRefresh)
        } catch {
            errorMessage = error.localizedDescription
        }
        lifecycleObserver = WorkspaceLifecycleObserver { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, vaultSession == session, observationID == observation else { return }
                updatePresentationDay()
                await refresh()
            }
        }
        refreshLoop = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: fallbackInterval, tolerance: tolerance) } catch { return }
                guard let self, vaultSession == session, observationID == observation, !Task.isCancelled else { return }
                await refresh()
            }
        }
        updatePresentationDay()
    }

    func scheduleExternalRefresh() {
        // A fixed coalescing window also avoids starvation during sustained provider activity.
        guard externalRefreshTask == nil else { return }
        let session = vaultSession
        externalRefreshTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            guard let self, vaultSession == session, !Task.isCancelled else { return }
            externalRefreshTask = nil
            await refresh()
        }
    }

    func updatePresentationDay() {
        let now = clock()
        let day = vaultCalendar.startOfDay(for: now)
        if presentationDay != day {
            presentationDay = day
        }
        dayChangeTask?.cancel()
        guard store != nil,
              let next = vaultCalendar.date(byAdding: .day, value: 1, to: day) else { return }
        let session = vaultSession
        dayChangeTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(max(1, next.timeIntervalSince(now)))) } catch { return }
            guard let self, vaultSession == session, !Task.isCancelled else { return }
            updatePresentationDay()
        }
    }

    func stopVaultObservation() {
        observationID = UUID()
        vaultObserver = nil
        lifecycleObserver = nil
        refreshLoop?.cancel()
        refreshLoop = nil
        externalRefreshTask?.cancel()
        externalRefreshTask = nil
        dayChangeTask?.cancel()
        dayChangeTask = nil
        refreshQueue.cancel()
    }
}
