import AppKit

class ImageCacheManager {
    static let shared = ImageCacheManager()
    private var cache: [String: NSImage] = [:]
    private let cacheQueue = DispatchQueue(label: "image.cache", attributes: .concurrent)
    
    private init() {}
    
    func getImage(for key: String) -> NSImage? {
        return cacheQueue.sync {
            return cache[key]
        }
    }
    
    func setImage(_ image: NSImage, for key: String) {
        cacheQueue.async(flags: .barrier) {
            self.cache[key] = image
        }
    }
    
    // Async loading function to prevent main thread blocking
    func loadImageAsync(from path: String, completion: @escaping (NSImage?) -> Void) {
        // Check cache first on concurrent queue
        cacheQueue.async {
            if let cachedImage = self.cache[path] {
                DispatchQueue.main.async {
                    completion(cachedImage)
                }
                return
            }
            
            // Load image on background queue
            DispatchQueue.global(qos: .userInitiated).async {
                let image = NSImage(contentsOfFile: path)
                
                // Cache the image
                if let image = image {
                    self.cacheQueue.async(flags: .barrier) {
                        self.cache[path] = image
                    }
                }
                
                // Return on main queue
                DispatchQueue.main.async {
                    completion(image)
                }
            }
        }
    }
    
    func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
}
