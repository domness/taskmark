import AppKit
import LocalTodoDomain
import SwiftUI

struct WorkspaceTabBar: NSViewRepresentable {
    let model: WorkspaceModel
    let width: CGFloat
    let tabs: [WorkspaceTab]
    let selection: WorkspaceTab?
    let onSelect: (WorkspaceTab) -> Void
    let onClose: (WorkspaceTab) -> Void
    @Environment(\.themeTypography) private var typography
    @Environment(\.vaultAppearance) private var appearance
    @Environment(\.colorScheme) private var colorScheme

    func makeNSView(context _: Context) -> WorkspaceTabBarView {
        let view = WorkspaceTabBarView()
        update(view)
        return view
    }

    func updateNSView(_ view: WorkspaceTabBarView, context _: Context) {
        update(view)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: WorkspaceTabBarView, context _: Context) -> CGSize? {
        // The document's intrinsic width must not become the toolbar viewport's minimum width.
        CGSize(width: min(width, max(1, proposal.width ?? width)), height: nsView.toolbarFittingSize.height)
    }

    private func update(_ view: WorkspaceTabBarView) {
        view.updateViewportWidth(width)
        view.update(
            tabs.map { tab in
                WorkspaceTabPresentation(
                    tab: tab,
                    title: title(for: tab),
                    systemImage: systemImage(for: tab),
                    isSelected: selection == tab
                )
            },
            typography: typography,
            selectedBackgroundColor: NSColor(appearance.color(
                "--background",
                scheme: colorScheme,
                fallback: Color(nsColor: .windowBackgroundColor)
            )),
            onSelect: onSelect,
            onClose: onClose
        )
    }

    private func title(for tab: WorkspaceTab) -> String {
        switch tab {
        case let .route(route):
            switch route {
            case let .project(path): model.projectDisplayTitle(path)
            case let .area(path): model.areaDisplayTitle(path)
            default: route.title
            }
        case let .task(path):
            model.taskDrafts[path]?.title ?? model.snapshot?.tasks[path]?.value.title ?? fallbackTitle(path)
        }
    }

    private func systemImage(for tab: WorkspaceTab) -> String {
        switch tab {
        case .task: "doc.text"
        case let .route(route): systemImage(for: route)
        }
    }

    private func systemImage(for route: WorkspaceRoute) -> String {
        switch route {
        case .today, .inbox, .next, .upcoming, .waiting, .someday, .completed, .all:
            focusSystemImage(for: route)
        case .search: "magnifyingglass"
        case .filters, .savedFilter: "line.3.horizontal.decrease.circle"
        case .issues: "exclamationmark.triangle"
        case .project: "square.stack"
        case .area: "circle.grid.2x2"
        case .tag: "tag"
        case .priority: "exclamationmark"
        }
    }

    private func focusSystemImage(for route: WorkspaceRoute) -> String {
        switch route {
        case .today: "sun.max"
        case .inbox: "tray"
        case .next: "arrow.right.circle"
        case .upcoming: "calendar"
        case .waiting: "hourglass"
        case .someday: "archivebox"
        case .completed: "checkmark.circle"
        default: "checklist"
        }
    }

    private func fallbackTitle(_ path: VaultPath) -> String {
        let filename = path.value.split(separator: "/").last.map(String.init) ?? path.value
        return filename.hasSuffix(".md") ? String(filename.dropLast(3)) : filename
    }
}

struct WorkspaceTabPresentation: Equatable {
    let tab: WorkspaceTab
    let title: String
    let systemImage: String
    let isSelected: Bool
}

final class WorkspaceTabBarView: NSView {
    private var typography = ThemeTypography(family: nil)
    private var tabHeight: CGFloat {
        let font = typography.nativeFont(.body)
        return max(30, ceil(font.ascender - font.descender + font.leading) + 8)
    }

    private var viewportWidth: CGFloat = 1
    private let scrollView = WorkspaceTabScrollView()
    private let document = NSView()
    private var presentations = [WorkspaceTabPresentation]()
    private var items = [WorkspaceTabItemView]()
    private var selectedBackgroundColor = NSColor.windowBackgroundColor

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        document.frame = NSRect(x: 0, y: 0, width: 520, height: tabHeight)
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.horizontalScrollElasticity = .automatic
        scrollView.verticalScrollElasticity = .none
        scrollView.documentView = document
        addSubview(scrollView)
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    var toolbarFittingSize: CGSize {
        guard !presentations.isEmpty else { return CGSize(width: 1, height: tabHeight) }
        return CGSize(width: viewportWidth, height: tabHeight)
    }

    func updateViewportWidth(_ width: CGFloat) {
        guard viewportWidth != width else { return }
        viewportWidth = width
        invalidateIntrinsicContentSize()
        scrollSelectionIntoView()
    }

    override func layout() {
        super.layout()
        scrollView.frame = bounds
        document.frame = NSRect(x: 0, y: 0, width: max(contentWidth, bounds.width), height: bounds.height)
        var leading: CGFloat = 0
        for (item, presentation) in zip(items, presentations) {
            let width = preferredWidth(for: presentation)
            item.frame = NSRect(x: leading, y: 0, width: width, height: tabHeight)
            leading += width
        }
    }

    func update(
        _ presentations: [WorkspaceTabPresentation],
        typography: ThemeTypography = ThemeTypography(family: nil),
        selectedBackgroundColor: NSColor = .windowBackgroundColor,
        onSelect: @escaping (WorkspaceTab) -> Void,
        onClose: @escaping (WorkspaceTab) -> Void
    ) {
        let colorChanged = !selectedBackgroundColor.isEqual(self.selectedBackgroundColor)
        let typographyChanged = typography != self.typography
        guard presentations != self.presentations || colorChanged || typographyChanged else { return }
        let needsResize = typographyChanged || presentations.count != self.presentations.count
            || zip(presentations, self.presentations).contains { current, previous in
                current.tab != previous.tab
                    || current.title != previous.title
                    || current.systemImage != previous.systemImage
            }
        let reusesItems = presentations.map(\.tab) == self.presentations.map(\.tab)
        self.typography = typography
        self.presentations = presentations
        self.selectedBackgroundColor = selectedBackgroundColor
        if reusesItems {
            updateItems(presentations, onSelect: onSelect, onClose: onClose)
        } else {
            replaceItems(presentations, onSelect: onSelect, onClose: onClose)
        }
        isHidden = presentations.isEmpty
        if needsResize {
            invalidateIntrinsicContentSize()
        }
        needsLayout = true
        scrollSelectionIntoView()
    }

    private func updateItems(
        _ presentations: [WorkspaceTabPresentation],
        onSelect: @escaping (WorkspaceTab) -> Void,
        onClose: @escaping (WorkspaceTab) -> Void
    ) {
        for (item, presentation) in zip(items, presentations) {
            item.update(
                presentation: presentation,
                selectedBackgroundColor: selectedBackgroundColor,
                typography: typography,
                onSelect: onSelect,
                onClose: onClose
            )
        }
    }

    private func replaceItems(
        _ presentations: [WorkspaceTabPresentation],
        onSelect: @escaping (WorkspaceTab) -> Void,
        onClose: @escaping (WorkspaceTab) -> Void
    ) {
        for item in items {
            item.removeFromSuperview()
        }
        items = presentations.map {
            WorkspaceTabItemView(
                presentation: $0,
                selectedBackgroundColor: selectedBackgroundColor,
                typography: typography,
                onSelect: onSelect,
                onClose: onClose
            )
        }
        for (item, presentation) in zip(items, presentations) {
            item.frame = NSRect(x: 0, y: 0, width: preferredWidth(for: presentation), height: tabHeight)
            document.addSubview(item)
        }
    }

    private func preferredWidth(for presentation: WorkspaceTabPresentation) -> CGFloat {
        let font = typography.nativeFont(.body, weight: .medium)
        let titleWidth = (presentation.title as NSString).size(withAttributes: [.font: font]).width
        // Icon, title/image spacing, close button, item spacing and horizontal padding.
        return min(240, max(72, ceil(titleWidth) + 58))
    }

    private var contentWidth: CGFloat {
        presentations.reduce(CGFloat.zero) { $0 + preferredWidth(for: $1) }
    }

    private func scrollSelectionIntoView() {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  let index = presentations.firstIndex(where: \.isSelected),
                  items.indices.contains(index) else { return }
            layoutSubtreeIfNeeded()
            document.scrollToVisible(items[index].frame.insetBy(dx: -8, dy: 0))
        }
    }

    override var intrinsicContentSize: NSSize {
        toolbarFittingSize
    }
}

final class WorkspaceTabScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        guard let documentView else {
            super.scrollWheel(with: event)
            return
        }
        let delta = abs(event.scrollingDeltaX) >= abs(event.scrollingDeltaY)
            ? event.scrollingDeltaX
            : event.scrollingDeltaY
        let maximumX = max(0, documentView.frame.width - contentView.bounds.width)
        guard maximumX > 0 else { return }
        var origin = contentView.bounds.origin
        origin.x = min(max(0, origin.x - delta), maximumX)
        contentView.setBoundsOrigin(origin)
        reflectScrolledClipView(contentView)
    }
}
