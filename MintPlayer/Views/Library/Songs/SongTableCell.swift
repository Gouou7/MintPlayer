import SwiftUI

struct SongTableCell<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        HStack(spacing: 0) {
            content
            Spacer(minLength: 0)
        }
            .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
            .contentShape(Rectangle())
    }
}
