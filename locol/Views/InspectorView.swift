import SwiftUI

struct InspectorView: View {
    let item: SidebarItem?
    @Environment(AppContainer.self) private var container
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch item {
                case .collector(let id):
                    CollectorInspector(collectorId: id)
                    
                case .otlpReceiver:
                    OTLPReceiverInspector()
                    
                case .telemetryViewer:
                    TelemetryInspector()
                    
                case .dataGenerator:
                    DataGeneratorInspector()
                    
                case .sqlQuery:
                    SQLQueryInspector()
                    
                case nil:
                    EmptyInspector()
                }
            }
            .padding()
        }
        .navigationTitle("Inspector")
    }
}

// MARK: - Collector Inspector

struct CollectorInspector: View {
    let collectorId: UUID
    @Environment(AppContainer.self) private var container
    @State private var showSnippets = false
    
    var collector: CollectorInstance? {
        container.collectorManager.collectors.first { $0.id == collectorId }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let collector = collector {
                // Quick Actions
                Section {
                    VStack(spacing: 8) {
                        Button(action: { toggleCollectorState() }) {
                            Label(
                                collector.isRunning ? "Stop Collector" : "Start Collector",
                                systemImage: collector.isRunning ? "stop.fill" : "play.fill"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        
                        if collector.isRunning {
                            Button(action: { restartCollector() }) {
                                Label("Restart", systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } header: {
                    InspectorSectionHeader("QUICK ACTIONS")
                }
                
                Divider()
                
                // Status
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Status") {
                            HStack {
                                Circle()
                                    .fill(collector.isRunning ? .green : .gray)
                                    .frame(width: 8, height: 8)
                                Text(collector.isRunning ? "Running" : "Stopped")
                                    .font(.caption)
                            }
                        }
                        
                        if let startTime = collector.startTime {
                            LabeledContent("Uptime") {
                                Text(startTime.formatted(.relative(presentation: .named)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        LabeledContent("Version") {
                            Text(collector.version)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if container.collectorManager.isProcessingOperation && 
                           container.collectorManager.activeCollector?.id == collector.id {
                            LabeledContent("Operation") {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Processing...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    InspectorSectionHeader("STATUS")
                }
                
                Divider()
                
                // Configuration Info
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Config Path") {
                            Text(URL(fileURLWithPath: collector.configPath).lastPathComponent)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if !collector.commandLineFlags.isEmpty {
                            LabeledContent("Flags") {
                                Text(collector.commandLineFlags)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        
                        if let components = collector.components {
                            LabeledContent("Components") {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(components.receivers!.count) receivers")
                                        .font(.caption2)
                                    Text("\(components.processors!.count) processors")
                                        .font(.caption2)
                                    Text("\(components.exporters!.count) exporters")
                                        .font(.caption2)
                                }
                                .foregroundStyle(.secondary)
                            }
                        }
                        
                        Button(action: { showSnippets.toggle() }) {
                            Label(showSnippets ? "Hide Snippets" : "Show Snippets", systemImage: "doc.on.clipboard")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                } header: {
                    InspectorSectionHeader("CONFIGURATION")
                }
                
                if showSnippets {
                    Divider()
                    
                    // Snippets Section
                    Section {
                        SnippetsInspectorView(
                            snippetManager: container.snippetManager,
                            onAction: { _ in /* Snippet actions handled by ConfigEditorView */ }
                        )
                        .frame(maxHeight: 300)
                    } header: {
                        InspectorSectionHeader("SNIPPETS")
                    }
                }
            } else {
                Text("Collector not found")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func toggleCollectorState() {
        guard let collector = collector else { return }
        if collector.isRunning {
            container.collectorManager.stopCollector(withId: collector.id)
        } else {
            container.collectorManager.startCollector(withId: collector.id)
        }
    }
    
    private func restartCollector() {
        guard let collector = collector else { return }
        container.collectorManager.stopCollector(withId: collector.id)
        // Add a small delay then restart
        Task {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            await MainActor.run {
                container.collectorManager.startCollector(withId: collector.id)
            }
        }
    }
}

// MARK: - Other Inspectors

struct OTLPReceiverInspector: View {
    @Environment(AppContainer.self) private var container
    @State private var serverRunning = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Status") {
                        HStack {
                            Circle()
                                .fill(serverRunning ? .green : .gray)
                                .frame(width: 8, height: 8)
                            Text(serverRunning ? "Active" : "Inactive")
                                .font(.caption)
                        }
                    }
                    
                    LabeledContent("Endpoint") {
                        Text(container.settings.grpcEndpoint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    LabeledContent("Signals") {
                        VStack(alignment: .trailing, spacing: 2) {
                            if container.settings.tracesEnabled {
                                Text("Traces")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                            if container.settings.metricsEnabled {
                                Text("Metrics")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                            if container.settings.logsEnabled {
                                Text("Logs")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            } header: {
                InspectorSectionHeader("RECEIVER STATUS")
            }
        }
        .task {
            serverRunning = await container.server.isRunning()
        }
    }
}

struct TelemetryInspector: View {
    @Environment(AppContainer.self) private var container
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Selected") {
                        Text(container.viewer.selectedCollector)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if !container.viewer.collectorStats.isEmpty {
                        ForEach(container.viewer.collectorStats, id: \.collectorName) { stats in
                            LabeledContent(stats.collectorName) {
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text("\(stats.spanCount) spans")
                                        .font(.caption2)
                                    Text("\(stats.metricCount) metrics")
                                        .font(.caption2)
                                    Text("\(stats.logCount) logs")
                                        .font(.caption2)
                                }
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                InspectorSectionHeader("TELEMETRY DATA")
            }
        }
    }
}

struct DataGeneratorInspector: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Section {
                Text("Data generation tools and settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                InspectorSectionHeader("DATA GENERATOR")
            }
        }
    }
}

struct SQLQueryInspector: View {
    @Environment(AppContainer.self) private var container
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Target") {
                        Text(container.viewer.selectedCollector)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let result = container.viewer.lastQueryResult {
                        LabeledContent("Last Result") {
                            Text("\(result.rows.count) rows")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if container.viewer.isExecutingQuery {
                        LabeledContent("Status") {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Executing...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                InspectorSectionHeader("QUERY STATUS")
            }
        }
    }
}

struct EmptyInspector: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sidebar.right")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            
            Text("Inspector")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Select an item from the sidebar to view contextual information and controls")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Helper Views

struct InspectorSectionHeader: View {
    let title: String
    
    init(_ title: String) {
        self.title = title
    }
    
    var body: some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}
