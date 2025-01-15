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
                        
                        Button("View Metrics & Logs") {
                            openWindow(id: "MetricsLogViewerWindow", value: collector.id)
                        }
                        
                        Button("Edit Config") {
                            openWindow(id: "ConfigEditorWindow", value: collector.id)
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
        .defaultSize(width: 900, height: 600)
        
        WindowGroup("Config Editor", id: "ConfigEditorWindow", for: UUID.self) { $collectorId in
            if let id = collectorId,
               let collector = collectorManager.collectors.first(where: { $0.id == id }) {
                ConfigEditorView(manager: collectorManager, collectorId: id)
            }
        }
        .defaultSize(width: 800, height: 600)
        
        WindowGroup("Metrics & Logs", id: "MetricsLogViewerWindow", for: UUID.self) { $collectorId in
            if let id = collectorId,
               let collector = collectorManager.collectors.first(where: { $0.id == id }) {
                MetricsLogView(collector: collector, manager: collectorManager)
            }
        }
        .defaultSize(width: 1000, height: 700)
    }
}
