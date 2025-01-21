import SwiftUI
import AppKit

class WindowManager {
    static let shared = WindowManager()
    private var windowControllers: [NSWindowController] = []
    
    func openDataGeneratorWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Send Data"
        window.contentView = NSHostingView(rootView: DataGeneratorView())
        window.center()
        
        let windowController = NSWindowController(window: window)
        windowControllers.append(windowController)
        
        window.delegate = WindowDelegate(manager: self, windowController: windowController)
        windowController.showWindow(nil)
    }
    
    func removeWindowController(_ windowController: NSWindowController) {
        windowControllers.removeAll { $0 === windowController }
    }
}

class WindowDelegate: NSObject, NSWindowDelegate {
    private let manager: WindowManager
    private let windowController: NSWindowController
    
    init(manager: WindowManager, windowController: NSWindowController) {
        self.manager = manager
        self.windowController = windowController
        super.init()
    }
    
    func windowWillClose(_ notification: Notification) {
        manager.removeWindowController(windowController)
    }
} 