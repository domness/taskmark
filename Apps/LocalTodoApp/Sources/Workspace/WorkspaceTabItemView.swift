import AppKit

final class WorkspaceTabItemView: NSView {
    private var presentation: WorkspaceTabPresentation
    private var selectedBackgroundColor: NSColor
    private var onSelect: (WorkspaceTab) -> Void
    private var onClose: (WorkspaceTab) -> Void
    private let titleButton: NSButton
    private let closeButton: NSButton

    var isSelected: Bool {
        presentation.isSelected
    }

    init(
        presentation: WorkspaceTabPresentation,
        selectedBackgroundColor: NSColor,
        onSelect: @escaping (WorkspaceTab) -> Void,
        onClose: @escaping (WorkspaceTab) -> Void
    ) {
        self.presentation = presentation
        self.selectedBackgroundColor = selectedBackgroundColor
        self.onSelect = onSelect
        self.onClose = onClose
        titleButton = NSButton(title: presentation.title, target: nil, action: nil)
        closeButton = NSButton(
            image: NSImage(systemSymbolName: "xmark", accessibilityDescription: nil) ?? NSImage(),
            target: nil,
            action: nil
        )
        super.init(frame: .zero)
        configureView()
        update(
            presentation: presentation,
            selectedBackgroundColor: selectedBackgroundColor,
            onSelect: onSelect,
            onClose: onClose
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateSelectionBackground()
    }

    func update(
        presentation: WorkspaceTabPresentation,
        selectedBackgroundColor: NSColor,
        onSelect: @escaping (WorkspaceTab) -> Void,
        onClose: @escaping (WorkspaceTab) -> Void
    ) {
        self.presentation = presentation
        self.selectedBackgroundColor = selectedBackgroundColor
        self.onSelect = onSelect
        self.onClose = onClose
        titleButton.title = presentation.title
        titleButton.image = NSImage(systemSymbolName: presentation.systemImage, accessibilityDescription: nil)
        titleButton.toolTip = presentation.title
        titleButton.contentTintColor = presentation.isSelected ? .labelColor : .secondaryLabelColor
        titleButton.font = .systemFont(
            ofSize: NSFont.smallSystemFontSize,
            weight: presentation.isSelected ? .medium : .regular
        )
        titleButton.setAccessibilitySelected(presentation.isSelected)
        closeButton.toolTip = "Close \(presentation.title)"
        closeButton.setAccessibilityLabel("Close \(presentation.title)")
        closeButton.alphaValue = presentation.isSelected ? 1 : 0.62
        updateSelectionBackground()
    }

    private func configureView() {
        wantsLayer = true
        heightAnchor.constraint(equalToConstant: 30).isActive = true
        configureTitleButton()
        configureCloseButton()
        let stack = NSStackView(views: [titleButton, closeButton])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    private func configureTitleButton() {
        titleButton.target = self
        titleButton.action = #selector(selectTab)
        titleButton.isBordered = false
        titleButton.imagePosition = .imageLeading
        titleButton.imageHugsTitle = true
        titleButton.lineBreakMode = .byTruncatingTail
        titleButton.alignment = .left
        titleButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleButton.widthAnchor.constraint(lessThanOrEqualToConstant: 210).isActive = true
    }

    private func configureCloseButton() {
        closeButton.target = self
        closeButton.action = #selector(closeTab)
        closeButton.isBordered = false
        closeButton.contentTintColor = .tertiaryLabelColor
        closeButton.widthAnchor.constraint(equalToConstant: 16).isActive = true
    }

    @objc private func selectTab() {
        Task { @MainActor [presentation, onSelect] in
            onSelect(presentation.tab)
        }
    }

    @objc private func closeTab() {
        Task { @MainActor [presentation, onClose] in
            onClose(presentation.tab)
        }
    }

    private func updateSelectionBackground() {
        layer?.backgroundColor = presentation.isSelected
            ? selectedBackgroundColor.cgColor
            : NSColor.clear.cgColor
    }
}
