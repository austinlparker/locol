//
//  locolApp.swift
//  locol
//
//  Created by Austin Parker on 1/12/25.
//

import SwiftUI
import AppKit
import Combine
import os

class AppTerminationHandler: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    private var collectorManager: CollectorManager?
    
    func setup(collectorManager: CollectorManager) {
        self.collectorManager = collectorManager
        
        NSApplication.shared.publisher(for: \.currentEvent)
            .filter { $0?.type == .applicationDefined }
            .sink { [weak self] _ in
                guard let self = self,
                      let manager = self.collectorManager else { return }
                // Stop all collectors before quitting
                for collector in manager.collectors where collector.isRunning {
                    manager.stopCollector(withId: collector.id)
                }
            }
            .store(in: &cancellables)
    }
}

private struct MenuBarView: View {
    @ObservedObject var collectorManager: CollectorManager
    @ObservedObject var terminationHandler: AppTerminationHandler
    @Environment(\.openWindow) private var openWindow
    
    private func activateWindow(withId id: String) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            NSApp.windows.forEach { window in
                if window.identifier?.rawValue == id {
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                }
            }
        }
    }
    
    var body: some View {
        Group {
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
                            NSApplication.shared.activate(ignoringOtherApps: true)
                            openWindow(id: "MetricsLogViewerWindow", value: collector.id)
                            activateWindow(withId: "MetricsLogViewerWindow")
                        }
                        
                        Button("Edit Config") {
                            NSApplication.shared.activate(ignoringOtherApps: true)
                            openWindow(id: "ConfigEditorWindow", value: collector.id)
                            activateWindow(withId: "ConfigEditorWindow")
                        }
                    }
                }
            }
            
            Divider()
            
            Button("Settings...") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: "SettingsWindow")
                activateWindow(withId: "SettingsWindow")
            }
            
            Divider()
            
            Button("Send Data") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: "DataGeneratorWindow")
                activateWindow(withId: "DataGeneratorWindow")
            }

            Divider()
            
            Button("Quit") {
                // Stop all collectors before quitting
                for collector in collectorManager.collectors where collector.isRunning {
                    collectorManager.stopCollector(withId: collector.id)
                }
                NSApplication.shared.terminate(nil)
            }
        }
        .onAppear {
            terminationHandler.setup(collectorManager: collectorManager)
        }
    }
}

@main
struct locolApp: App {
    @StateObject private var collectorManager = CollectorManager()
    @StateObject private var terminationHandler = AppTerminationHandler()
    @StateObject private var dataGeneratorManager = DataGeneratorManager.shared
    @Environment(\.openWindow) private var openWindow
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    private func activateWindow(withId id: String) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            NSApp.windows.forEach { window in
                if window.identifier?.rawValue == id {
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                }
            }
        }
    }
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView(collectorManager: collectorManager, terminationHandler: terminationHandler)
        } label: {
            Image("menubar-icon")
        }
        .menuBarExtraStyle(.menu)
        .commands {
            // Add app menu commands
            CommandGroup(replacing: .appInfo) {
                Button("About locol") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            .applicationName: "locol",
                            .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
                            .credits: NSAttributedString(
                                string: "A local OpenTelemetry Collector manager.",
                                attributes: [
                                    .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
                                ]
                            )
                        ]
                    )
                }
            }
            
            // Add help menu commands
            CommandGroup(replacing: .help) {
                Link("locol Documentation",
                     destination: URL(string: "https://github.com/austinlparker/locol")!)
                
                Divider()
                
                Link("Report an Issue",
                     destination: URL(string: "https://github.com/austinlparker/locol/issues")!)
            }
        }
        
        Window("Settings", id: "SettingsWindow") {
            SettingsView(manager: collectorManager)
                .onAppear {
                    activateWindow(withId: "SettingsWindow")
                }
        }
        .defaultSize(width: 900, height: 600)
        
        WindowGroup("Config Editor", id: "ConfigEditorWindow", for: UUID.self) { $collectorId in
            if let id = collectorId,
               let _ = collectorManager.collectors.first(where: { $0.id == id }) {
                ConfigEditorView(manager: collectorManager, collectorId: id)
                    .onAppear {
                        activateWindow(withId: "ConfigEditorWindow")
                    }
            }
        }
        .defaultSize(width: 800, height: 600)
        
        WindowGroup("Metrics & Logs", id: "MetricsLogViewerWindow", for: UUID.self) { $collectorId in
            if let id = collectorId,
               let collector = collectorManager.collectors.first(where: { $0.id == id }) {
                MetricsLogView(collector: collector, manager: collectorManager)
                    .onAppear {
                        activateWindow(withId: "MetricsLogViewerWindow")
                    }
            }
        }
        .defaultSize(width: 1000, height: 700)
        
        Window("Send Data", id: "DataGeneratorWindow") {
            DataGeneratorView(manager: dataGeneratorManager)
                .onAppear {
                    activateWindow(withId: "DataGeneratorWindow")
                }
        }
        .defaultSize(width: 600, height: 800)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.configureLogging()
    }
}
