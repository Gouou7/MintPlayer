import SwiftUI

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    var detail: String?
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 58, weight: .semibold))
                .foregroundStyle(.secondary)
            
            Text(title)
                .font(.headline)
            
            if let detail {
                Text(detail)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
