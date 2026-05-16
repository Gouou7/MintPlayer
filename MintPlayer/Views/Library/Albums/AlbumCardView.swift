import SwiftUI

struct AlbumCardView: View {
    let album: Album
    
    var body: some View {
        VStack(spacing: 12) {
            // 专辑封面
            AsyncImage(url: URL(string: album.coverPath)) {
                image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "rectangle.stack.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(.secondary)
            }
            .frame(width: 180, height: 180)
            .cornerRadius(8)
            .shadow(radius: 4)
            // .hoverEffect(.scale) // 在 macOS 中可能不支持
            
            // 专辑信息
            VStack(alignment: .leading, spacing: 4) {
                Text(album.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(album.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text("\(album.year)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 180, alignment: .leading)
        }
        .padding(0)
    }
}
