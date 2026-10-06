import Foundation
import AppKit
import Combine
import CryptoKit
import ImageIO
import UniformTypeIdentifiers

// Every image decoder, encoder and backdrop renderer shares this serial queue.
final class ArtworkWorkQueue {
    static let shared = ArtworkWorkQueue()

    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "MintPlayer.artwork"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .utility
        return queue
    }()

    func enqueue(priority: Operation.QueuePriority = .normal, _ work: @escaping @Sendable () -> Void) {
        let operation = BlockOperation { autoreleasepool(invoking: work) }
        operation.queuePriority = priority
        operation.qualityOfService = priority == .veryLow ? .background : .utility
        queue.addOperation(operation)
    }

    func perform<T>(priority: Operation.QueuePriority = .veryHigh, _ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            enqueue(priority: priority) { continuation.resume(returning: work()) }
        }
    }

    // Only the existing background metadata scanner uses the synchronous bridge.
    func performAndWait<T>(_ work: @escaping @Sendable () -> T) -> T {
        precondition(!Thread.isMainThread)
        let semaphore = DispatchSemaphore(value: 0)
        let result = WorkResult<T>()
        enqueue {
            result.value = work()
            semaphore.signal()
        }
        semaphore.wait()
        return result.value!
    }

    // The semaphore publishes the sole writer's result before the waiting reader accesses it.
    private final class WorkResult<Value>: @unchecked Sendable {
        var value: Value?
    }
}

final class ArtworkStore: ObservableObject {
    static let shared = ArtworkStore()

    @Published private(set) var contentRevision = 0

    private let rootURL: URL?
    private let stateLock = NSLock()
    private var libraryPaths = Set<String>()
    private var currentArtworkPath: String?
    private var activeWork = Set<UUID>()
    private var cleanupAllowed = false
    private var cleanupQueued = false
    private var needsCleanup = true

    private init() {
        rootURL = try? AppConfiguration.applicationSupportDirectory()
            .appendingPathComponent("Artwork", isDirectory: true)
    }

    func beginLibraryWork() -> UUID {
        let id = UUID()
        stateLock.lock()
        activeWork.insert(id)
        stateLock.unlock()
        return id
    }

    func endLibraryWork(_ id: UUID) {
        stateLock.lock()
        activeWork.remove(id)
        needsCleanup = true
        stateLock.unlock()
    }

    func updateLibraryReferences(_ paths: Set<String>, allowCleanup: Bool) {
        let normalizedPaths = Set(paths.map { URL(fileURLWithPath: $0).standardizedFileURL.path })
        stateLock.lock()
        if libraryPaths != normalizedPaths || cleanupAllowed != allowCleanup { needsCleanup = true }
        libraryPaths = normalizedPaths
        cleanupAllowed = allowCleanup
        stateLock.unlock()
    }

    func setCurrentArtworkPath(_ path: String?) {
        let normalizedPath = path.map { URL(fileURLWithPath: $0).standardizedFileURL.path }
        stateLock.lock()
        guard currentArtworkPath != normalizedPath else {
            stateLock.unlock()
            return
        }
        currentArtworkPath = normalizedPath
        needsCleanup = true
        stateLock.unlock()
        scheduleCleanup()
    }

    @MainActor
    func refreshImages() {
        contentRevision += 1
    }

    func cacheEmbeddedArtwork(_ data: Data) throws -> String {
        try ArtworkWorkQueue.shared.performAndWait {
            Result { try self.writeArtwork(data) }
        }.get()
    }

    func migrateLegacyArtwork(at path: String) async -> String? {
        await ArtworkWorkQueue.shared.perform(priority: .veryLow) {
            guard let rootURL = self.rootURL, self.isDirectory(rootURL),
                  self.isLegacyArtworkPath(path), self.isRegularFile(URL(fileURLWithPath: path)) else { return nil }
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
                return try self.writeArtwork(data)
            } catch {
                print("Error migrating artwork: \(error)")
                return nil
            }
        }
    }

    func isLegacyArtworkPath(_ path: String) -> Bool {
        guard let rootURL else { return false }
        let url = URL(fileURLWithPath: path).standardizedFileURL
        return url.deletingLastPathComponent() == rootURL.standardizedFileURL && isLegacyFileName(url.lastPathComponent)
    }

    func scheduleCleanup() {
        stateLock.lock()
        guard cleanupAllowed, activeWork.isEmpty, needsCleanup, !cleanupQueued else {
            stateLock.unlock()
            return
        }
        cleanupQueued = true
        stateLock.unlock()
        ArtworkWorkQueue.shared.enqueue(priority: .veryLow) {
            self.stateLock.lock()
            self.cleanupQueued = false
            self.stateLock.unlock()
            self.removeUnusedArtwork()
        }
    }

    func collectUnusedArtwork() async {
        await ArtworkWorkQueue.shared.perform(priority: .veryLow) { self.removeUnusedArtwork() }
    }

    private func writeArtwork(_ data: Data) throws -> String {
        guard let rootURL else { throw CocoaError(.fileWriteUnknown) }
        let directory = rootURL.appendingPathComponent("v2", isDirectory: true)
        try createDirectory(rootURL)
        try createDirectory(directory)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        for fileExtension in ["jpg", "png"] {
            let candidate = directory.appendingPathComponent(digest).appendingPathExtension(fileExtension)
            if isRegularFile(candidate), isValidArtwork(candidate) { return candidate.path }
        }

        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
              width.intValue > 0, height.intValue > 0 else { throw CocoaError(.fileReadCorruptFile) }
        let size = min(1024, max(width.intValue, height.intValue))
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: size
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let hasAlpha = [CGImageAlphaInfo.first, .last, .premultipliedFirst, .premultipliedLast, .alphaOnly].contains(image.alphaInfo)
        let type = hasAlpha ? UTType.png : UTType.jpeg
        let fileURL = directory.appendingPathComponent(digest).appendingPathExtension(hasAlpha ? "png" : "jpg")
        let encodedData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(encodedData as CFMutableData, type.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        // Atomic replacement also avoids modifying a file linked elsewhere by the user.
        try (encodedData as Data).write(to: fileURL, options: .atomic)
        guard isValidArtwork(fileURL) else { throw CocoaError(.fileReadCorruptFile) }
        return fileURL.path
    }

    private func isValidArtwork(_ url: URL) -> Bool {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
              (1...1024).contains(width.intValue), (1...1024).contains(height.intValue) else { return false }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: 64
        ] as CFDictionary) != nil
    }

    private func createDirectory(_ url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            guard isDirectory(url) else { throw CocoaError(.fileWriteNoPermission) }
        } else {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        }
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType) == .typeDirectory
    }

    private func isRegularFile(_ url: URL) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType) == .typeRegular
    }

    private func isLegacyFileName(_ name: String) -> Bool {
        let url = URL(fileURLWithPath: name)
        let stem = url.deletingPathExtension().lastPathComponent
        return url.pathExtension == "jpg" && !stem.isEmpty && stem.utf8.allSatisfy { (48...57).contains($0) }
    }

    private func isCacheFileName(_ name: String) -> Bool {
        let url = URL(fileURLWithPath: name)
        let stem = url.deletingPathExtension().lastPathComponent
        return ["jpg", "png"].contains(url.pathExtension) && stem.count == 64 && stem.utf8.allSatisfy {
            (48...57).contains($0) || (97...102).contains($0)
        }
    }

    private func removeUnusedArtwork() {
        stateLock.lock()
        guard cleanupAllowed, activeWork.isEmpty, needsCleanup else {
            stateLock.unlock()
            return
        }
        needsCleanup = false
        stateLock.unlock()
        guard let rootURL, isDirectory(rootURL) else { return }
        let cacheURL = rootURL.appendingPathComponent("v2", isDirectory: true)
        let legacyFiles = (try? FileManager.default.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil)) ?? []
        let cacheFiles = isDirectory(cacheURL)
            ? (try? FileManager.default.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil)) ?? [] : []
        let candidates = legacyFiles.filter { isLegacyFileName($0.lastPathComponent) }
            + cacheFiles.filter { isCacheFileName($0.lastPathComponent) }
        for url in candidates {
            stateLock.lock()
            // Check live references under the same lock used to start scans and pin playback.
            let path = url.standardizedFileURL.path
            if cleanupAllowed, activeWork.isEmpty, !libraryPaths.contains(path), currentArtworkPath != path,
               isDirectory(rootURL), isDirectory(url.deletingLastPathComponent()), isRegularFile(url) {
                do { try FileManager.default.removeItem(at: url) }
                catch { print("Error removing unused artwork: \(error)") }
            }
            stateLock.unlock()
        }
    }
}
