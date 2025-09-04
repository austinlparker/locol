import SwiftUI
import Charts
import GRDB

struct TelemetryView: View {
    let collectorManager: CollectorManager?
    @State private var viewModel: TelemetryViewModel
    @State private var selectedSignalType: SignalType = .traces
    
    init(collectorManager: CollectorManager) {
        self.collectorManager = collectorManager
        
        // Initialize view model with a running collector, or the first available collector
        let runningCollector = collectorManager.collectors.first(where: { $0.isRunning })?.name
        let firstCollector = collectorManager.collectors.first?.name
        let initialCollector = runningCollector ?? firstCollector ?? ""
        
        self._viewModel = State(initialValue: TelemetryViewModel(initialCollector: initialCollector))
    }
    
    init(collectorName: String) {
        self.collectorManager = nil
        self._viewModel = State(initialValue: TelemetryViewModel(initialCollector: collectorName))
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar with signal types
            sidebarContent
        } detail: {
            // Detail view for selected signal type
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .navigationTitle("OTLP Telemetry")
        .toolbar {
            // Collector selection (only show when collectorManager is available)
            ToolbarItemGroup(placement: .navigation) {
                if collectorManager != nil {
                    Menu {
                        ForEach(viewModel.availableCollectors, id: \.self) { collector in
                            Button(collector) {
                                viewModel.updateCollector(collector)
                            }
                        }
                    } label: {
                        Label("Collector: \(viewModel.selectedCollector)", systemImage: "server.rack")
                    }
                }
            }
            
            // Time range selector
            ToolbarItemGroup(placement: .automatic) {
                Picker("Time Range", selection: Binding(
                    get: { viewModel.selectedTimeRange },
                    set: { viewModel.updateTimeRange($0) }
                )) {
                    ForEach(TelemetryTimeRange.allCases) { range in
                        Text(range.displayName)
                            .tag(range)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }
    
    private var sidebarContent: some View {
        List(SignalType.allCases, id: \.self, selection: $selectedSignalType) { signalType in
            NavigationLink(value: signalType) {
                Label {
                    Text(signalType.title)
                } icon: {
                    Image(systemName: signalType.iconName)
                        .foregroundStyle(signalType.color)
                }
                
                Spacer()
                
                // Count badge
                if let count = signalCount(for: signalType), count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(signalType.color.opacity(0.2))
                        .foregroundStyle(signalType.color)
                        .clipShape(Capsule())
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 120, idealWidth: 160, maxWidth: 200)
        .navigationTitle("Signals")
    }
    
    @ViewBuilder
    private var detailContent: some View {
        if viewModel.hasTelemetryData {
            switch selectedSignalType {
            case .traces:
                EnhancedTracesView(viewModel: viewModel)
            case .metrics:
                EnhancedMetricsView(viewModel: viewModel)
            case .logs:
                EnhancedLogsView(viewModel: viewModel)
            }
        } else {
            emptyDataView
        }
    }
    
    private var emptyDataView: some View {
        ContentUnavailableView {
            Label("No Telemetry Data", systemImage: "chart.line.uptrend.xyaxis")
        } description: {
            Text("Start sending OTLP data to see traces, metrics, and logs here")
        } actions: {
            Button("Refresh") {
                // Trigger refresh of data
                // Refresh functionality would need to be implemented
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private func signalCount(for signalType: SignalType) -> Int? {
        switch signalType {
        case .traces:
            return viewModel.traceHierarchies.count
        case .metrics:
            return viewModel.groupedMetrics.count
        case .logs:
            return viewModel.recentLogs.count
        }
    }
}

// MARK: - Signal Types

enum SignalType: CaseIterable, Hashable {
    case traces
    case metrics
    case logs
    
    var title: String {
        switch self {
        case .traces: return "Traces"
        case .metrics: return "Metrics"  
        case .logs: return "Logs"
        }
    }
    
    var iconName: String {
        switch self {
        case .traces: return "point.3.connected.trianglepath.dotted"
        case .metrics: return "chart.line.uptrend.xyaxis"
        case .logs: return "doc.text"
        }
    }
    
    var color: Color {
        switch self {
        case .traces: return .blue
        case .metrics: return .green
        case .logs: return .purple
        }
    }
}

// MARK: - Enhanced Views with NSTableView

struct EnhancedLogsView: View {
    let viewModel: TelemetryViewModel
    @State private var selectedLog: TelemetryLog?
    
    var body: some View {
        Group {
            if viewModel.recentLogs.isEmpty {
                ContentUnavailableView {
                    Label("No Logs Found", systemImage: "doc.text")
                } description: {
                    Text("Start sending log data to see entries here")
                } actions: {
                    Button("Refresh") {
                        // Refresh functionality would need to be implemented
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                // Use high-performance NSTableView
                LogsTableView(
                    logs: viewModel.recentLogs,
                    searchText: viewModel.searchText,
                    selectedLog: $selectedLog
                )
            }
        }
        .navigationTitle("Logs (\(viewModel.recentLogs.count))")
        .searchable(text: Binding(
            get: { viewModel.searchText },
            set: { viewModel.updateSearchText($0) }
        ), prompt: "Search logs...")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    ForEach(LogSeverity.allCases, id: \.self) { severity in
                        Toggle(severity.displayName, isOn: Binding(
                            get: { viewModel.selectedSeverityLevels.contains(severity) },
                            set: { isSelected in
                                var levels = viewModel.selectedSeverityLevels
                                if isSelected {
                                    levels.insert(severity)
                                } else {
                                    levels.remove(severity)
                                }
                                viewModel.updateSeverityLevels(levels)
                            }
                        ))
                    }
                } label: {
                    Label("Filter Severity", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }
}

// MARK: - LogSeverity Extension

extension LogSeverity {
    var swiftUIColor: Color {
        switch self {
        case .trace, .debug: return .gray
        case .info: return .blue
        case .warn: return .orange
        case .error, .fatal: return .red
        }
    }
}

struct EnhancedMetricsView: View {
    let viewModel: TelemetryViewModel
    @State private var selectedMetric: TelemetryMetricGroup?
    
    var body: some View {
        Group {
            if viewModel.groupedMetrics.isEmpty {
                ContentUnavailableView {
                    Label("No Metrics Found", systemImage: "chart.line.uptrend.xyaxis")
                } description: {
                    Text("Start sending metric data to see charts here")
                } actions: {
                    Button("Refresh") {
                        // Refresh functionality would need to be implemented
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                // Use compact NSTableView for better screen utilization
                MetricsTableView(
                    metrics: viewModel.groupedMetrics,
                    selectedMetric: $selectedMetric
                )
            }
        }
        .navigationTitle("Metrics (\(viewModel.groupedMetrics.count))")
        .searchable(text: Binding(
            get: { viewModel.selectedMetricName ?? "" },
            set: { viewModel.updateMetricName($0.isEmpty ? nil : $0) }
        ), prompt: "Search metrics...")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button("All Metrics") {
                        viewModel.updateMetricName(nil)
                    }
                    
                    if !viewModel.metricSummaries.isEmpty {
                        Divider()
                        
                        ForEach(viewModel.metricSummaries, id: \.name) { summary in
                            Button("\(summary.name) (\(summary.type.rawValue))") {
                                viewModel.updateMetricName(summary.name)
                            }
                        }
                    }
                } label: {
                    Label("Filter Metrics", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }
}

struct EnhancedTracesView: View {
    let viewModel: TelemetryViewModel
    @State private var selectedTrace: TraceHierarchy?
    
    var body: some View {
        NavigationSplitView {
            Group {
                if viewModel.traceHierarchies.isEmpty {
                    ContentUnavailableView {
                        Label("No Traces Found", systemImage: "point.3.connected.trianglepath.dotted")
                    } description: {
                        Text("Start sending trace data to see spans here")
                    } actions: {
                        Button("Refresh") {
                            // Refresh functionality would need to be implemented
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    // Use high-performance NSTableView
                    TracesTableView(
                        traces: viewModel.traceHierarchies,
                        selectedTrace: $selectedTrace
                    )
                }
            }
            .navigationTitle("Traces (\(viewModel.traceHierarchies.count))")
        } detail: {
            // Trace waterfall detail
            Group {
                if let selectedTrace = selectedTrace {
                    TraceWaterfallView(hierarchy: selectedTrace)
                } else {
                    ContentUnavailableView {
                        Label("Select a Trace", systemImage: "point.3.connected.trianglepath.dotted")
                    } description: {
                        Text("Choose a trace from the list to see detailed span information")
                    }
                }
            }
        }
    }
}

struct TraceWaterfallView: View {
    let hierarchy: TraceHierarchy
    @State private var expandedSpans: Set<String> = []
    
    var body: some View {
        // Use high-performance NSOutlineView for hierarchical spans
        TraceWaterfallOutlineView(
            hierarchy: hierarchy,
            expandedSpans: $expandedSpans
        )
        .navigationTitle("Trace Details")
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter
    }()
    
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter
    }()
}


#Preview {
    TelemetryView(collectorManager: CollectorManager())
}