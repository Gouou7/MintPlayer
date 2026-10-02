import SwiftUI
import AppKit

enum MintTheme {
    static var contentBackground: some View {
        NativeContentBackground()
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    static let textOnAccent = Color.black
    static let activeControl = Color.black
    static let inactiveControl = Color.secondary
    static let hoverFill = Color.primary.opacity(0.07)
    static let pressedFill = Color.primary.opacity(0.12)
    static let contentHoverStroke = Color.primary.opacity(0.12)
}

extension View {
    func mintRowHover(isSelected: Bool = false, cornerRadius: CGFloat = 8) -> some View {
        modifier(MintRowHoverModifier(isSelected: isSelected, cornerRadius: cornerRadius))
    }
}

private struct MintRowHoverModifier: ViewModifier {
    let isSelected: Bool
    let cornerRadius: CGFloat
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlActiveState) private var controlActiveState
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .background {
                if isHovered && isEnabled && !isSelected && controlActiveState != .inactive {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(MintTheme.hoverFill)
                }
            }
            .onHover { isHovered = $0 }
            .onDisappear { isHovered = false }
    }
}

struct MintPlainIconButtonStyle: ButtonStyle {
    var isActive = false
    var inactiveForeground = Color.primary
    var shape: AnyShape = AnyShape(Circle())
    var hoverSize: CGSize = CGSize(width: 38, height: 38)

    func makeBody(configuration: Configuration) -> some View {
        HoverButtonBody(
            configuration: configuration,
            isActive: isActive,
            inactiveForeground: inactiveForeground,
            shape: shape,
            hoverSize: hoverSize
        )
    }

    private struct HoverButtonBody: View {
        let configuration: Configuration
        let isActive: Bool
        let inactiveForeground: Color
        let shape: AnyShape
        let hoverSize: CGSize
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .foregroundStyle(isActive ? Color.accentColor : inactiveForeground)
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

private struct NativeContentBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        // The native content material applies wallpaper tinting without a custom color.
        view.material = .contentBackground
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
