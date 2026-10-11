import AppKit
@testable import LocalTodoApp
import SwiftUI
import Testing
import XCTest

@MainActor
final class WorkspaceTabOverflowTests: XCTestCase {
    func testOverflowStaysInsideCanvasAndScrollsAcrossResizing() async throws {
        try await withWorkspace { fixture, root in
            await fixture.createTask(
                title: "A longer task title for overflow testing",
                vaultSession: fixture.vaultSession
            )
            let window = try await openVaultScene()
            defer { window.close() }
            let model = try #require((window.delegate as? WorkspaceWindowDelegate)?.model)
            defer { model.releaseWindowResources() }
            #expect(try await model.openVault(root))
            window.makeKeyAndOrderFront(nil)
            try await waitForNativeUI("sidebar destinations", in: window) {
                guard let content = window.contentView else { return false }
                return self.descendants(in: content, as: CommandClickTrackingView.self).count >= 9
            }
            let content = try XCTUnwrap(window.contentView)
            let destinations = descendants(in: content, as: CommandClickTrackingView.self)
            for destination in destinations {
                destination.action?()
            }
            for width in [1600.0, 1120.0, 840.0, 1600.0] {
                window.setContentSize(NSSize(width: width, height: 720))
                for presented in [true, false] {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { model.isInspectorPresented = presented }
                    _ = try await settledBar(in: window)
                    window.setContentSize(NSSize(width: width, height: 720))
                    try await assertOverflow(in: window)
                    XCTAssertEqual(window.frame.width, width, accuracy: 2)
                }
            }
        }
    }

    func testTwoTabsStartAtTheLeadingCanvasEdge() async throws {
        try await withWorkspace { _, root in
            let window = try await openVaultScene()
            defer { window.close() }
            let model = try #require((window.delegate as? WorkspaceWindowDelegate)?.model)
            defer { model.releaseWindowResources() }
            #expect(try await model.openVault(root))
            window.makeKeyAndOrderFront(nil)
            try await waitForNativeUI("sidebar destinations", in: window) {
                guard let content = window.contentView else { return false }
                return self.descendants(in: content, as: CommandClickTrackingView.self).count >= 9
            }
            let content = try XCTUnwrap(window.contentView)
            for destination in descendants(in: content, as: CommandClickTrackingView.self).prefix(2) {
                destination.action?()
            }
            for presented in [true, false] {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { model.isInspectorPresented = presented }
                _ = try await settledBar(in: window)
                window.setContentSize(NSSize(width: 1600, height: 720))
                try await assertOverflow(in: window)
            }
        }
    }

    func testSelectionAndWheelScrollingKeepOverflowReachable() async throws {
        let bar = WorkspaceTabBarView(frame: NSRect(x: 0, y: 0, width: 280, height: 30))
        let window = NSWindow(contentRect: bar.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = bar
        defer { window.close() }
        let routes: [WorkspaceRoute] = [.today, .inbox, .upcoming, .waiting, .someday, .completed, .all, .search]
        let tabs = routes.map {
            WorkspaceTabPresentation(tab: .route($0), title: $0.title, systemImage: "tray", isSelected: $0 == .search)
        }
        bar.updateViewportWidth(280)
        bar.update(tabs, onSelect: { _ in }, onClose: { _ in })
        window.orderFront(nil)
        let scroll = try XCTUnwrap(descendants(in: bar, as: WorkspaceTabScrollView.self).first)
        let last = try XCTUnwrap(descendants(in: bar, as: WorkspaceTabItemView.self).last)
        try await waitForNativeUI("selected overflow tab", in: window) {
            scroll.documentVisibleRect.contains(last.frame)
        }
        try scrollWheel(scroll, horizontal: 10000, vertical: 0)
        XCTAssertEqual(scroll.contentView.bounds.minX, 0)
        try scrollWheel(scroll, horizontal: 0, vertical: -10000)
        XCTAssertEqual(scroll.contentView.bounds.maxX, scroll.documentView?.frame.maxX)
        // Pending reveals must resolve current selection after tabs close, not retain stale indices.
        bar.updateViewportWidth(260)
        bar.update([], onSelect: { _ in }, onClose: { _ in })
        await Task.yield()
        XCTAssertTrue(bar.isHidden)
    }

    private func scrollWheel(_ scroll: WorkspaceTabScrollView, horizontal: Int32, vertical: Int32) throws {
        let event = try XCTUnwrap(CGEvent(
            scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
            wheel1: vertical, wheel2: horizontal, wheel3: 0
        ))
        try scroll.scrollWheel(with: XCTUnwrap(NSEvent(cgEvent: event)))
    }

    private func assertOverflow(in window: NSWindow) async throws {
        let bar = try await settledBar(in: window)
        if ProcessInfo.processInfo.environment["TASKMARK_TAB_CAPTURE"] != nil {
            print("TASKMARK_CAPTURE \(window.windowNumber) tabs-\(Int(window.frame.width))")
            try await Task.sleep(for: .seconds(2))
        }
        let scroll = try XCTUnwrap(descendants(in: bar, as: WorkspaceTabScrollView.self).first)
        let root = try XCTUnwrap(window.contentView)
        let splits = descendants(in: root, as: NSSplitView.self)
        let sidebar = try XCTUnwrap(splits.first { $0.arrangedSubviews.count >= 2 }?.arrangedSubviews.first)
        let sidebarFrame = sidebar.convert(sidebar.bounds, to: nil)
        let barFrame = bar.convert(bar.bounds, to: nil)
        let search = try XCTUnwrap(window.toolbar?.items.first { $0.label == "Search" }?.view)
        for item in window.toolbar?.items.filter({ [
            "Search",
            "New Task",
            "View Options",
            "Hide Inspector",
            "Show Inspector",
        ].contains($0.label) }) ?? [] {
            XCTAssertTrue(item.view?.window === window, "\(item.label) must remain visible")
        }
        let searchFrame = search.convert(search.bounds, to: nil)
        XCTAssertGreaterThanOrEqual(barFrame.minX, sidebarFrame.maxX)
        XCTAssertLessThanOrEqual(barFrame.minX - sidebarFrame.maxX, 28, "Tabs must start at the canvas leading edge")
        XCTAssertLessThanOrEqual(barFrame.maxX, searchFrame.minX)
        XCTAssertLessThanOrEqual(scroll.bounds.width, bar.bounds.width)
        let document = try XCTUnwrap(scroll.documentView)
        if document.frame.width <= scroll.contentView.bounds.width {
            return
        }
        scroll.contentView.scroll(to: .zero)
        let event = try XCTUnwrap(CGEvent(
            scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: 0, wheel2: -100, wheel3: 0
        ))
        try scroll.scrollWheel(with: XCTUnwrap(NSEvent(cgEvent: event)))
        XCTAssertGreaterThan(scroll.contentView.bounds.minX, 0)
    }

    private func settledBar(in window: NSWindow) async throws -> WorkspaceTabBarView {
        var previous = CGRect.zero
        var confirmations = 0
        for _ in 0 ..< 100 {
            try await Task.sleep(for: .milliseconds(25))
            window.display()
            guard let bar = window.toolbar?.items.compactMap(\.view).flatMap({
                descendants(in: $0, as: WorkspaceTabBarView.self)
            }).first else { continue }
            let frame = bar.convert(bar.bounds, to: nil)
            confirmations = frame == previous ? confirmations + 1 : 0
            if confirmations == 8 {
                return bar
            }
            previous = frame
        }
        return try XCTUnwrap(nil, "Toolbar failed to settle")
    }

    private func descendants<T: NSView>(in view: NSView, as _: T.Type) -> [T] {
        let current = (view as? T).map { [$0] } ?? []
        return current + view.subviews.flatMap { descendants(in: $0, as: T.self) }
    }
}
