import SwiftUI
import ImageIO

struct ArtworkImage: View {
    let path: String?
    var cornerRadius: CGFloat = 10
    var targetSize: CGSize = CGSize(width: 360, height: 360)
    
    @Environment(\.displayScale) private var displayScale
    @State private var image: NSImage?
    @State private var displayedCacheKey: String?
    
    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(
                    colors: [MintTheme.accent.opacity(0.34), Color.secondary.opacity(0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                Image(systemName: "music.note")
                    .font(.system(size: 44, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: cacheKey) {
            await loadImage(for: cacheKey)
        }
    }
    
    private var cacheKey: String {
        guard let path, !path.isEmpty else { return "empty" }
        return "\(path)|\(Int(targetSize.width))x\(Int(targetSize.height))|\(displayScale)"
    }
    
    @MainActor
    private func loadImage(for requestedCacheKey: String) async {
        guard displayedCacheKey != requestedCacheKey else { return }
        
        guard let path, !path.isEmpty else {
            image = nil
            displayedCacheKey = requestedCacheKey
            return
        }
        
        if let cachedImage = ArtworkCache.shared.cachedImage(
            path: path,
            pointSize: targetSize,
            scale: displayScale
        ) {
            image = cachedImage
            displayedCacheKey = requestedCacheKey
            return
        }
        
        image = nil
        displayedCacheKey = nil
        
        let loadedImage = await ArtworkCache.shared.image(
            path: path,
            pointSize: targetSize,
            scale: displayScale
        )
        
        guard cacheKey == requestedCacheKey else { return }
        image = loadedImage
        displayedCacheKey = requestedCacheKey
    }
}

final class ArtworkCache {
    static let shared = ArtworkCache()
    
    private let cache = NSCache<NSString, NSImage>()
    
    private init() {
        cache.countLimit = 600
        cache.totalCostLimit = 96 * 1024 * 1024
    }
    
    func cachedImage(path: String, pointSize: CGSize, scale: CGFloat) -> NSImage? {
        let key = cacheKey(path: path, pointSize: pointSize, scale: scale) as NSString
        return cache.object(forKey: key)
    }
    
    func image(path: String, pointSize: CGSize, scale: CGFloat) async -> NSImage? {
        let key = cacheKey(path: path, pointSize: pointSize, scale: scale) as NSString
        if let cachedImage = cache.object(forKey: key) {
            return cachedImage
        }
        
        return await Task.detached(priority: .utility) {
            guard let image = Self.downsampledImage(path: path, pointSize: pointSize, scale: scale) else {
                return nil
            }
            
            self.cache.setObject(image, forKey: key, cost: Self.cost(for: image, pointSize: pointSize, scale: scale))
            return image
        }.value
    }
    
    private func cacheKey(path: String, pointSize: CGSize, scale: CGFloat) -> String {
        let width = Int(pointSize.width * scale)
        let height = Int(pointSize.height * scale)
        return "\(path)|\(width)x\(height)"
    }
    
    private static func downsampledImage(path: String, pointSize: CGSize, scale: CGFloat) -> NSImage? {
        let url = URL(fileURLWithPath: path)
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options) else {
            return nil
        }
        
        let maxPixelSize = max(64, Int(max(pointSize.width, pointSize.height) * scale))
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return nil
        }
        
        return NSImage(cgImage: cgImage, size: pointSize)
    }
    
    private static func cost(for image: NSImage, pointSize: CGSize, scale: CGFloat) -> Int {
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cgImage.bytesPerRow * cgImage.height
        }
        
        return Int(pointSize.width * pointSize.height * scale * scale * 4)
    }
}
