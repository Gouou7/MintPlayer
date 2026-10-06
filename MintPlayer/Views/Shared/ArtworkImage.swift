import SwiftUI
import ImageIO

struct ArtworkImage: View {
    let path: String?
    var cornerRadius: CGFloat = 10
    var targetSize: CGSize = CGSize(width: 360, height: 360)
    var crossfadeChanges = false
    
    @Environment(\.displayScale) private var displayScale
    @ObservedObject private var artworkStore = ArtworkStore.shared
    @State private var image: NSImage?
    @State private var displayedCacheKey: String?
    @State private var previousImage: NSImage?
    @State private var showsPreviousImage = false
    @State private var crossfadeGeneration = 0

    private let imageTransitionDuration: TimeInterval = 0.28
    
    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .id(displayedCacheKey)
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.16))

                Image(systemName: "rectangle.stack.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: min(targetSize.width, targetSize.height) * 0.34)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }

            if let previousImage {
                Image(nsImage: previousImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(showsPreviousImage ? 1 : 0)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .animation(crossfadeChanges ? .easeInOut(duration: imageTransitionDuration) : nil, value: showsPreviousImage)
        .task(id: cacheKey) {
            await loadImage(for: cacheKey)
        }
    }
    
    private var cacheKey: String {
        guard let path, !path.isEmpty else { return "empty" }
        return "\(path)|\(Int(targetSize.width))x\(Int(targetSize.height))|\(displayScale)|\(artworkStore.contentRevision)"
    }
    
    @MainActor
    private func loadImage(for requestedCacheKey: String) async {
        guard displayedCacheKey != requestedCacheKey else { return }
        
        guard let path, !path.isEmpty else {
            updateDisplayedImage(nil, cacheKey: requestedCacheKey)
            return
        }
        
        if let cachedImage = ArtworkCache.shared.cachedImage(
            path: path,
            pointSize: targetSize,
            scale: displayScale
        ) {
            updateDisplayedImage(cachedImage, cacheKey: requestedCacheKey)
            return
        }

        if !crossfadeChanges {
            image = nil
            displayedCacheKey = nil
        }

        let loadedImage = await ArtworkCache.shared.image(
            path: path,
            pointSize: targetSize,
            scale: displayScale
        )
        
        guard !Task.isCancelled, cacheKey == requestedCacheKey else { return }
        updateDisplayedImage(loadedImage, cacheKey: requestedCacheKey)
    }

    @MainActor
    private func updateDisplayedImage(_ nextImage: NSImage?, cacheKey nextCacheKey: String) {
        guard displayedCacheKey != nextCacheKey else { return }

        if crossfadeChanges, let image {
            previousImage = image
            showsPreviousImage = true
        } else {
            previousImage = nil
            showsPreviousImage = false
        }

        image = nextImage
        displayedCacheKey = nextCacheKey

        guard crossfadeChanges, previousImage != nil else { return }

        crossfadeGeneration += 1
        let generation = crossfadeGeneration

        withAnimation(.easeInOut(duration: imageTransitionDuration)) {
            showsPreviousImage = false
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(imageTransitionDuration * 1_000_000_000))
            guard crossfadeGeneration == generation else { return }
            previousImage = nil
        }
    }
}

final class ArtworkCache {
    static let shared = ArtworkCache()
    
    private let cache = NSCache<NSString, NSImage>()
    private var inFlight: [String: Task<NSImage?, Never>] = [:]
    
    private init() {
        cache.countLimit = 600
        cache.totalCostLimit = 96 * 1024 * 1024
    }
    
    @MainActor
    func cachedImage(path: String, pointSize: CGSize, scale: CGFloat) -> NSImage? {
        let key = cacheKey(path: path, pointSize: pointSize, scale: scale) as NSString
        return cache.object(forKey: key)
    }
    
    @MainActor
    func image(path: String, pointSize: CGSize, scale: CGFloat) async -> NSImage? {
        let key = cacheKey(path: path, pointSize: pointSize, scale: scale)
        if let cachedImage = cache.object(forKey: key as NSString) {
            return cachedImage
        }
        if let task = inFlight[key] { return await task.value }

        let task = Task<NSImage?, Never> {
            await ArtworkWorkQueue.shared.perform {
                guard let image = Self.downsampledImage(path: path, pointSize: pointSize, scale: scale) else { return nil }
                self.cache.setObject(image, forKey: key as NSString, cost: Self.cost(for: image, pointSize: pointSize, scale: scale))
                return image
            }
        }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        return image
    }
    
    @MainActor
    private func cacheKey(path: String, pointSize: CGSize, scale: CGFloat) -> String {
        let width = Int(pointSize.width * scale)
        let height = Int(pointSize.height * scale)
        return "\(path)|\(width)x\(height)|\(ArtworkStore.shared.contentRevision)"
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
