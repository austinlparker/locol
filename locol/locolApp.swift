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

@main
struct locolApp: App {
    @State private var collectorManager = CollectorManager()
    @Environment(\.openWindow) private var openWindow
    
    var body: some Scene {
        WindowGroup("OpenTelemetry Collector Manager") {
            MainAppView(
                collectorManager: collectorManager
            )
            .task {
                Logger.app.notice("Application launched successfully")
                
                // Initialize telemetry infrastructure
                _ = TelemetryStorage.shared
                _ = TelemetryViewer.shared
                _ = OTLPServer.shared
                
                Task {
                    // Auto-start the OTLP server if configured
                    await OTLPServer.shared.autoStartIfEnabled()
                    Logger.app.notice("OTLP server initialization completed")
                    
                    // Initialize telemetry viewer stats
                    await TelemetryViewer.shared.refreshCollectorStats()
                    Logger.app.notice("Telemetry viewer initialized")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                // Clean up on app termination
                Task {
                    await OTLPServer.shared.stopOnAppTermination()
                    Logger.app.notice("Application shutdown completed")
                }
            }
        }
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
                        // Use SwiftUI's environment for window dismissal
                        guard let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "AboutWindow" }) else { return }
                        window.close()
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
                .frame(width: 500, height: 400)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 500, height: 400)
    }
}

