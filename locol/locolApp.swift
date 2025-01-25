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
import Observation

@Observable
final class AppTerminationHandler {
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
    let collectorManager: CollectorManager
    let terminationHandler: AppTerminationHandler
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        Group {
            if collectorManager.collectors.isEmpty {
                Text("No collectors configured")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(collectorManager.collectors) { collector in
                    Label {
                        Text(collector.name)
                    } icon: {
                        Image(systemName: collector.isRunning ? "circle.fill" : "circle")
                            .foregroundStyle(collector.isRunning ? .green : .secondary)
                    }
                }
            }
            
            Divider()
            
            Button("Show Dashboard") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: "MainWindow")
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
    @State private var collectorManager = CollectorManager()
    @State private var dataGeneratorManager = DataGeneratorManager()
    @State private var terminationHandler = AppTerminationHandler()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup(id: "MainWindow") {
            MainDashboardView(
                collectorManager: collectorManager,
                dataGeneratorManager: dataGeneratorManager,
                terminationHandler: terminationHandler
            )
        }
        .windowStyle(.hiddenTitleBar)
        
        MenuBarExtra {
            MenuBarView(
                collectorManager: collectorManager,
                terminationHandler: terminationHandler
            )
        } label: {
            Image(systemName: "circle.hexagongrid.fill")
        }
        
        Window("Config Editor", id: "ConfigEditorWindow") {
            ConfigEditorView(manager: collectorManager, collectorId: nil)
        }
        
        Window("Metrics & Logs", id: "MetricsLogViewerWindow") {
            if let collectorId = NSApplication.shared.keyWindow?.identifier?.rawValue,
               let collector = collectorManager.collectors.first(where: { $0.id.uuidString == collectorId }) {
                MetricsLogView(collector: collector, manager: collectorManager)
            } else {
                Text("No collector selected")
                    .foregroundStyle(.secondary)
            }
        }
        
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
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.configureLogging()
        
        // Open main window on launch
        NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
    }
}
