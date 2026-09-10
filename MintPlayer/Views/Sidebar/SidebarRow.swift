import SwiftUI

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
