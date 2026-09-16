import SwiftUI

struct SidebarRow: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    @Environment(\.controlActiveState) private var controlActiveState

    init(title: String, systemImage: String, isSelected: Bool = false) {
        self.title = title
        self.systemImage = systemImage
        self.isSelected = isSelected
    }

    var body: some View {
        Label {
            Text(title)
                .lineLimit(1)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(iconColor)
                .frame(width: 18)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.gray.opacity(controlActiveState == .inactive ? 0.12 : 0.20))
            }
        }
        .contentShape(Rectangle())
        .mintRowHover(isSelected: isSelected, cornerRadius: 10)
    }

    private var iconColor: Color {
        controlActiveState == .inactive ? .secondary : .accentColor
    }
}
