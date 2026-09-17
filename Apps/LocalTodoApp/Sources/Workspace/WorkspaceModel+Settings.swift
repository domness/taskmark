import Foundation
import LocalTodoMarkdown

extension WorkspaceModel {
    func resetPersonalization() {
        loadSidebarOrder()
        configurationSettings = nil
        configurationSettingsError = nil
        vaultAppearance = VaultAppearance()
        stylesheetDiagnostic = nil
    }

    func refreshVaultPreferences() async {
        await refreshSavedFilters()
        await refreshAppearance()
        await refreshConfigurationSettings()
    }

    /// Display preferences must not change the shared recurrence calendar's week boundaries.
    var planningCalendar: Calendar {
        var calendar = vaultCalendar
        calendar.firstWeekday = preferences.weekStart.rawValue
        return calendar
    }

    func refreshConfigurationSettings() async {
        guard let store, !isSavingConfiguration else { return }
        let session = vaultSession
        do {
            let record = try await store.configurationRecord()
            guard session == vaultSession, !isSavingConfiguration else { return }
            configurationSettings = record
        } catch {
            guard session == vaultSession else { return }
            configurationSettings = nil
            configurationSettingsError = error.localizedDescription
        }
    }

    func setVaultTimezone(_ identifier: String?) async {
        guard let store, let configurationSettings, !isSavingConfiguration else { return }
        guard pendingMutationPaths.isEmpty, !isHistoryBusy, !hasDirtyDrafts, !filterState.isSaving else {
            configurationSettingsError = "Finish saving or resolving pending changes before changing the time zone."
            return
        }
        guard configurationSettings.value.timezone != identifier else { return }
        isSavingConfiguration = true
        configurationSettingsError = nil
        modelEpoch += 1
        defer { isSavingConfiguration = false }
        do {
            let saved = try await store.setTimezone(identifier, expectedRevision: configurationSettings.revision)
            self.configurationSettings = saved
            if let snapshot {
                self.snapshot = VaultSnapshot(
                    generation: snapshot.generation, configuration: saved.value, tasks: snapshot.tasks,
                    projects: snapshot.projects, areas: snapshot.areas, diagnostics: snapshot.diagnostics
                )
            }
            await refresh()
        } catch {
            configurationSettingsError = error.localizedDescription
        }
    }

    func formattedTimestamp(_ date: Date) -> String {
        let calendar = vaultCalendar
        let dateText = preferences.dateFormat.formatter(calendar: calendar).string(from: date)
        return dateText + " · " + preferences.timeFormat.string(date, calendar: calendar)
    }
}
