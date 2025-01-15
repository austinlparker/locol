//
//  locolApp.swift
//  locol
//
//  Created by Austin Parker on 1/12/25.
//

import SwiftUI

@main
struct locolApp: App {
    @StateObject private var collectorManager = CollectorManager()
    @Environment(\.openWindow) private var openWindow
    
    var body: some Scene {
        MenuBarExtra {
            if collectorManager.collectors.isEmpty {
                Text("No collectors configured")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(collectorManager.collectors) { collector in
                    Menu(collector.name) {
                        Button(collector.isRunning ? "Stop" : "Start") {
                            if collector.isRunning {
                                collectorManager.stopCollector(withId: collector.id)
                            } else {
                                collectorManager.startCollector(withId: collector.id)
                            }
                        }
                        
                        Button("View Metrics") {
                            openWindow(id: "ConfigEditorWindow", value: collector.id)
                        }
                        
                        Button("View Logs") {
                            openWindow(id: "LogViewerWindow", value: collector.id)
                        }
                    }
                }
            }
            
            Divider()
            
            Button("Settings...") {
                openWindow(id: "SettingsWindow")
            }
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image("menubar-icon")
        }
        .menuBarExtraStyle(.menu)
        
        Window("Settings", id: "SettingsWindow") {
            SettingsView(manager: collectorManager)
        }
        
        WindowGroup("Config Editor", id: "ConfigEditorWindow", for: UUID.self) { $collectorId in
            if let id = collectorId,
               let collector = collectorManager.collectors.first(where: { $0.id == id }) {
                ConfigEditorView(manager: collectorManager, collectorId: id)
            }
        }
        .defaultSize(width: 800, height: 600)
        
        WindowGroup("Log Viewer", id: "LogViewerWindow", for: UUID.self) { $collectorId in
            if let id = collectorId,
               let collector = collectorManager.collectors.first(where: { $0.id == id }) {
                LogViewer(collector: collector)
            }
        }
        .defaultSize(width: 800, height: 600)
    }
}
