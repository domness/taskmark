import AppKit
@testable import LocalTodoApp
import LocalTodoDomain
import SwiftUI
import Testing
import XCTest

@Test func workspaceTabsStartEmptyAndDeduplicateDestinations() {
    var state = WorkspaceTabState()
    #expect(state.isEmpty)
    #expect(state.selection == nil)

    state.open(.route(.today))
    state.open(.route(.upcoming))
    state.open(.route(.today))

    #expect(state.tabs == [.route(.today), .route(.upcoming)])
    #expect(state.selection == .route(.today))
}

@Test func firstCommandClickPreservesTheVisibleRouteAsTheInitialTab() throws {
    let task = try VaultPath("Tasks/notes.md")
    var state = WorkspaceTabState()

    state.open(.task(task), preserving: .route(.today))

    #expect(state.tabs == [.route(.today), .task(task)])
    #expect(state.selection == .task(task))
}

@Test func commandClickingTheVisibleRouteCreatesOnlyItsInitialTab() {
    var state = WorkspaceTabState()

    state.open(.route(.today), preserving: .route(.today))

    #expect(state.tabs == [.route(.today)])
    #expect(state.selection == .route(.today))
}

@Test func workspaceTabNavigationReusesAnExistingRouteTab() throws {
    let task = try VaultPath("Tasks/notes.md")
    var state = WorkspaceTabState()
    state.open(.route(.today))
    state.open(.task(task))

    state.navigate(to: .upcoming)
    #expect(state.tabs == [.route(.today), .route(.upcoming)])
    #expect(state.selection == .route(.upcoming))

    state.navigate(to: .today)
    #expect(state.tabs == [.route(.today), .route(.upcoming)])
    #expect(state.selection == .route(.today))
}

@Test func closingTabsSelectsANeighborThenReturnsToTheDefaultWorkspace() {
    var state = WorkspaceTabState()
    state.open(.route(.today))
    state.open(.route(.upcoming))
    state.open(.route(.inbox))

    state.close(.route(.upcoming))
    #expect(state.selection == .route(.inbox))
    state.close(.route(.inbox))
    #expect(state.selection == .route(.today))
    state.close(.route(.today))
    #expect(state.isEmpty)
    #expect(state.selection == nil)
}

@Test func commandClickRequiresASingleClickWithTheCommandModifier() {
    #expect(CommandClickGesture.matches(clickCount: 1, modifiers: .command))
    #expect(CommandClickGesture.matches(clickCount: 1, modifiers: [.command, .shift]))
    #expect(!CommandClickGesture.matches(clickCount: 1, modifiers: []))
    #expect(!CommandClickGesture.matches(clickCount: 2, modifiers: .command))
}

@MainActor
final class WorkspaceTabNativeTests: XCTestCase {
    func testSelectionReusesNativeButtonsAndCloseRemainsSafe() async throws {
        let task = try VaultPath("Tasks/notes.md")
        let harness = WorkspaceTabTestHarness(task: task)

        let scrollViews = descendants(in: harness.view, as: NSScrollView.self)
        XCTAssertEqual(scrollViews.count, 1)
        XCTAssertFalse(scrollViews[0].hasHorizontalScroller)
        XCTAssertFalse(scrollViews[0].hasVerticalScroller)
        let originalButtons = descendants(in: harness.view, as: NSButton.self)
        XCTAssertEqual(originalButtons.count, 4)
        let originalItems = descendants(in: harness.view, as: WorkspaceTabItemView.self)
        XCTAssertEqual(originalItems.count, 2)
        XCTAssertEqual(originalItems[0].layer?.cornerRadius, 0)
        XCTAssertEqual(originalItems[0].layer?.borderWidth, 0)
        for _ in 0 ..< 1000 {
            XCTAssertEqual(harness.view.toolbarFittingSize.height, 30)
        }
        try await exerciseSelectionCycles(harness, buttons: originalButtons)

        originalButtons[3].performClick(nil)
        await Task.yield()
        XCTAssertEqual(harness.closed, .task(task))
        harness.showTodayOnly()
        XCTAssertEqual(descendants(in: harness.view, as: NSButton.self).count, 2)
    }

    func testProductionToolbarSwitchesAndClosesWithoutReplacingTabs() async throws {
        try await withWorkspace { model, _ in
            await model.createTask(title: "Detailed notes", vaultSession: model.vaultSession)
            let path = try #require(model.selectedTaskPath)
            var state = WorkspaceTabState()
            state.open(.route(.today))
            state.open(.task(path))
            let controller = NSHostingController(rootView: WorkspaceView(model: model, initialTabState: state))
            let window = NSWindow(contentViewController: controller)
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 1120, height: 720))
            window.makeKeyAndOrderFront(nil)
            defer { window.close() }
            try await waitForTabs("visible workspace window") {
                window.isVisible && window.contentView?.window === window
            }
            let bar = try await waitForTabBar(in: window)
            let originalItems = descendants(in: bar, as: WorkspaceTabItemView.self)
            XCTAssertEqual(originalItems.count, 2)
            for _ in 0 ..< 5 {
                try await selectTab(originalItems[0], expectedIndex: 0, in: bar)
                XCTAssertNil(model.selectedTaskPath)
                XCTAssertTrue(originalItems[0] === descendants(in: bar, as: WorkspaceTabItemView.self)[0])
                try await selectTab(originalItems[1], expectedIndex: 1, in: bar)
                XCTAssertEqual(model.selectedTaskPath, path)
            }
            descendants(in: originalItems[1], as: NSButton.self)[1].performClick(nil)
            try await waitForTabs("closing active toolbar tab") {
                self.descendants(in: bar, as: WorkspaceTabItemView.self).count == 1
            }
            XCTAssertTrue(window.isVisible)
        }
    }

    private func exerciseSelectionCycles(
        _ harness: WorkspaceTabTestHarness,
        buttons: [NSButton]
    ) async throws {
        for _ in 0 ..< 20 {
            buttons[2].performClick(nil)
            await Task.yield()
            XCTAssertEqual(harness.selected, harness.notes.tab)
            harness.selectNotes()
            let updatedButtons = descendants(in: harness.view, as: NSButton.self)
            XCTAssertTrue(buttons[0] === updatedButtons[0])
            XCTAssertTrue(buttons[2] === updatedButtons[2])
            buttons[0].performClick(nil)
            await Task.yield()
            XCTAssertEqual(harness.selected, harness.today.tab)
            harness.selectToday()
        }
    }

    private func waitForTabBar(in window: NSWindow) async throws -> WorkspaceTabBarView {
        try await waitForTabs("workspace toolbar tabs") {
            self.tabBar(in: window) != nil
        }
        return try XCTUnwrap(tabBar(in: window))
    }

    private func selectTab(
        _ item: WorkspaceTabItemView,
        expectedIndex: Int,
        in bar: WorkspaceTabBarView
    ) async throws {
        descendants(in: item, as: NSButton.self)[0].performClick(nil)
        try await waitForTabs("selecting toolbar tab \(expectedIndex)") {
            let items = self.descendants(in: bar, as: WorkspaceTabItemView.self)
            return items.indices.contains(expectedIndex) && items[expectedIndex].isSelected
        }
    }

    private func waitForTabs(_ transition: String, until predicate: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        var confirmations = 0
        while ContinuousClock.now < deadline {
            confirmations = predicate() ? confirmations + 1 : 0
            if confirmations == 3 {
                return
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        _ = try XCTUnwrap(confirmations == 3 ? true : nil, "Timed out while \(transition)")
    }

    private func tabBar(in window: NSWindow) -> WorkspaceTabBarView? {
        window.toolbar?.items.lazy.compactMap(\.view).compactMap {
            self.descendants(in: $0, as: WorkspaceTabBarView.self).first
        }.first
    }

    private func descendants<T: NSView>(in view: NSView, as _: T.Type) -> [T] {
        let current = (view as? T).map { [$0] } ?? []
        return current + view.subviews.flatMap { descendants(in: $0, as: T.self) }
    }
}

@MainActor
private final class WorkspaceTabTestHarness {
    let view = WorkspaceTabBarView()
    let today = WorkspaceTabPresentation(
        tab: .route(.today), title: "Today", systemImage: "sun.max", isSelected: true
    )
    let notes: WorkspaceTabPresentation
    var selected: WorkspaceTab?
    var closed: WorkspaceTab?

    init(task: VaultPath) {
        notes = WorkspaceTabPresentation(
            tab: .task(task), title: "Detailed notes", systemImage: "doc.text", isSelected: false
        )
        view.frame = NSRect(x: 0, y: 0, width: 360, height: 30)
        selectToday()
    }

    func selectToday() {
        update([today, notes])
    }

    func selectNotes() {
        update([today.withSelection(false), notes.withSelection(true)])
    }

    func showTodayOnly() {
        update([today])
    }

    private func update(_ presentations: [WorkspaceTabPresentation]) {
        view.update(presentations, onSelect: { self.selected = $0 }, onClose: { self.closed = $0 })
    }
}

private extension WorkspaceTabPresentation {
    func withSelection(_ isSelected: Bool) -> Self {
        Self(tab: tab, title: title, systemImage: systemImage, isSelected: isSelected)
    }
}
