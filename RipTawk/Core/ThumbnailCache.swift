import UIKit

final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private init() {}
    
    private var cache: [String: UIImage] = [:]
    
    func getImage(for key: String) -> UIImage? {
        return cache[key]
    }
    
    func setImage(_ image: UIImage, for key: String) {
        cache[key] = image
    }
} 