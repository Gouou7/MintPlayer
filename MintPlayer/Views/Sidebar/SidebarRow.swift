import SwiftUI
import AppKit

struct SidebarRow: View {
    let title: String
    let systemImage: String
    @Environment(\.controlActiveState) private var controlActiveState
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconColor)
                .frame(width: 24)
            
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var iconColor: Color {
        controlActiveState == .inactive ? .secondary : MintTheme.accent
    }
}

struct MintSidebarRowButtonStyle: ButtonStyle {
    var isSelected = false
    var isHighlighted = false
    var cornerRadius = MintTheme.selectedRowCornerRadius

    func makeBody(configuration: Configuration) -> Body {
        Body(
            configuration: configuration,
            isSelected: isSelected,
            isHighlighted: isHighlighted,
            cornerRadius: cornerRadius
        )
    }

    struct Body: View {
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
                        shape.fill(Color(nsColor: .unemphasizedSelectedContentBackgroundColor))
                    } else if configuration.isPressed {
                        shape.fill(MintTheme.pressedFill)
                    } else if isHovered || isHighlighted {
                        shape.fill(MintTheme.hoverFill)
                    }
                }
                .opacity(configuration.isPressed ? 0.86 : 1)
                .contentShape(shape)
                .onHover { isHovered = $0 }
        }
    }
}
