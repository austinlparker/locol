import SwiftUI

private enum DetailTab: String {
    case metrics, logs, traces
}

struct ResourceDetailView: View {
    let resourceGroup: ResourceAttributeGroup
    @State private var selectedTab = DetailTab.metrics
    @State private var metrics: [MetricRow] = []
    @State private var logs: [LogRow] = []
    @State private var spans: [SpanRow] = []
    @State private var isLoading = false
    @State private var error: Error?
    
    private let dataExplorer: DataExplorerProtocol
    
    init(resourceGroup: ResourceAttributeGroup, dataExplorer: DataExplorerProtocol) {
        self.resourceGroup = resourceGroup
        self.dataExplorer = dataExplorer
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text(resourceGroup.displayName)
                    .font(.title2)
                    .bold()
                
                HStack(spacing: 8) {
                    Label("\(resourceGroup.count) resources", systemImage: "square.3.layers.3d")
                    Label("\(metrics.count) metrics", systemImage: "chart.xyaxis.line")
                    Label("\(logs.count) logs", systemImage: "text.alignleft")
                    Label("\(spans.count) spans", systemImage: "point.3.connected.trianglepath.dotted")
                }
                .foregroundStyle(.secondary)
                .font(.caption)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background)
            
            Divider()
            
            // Content
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = error {
                ContentUnavailableView {
                    Label("Error Loading Data", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error.localizedDescription)
                }
            } else {
                TabView(selection: $selectedTab) {
                    MetricsView(metrics: metrics)
                        .tabItem {
                            Label("Metrics", systemImage: "chart.xyaxis.line")
                        }
                        .tag(DetailTab.metrics)
                    
                    LogsView(logs: logs)
                        .tabItem {
                            Label("Logs", systemImage: "text.alignleft")
                        }
                        .tag(DetailTab.logs)
                    
                    SpansView(spans: spans)
                        .tabItem {
                            Label("Spans", systemImage: "point.3.connected.trianglepath.dotted")
                        }
                        .tag(DetailTab.traces)
                }
            }
        }
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }
    
    private func loadData() async {
        isLoading = true
        error = nil
        
        do {
            let resourceIds = await dataExplorer.getResourceIds(forGroup: resourceGroup)
            
            async let metricsTask = dataExplorer.getMetrics(forResourceIds: resourceIds)
            async let logsTask = dataExplorer.getLogs(forResourceIds: resourceIds)
            async let spansTask = dataExplorer.getSpans(forResourceIds: resourceIds)
            
            let (metrics, logs, spans) = await (metricsTask, logsTask, spansTask)
            self.metrics = metrics
            self.logs = logs
            self.spans = spans
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
}

// MARK: - Helper Views

private struct MetricsView: View {
    let metrics: [MetricRow]
    
    var body: some View {
        if metrics.isEmpty {
            ContentUnavailableView {
                Label("No Metrics", systemImage: "chart.xyaxis.line")
            } description: {
                Text("No metrics found for this resource")
            }
        } else {
            List(metrics) { metric in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(metric.name)
                            .font(.headline)
                        Spacer()
                        Text(metric.time.formatted())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if !metric.description_p.isEmpty {
                        Text(metric.description_p)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text(String(format: "%.6f", metric.value))
                            .font(.system(.body, design: .monospaced))
                        if !metric.unit.isEmpty {
                            Text(metric.unit)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct LogsView: View {
    let logs: [LogRow]
    
    var body: some View {
        if logs.isEmpty {
            ContentUnavailableView {
                Label("No Logs", systemImage: "text.alignleft")
            } description: {
                Text("No logs found for this resource")
            }
        } else {
            List(logs) { log in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(log.timestamp.formatted())
                            .font(.system(.caption, design: .monospaced))
                        Text(log.severityText)
                            .font(.caption)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(severityColor(log.severityText))
                            )
                        Spacer()
                    }
                    Text(log.body)
                        .font(.body)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private func severityColor(_ severity: String) -> Color {
        switch severity.lowercased() {
        case "error": return .red.opacity(0.2)
        case "warn": return .yellow.opacity(0.2)
        case "info": return .blue.opacity(0.2)
        case "debug": return .gray.opacity(0.2)
        default: return .clear
        }
    }
}

private struct SpansView: View {
    let spans: [SpanRow]
    
    var body: some View {
        if spans.isEmpty {
            ContentUnavailableView {
                Label("No Spans", systemImage: "point.3.connected.trianglepath.dotted")
            } description: {
                Text("No spans found for this resource")
            }
        } else {
            List(spans) { span in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(span.name)
                            .font(.headline)
                        Spacer()
                        Text(formatDuration(span.endTime.timeIntervalSince(span.startTime)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("Trace: \(span.traceId)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    
                    if !span.parentSpanId.isEmpty {
                        Text("Parent: \(span.parentSpanId)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return String(format: "%.2fms", duration * 1000)
        } else {
            return String(format: "%.2fs", duration)
        }
    }
} 