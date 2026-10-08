import AppKit
import SwiftUI

struct ThemedListSelection: ViewModifier {
    let isSelected: Bool
    @Environment(\.vaultAppearance) private var appearance
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .listRowBackground(selectionBackground)
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 7)
                .fill(appearance.color("--selection-background", scheme: scheme, fallback: .clear))
                .padding(.vertical, 1)
        } else {
            Color.clear
        }
    }
}

private struct NativeListSelectionAdapter: NSViewRepresentable {
    let color: NSColor

    func makeNSView(context _: Context) -> NativeListSelectionView {
        let view = NativeListSelectionView()
        view.selectionColor = color
        return view
    }

    func updateNSView(_ view: NativeListSelectionView, context _: Context) {
        view.selectionColor = color
        view.connectToTable()
    }
}

final class ThemedSelectionBackgroundView: NSView {
    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }
}

final class NativeListSelectionView: NSView {
    var selectionColor = NSColor.clear
    private weak var tableView: NSTableView?
    private weak var observedWindow: NSWindow?

    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window, observedWindow !== window {
            observedWindow = window
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowUpdated),
                name: NSWindow.didUpdateNotification,
                object: window
            )
        }
        connectToTable()
    }

    func connectToTable() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let table = matchingTable() else { return }
            if tableView !== table {
                tableView = table
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(tableChanged),
                    name: NSTableView.selectionDidChangeNotification,
                    object: table
                )
                if let clipView = table.enclosingScrollView?.contentView {
                    clipView.postsBoundsChangedNotifications = true
                    NotificationCenter.default.addObserver(
                        self,
                        selector: #selector(tableChanged),
                        name: NSView.boundsDidChangeNotification,
                        object: clipView
                    )
                }
            }
            applySelectionBackgrounds(in: table)
        }
    }

    @objc private func tableChanged(_: Notification) {
        guard let tableView else { return }
        applySelectionBackgrounds(in: tableView)
    }

    @objc private func windowUpdated(_: Notification) {
        connectToTable()
    }

    private func matchingTable() -> NSTableView? {
        guard let contentView = window?.contentView else { return nil }
        let adapterFrame = convert(bounds, to: nil)
        return contentView.descendants(of: NSTableView.self).max { lhs, rhs in
            intersectionArea(of: lhs, with: adapterFrame) < intersectionArea(of: rhs, with: adapterFrame)
        }
    }

    private func intersectionArea(of table: NSTableView, with frame: NSRect) -> CGFloat {
        let intersection = table.convert(table.visibleRect, to: nil).intersection(frame)
        return intersection.width * intersection.height
    }

    private func applySelectionBackgrounds(in table: NSTableView) {
        let rows = table.rows(in: table.visibleRect)
        guard rows.location != NSNotFound else { return }
        for index in rows.location ..< NSMaxRange(rows) {
            if let row = table.rowView(atRow: index, makeIfNecessary: false) {
                row.subviews.filter { $0 is ThemedSelectionBackgroundView }.forEach { $0.removeFromSuperview() }
                guard table.isRowSelected(index) else { continue }
                // The themed surface is intentionally neutral, so keep semantic
                // primary/secondary text instead of AppKit's white emphasized text.
                row.isEmphasized = false
                let background = ThemedSelectionBackgroundView(frame: row.bounds)
                background.wantsLayer = true
                background.layer?.backgroundColor = selectionColor.cgColor
                background.layer?.cornerRadius = 7
                background.autoresizingMask = [.width, .height]
                row.addSubview(background, positioned: .below, relativeTo: row.subviews.first)
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

private extension NSView {
    func descendants<T: NSView>(of _: T.Type) -> [T] {
        subviews.flatMap { view in
            (view as? T).map { [$0] } ?? view.descendants(of: T.self)
        }
    }
}

extension View {
    func themedListSelection(isSelected: Bool) -> some View {
        modifier(ThemedListSelection(isSelected: isSelected))
    }

    func disableNativeListSelectionHighlight() -> some View {
        modifier(NativeListSelectionBackground())
    }
}

private struct NativeListSelectionBackground: ViewModifier {
    @Environment(\.vaultAppearance) private var appearance
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content.overlay(
            NativeListSelectionAdapter(color: selectionColor)
                .allowsHitTesting(false)
        )
    }

    private var selectionColor: NSColor {
        let values = scheme == .dark ? appearance.dark : appearance.light
        guard let value = values["--selection-background"], let hex = UInt32(value.dropFirst(), radix: 16) else {
            return .clear
        }
        return NSColor(
            srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255,
            alpha: 1
        )
    }
}
