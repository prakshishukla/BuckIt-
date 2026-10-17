import UIKit

/// Saves challenge photos as JPEGs in Documents/photos and loads them (or bundled "asset:" images) back.
enum PhotoStore {
    static let assetPrefix = "asset:"
    private static let cache = NSCache<NSString, UIImage>()

    private static var directory: URL {
        let dir = URL.documentsDirectory.appending(path: "photos", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func save(_ image: UIImage) -> String? {
        let resized = image.resized(maxDimension: 1600)
        guard let data = resized.jpegData(compressionQuality: 0.82) else { return nil }
        let name = UUID().uuidString + ".jpg"
        do {
            try data.write(to: directory.appending(path: name), options: .atomic)
            cache.setObject(resized, forKey: name as NSString)
            return name
        } catch {
            print("BuckIt: failed to save photo: \(error)")
            return nil
        }
    }

    static func image(_ name: String?) -> UIImage? {
        guard let name else { return nil }
        if name.hasPrefix(assetPrefix) { return UIImage(named: String(name.dropFirst(assetPrefix.count))) }
        if let cached = cache.object(forKey: name as NSString) { return cached }
        guard let image = UIImage(contentsOfFile: directory.appending(path: name).path) else { return nil }
        cache.setObject(image, forKey: name as NSString)
        return image
    }

    static func deleteAll() {
        cache.removeAllObjects()
        try? FileManager.default.removeItem(at: directory)
    }
}

extension UIImage {
    /// Downscales (never upscales) and bakes in orientation.
    func resized(maxDimension: CGFloat) -> UIImage {
        let scale = min(1, maxDimension / max(size.width, size.height))
        let newSize = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
