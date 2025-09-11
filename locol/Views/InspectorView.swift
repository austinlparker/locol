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
    @State private var record: CollectorRecord? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Component editor for Pipeline Designer selection
            if let selected = container.selectedPipelineComponent {
                Section {
                    ComponentInspectorView(
                        component: binding(for: selected),
                        onConfigChanged: { updated in updateComponent(updated) }
                    )
                } header: {
                    InspectorSectionHeader("COMPONENT")
                }
                Divider()
            }
            if let record = record {
                // Quick Actions
                Section {
                    VStack(spacing: 8) {
                        Button(action: { toggleCollectorState() }) {
                            Label(
                                isRunning ? "Stop Collector" : "Start Collector",
                                systemImage: isRunning ? "stop.fill" : "play.fill"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        
                        if isRunning {
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
                                    .fill(isRunning ? .green : .gray)
                                    .frame(width: 8, height: 8)
                                Text(isRunning ? "Running" : "Stopped")
                                    .font(.caption)
                            }
                        }
                        
                        if container.collectorManager.activeCollector?.id == collectorId,
                           let startTime = container.collectorManager.activeCollector?.startTime {
                            LabeledContent("Uptime") {
                                Text(startTime.formatted(.relative(presentation: .named)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        LabeledContent("Version") {
                            Text(record.version)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if container.collectorManager.isProcessingOperation && 
                           container.collectorManager.activeCollector?.id == collectorId {
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
                        LabeledContent("Binary") {
                            Text(record.binaryPath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        LabeledContent("Data Directory") {
                            Text(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".locol/collectors/\(record.name)").path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                } header: {
                    InspectorSectionHeader("CONFIGURATION")
                }
                
                Divider()
                
                // Components Section omitted until store-backed snapshot is available.
                
                // Command Line Flags Section
                if !(record.flags.isEmpty) {
                    Section {
                        Text(record.flags)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .padding(.vertical, 4)
                    } header: {
                        InspectorSectionHeader("COMMAND LINE FLAGS")
                    }
                }
            } else {
                Text("Collector not found")
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            if record == nil {
                record = try? await container.collectorStore.getCollector(collectorId)
            }
        }
    }
    
    private func toggleCollectorState() {
        if isRunning {
            container.collectorManager.stopCollector(withId: collectorId)
        } else {
            container.collectorManager.startCollector(withId: collectorId)
        }
    }
    
    private func restartCollector() {
        container.collectorManager.stopCollector(withId: collectorId)
        // Add a small delay then restart
        Task {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            await MainActor.run {
                container.collectorManager.startCollector(withId: collectorId)
            }
        }
    }

    private var isRunning: Bool {
        // Prefer process state; fall back to DB record state
        if container.collectorManager.isCollectorRunning(withId: collectorId) { return true }
        return record?.isRunning ?? false
    }

    // MARK: - Pipeline editing helpers
    private func binding(for component: ComponentInstance) -> Binding<ComponentInstance> {
        // Top-level collections
        if let index = container.pipelineConfig.receivers.firstIndex(of: component) {
            return Binding(
                get: { container.pipelineConfig.receivers[index] },
                set: { container.pipelineConfig.receivers[index] = $0 }
            )
        } else if let index = container.pipelineConfig.processors.firstIndex(of: component) {
            return Binding(
                get: { container.pipelineConfig.processors[index] },
                set: { container.pipelineConfig.processors[index] = $0 }
            )
        } else if let index = container.pipelineConfig.exporters.firstIndex(of: component) {
            return Binding(
                get: { container.pipelineConfig.exporters[index] },
                set: { container.pipelineConfig.exporters[index] = $0 }
            )
        } else if let index = container.pipelineConfig.extensions.firstIndex(of: component) {
            return Binding(
                get: { container.pipelineConfig.extensions[index] },
                set: { container.pipelineConfig.extensions[index] = $0 }
            )
        } else if let index = container.pipelineConfig.connectors.firstIndex(of: component) {
            return Binding(
                get: { container.pipelineConfig.connectors[index] },
                set: { container.pipelineConfig.connectors[index] = $0 }
            )
        }
        // Search inside pipelines
        for pIndex in container.pipelineConfig.pipelines.indices {
            if let rIndex = container.pipelineConfig.pipelines[pIndex].receivers.firstIndex(of: component) {
                return Binding(
                    get: { container.pipelineConfig.pipelines[pIndex].receivers[rIndex] },
                    set: { container.pipelineConfig.pipelines[pIndex].receivers[rIndex] = $0 }
                )
            }
            if let prIndex = container.pipelineConfig.pipelines[pIndex].processors.firstIndex(of: component) {
                return Binding(
                    get: { container.pipelineConfig.pipelines[pIndex].processors[prIndex] },
                    set: { container.pipelineConfig.pipelines[pIndex].processors[prIndex] = $0 }
                )
            }
            if let eIndex = container.pipelineConfig.pipelines[pIndex].exporters.firstIndex(of: component) {
                return Binding(
                    get: { container.pipelineConfig.pipelines[pIndex].exporters[eIndex] },
                    set: { container.pipelineConfig.pipelines[pIndex].exporters[eIndex] = $0 }
                )
            }
        }
        // If not found, avoid crashing — provide a transient binding to a copy
        let tmp = component
        return Binding(
            get: { tmp },
            set: { _ in }
        )
    }

    private func updateComponent(_ component: ComponentInstance) {
        if let index = container.pipelineConfig.receivers.firstIndex(where: { $0.id == component.id }) {
            container.pipelineConfig.receivers[index] = component
        } else if let index = container.pipelineConfig.processors.firstIndex(where: { $0.id == component.id }) {
            container.pipelineConfig.processors[index] = component
        } else if let index = container.pipelineConfig.exporters.firstIndex(where: { $0.id == component.id }) {
            container.pipelineConfig.exporters[index] = component
        } else if let index = container.pipelineConfig.extensions.firstIndex(where: { $0.id == component.id }) {
            container.pipelineConfig.extensions[index] = component
        } else if let index = container.pipelineConfig.connectors.firstIndex(where: { $0.id == component.id }) {
            container.pipelineConfig.connectors[index] = component
        }

        // Update in pipelines too
        for (pipelineIndex, pipeline) in container.pipelineConfig.pipelines.enumerated() {
            var updatedPipeline = pipeline
            var needsUpdate = false
            if let receiverIndex = updatedPipeline.receivers.firstIndex(where: { $0.id == component.id }) {
                updatedPipeline.receivers[receiverIndex] = component
                needsUpdate = true
            }
            if let processorIndex = updatedPipeline.processors.firstIndex(where: { $0.id == component.id }) {
                updatedPipeline.processors[processorIndex] = component
                needsUpdate = true
            }
            if let exporterIndex = updatedPipeline.exporters.firstIndex(where: { $0.id == component.id }) {
                updatedPipeline.exporters[exporterIndex] = component
                needsUpdate = true
            }
            if needsUpdate {
                container.pipelineConfig.pipelines[pipelineIndex] = updatedPipeline
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

struct ComponentInspectorSection: View {
    let title: String
    let items: [String]
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(items.count)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            if items.count <= 3 {
                // Show all items if few
                ForEach(items, id: \.self) { item in
                    Text("• \(item)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
            } else {
                // Show first 2 and "... X more"
                ForEach(items.prefix(2), id: \.self) { item in
                    Text("• \(item)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
                Text("• ... \(items.count - 2) more")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 4)
            }
        }
    }
}
