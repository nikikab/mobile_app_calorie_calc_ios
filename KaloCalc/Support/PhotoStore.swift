import UIKit
import ImageIO

/// Photos live in two places: a single "pending" file in the caches folder while the user is still choosing a product,
/// and permanent files in `photos/` once an entry is saved. Entries keep only the file name, because the path of the
/// app's container changes between installs and updates.
final class PhotoStore {
    static let maxSide: CGFloat = 1280

    static let shared = PhotoStore(
        photos: URL.documentsDirectory.appending(path: "photos", directoryHint: .isDirectory),
        pending: URL.cachesDirectory.appending(path: "pending.jpg"))

    private let photos: URL
    private let pending: URL

    init(photos: URL, pending: URL) {
        self.photos = photos
        self.pending = pending
    }

    /// A store in a fresh temporary folder, for tests and previews.
    static func temporary() -> PhotoStore {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        return PhotoStore(photos: root.appending(path: "photos", directoryHint: .isDirectory), pending: root.appending(path: "pending.jpg"))
    }

    func url(for name: String) -> URL { photos.appending(path: name) }

    /// Downsizes `image` so its longer side is at most `maxSide`, applies its rotation and stores it as the pending photo.
    func importPending(_ image: UIImage) throws -> URL {
        let longest = max(image.size.width, image.size.height)
        let scale = longest > Self.maxSide ? Self.maxSide / longest : 1
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        // Drawing applies the image's orientation, so the stored JPEG is upright.
        let redrawn = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let data = redrawn.jpegData(compressionQuality: 0.85) else { throw CocoaError(.fileWriteUnknown) }
        try FileManager.default.createDirectory(at: pending.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: pending, options: .atomic)
        return pending
    }

    func importPending(data: Data) throws -> URL {
        guard let image = UIImage(data: data) else { throw PhotoError.unreadable }
        return try importPending(image)
    }

    /// Copies the pending photo into permanent storage and returns its file name, or nil if there was none. The pending
    /// file is removed afterwards unless `keepPending` is set (used when several entries share one photo).
    func commitPending(_ pendingPath: String?, keepPending: Bool = false) throws -> String? {
        guard let pendingPath, FileManager.default.fileExists(atPath: pendingPath) else { return nil }
        try FileManager.default.createDirectory(at: photos, withIntermediateDirectories: true)
        let name = "\(UUID().uuidString).jpg"
        try FileManager.default.copyItem(at: URL(fileURLWithPath: pendingPath), to: url(for: name))
        if !keepPending { try? FileManager.default.removeItem(atPath: pendingPath) }
        return name
    }

    /// Removes a pending photo that was not used.
    func discardPending(_ path: String?) {
        if let path { try? FileManager.default.removeItem(atPath: path) }
    }

    func delete(_ name: String?) {
        if let name { try? FileManager.default.removeItem(at: url(for: name)) }
    }

    /// The photo decoded at a size of about `maxPixel` on its longer side, without loading the full image.
    func load(_ name: String, maxPixel: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url(for: name) as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary).map { UIImage(cgImage: $0) }
    }
}

enum PhotoError: Error {
    case unreadable
}
