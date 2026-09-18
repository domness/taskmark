import Foundation
import LocalTodoMarkdown

extension WorkspaceModel {
    func queuePreferenceState(_ key: String, value: some Encodable) {
        do {
            try queuePreferenceChange(key, value: ConfigurationValue.encode(value))
        } catch {
            configurationSettingsError = error.localizedDescription
        }
    }

    func queuePreferenceChange(_ key: String, value: ConfigurationValue) {
        guard let snapshot, store != nil else { return }
        preferenceEditGeneration &+= 1
        let stored = configurationSettings?.value.preferences ?? snapshot.configuration.preferences
        let base = preferenceBases[key] ?? stored[key] ?? .null
        preferenceBases[key] = base
        let desired = (stored[key] ?? .null).merging(value)
        if desired == base {
            pendingPreferenceChanges.removeValue(forKey: key)
            preferenceBases.removeValue(forKey: key)
        } else {
            pendingPreferenceChanges[key] = desired
        }
        preferenceConflicts.remove(key)
        configurationSettingsError = nil
        schedulePreferenceSave()
    }

    func applySharedPreferences(_ values: [String: ConfigurationValue]) throws {
        var sidebar = [String: [String]]()
        if case let .object(entries) = values["sidebar_order"] {
            for key in ["project", "area"] {
                sidebar[key] = try entries[key]?.decode([String].self)
            }
        }
        let orders = try values["custom_order"]?.decode([String: TaskCustomOrder].self) ?? [:]
        let views = try values["views"]?.decode([String: TaskListDisplayOptions].self) ?? [:]
        preferences.apply(values)
        sidebarOrders = sidebar
        taskCustomOrders = orders
        taskListDisplayOptionsByRoute = views
    }

    func receiveConfiguration(_ record: VaultConfigurationRecord) throws {
        for (key, desired) in pendingPreferenceChanges {
            let remote = record.value.preferences[key] ?? .null
            if remote == desired {
                pendingPreferenceChanges.removeValue(forKey: key)
                preferenceBases.removeValue(forKey: key)
                preferenceConflicts.remove(key)
            } else if remote != preferenceBases[key] {
                preferenceConflicts.insert(key)
            } else {
                preferenceConflicts.remove(key)
            }
        }
        configurationSettings = record
        var displayed = record.value.preferences
        displayed.merge(pendingPreferenceChanges) { _, pending in pending }
        try applySharedPreferences(displayed)
        if let snapshot {
            self.snapshot = VaultSnapshot(
                generation: snapshot.generation, configuration: record.value, tasks: snapshot.tasks,
                projects: snapshot.projects, areas: snapshot.areas, diagnostics: snapshot.diagnostics
            )
        }
        if !preferenceConflicts.isEmpty {
            configurationSettingsError = VaultConfigurationError.conflict.localizedDescription
        } else if pendingPreferenceChanges.isEmpty {
            configurationSettingsError = nil
        }
    }

    func flushPreferences() async -> Bool {
        preferenceSaveTask?.cancel()
        preferenceSaveTask = nil
        for _ in 0 ..< 100 where isSavingPreferences || isSavingConfiguration {
            try? await Task.sleep(for: .milliseconds(50))
        }
        if !pendingPreferenceChanges.isEmpty {
            await savePreferences()
        }
        return pendingPreferenceChanges.isEmpty && !isSavingPreferences && !isSavingConfiguration
    }

    func discardPreferenceChanges() async {
        guard let store, !isSavingPreferences, !isSavingConfiguration else { return }
        preferenceSaveTask?.cancel()
        isSavingPreferences = true
        defer { isSavingPreferences = false }
        let session = vaultSession
        let generation = preferenceEditGeneration
        do {
            let record = try await store.configurationRecord()
            guard session == vaultSession else { return }
            guard generation == preferenceEditGeneration else {
                configurationSettingsError = "Preferences changed while reloading. Review them before discarding."
                return
            }
            pendingPreferenceChanges.removeAll()
            preferenceBases.removeAll()
            preferenceConflicts.removeAll()
            try receiveConfiguration(record)
        } catch { configurationSettingsError = error.localizedDescription }
    }

    func keepPreferenceChanges() async {
        guard let store, !isSavingPreferences, !isSavingConfiguration else { return }
        preferenceSaveTask?.cancel()
        isSavingPreferences = true
        defer { isSavingPreferences = false }
        let session = vaultSession
        let keys = Array(pendingPreferenceChanges.keys)
        do {
            let record = try await store.configurationRecord()
            guard session == vaultSession else { return }
            configurationSettings = record
            for key in keys where pendingPreferenceChanges[key] != nil {
                let remote = record.value.preferences[key] ?? .null
                pendingPreferenceChanges[key] = pendingPreferenceChanges[key]?.rebasingChanges(
                    from: preferenceBases[key], onto: remote
                )
                preferenceBases[key] = remote
            }
            preferenceConflicts.removeAll()
            configurationSettingsError = nil
            try receiveConfiguration(record)
            isSavingPreferences = false
            await savePreferences()
        } catch { configurationSettingsError = error.localizedDescription }
    }

    private func schedulePreferenceSave() {
        preferenceSaveTask?.cancel()
        let session = vaultSession
        preferenceSaveTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            guard let self, session == vaultSession else { return }
            await savePreferences()
        }
    }

    private func savePreferences(retryingConflict: Bool = true) async {
        guard let store, !isSavingPreferences, !isSavingConfiguration,
              !pendingPreferenceChanges.isEmpty, preferenceConflicts.isEmpty else { return }
        isSavingPreferences = true
        modelEpoch += 1
        let session = vaultSession
        let changes = pendingPreferenceChanges
        let bases = preferenceBases
        do {
            let fresh = try await store.configurationRecord()
            try validatePreferenceBases(bases, changes: changes, fresh: fresh)
            let patch = changes.map { key, value in (key, value.changes(comparedTo: bases[key])) }
            let saved = try await store.setPreferences(
                Dictionary(uniqueKeysWithValues: patch),
                expectedRevision: fresh.revision
            )
            guard session == vaultSession else { isSavingPreferences = false; return }
            try acceptPreferenceSave(saved, changes: changes)
            isSavingPreferences = false
            if !pendingPreferenceChanges.isEmpty {
                schedulePreferenceSave()
            }
        } catch {
            isSavingPreferences = false
            guard session == vaultSession else { return }
            configurationSettingsError = error.localizedDescription
            if error is VaultConfigurationError {
                await refreshConfigurationSettings()
                if retryingConflict, preferenceConflicts.isEmpty {
                    await savePreferences(retryingConflict: false)
                }
            }
        }
    }

    private func validatePreferenceBases(
        _ bases: [String: ConfigurationValue], changes: [String: ConfigurationValue], fresh: VaultConfigurationRecord
    ) throws {
        for (key, desired) in changes {
            let remote = fresh.value.preferences[key] ?? .null
            guard remote == bases[key] || remote == desired else { throw VaultConfigurationError.conflict }
        }
    }

    private func acceptPreferenceSave(_ saved: VaultConfigurationRecord, changes: [String: ConfigurationValue]) throws {
        for (key, desired) in changes {
            if pendingPreferenceChanges[key] == desired {
                pendingPreferenceChanges.removeValue(forKey: key)
                preferenceBases.removeValue(forKey: key)
            } else {
                preferenceBases[key] = saved.value.preferences[key] ?? .null
            }
        }
        configurationSettingsError = nil
        try receiveConfiguration(saved)
    }
}
