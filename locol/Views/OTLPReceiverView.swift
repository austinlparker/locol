import SwiftUI

@available(macOS 15.0, *)
struct OTLPReceiverView: View {
    @State private var receiver: OTLPGRPCReceiver? = {
        if #available(macOS 15.0, *) {
            return OTLPGRPCReceiver.shared
        } else {
            return nil
        }
    }()
    @State private var settings = OTLPReceiverSettings.shared
    @State private var databaseStats: [DatabaseStats] = []
    private let telemetryDB = TelemetryDatabase.shared
    
    var body: some View {
        Form {
            // Status Section
            statusSection
            
            // Database Statistics Section
            databaseStatsSection
        }
        .formStyle(.grouped)
        .navigationTitle("OTLP Receiver")
        .onAppear {
            loadDatabaseStats()
        }
    }
    
    private var statusSection: some View {
        Section("Server Status") {
            GroupBox {
                VStack(spacing: 16) {
                    // Status indicator
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
                        }
                    }
                    
                    // Connection details when running
                    if receiver?.isRunning ?? false {
                        VStack(spacing: 8) {
                            LabeledContent("Endpoint", value: settings.grpcEndpoint)
                                .font(.caption)
                            
                            HStack {
                                Text("Enabled Services:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                HStack(spacing: 12) {
                                    if settings.tracesEnabled {
                                        Label("Traces", systemImage: "point.3.connected.trianglepath.dotted")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }
                                    
                                    if settings.metricsEnabled {
                                        Label("Metrics", systemImage: "chart.bar")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                    }
                                    
                                    if settings.logsEnabled {
                                        Label("Logs", systemImage: "text.line.first.and.arrowtriangle.forward")
                                            .font(.caption)
                                            .foregroundStyle(.purple)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
            
            // Statistics
            GroupBox("Received Data") {
                HStack {
                    LabeledContent("Traces", value: "\(receiver?.receivedTracesCount ?? 0)")
                        .foregroundStyle(.blue)
                    
                    Spacer()
                    
                    LabeledContent("Metrics", value: "\(receiver?.receivedMetricsCount ?? 0)")
                        .foregroundStyle(.green)
                    
                    Spacer()
                    
                    LabeledContent("Logs", value: "\(receiver?.receivedLogsCount ?? 0)")
                        .foregroundStyle(.purple)
                }
            }
        }
    }
    
    private var databaseStatsSection: some View {
        Section("Database Statistics") {
            if databaseStats.isEmpty {
                ContentUnavailableView {
                    Label("No Databases Found", systemImage: "cylinder")
                } description: {
                    Text("Collectors will create telemetry databases when they receive OTLP data")
                }
            } else {
                ForEach(databaseStats, id: \.collectorName) { stats in
                    DatabaseStatsCard(stats: stats, telemetryDB: telemetryDB)
                }
            }
        }
    }
    
    private func loadDatabaseStats() {
        Task {
            // Get all available collectors with databases
            let collectorsDir = CollectorFileManager.shared.baseDirectory.appendingPathComponent("collectors")
            
            do {
                let collectorNames = try FileManager.default.contentsOfDirectory(atPath: collectorsDir.path)
                
                var stats: [DatabaseStats] = []
                for collectorName in collectorNames {
                    let dbPath = collectorsDir.appendingPathComponent(collectorName).appendingPathComponent("telemetry.db")
                    if FileManager.default.fileExists(atPath: dbPath.path) {
                        do {
                            let collectorStats = try telemetryDB.getDatabaseStats(for: collectorName)
                            stats.append(collectorStats)
                        } catch {
                            print("Error getting stats for \(collectorName): \(error)")
                        }
                    }
                }
                
                await MainActor.run {
                    databaseStats = stats.sorted(by: { $0.collectorName < $1.collectorName })
                }
            } catch {
                print("Error scanning collectors directory: \(error)")
            }
        }
    }
}

struct DatabaseStatsCard: View {
    let stats: DatabaseStats
    let telemetryDB: TelemetryDatabase
    
    var body: some View {
        GroupBox(stats.collectorName) {
            VStack(spacing: 12) {
                // Database info and actions
                HStack {
                    LabeledContent("Database Size", value: String(format: "%.1f MB", stats.fileSizeMB))
                        .font(.caption)
                    
                    Spacer()
                    
                    Button("Clear Data") {
                        Task {
                            try? telemetryDB.clearData(for: stats.collectorName)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                // Data counts
                HStack {
                    LabeledContent("Spans", value: "\(stats.spanCount)")
                        .foregroundStyle(.blue)
                    
                    Spacer()
                    
                    LabeledContent("Metrics", value: "\(stats.metricCount)")
                        .foregroundStyle(.green)
                    
                    Spacer()
                    
                    LabeledContent("Logs", value: "\(stats.logCount)")
                        .foregroundStyle(.purple)
                }
                
                // Date range
                if let oldestDate = stats.oldestDate, let newestDate = stats.newestDate {
                    LabeledContent("Data Range", 
                        value: "\(DateFormatter.shortDateTime.string(from: oldestDate)) - \(DateFormatter.shortDateTime.string(from: newestDate))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}



#Preview {
    if #available(macOS 15.0, *) {
        OTLPReceiverView()
    } else {
        Text("Requires macOS 15.0+")
    }
}