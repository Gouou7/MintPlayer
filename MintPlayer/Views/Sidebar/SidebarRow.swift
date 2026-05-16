import SwiftUI

struct SidebarRow: View {
    let title: String
    let systemImage: String
    var isSelected = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isSelected ? MintTheme.accent : .secondary)
                .frame(width: 24)
            
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(isSelected ? MintTheme.accent : .primary)
                .lineLimit(1)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
