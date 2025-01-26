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
    private var appState: AppState?
    
    func setup(appState: AppState) {
        self.appState = appState
        
        NSApplication.shared.publisher(for: \.currentEvent)
            .filter { $0?.type == .applicationDefined }
            .sink { [weak self] _ in
                guard let self = self,
                      let appState = self.appState else { return }
                // Stop all collectors before quitting
                for collector in appState.collectors where collector.isRunning {
                    appState.stopCollector(withId: collector.id)
                }
            }
            .store(in: &cancellables)
    }
}

private struct MenuBarView: View {
    let appState: AppState
    let terminationHandler: AppTerminationHandler
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        Group {
            if appState.collectors.isEmpty {
                Text("No collectors configured")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appState.collectors) { collector in
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
                for collector in appState.collectors where collector.isRunning {
                    appState.stopCollector(withId: collector.id)
                }
                NSApplication.shared.terminate(nil)
            }
        }
        .onAppear {
            terminationHandler.setup(appState: appState)
        }
    }
}

// MARK: - Scenes
struct MainScene: Scene {
    let appState: AppState
    let dataGeneratorManager: DataGeneratorManager
    let terminationHandler: AppTerminationHandler
    
    var body: some Scene {
        WindowGroup(id: "MainWindow") {
            MainDashboardView(
                appState: appState,
                dataGeneratorManager: dataGeneratorManager,
                terminationHandler: terminationHandler
            )
        }
        .windowStyle(.hiddenTitleBar)
    }
}

struct MenuBarScene: Scene {
    let appState: AppState
    let terminationHandler: AppTerminationHandler
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                appState: appState,
                terminationHandler: terminationHandler
            )
        } label: {
            Image(systemName: "circle.hexagongrid.fill")
        }
    }
}

struct ConfigEditorScene: Scene {
    let appState: AppState
    
    var body: some Scene {
        WindowGroup("Config Editor", id: "ConfigEditorWindow", for: String.self) { collectorId in
            ConfigEditorWindowContent(appState: appState, collectorId: collectorId)
        }
    }
}

@main
struct locolApp: App {
    @State private var appState = AppState()
    @State private var dataGeneratorManager = DataGeneratorManager()
    @State private var terminationHandler = AppTerminationHandler()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MainScene(
            appState: appState,
            dataGeneratorManager: dataGeneratorManager,
            terminationHandler: terminationHandler
        )
        
        MenuBarScene(
            appState: appState,
            terminationHandler: terminationHandler
        )
        
        ConfigEditorScene(appState: appState)
        
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

// MARK: - Window Content Views
private struct ConfigEditorWindowContent: View {
    let appState: AppState
    @Binding var collectorId: String?
    
    var body: some View {
        if let collectorId = collectorId,
           let collector = appState.collectors.first(where: { $0.id.uuidString == collectorId }) {
            ConfigEditorView(appState: appState, collectorId: collector.id)
        } else {
            ConfigEditorView(appState: appState, collectorId: nil)
        }
    }
}
