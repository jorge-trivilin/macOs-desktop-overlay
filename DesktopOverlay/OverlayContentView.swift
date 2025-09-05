import SwiftUI
import AppKit

struct OverlayContentView: View {
    @State private var wallpaperImage: NSImage?
    @State private var isLoading = false
    let selectedWallpaper: String
    let customImagePath: String?
    
    // Updated initializer to handle custom images
    init(selectedWallpaper: String = "Monterey Graphic", customImagePath: String? = nil) {
        self.selectedWallpaper = selectedWallpaper
        self.customImagePath = customImagePath
    }
    
    var body: some View {
        ZStack {
            if let wallpaperImage = wallpaperImage {
                Image(nsImage: wallpaperImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                // Show loading state or fallback
                if isLoading {
                    Color.gray.opacity(0.2)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.5)
                        )
                } else {
                    Color.gray.opacity(0.3)
                }
            }
            
            // Optional: Slight overlay to differentiate from actual wallpaper
            Color.black.opacity(0.05)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadWallpaperAsync()
        }
        .onChange(of: selectedWallpaper) { _ in
            loadWallpaperAsync()
        }
        .onChange(of: customImagePath) { _ in
            loadWallpaperAsync()
        }
    }
    
    // FIXED: Completely async image loading to prevent ALL main thread blocking
    private func loadWallpaperAsync() {
        isLoading = true
        wallpaperImage = nil
        
        // Use Task with detached priority to ensure background execution
        Task.detached(priority: .background) {
            let image = await loadImageInBackground()
            
            // Update UI on main thread
            await MainActor.run {
                self.wallpaperImage = image
                self.isLoading = false
            }
        }
    }
    
    // FIXED: All image operations moved to background with proper async/await
    private func loadImageInBackground() async -> NSImage? {
        return await withCheckedContinuation { continuation in
            // Use global background queue with QoS
            DispatchQueue.global(qos: .background).async {
                let image = self.loadWallpaperSync()
                continuation.resume(returning: image)
            }
        }
    }
    
    // FIXED: This now runs entirely on background thread with proper error handling
    private func loadWallpaperSync() -> NSImage? {
        // First try custom image if available
        if let customPath = customImagePath {
            return loadImageFromPath(customPath)
        }
        
        // Fallback to system wallpaper
        return getSystemWallpaper(named: selectedWallpaper)
    }
    
    // FIXED: Enhanced error handling and async file loading
    private func loadImageFromPath(_ path: String) -> NSImage? {
        // Check if file exists first (fast operation)
        guard FileManager.default.fileExists(atPath: path) else {
            print("⚠️ Image file not found at path: \(path)")
            return nil
        }
        
        // This is the operation that was causing main thread blocking
        // Now running on background thread
        let image = NSImage(contentsOfFile: path)
        
        if image == nil {
            print("⚠️ Failed to load image from path: \(path)")
        }
        
        return image
    }
    
    private func getSystemWallpaper(named: String) -> NSImage? {
        // Map wallpaper names to file paths
        let wallpaperPaths: [String: String] = [
            "Monterey Graphic": "/System/Library/Desktop Pictures/Monterey Graphic.heic",
            "Big Sur Graphic": "/System/Library/Desktop Pictures/Big Sur Graphic.heic",
            "Catalina": "/System/Library/Desktop Pictures/Catalina.heic",
            "Mojave": "/System/Library/Desktop Pictures/Mojave.heic",
            "High Sierra": "/System/Library/Desktop Pictures/High Sierra.jpg",
            "Sierra": "/System/Library/Desktop Pictures/Sierra.jpg",
            "El Capitan": "/System/Library/Desktop Pictures/El Capitan.jpg",
            "Yosemite": "/System/Library/Desktop Pictures/Yosemite.jpg",
            "Mavericks": "/System/Library/Desktop Pictures/Mavericks.jpg"
        ]
        
        if let path = wallpaperPaths[named] {
            return loadImageFromPath(path)
        }
        
        // Fallback: try all paths if specific one not found
        for path in wallpaperPaths.values {
            if let image = loadImageFromPath(path) {
                return image
            }
        }
        
        print("⚠️ No wallpaper found for: \(named)")
        return nil
    }
}

struct OverlayContentView_Previews: PreviewProvider {
    static var previews: some View {
        OverlayContentView()
    }
}
