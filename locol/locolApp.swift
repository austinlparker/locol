//
//  locolApp.swift
//  locol
//
//  Created by Austin Parker on 1/12/25.
//

import SwiftUI
import os

@main
struct locolApp: App {
    @State private var container = AppContainer()
    @Environment(\.openWindow) private var openWindow
    
    // Computed property for collector manager
    private var collectorManager: CollectorManager {
        container.collectorManager
    }
    
    var body: some Scene {
        WindowGroup("OpenTelemetry Collector Manager") {
            MainAppView()
                .environment(container)
            .task {
                Logger.app.notice("Application launched successfully")
                
                Task {
                    // Auto-start the OTLP server if configured
                    await container.server.autoStartIfEnabled()
                    Logger.app.notice("OTLP server initialization completed")
                    
                    // Initialize telemetry viewer stats
                    await container.viewer.refreshCollectorStats()
                    Logger.app.notice("Telemetry viewer initialized")
                }
            }
            .onDisappear {
                // Clean up when app terminates - SwiftUI will handle the lifecycle
                Task {
                    await container.server.stopOnAppTermination()
                    await container.collectorManager.cleanupOnTermination()
                    Logger.app.notice("Application shutdown completed")
                }
            }
        }
        .windowToolbarStyle(.automatic)
        .commands {
            // Add app menu commands
            CommandGroup(replacing: .appInfo) {
                Button("About locol") {
                    openWindow(id: "AboutWindow")
                }
            }
            
            // Add settings menu command
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    openWindow(id: "SettingsWindow")
                }
                .keyboardShortcut(",", modifiers: .command)
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
        
        // Custom SwiftUI About window
        Window("About locol", id: "AboutWindow") {
            VStack(spacing: 20) {
                Image("menubar-icon")
                    .resizable()
                    .frame(width: 128, height: 128)
                    .padding(.top, 20)
                
                Text("locol")
                    .font(.largeTitle)
                    .bold()
                
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")")
                    .font(.subheadline)
                
                Text("A local OpenTelemetry Collector manager.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                HStack {
                    Spacer()
                    Button("OK") {
                        // SwiftUI will handle window dismissal automatically
                    }
                    .keyboardShortcut(.defaultAction)
                    Spacer()
                }
                .padding(.bottom, 20)
            }
            .frame(width: 400, height: 350)
        }
        .defaultSize(width: 400, height: 350)
        
        // Settings window
        Window("Settings", id: "SettingsWindow") {
            AppSettingsView()
                .environment(container)
                .frame(width: 500, height: 400)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 500, height: 400)
    }
}
