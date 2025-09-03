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

// MARK: - Enhanced Views

struct EnhancedLogsView: View {
    let viewModel: TelemetryViewModel
    
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
                // Use Table for better performance and semantic structure
                Table(viewModel.recentLogs, id: \.identifier) {
                    TableColumn("Level") { log in
                        Label {
                            Text(log.severity.displayName)
                        } icon: {
                            Circle()
                                .fill(log.severity.swiftUIColor)
                                .frame(width: 8, height: 8)
                        }
                        .font(.caption)
                        .foregroundStyle(log.severity.swiftUIColor)
                    }
                    .width(60)
                    
                    TableColumn("Service") { log in
                        if let serviceName = log.attributes["service.name"]?.displayValue {
                            Text(serviceName)
                                .font(.caption)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }
                    .width(80)
                    
                    TableColumn("Message") { log in
                        Text(log.body)
                            .textSelection(.enabled)
                            .lineLimit(3)
                    }
                    .width(min: 200)
                    
                    TableColumn("Time") { log in
                        Text(formatLogTimestamp(log.timestamp))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .width(80)
                }
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
    
    private func formatLogTimestamp(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(timestamp) / 1_000_000_000)
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
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
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 260, maximum: 380), spacing: 12)
                    ], spacing: 12) {
                        ForEach(viewModel.groupedMetrics) { group in
                            EnhancedMetricCard(group: group)
                        }
                    }
                    .padding(12)
                }
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

struct EnhancedMetricCard: View {
    let group: TelemetryMetricGroup
    
    var body: some View {
        // Use GroupBox for semantic grouping instead of manual VStack
        GroupBox {
            LabeledContent {
                if let latestValue = group.latestValue {
                    Text(formatMetricValue(latestValue))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                }
            } label: {
                Label {
                    Text(group.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                } icon: {
                    Text(group.type.rawValue.uppercased())
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(metricTypeColor(group.type))
                        .clipShape(Capsule())
                }
            }
            
            // Sparkline chart
            if group.metrics.count > 1 {
                Chart(group.metrics, id: \.timestamp) { metric in
                    LineMark(
                        x: .value("Time", Date(timeIntervalSince1970: Double(metric.timestamp) / 1_000_000_000)),
                        y: .value("Value", metric.value ?? 0)
                    )
                    .foregroundStyle(metricTypeColor(group.type))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 40)
            } else {
                Text("Insufficient data for trend")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 40)
            }
            
            // Labels using simple ScrollView
            if !group.labels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(group.labels.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                            Text("\(key):\(value)")
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.gray.opacity(0.1))
                                .foregroundStyle(.secondary)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func metricTypeColor(_ type: TelemetryMetric.MetricType) -> Color {
        switch type {
        case .counter: return .blue
        case .gauge: return .green
        case .histogram: return .purple
        case .summary: return .orange
        }
    }
    
    private func formatMetricValue(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", value / 1_000)
        } else if value < 1 {
            return String(format: "%.3f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}


struct EnhancedTracesView: View {
    let viewModel: TelemetryViewModel
    @State private var selectedTrace: TraceHierarchy?
    
    var body: some View {
        // Use Table for traces list instead of manual layout
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
                    Table(viewModel.traceHierarchies, id: \.spans.first?.traceId, selection: $selectedTrace) {
                        TableColumn("Service") { hierarchy in
                            Text(hierarchy.rootSpans.first?.serviceName ?? "Unknown")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        TableColumn("Operation") { hierarchy in
                            Text(hierarchy.rootSpans.first?.operationName ?? "Unknown")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        TableColumn("Spans") { hierarchy in
                            Text("\(hierarchy.spans.count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .width(60)
                        
                        TableColumn("Duration") { hierarchy in
                            Text(formatDuration(hierarchy.duration))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(durationColor(hierarchy.duration))
                        }
                        .width(80)
                        
                        TableColumn("Time") { hierarchy in
                            if let rootSpan = hierarchy.rootSpans.first {
                                Text(formatTimestamp(rootSpan.startTime))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .width(100)
                    }
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
    
    private func formatDuration(_ duration: Int64) -> String {
        if duration > 1_000_000_000 {
            return String(format: "%.1fs", Double(duration) / 1_000_000_000)
        } else if duration > 1_000_000 {
            return String(format: "%.1fms", Double(duration) / 1_000_000)
        } else {
            return String(format: "%.1fμs", Double(duration) / 1_000)
        }
    }
    
    private func durationColor(_ duration: Int64) -> Color {
        if duration > 5_000_000_000 { // > 5s
            return .red
        } else if duration > 1_000_000_000 { // > 1s
            return .orange
        } else if duration > 100_000_000 { // > 100ms
            return .yellow
        } else {
            return .green
        }
    }
    
    private func formatTimestamp(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(timestamp) / 1_000_000_000)
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

struct TraceWaterfallView: View {
    let hierarchy: TraceHierarchy
    @State private var expandedSpans: Set<String> = []
    
    var body: some View {
        // Use OutlineGroup for hierarchical trace spans
        List(hierarchy.spans, id: \.spanId, children: \.childSpans) { span in
            TraceSpanRowView(
                span: span,
                hierarchy: hierarchy,
                expandedSpans: $expandedSpans
            )
        }
        .listStyle(.plain)
        .navigationTitle("Trace Details")
    }
}

struct TraceSpanRowView: View {
    let span: TelemetrySpan
    let hierarchy: TraceHierarchy
    @Binding var expandedSpans: Set<String>
    
    private var isExpanded: Bool {
        expandedSpans.contains(span.spanId)
    }
    
    var body: some View {
        DisclosureGroup(isExpanded: Binding(
            get: { isExpanded },
            set: { expanded in
                if expanded {
                    expandedSpans.insert(span.spanId)
                } else {
                    expandedSpans.remove(span.spanId)
                }
            }
        )) {
            // Expanded details using Form for semantic structure
            Form {
                Section {
                    LabeledContent("Span ID", value: String(span.spanId.prefix(12)) + "...")
                    LabeledContent("Trace ID", value: String(span.traceId.prefix(12)) + "...")
                    if let parentId = span.parentSpanId {
                        LabeledContent("Parent ID", value: String(parentId.prefix(12)) + "...")
                    }
                    LabeledContent("Start Time", value: formatTimestamp(span.startTime))
                    LabeledContent("Duration", value: formatDuration(span.duration))
                }
            }
            .formStyle(.grouped)
        } label: {
            // Use LabeledContent for the main span info
            LabeledContent {
                HStack {
                    if let serviceName = span.serviceName {
                        Text(serviceName)
                            .font(.caption)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                    
                    Text(formatDuration(span.duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } label: {
                Text(span.operationName ?? "Unknown Operation")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
    }
    
    private func formatDuration(_ duration: Int64) -> String {
        if duration > 1_000_000_000 {
            return String(format: "%.1fs", Double(duration) / 1_000_000_000)
        } else if duration > 1_000_000 {
            return String(format: "%.1fms", Double(duration) / 1_000_000)
        } else {
            return String(format: "%.1fμs", Double(duration) / 1_000)
        }
    }
    
    private func formatTimestamp(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(timestamp) / 1_000_000_000)
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .short
        return formatter.string(from: date)
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

// Add support for child spans in TraceHierarchy if not already present
extension TelemetrySpan {
    var childSpans: [TelemetrySpan]? {
        // This would need to be implemented based on your TraceHierarchy structure
        // For now, return nil to make it work without children
        return nil
    }
}

#Preview {
    TelemetryView(collectorManager: CollectorManager())
}