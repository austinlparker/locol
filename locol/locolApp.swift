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



// SwiftUI logging setup view modifier
struct LogSetupViewModifier: ViewModifier {
    @State private var didSetupLogging = false
    
    func body(content: Content) -> some View {
        content.onAppear {
            if !didSetupLogging {
                Logger.configureLogging()
                didSetupLogging = true
            }
        }
    }
}

extension View {
    func setupLogging() -> some View {
        self.modifier(LogSetupViewModifier())
    }
}

@main
struct locolApp: App {
    @State private var collectorManager = CollectorManager()
    @State private var dataGeneratorManager = DataGeneratorManager.shared
    @Environment(\.openWindow) private var openWindow
    
    var body: some Scene {
        WindowGroup("OpenTelemetry Collector Manager") {
            MainAppView(
                collectorManager: collectorManager,
                dataGeneratorManager: dataGeneratorManager
            )
            .setupLogging() // Initialize logging when app launches
            .task {
                // Start OTLP receiver when app launches
                //try await otlpReceiver.start()
                Logger.app.info("OTLP receiver started successfully")
                
                // Initialize telemetry database maintenance
                if #available(macOS 15.0, *) {
                    TelemetryDatabase.shared.startPeriodicMaintenance(intervalHours: 24)
                    Logger.app.info("Started telemetry database maintenance")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                // Clean up database connections on app termination
                if #available(macOS 15.0, *) {
                    TelemetryDatabase.shared.closeAllConnections()
                    Logger.app.info("Closed telemetry database connections")
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
            if #available(macOS 15.0, *) {
                AppSettingsView()
                    .frame(width: 500, height: 400)
            } else {
                VStack {
                    Text("Settings")
                        .font(.title2)
                    Text("Advanced settings require macOS 15.0 or newer")
                        .foregroundStyle(.secondary)
                }
                .frame(width: 500, height: 400)
            }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 500, height: 400)
    }
}

