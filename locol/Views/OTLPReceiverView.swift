import SwiftUI

@available(macOS 15.0, *)
struct OTLPReceiverView: View {
    @State private var serverStats: ServerStatistics?
    @State private var isRefreshing = false
    private let server = OTLPServer.shared
    private let settings = OTLPReceiverSettings.shared
    private let viewer = TelemetryViewer.shared
    
    var body: some View {
        Form {
            // Status Section
            statusSection
            
            // Receiver Statistics Section
            receiverStatsSection
            
            // Database Statistics Section
            databaseStatsSection
            
            // Collector Filter Section
            collectorFilterSection
        }
        .formStyle(.grouped)
        .navigationTitle("OTLP Receiver")
        .onAppear {
            Task {
                await refreshStats()
                await viewer.refreshCollectorStats()
            }
        }
    }
    
    private var statusSection: some View {
        Section("Server Status") {
            GroupBox {
                VStack(spacing: 16) {
                    // Status indicator
                    HStack {
                        Label(serverStats?.isRunning == true ? "Running" : "Stopped", 
                              systemImage: "circle.fill")
                            .labelStyle(.iconOnly)
                            .foregroundStyle(serverStats?.isRunning == true ? .green : .red)
                        
                        Text(serverStats?.isRunning == true ? "Running" : "Stopped")
                            .font(.headline)
                            .foregroundStyle(serverStats?.isRunning == true ? .green : .red)
                        
                        Spacer()
                        
                        Button(serverStats?.isRunning == true ? "Stop Server" : "Start Server") {
                            Task {
                                if serverStats?.isRunning == true {
                                    await server.stop()
                                } else {
                                    try? await server.start()
                                }
                                await refreshStats()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    // Endpoint information
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("gRPC Endpoint")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(serverStats?.bindAddress ?? "unknown"):\(serverStats?.grpcPort ?? 0)")
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        Spacer()
                        
                        Button("Restart") {
                            Task { 
                                try? await server.restart()
                                await refreshStats()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }
    
    private var receiverStatsSection: some View {
        Section("Receiver Statistics") {
            GroupBox {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Traces Received")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(serverStats?.receivedTraces ?? 0)")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading) {
                            Text("Metrics Received")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(serverStats?.receivedMetrics ?? 0)")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading) {
                            Text("Logs Received")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(serverStats?.receivedLogs ?? 0)")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    HStack {
                        if let startTime = serverStats?.startTime {
                            VStack(alignment: .leading) {
                                Text("Uptime")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(formatUptime(startTime))
                                    .font(.subheadline)
                            }
                            
                            Spacer()
                        }
                        
                        Button("Reset Counters") {
                            Task {
                                await server.resetStatistics()
                                await refreshStats()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }
    
    private var databaseStatsSection: some View {
        Section("Database Statistics") {
            if isRefreshing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading database statistics...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            } else if viewer.collectorStats.isEmpty {
                Text("No telemetry data found")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(viewer.collectorStats, id: \.collectorName) { stats in
                    collectorStatsRow(stats)
                }
                
                // Total summary
                if viewer.collectorStats.count > 1 {
                    Divider()
                    let totalSpans = viewer.collectorStats.reduce(0) { $0 + $1.spanCount }
                    let totalMetrics = viewer.collectorStats.reduce(0) { $0 + $1.metricCount }
                    let totalLogs = viewer.collectorStats.reduce(0) { $0 + $1.logCount }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total (All Collectors)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(totalSpans + totalMetrics + totalLogs) items")
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        Text("Spans: \(totalSpans), Metrics: \(totalMetrics), Logs: \(totalLogs)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                HStack {
                    Spacer()
                    Button("Refresh") {
                        Task {
                            isRefreshing = true
                            await viewer.refreshCollectorStats()
                            isRefreshing = false
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }
    
    private var collectorFilterSection: some View {
        Section("Collector Filter") {
            Picker("Show data for:", selection: Binding(
                get: { viewer.selectedCollector },
                set: { viewer.selectedCollector = $0 }
            )) {
                Text("All Collectors").tag("all")
                ForEach(viewer.collectorStats, id: \.collectorName) { stats in
                    Text(stats.collectorName).tag(stats.collectorName)
                }
            }
            .pickerStyle(.menu)
        }
    }
    
    private func collectorStatsRow(_ stats: CollectorStats) -> some View {
        GroupBox {
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(stats.collectorName)
                            .font(.headline)
                        Text("\(stats.spanCount + stats.metricCount + stats.logCount) total items")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Clear Data") {
                        Task {
                            await viewer.clearCollectorData(stats.collectorName)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                HStack(spacing: 16) {
                    VStack {
                        Text("\(formatCount(stats.spanCount))")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Spans")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack {
                        Text("\(formatCount(stats.metricCount))")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Metrics")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack {
                        Text("\(formatCount(stats.logCount))")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Logs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    private func refreshStats() async {
        serverStats = await server.getStatistics()
    }
    
    private func formatUptime(_ startTime: Date) -> String {
        let uptime = Date().timeIntervalSince(startTime)
        let hours = Int(uptime) / 3600
        let minutes = Int(uptime) % 3600 / 60
        return "\(hours)h \(minutes)m"
    }
    
    private func formatCount(_ count: Int) -> String {
        if count < 1000 {
            return "\(count)"
        } else if count < 1_000_000 {
            return String(format: "%.1fK", Double(count) / 1000)
        } else {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        }
    }
}