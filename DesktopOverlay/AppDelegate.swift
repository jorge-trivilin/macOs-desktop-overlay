import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayWindows: [NSWindow] = []
    var statusItem: NSStatusItem?
    
    @Published var selectedWallpaper = "Monterey Graphic"
    @Published var customImagePath: String?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🛠️ AppDelegate applicationDidFinishLaunching called")
        
        let runningApps = NSWorkspace.shared.runningApplications
        let currentApp = Bundle.main.bundleIdentifier
        
        let otherInstances = runningApps.filter { app in
            app.bundleIdentifier == currentApp && app.processIdentifier != NSRunningApplication.current.processIdentifier
        }
        
        if !otherInstances.isEmpty {
            print("🛠️ Another instance already running, terminating this one")
            NSApp.terminate(nil)
            return
        }
        
        setupStatusBarItem()
        createOverlayWindows()
        
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func setupStatusBarItem() {
        print("🛠️ Creating status bar item")
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "🎨"
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Overlay", action: #selector(toggleOverlay), keyEquivalent: "t"))
        menu.addItem(NSMenuItem.separator())
        
        // Add wallpaper selection submenu
        let wallpaperMenu = NSMenu()
        let wallpaperMenuItem = NSMenuItem(title: "Choose Wallpaper", action: nil, keyEquivalent: "")
        wallpaperMenuItem.submenu = wallpaperMenu
        
        let wallpapers = [
            "Monterey Graphic",
            "Big Sur Graphic",
            "Catalina",
            "Mojave",
            "High Sierra",
            "Sierra",
            "El Capitan",
            "Yosemite",
            "Mavericks"
        ]
        
        for wallpaper in wallpapers {
            let item = NSMenuItem(title: wallpaper, action: #selector(selectWallpaper(_:)), keyEquivalent: "")
            item.representedObject = wallpaper
            item.target = self  // Set target explicitly
            // Add checkmark for currently selected wallpaper
            if wallpaper == selectedWallpaper {
                item.state = .on
            }
            wallpaperMenu.addItem(item)
        }
        
        wallpaperMenu.addItem(NSMenuItem.separator())
        
        // Add custom image option
        let customImageItem = NSMenuItem(title: "Choose Custom Image...", action: #selector(selectCustomImage), keyEquivalent: "")
        customImageItem.target = self  // CRITICAL: Set target explicitly
        wallpaperMenu.addItem(customImageItem)
        
        // Add current custom image if one is selected
        if let customPath = customImagePath {
            let currentCustomItem = NSMenuItem(title: "✓ \(URL(fileURLWithPath: customPath).lastPathComponent)", action: nil, keyEquivalent: "")
            wallpaperMenu.addItem(currentCustomItem)
        }
        
        menu.addItem(wallpaperMenuItem)
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self  // CRITICAL: Set target explicitly
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func selectCustomImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        panel.title = "Choose Wallpaper Image"
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                customImagePath = url.path
                selectedWallpaper = "Custom"
                refreshOverlays()
                updateMenuCheckmarks()
            }
        }
    }
    
    @objc private func selectWallpaper(_ sender: NSMenuItem) {
        if let wallpaperName = sender.representedObject as? String {
            selectedWallpaper = wallpaperName
            customImagePath = nil // Clear custom image when selecting system wallpaper
            refreshOverlays()
            updateMenuCheckmarks()
        }
    }
    
    private func updateMenuCheckmarks() {
        guard let menu = statusItem?.menu,
              let wallpaperMenuItem = menu.item(withTitle: "Choose Wallpaper"),
              let wallpaperSubmenu = wallpaperMenuItem.submenu else { return }
        
        // Clear all checkmarks
        for item in wallpaperSubmenu.items {
            item.state = .off
        }
        
        // Set checkmark for selected wallpaper
        if let selectedItem = wallpaperSubmenu.items.first(where: { $0.representedObject as? String == selectedWallpaper }) {
            selectedItem.state = .on
        }
    }
    
    private func refreshOverlays() {
        hideOverlays()
        createOverlayWindows()
    }
    
    @objc private func toggleOverlay() {
        if overlayWindows.first?.isVisible == true {
            hideOverlays()
        } else {
            showOverlays()
        }
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private func createOverlayWindows() {
        overlayWindows.removeAll()
        
        for screen in NSScreen.screens {
            let screenRect = screen.frame
            
            let overlayWindow = NSWindow(
                contentRect: screenRect,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            
            overlayWindow.isOpaque = false
            overlayWindow.backgroundColor = .clear
            overlayWindow.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
            overlayWindow.ignoresMouseEvents = true
            overlayWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            overlayWindow.sharingType = .none
            
            // Pass selected wallpaper and custom path to the view
            let contentView = OverlayContentView(
                selectedWallpaper: selectedWallpaper,
                customImagePath: customImagePath
            )
            overlayWindow.contentView = NSHostingView(rootView: contentView)
            
            overlayWindows.append(overlayWindow)
        }
        
        showOverlays()
    }
    
    private func showOverlays() {
        for window in overlayWindows {
            window.orderBack(nil)
        }
    }
    
    private func hideOverlays() {
        for window in overlayWindows {
            window.orderOut(nil)
        }
    }
    
    // Clean up on termination
    func applicationWillTerminate(_ notification: Notification) {
        hideOverlays()
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }
}
