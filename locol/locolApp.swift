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
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    
    var body: some Scene {
        MenuBarExtra("OpenTelemetry Collector", systemImage: "wave.3.up") {
            Button("Config") {
                openWindow(id: "ConfigEditorWindow")
            }
            Button("Settings") {
                openWindow(id: "SettingsWindow")
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        
        Window("Configuration", id: "ConfigEditorWindow") {
            ConfigEditorView(manager: collectorManager)
        }
        Window("Settings", id: "SettingsWindow") {
            SettingsView(manager: collectorManager)
        }
    }
}
