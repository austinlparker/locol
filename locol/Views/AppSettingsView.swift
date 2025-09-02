import SwiftUI

@available(macOS 15.0, *)
struct AppSettingsView: View {
    @State private var settings = OTLPReceiverSettings.shared
    @State private var otlpReceiver: OTLPGRPCReceiver? = {
        if #available(macOS 15.0, *) {
            return OTLPGRPCReceiver.shared
        } else {
            return nil
        }
    }()
    
    var body: some View {
        TabView {
            OTLPReceiverSettingsView(settings: settings, receiver: otlpReceiver)
                .tabItem {
                    Label("OTLP Receiver", systemImage: "antenna.radiowaves.left.and.right")
                }
        }
        .padding()
    }
}

@available(macOS 15.0, *)
struct OTLPReceiverSettingsView: View {
    @Bindable var settings: OTLPReceiverSettings
    var receiver: OTLPGRPCReceiver?
    
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
                        Label((receiver?.isRunning ?? false) ? "Running" : "Stopped", 
                              systemImage: "circle.fill")
                            .labelStyle(.iconOnly)
                            .foregroundStyle((receiver?.isRunning ?? false) ? .green : .red)
                        
                        Text((receiver?.isRunning ?? false) ? "Running" : "Stopped")
                            .font(.headline)
                            .foregroundStyle((receiver?.isRunning ?? false) ? .green : .red)
                        
                        Spacer()
                        
                        if #available(macOS 15.0, *), let receiver = receiver {
                            Button(receiver.isRunning ? "Stop Receiver" : "Restart Receiver") {
                                Task {
                                    await receiver.restart()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(receiver.isRunning ? .red : .green)
                        } else {
                            Text("Requires macOS 15.0+")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
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
                LabeledContent("Traces Received", value: "\(receiver?.receivedTracesCount ?? 0)")
                    .font(.system(.body, design: .monospaced))
                
                LabeledContent("Metrics Received", value: "\(receiver?.receivedMetricsCount ?? 0)")
                    .font(.system(.body, design: .monospaced))
                
                LabeledContent("Logs Received", value: "\(receiver?.receivedLogsCount ?? 0)")
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
                    settings.saveToUserDefaults()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview {
    if #available(macOS 15.0, *) {
        AppSettingsView()
            .frame(width: 500, height: 400)
    } else {
        Text("Requires macOS 15.0+")
    }
}