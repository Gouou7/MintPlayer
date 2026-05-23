import SwiftUI
import AppKit

enum MintTheme {
    static let accentNSColor = NSColor(name: nil) { appearance in
        let match = appearance.bestMatch(from: [.darkAqua, .aqua])
        return NSColor(hex: match == .darkAqua ? 0xAAFFC7 : 0x67C090)
    }

    static let accent = Color(nsColor: accentNSColor)
    static let textOnAccent = Color.black
    static let activeControl = Color.black
    static let inactiveControl = Color.secondary
    static let selectedRowCornerRadius: CGFloat = 8
    static let selectedRowFill = accent.opacity(0.18)
    static let selectedRowStroke = accent.opacity(0.38)
    static let hoverFill = Color.primary.opacity(0.07)
    static let pressedFill = Color.primary.opacity(0.12)
    static let contentHoverStroke = Color.primary.opacity(0.12)

    static func selectedRowFillNSColor(for appearance: NSAppearance?) -> NSColor {
        accentNSColor.withAlphaComponent(0.18)
    }

    static func selectedRowStrokeNSColor(for appearance: NSAppearance?) -> NSColor {
        accentNSColor.withAlphaComponent(0.38)
    }

    static func hoverFillNSColor(for appearance: NSAppearance?) -> NSColor {
        let match = appearance?.bestMatch(from: [.darkAqua, .aqua])
        let alpha: CGFloat = match == .darkAqua ? 0.12 : 0.08
        return NSColor.labelColor.withAlphaComponent(alpha)
    }
}

struct MintSelectedRowStyle: ViewModifier {
    let isSelected: Bool
    var cornerRadius: CGFloat = MintTheme.selectedRowCornerRadius

    func body(content: Content) -> some View {
        content
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(MintTheme.selectedRowFill)
                }
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(MintTheme.selectedRowStroke, lineWidth: 1)
                }
            }
    }
}

extension View {
    func mintSelectedRowStyle(_ isSelected: Bool, cornerRadius: CGFloat = MintTheme.selectedRowCornerRadius) -> some View {
        modifier(MintSelectedRowStyle(isSelected: isSelected, cornerRadius: cornerRadius))
    }
}

struct MintPlainIconButtonStyle: ButtonStyle {
    var isActive = false
    var shape: AnyShape = AnyShape(Circle())
    var hoverSize: CGSize = CGSize(width: 38, height: 38)

    func makeBody(configuration: Configuration) -> some View {
        HoverButtonBody(
            configuration: configuration,
            isActive: isActive,
            shape: shape,
            hoverSize: hoverSize
        )
    }

    private struct HoverButtonBody: View {
        let configuration: Configuration
        let isActive: Bool
        let shape: AnyShape
        let hoverSize: CGSize
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .foregroundStyle(isActive ? MintTheme.accent : Color.primary)
                .background {
                    if configuration.isPressed {
                        shape.fill(MintTheme.pressedFill)
                            .frame(width: hoverSize.width, height: hoverSize.height)
                    } else if isHovered {
                        shape.fill(MintTheme.hoverFill)
                            .frame(width: hoverSize.width, height: hoverSize.height)
                    }
                }
                .opacity(configuration.isPressed ? 0.78 : 1)
                .contentShape(shape)
                .onHover { isHovered = $0 }
        }
    }
}

struct MintRowButtonStyle: ButtonStyle {
    var isSelected = false
    var isHighlighted = false
    var cornerRadius = MintTheme.selectedRowCornerRadius

    func makeBody(configuration: Configuration) -> some View {
        HoverRowBody(
            configuration: configuration,
            isSelected: isSelected,
            isHighlighted: isHighlighted,
            cornerRadius: cornerRadius
        )
    }

    private struct HoverRowBody: View {
        let configuration: Configuration
        let isSelected: Bool
        let isHighlighted: Bool
        let cornerRadius: CGFloat
        @State private var isHovered = false

        private var shape: RoundedRectangle {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        }

        var body: some View {
            configuration.label
                .background {
                    if isSelected {
                        shape.fill(MintTheme.selectedRowFill)
                    } else if configuration.isPressed {
                        shape.fill(MintTheme.pressedFill)
                    } else if isHovered || isHighlighted {
                        shape.fill(MintTheme.hoverFill)
                    }
                }
                .overlay {
                    if isSelected {
                        shape.stroke(MintTheme.selectedRowStroke, lineWidth: 1)
                    }
                }
                .opacity(configuration.isPressed ? 0.86 : 1)
                .contentShape(shape)
                .onHover { isHovered = $0 }
        }
    }
}

struct MintContentButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 12
    var hoverOutset: CGFloat = 6

    func makeBody(configuration: Configuration) -> some View {
        HoverContentBody(
            configuration: configuration,
            cornerRadius: cornerRadius,
            hoverOutset: hoverOutset
        )
    }

    private struct HoverContentBody: View {
        let configuration: Configuration
        let cornerRadius: CGFloat
        let hoverOutset: CGFloat
        @State private var isHovered = false

        private var shape: RoundedRectangle {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        }

        var body: some View {
            configuration.label
                .padding(hoverOutset)
                .background {
                    if configuration.isPressed {
                        shape.fill(MintTheme.pressedFill)
                    } else if isHovered {
                        shape.fill(MintTheme.hoverFill)
                    }
                }
                .overlay {
                    if isHovered || configuration.isPressed {
                        shape.stroke(MintTheme.contentHoverStroke, lineWidth: 1)
                    }
                }
                .opacity(configuration.isPressed ? 0.84 : 1)
                .contentShape(shape)
                .onHover { isHovered = $0 }
                .padding(-hoverOutset)
        }
    }
}

struct MintHoverRowStyle: ViewModifier {
    var isSelected = false
    var cornerRadius = MintTheme.selectedRowCornerRadius
    @State private var isHovered = false

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    func body(content: Content) -> some View {
        content
            .background {
                if isSelected {
                    shape.fill(MintTheme.selectedRowFill)
                } else if isHovered {
                    shape.fill(MintTheme.hoverFill)
                }
            }
            .overlay {
                if isSelected {
                    shape.stroke(MintTheme.selectedRowStroke, lineWidth: 1)
                }
            }
            .contentShape(shape)
            .onHover { isHovered = $0 }
    }
}

extension View {
    func mintHoverRowStyle(_ isSelected: Bool = false, cornerRadius: CGFloat = MintTheme.selectedRowCornerRadius) -> some View {
        modifier(MintHoverRowStyle(isSelected: isSelected, cornerRadius: cornerRadius))
    }
}

final class MintTableRowView: NSTableRowView {
    private let horizontalInset: CGFloat
    private let verticalInset: CGFloat
    private var hoverTrackingArea: NSTrackingArea?
    private var isMouseInside = false {
        didSet {
            guard oldValue != isMouseInside else { return }
            needsDisplay = true
        }
    }

    init(horizontalInset: CGFloat = 4, verticalInset: CGFloat = 3) {
        self.horizontalInset = horizontalInset
        self.verticalInset = verticalInset
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        horizontalInset = 4
        verticalInset = 3
        super.init(coder: coder)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }

        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .activeInKeyWindow,
            .inVisibleRect
        ]
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: options,
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        isMouseInside = true
    }

    override func mouseExited(with event: NSEvent) {
        isMouseInside = false
    }

    override func scrollWheel(with event: NSEvent) {
        invalidateVisibleRowHover()
        super.scrollWheel(with: event)
        DispatchQueue.main.async { [weak self] in
            self?.invalidateVisibleRowHover()
        }
    }

    override func drawBackground(in dirtyRect: NSRect) {
        super.drawBackground(in: dirtyRect)

        guard isMouseOverRow, !isSelected else { return }
        let hoverRect = bounds.insetBy(dx: horizontalInset, dy: verticalInset)
        guard hoverRect.width > 0, hoverRect.height > 0 else { return }

        let path = NSBezierPath(
            roundedRect: hoverRect,
            xRadius: MintTheme.selectedRowCornerRadius,
            yRadius: MintTheme.selectedRowCornerRadius
        )
        MintTheme.hoverFillNSColor(for: effectiveAppearance).setFill()
        path.fill()
    }

    override func drawSelection(in dirtyRect: NSRect) {
        guard selectionHighlightStyle != .none else { return }

        let selectionRect = bounds.insetBy(dx: horizontalInset, dy: verticalInset)
        guard selectionRect.width > 0, selectionRect.height > 0 else { return }

        let path = NSBezierPath(
            roundedRect: selectionRect,
            xRadius: MintTheme.selectedRowCornerRadius,
            yRadius: MintTheme.selectedRowCornerRadius
        )
        MintTheme.selectedRowFillNSColor(for: effectiveAppearance).setFill()
        path.fill()
        MintTheme.selectedRowStrokeNSColor(for: effectiveAppearance).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private var isMouseOverRow: Bool {
        guard let window else { return false }
        let point = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        return bounds.contains(point)
    }

    private func invalidateVisibleRowHover() {
        guard let tableView = superview as? NSTableView ?? enclosingScrollView?.documentView as? NSTableView else {
            needsDisplay = true
            return
        }

        let visibleRows = tableView.rows(in: tableView.visibleRect)
        guard visibleRows.location != NSNotFound else { return }

        for row in visibleRows.location..<NSMaxRange(visibleRows) {
            tableView.rowView(atRow: row, makeIfNecessary: false)?.needsDisplay = true
        }
    }
}

private extension NSColor {
    convenience init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0

        self.init(calibratedRed: red, green: green, blue: blue, alpha: 1)
    }
}
