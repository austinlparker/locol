import SwiftUI

struct AppSettingsView: View {
    @State private var settings = OTLPReceiverSettings.shared
    @State private var serverStats: ServerStatistics?
    private let server = OTLPServer.shared
    
    var body: some View {
        TabView {
            OTLPReceiverSettingsView(settings: settings, server: server, serverStats: $serverStats)
                .tabItem {
                    Label("OTLP Receiver", systemImage: "antenna.radiowaves.left.and.right")
                }
        }
        .padding()
        .task {
            serverStats = await server.getStatistics()
        }
    }
}

struct OTLPReceiverSettingsView: View {
    @Bindable var settings: OTLPReceiverSettings
    let server: OTLPServer
    @Binding var serverStats: ServerStatistics?
    
    var body: some View {
        Form {
            // Description Section
            Section {
                Text("Configure the built-in gRPC OTLP receiver to accept telemetry data directly from collectors and applications.")
                    .foregroundStyle(.secondary)
                    .font(.body)
            } header: {
                Text("OTLP Receiver Settings")
                    .font(.title2)
                    .bold()
            }
            
            // Server Status
            Section("Status") {
                GroupBox {
                    HStack {
                        let isRunning = serverStats?.isRunning ?? false
                        Label(isRunning ? "Running" : "Stopped", 
                              systemImage: "circle.fill")
                            .labelStyle(.iconOnly)
                            .foregroundStyle(isRunning ? .green : .red)
                        
                        Text(isRunning ? "Running" : "Stopped")
                            .font(.headline)
                            .foregroundStyle(isRunning ? .green : .red)
                        
                        Spacer()
                        
                        Button(isRunning ? "Stop Server" : "Start Server") {
                            Task {
                                do {
                                    if isRunning {
                                        await server.stop()
                                    } else {
                                        try await server.start()
                                    }
                                    serverStats = await server.getStatistics()
                                } catch {
                                    // Handle server start error - could show an alert
                                    print("Server operation failed: \(error)")
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(isRunning ? .red : .green)
                    }
                }
            }
            
            // Server Configuration
            Section("Network Settings") {
                LabeledContent("Bind Address") {
                    TextField("127.0.0.1", text: $settings.bindAddress)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                }
            }
            
            Section("gRPC Configuration") {
                LabeledContent("gRPC Port") {
                    TextField("14317", value: $settings.grpcPort, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 100)
                }
                
                LabeledContent("gRPC Endpoint", value: settings.grpcEndpoint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("All OTLP signals (traces, metrics, logs) use the same gRPC port with different service methods.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Signal Configuration") {
                Toggle("Enable Traces Receiver", isOn: $settings.tracesEnabled)
                Toggle("Enable Metrics Receiver", isOn: $settings.metricsEnabled)
                Toggle("Enable Logs Receiver", isOn: $settings.logsEnabled)
            }
            
            Section("Statistics") {
                LabeledContent("Traces Received", value: "\(serverStats?.receivedTraces ?? 0)")
                    .font(.system(.body, design: .monospaced))
                
                LabeledContent("Metrics Received", value: "\(serverStats?.receivedMetrics ?? 0)")
                    .font(.system(.body, design: .monospaced))
                
                LabeledContent("Logs Received", value: "\(serverStats?.receivedLogs ?? 0)")
                    .font(.system(.body, design: .monospaced))
            }
        }
        .formStyle(.grouped)
        .navigationTitle("OTLP Receiver Settings")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button("Reset to Defaults") {
                    settings.grpcPort = 14317
                    settings.bindAddress = "localhost"
                    settings.tracesEnabled = true
                    settings.metricsEnabled = true
                    settings.logsEnabled = true
                }
                .buttonStyle(.bordered)
                
                Button("Save Settings") {
                    // Settings are automatically saved via didSet
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview {
    AppSettingsView()
        .frame(width: 500, height: 400)
}