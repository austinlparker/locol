//
//  locolApp.swift
//  locol
//
//  Created by Austin Parker on 1/12/25.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var collectorManager: CollectorManager?
    
    func applicationWillTerminate(_ notification: Notification) {
        // Stop all running collectors and wait for them to terminate
        if let manager = collectorManager {
            let group = DispatchGroup()
            
            for collector in manager.collectors where collector.isRunning {
                group.enter()
                manager.stopCollector(withId: collector.id)
                // Give each collector a moment to stop
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                    // Force kill if still running
                    if manager.isCollectorRunning(withId: collector.id) {
                        CollectorLogger.shared.debug("Force killing collector: \(collector.name)")
                        if let process = manager.processManager.getProcess(forCollector: collector) {
                            kill(process.processIdentifier, SIGKILL)
                        }
                    }
                    group.leave()
                }
            }
            
            // Wait for all collectors to stop with a timeout
            _ = group.wait(timeout: .now() + 2.0)
        }
    }
}

@main
struct locolApp: App {
    @StateObject private var collectorManager = CollectorManager()
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    @State private var selectedCollectorId: UUID? = nil
    @State private var configWindowLevel: WindowLevel = .normal
    @State private var logsWindowLevel: WindowLevel = .normal
    
    // Initialize app delegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Set collector manager reference in app delegate
        let delegate = NSApplication.shared.delegate as? AppDelegate
        delegate?.collectorManager = collectorManager
    }
    
    var body: some Scene {
        MenuBarExtra {
            Button("Settings") {
                if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "SettingsWindow" }) {
                    window.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                } else {
                    openWindow(id: "SettingsWindow")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            let image: NSImage = {
                let ratio = $0.size.height / $0.size.width
                $0.size.height = 18
                $0.size.width = 18 / ratio
                return $0
            }(NSImage(named: "opentelemetry-icon-white")!)
            
            Image(nsImage: image)
                .foregroundStyle(.primary)
        }
        
        Window("Settings", id: "SettingsWindow") {
            SettingsView(manager: collectorManager)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 800, height: 400)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .commandsRemoved()
        
        // Only show config editor when a collector is selected
        WindowGroup("Configuration", id: "ConfigEditorWindow", for: UUID.self) { $collectorId in
            if let id = collectorId {
                ConfigEditorView(manager: collectorManager, collectorId: id)
                    .onAppear {
                        configWindowLevel = .floating
                        // Reset window level after a delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            configWindowLevel = .normal
                        }
                    }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 800, height: 600)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .windowLevel(configWindowLevel)
        
        // Log viewer window
        WindowGroup("Logs", id: "LogViewerWindow", for: UUID.self) { $collectorId in
            if let id = collectorId,
               let collector = collectorManager.collectors.first(where: { $0.id == id }) {
                LogViewer(collector: collector)
                    .onAppear {
                        logsWindowLevel = .floating
                        // Reset window level after a delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            logsWindowLevel = .normal
                        }
                    }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 800, height: 400)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .windowLevel(logsWindowLevel)
    }
}
