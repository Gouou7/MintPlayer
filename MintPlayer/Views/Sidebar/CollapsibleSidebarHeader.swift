import SwiftUI

struct CollapsibleSidebarHeader: View {
    let title: String
    @Binding var isExpanded: Bool
    var addSystemImage: String?
    var addHelp: String?
    var addAction: (() -> Void)?
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .textCase(.none)
            
            Spacer(minLength: 16)
            
            if let addSystemImage, let addAction {
                Button(action: addAction) {
                    Image(systemName: addSystemImage)
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(MintPlainIconButtonStyle())
                .foregroundStyle(.secondary)
                .help(addHelp ?? "")
                .opacity(isHovering ? 1 : 0)
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .opacity(isHovering ? 1 : 0)
        }
        .foregroundStyle(.secondary)
        .padding(.trailing, 18)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.16)) {
                isExpanded.toggle()
            }
        }
        .onHover { isHovering = $0 }
    }
}
