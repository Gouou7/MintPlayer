import SwiftUI

struct CircleGlassButtonSurface: ViewModifier {
    private let shape = Circle()

    func body(content: Content) -> some View {
        content
            .contentShape(shape)
            .glassEffect(.regular.interactive(), in: shape)
    }
}
