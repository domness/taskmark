import Foundation
import LocalTodoDomain
import LocalTodoMarkdown
import LocalTodoPresentation
import LocalTodoWorkspace
import Observation
import SwiftUI

@MainActor
@Observable
final class MobileWorkspace {
    enum OpenMode: Sendable {
        case existing
        case initializeEmptyFolder
    }

    var snapshot: VaultSnapshot? {
        session.snapshot
    }

    private(set) var vaultName: String?
    private(set) var isLoading = false
    var lastSuccessfulRefresh: Date?
    var isSaving: Bool {
        session.isSaving
    }

    var errorMessage: String?
    var isImporterPresented = false
    var pendingOpenMode: OpenMode = .existing
    var searchText = ""
    private(set) var customAppearance = TaskmarkAppearance()
    private(set) var stylesheetDiagnostic: String?

    let session: WorkspaceSession
    let checkpoints: TaskDraftCheckpointStore
    let captureCheckpoints: CaptureDraftCheckpointStore
    let collectionCheckpoints: CollectionDraftCheckpointStore
    let filterCheckpoints: FilterDraftCheckpointStore
    @ObservationIgnored private var lease: MobileVaultLease?
    @ObservationIgnored var presenter: MobileVaultPresenter?
    @ObservationIgnored var refreshTask: Task<Void, Never>?
    @ObservationIgnored private let bookmarks: MobileVaultBookmarkStore

    init(
        bookmarks: MobileVaultBookmarkStore = MobileVaultBookmarkStore(),
        session: WorkspaceSession = WorkspaceSession(),
        checkpoints: TaskDraftCheckpointStore? = nil,
        captureCheckpoints: CaptureDraftCheckpointStore? = nil,
        collectionCheckpoints: CollectionDraftCheckpointStore? = nil,
        filterCheckpoints: FilterDraftCheckpointStore? = nil
    ) {
        self.bookmarks = bookmarks
        self.session = session
        self.checkpoints = checkpoints ?? Self.defaultCheckpointStore()
        self.captureCheckpoints = captureCheckpoints ?? Self.defaultCaptureCheckpointStore()
        self.collectionCheckpoints = collectionCheckpoints ?? Self.defaultCollectionCheckpointStore()
        self.filterCheckpoints = filterCheckpoints ?? Self.defaultFilterCheckpointStore()
    }

    var vaultIdentifier: String? {
        session.rootURL?.standardizedFileURL.path
    }

    var tasks: [TodoTask] {
        session.tasks(for: .all, includeCompleted: true)
    }

    var initialRoute: WorkspaceRoute {
        guard case let .string(value) = snapshot?.configuration.preferences["initial_view"] else { return .today }
        switch value {
        case "inbox": return .inbox
        case "next": return .next
        case "upcoming": return .upcoming
        case "waiting": return .waiting
        case "someday": return .someday
        case "all": return .all
        case "search": return .search
        default: return .today
        }
    }

    var theme: TaskmarkTheme {
        guard case let .string(value) = snapshot?.configuration.preferences["theme"] else { return .standard }
        return TaskmarkTheme(rawValue: value) ?? .standard
    }

    var usesStylesheet: Bool {
        guard case let .bool(value) = snapshot?.configuration.preferences["vault_stylesheet"] else { return false }
        return value
    }

    var effectiveAppearance: TaskmarkAppearance {
        usesStylesheet ? theme.tokens.overriding(with: customAppearance) : theme.tokens
    }

    var preferredColorScheme: ColorScheme? {
        guard case let .string(value) = snapshot?.configuration.preferences["appearance"] else { return nil }
        switch value {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    func mobileFontSize(for scheme: ColorScheme) -> Double {
        let fallback = theme == .catppuccin ? 18.0 : 17.0
        return usesStylesheet ? customAppearance
            .number("--task-font-size", scheme: scheme, fallback: fallback) : fallback
    }

    func tasks(for route: WorkspaceRoute, includeCompleted: Bool = false) -> [TodoTask] {
        session.tasks(for: route, searchText: searchText, includeCompleted: includeCompleted)
    }

    func taskMarkdown(at path: VaultPath) async -> String? {
        do { return try await session.taskMarkdown(at: path) } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func viewOptions(for route: WorkspaceRoute) -> WorkspaceViewOptions {
        session.viewOptions(for: route)
    }

    func customOrder(for route: WorkspaceRoute) -> WorkspaceCustomOrder {
        session.customOrder(for: route)
    }

    func setViewOptions(_ options: WorkspaceViewOptions, for route: WorkspaceRoute) async {
        do { try await session.setViewOptions(options, for: route) } catch { errorMessage = error.localizedDescription }
    }

    func setCustomOrder(_ order: WorkspaceCustomOrder, for route: WorkspaceRoute) async {
        do { try await session.setCustomOrder(order, for: route) } catch { errorMessage = error.localizedDescription }
    }

    func requestOpen() {
        pendingOpenMode = .existing
        isImporterPresented = true
    }

    func requestCreate() {
        pendingOpenMode = .initializeEmptyFolder
        isImporterPresented = true
    }

    func restoreVault() async {
        do {
            guard let url = try bookmarks.restore() else { return }
            try await open(url, mode: .existing)
        } catch {
            errorMessage = "Access to the previous vault is no longer available. "
                + "Locate it to continue. \(error.localizedDescription)"
        }
    }

    func prepareUITestVaultIfRequested() async -> Bool {
        guard ProcessInfo.processInfo.arguments.contains("--ui-testing") else { return false }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("TaskmarkUITestVault")
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            try VaultInitializer.initialize(at: url, timezone: "Europe/London")
            try await session.open(root: url)
            _ = try await session.capture(title: "Today fixture", route: .today)
            _ = try await session.capture(title: "Inbox fixture", route: .inbox)
            vaultName = url.lastPathComponent
            await refreshAppearance()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return true
        }
    }

    func handlePickedFolder(_ result: Result<[URL], Error>) async {
        do {
            guard let url = try result.get().first else { return }
            try await open(url, mode: pendingOpenMode)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension MobileWorkspace {
    func updateTitle(for path: VaultPath, title: String) async {
        do {
            var patch = TaskPatch()
            patch.title = .set(title)
            try await session.updateTask(at: path, patch: patch)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func complete(_ path: VaultPath) async {
        do {
            try await session.toggleCompletion(at: path)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func capture(title: String, route: WorkspaceRoute, patch: TaskPatch = TaskPatch()) async -> Bool {
        do {
            _ = try await session.capture(title: title, route: route, patch: patch)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateTask(at path: VaultPath, patch: TaskPatch) async -> Bool {
        do {
            try await session.updateTask(at: path, patch: patch)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteTask(at path: VaultPath) async -> Bool {
        do {
            try await session.deleteTask(at: path)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func duplicateTask(at path: VaultPath) async -> VaultPath? {
        do {
            return try await session.duplicateTask(at: path)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func setPreferences(_ changes: [String: ConfigurationValue]) async -> Bool {
        do {
            try await session.setPreferences(changes)
            await refreshAppearance()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func setTimezone(_ identifier: String?) async -> Bool {
        do {
            try await session.setTimezone(identifier)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func open(_ url: URL, mode: OpenMode) async throws {
        isLoading = true
        defer { isLoading = false }
        let candidateLease = MobileVaultLease(url: url)
        if mode == .initializeEmptyFolder {
            try VaultInitializer.initialize(at: candidateLease.url)
        }
        try await session.open(root: candidateLease.url)
        try bookmarks.save(candidateLease.url)
        lease = candidateLease
        vaultName = candidateLease.url.lastPathComponent
        lastSuccessfulRefresh = Date()
        configureProviderObservation(for: candidateLease.url)
        await refreshAppearance()
        errorMessage = nil
    }

    func refreshAppearance() async {
        guard usesStylesheet else {
            customAppearance = TaskmarkAppearance()
            stylesheetDiagnostic = nil
            return
        }
        do {
            customAppearance = try await session.stylesheet().map(TaskmarkAppearance.parse) ?? TaskmarkAppearance()
            stylesheetDiagnostic = nil
        } catch {
            customAppearance = TaskmarkAppearance()
            stylesheetDiagnostic = error.localizedDescription
        }
    }
}
