import SwiftUI

@available(macOS 15.0, *)
struct OTLPReceiverView: View {
    @State private var isRefreshing = false
    private let server: OTLPServerProtocol
    private let settings: OTLPReceiverSettings
    private let viewer: TelemetryViewer
    @State private var stats: ServerStatistics?
    
    init(server: OTLPServerProtocol, settings: OTLPReceiverSettings, viewer: TelemetryViewer) {
        self.server = server
        self.settings = settings
        self.viewer = viewer
    }
    
    // Timer for live updates
    @State private var refreshTimer: Timer?
    
    var body: some View {
        Form {
            // Live Data Flow Section
            liveDataSection
            
            // Server Info Section  
            serverInfoSection
            
            // Database Statistics Section
            databaseStatsSection
            
            // Collector Filter Section
            collectorFilterSection
        }
        .formStyle(.grouped)
        .navigationTitle("OTLP Live Tap")
        .onAppear {
            startLiveUpdates()
        }
        .onDisappear {
            stopLiveUpdates()
        }
    }
    
    private var liveDataSection: some View {
        Section("Live Telemetry Flow") {
            GroupBox {
                VStack(spacing: 16) {
                    // Live status indicator
                    HStack {
                        Label("Live", systemImage: "dot.radiowaves.left.and.right")
                            .labelStyle(.iconOnly)
                            .foregroundStyle((stats?.isRunning ?? false) ? .green : .red)
                            .symbolEffect(.pulse, options: .repeating, value: stats?.isRunning ?? false)
                        
                        Text((stats?.isRunning ?? false) ? "Receiving Data" : "Offline")
                            .font(.headline)
                            .foregroundStyle((stats?.isRunning ?? false) ? .green : .red)
                        
                        Spacer()
                        
                        if let startTime = stats?.startTime {
                            Text("Uptime: \(formatUptime(startTime))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Live counters with rate information
                    HStack(spacing: 24) {
                        LiveCounter(
                            title: "Traces",
                            count: stats?.receivedTraces ?? 0,
                            icon: "point.3.connected.trianglepath.dotted",
                            color: .blue
                        )
                        
                        LiveCounter(
                            title: "Metrics", 
                            count: stats?.receivedMetrics ?? 0,
                            icon: "chart.line.uptrend.xyaxis",
                            color: .orange
                        )
                        
                        LiveCounter(
                            title: "Logs",
                            count: stats?.receivedLogs ?? 0, 
                            icon: "text.alignleft",
                            color: .green
                        )
                    }
                }
            }
        }
    }
    
    private var serverInfoSection: some View {
        Section("Server Information") {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("gRPC Endpoint")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(settings.bindAddress):\(settings.grpcPort)")
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    HStack {
                        Text("Protocol")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("OpenTelemetry Protocol (OTLP)")
                            .font(.body)
                    }
                    
                    HStack {
                        Button("Reset Counters") {
                            Task {
                                await server.resetStatistics()
                                stats = await server.getStatistics()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Spacer()
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
    
    // Live update methods
    private func startLiveUpdates() {
        // Initial load
        Task {
            stats = await server.getStatistics()
            await viewer.refreshCollectorStats()
        }
        
        // Start periodic updates every 2 seconds
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                stats = await server.getStatistics()
                await viewer.refreshCollectorStats()
            }
        }
    }
    
    private func stopLiveUpdates() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// Live Counter Component
struct LiveCounter: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption)
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(formatCount(count))
                .font(.title2)
                .fontWeight(.semibold)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
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
