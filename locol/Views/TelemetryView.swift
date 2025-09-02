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
                HStack {
                    Label(signalType.title, systemImage: signalType.iconName)
                        .foregroundStyle(signalType.color)
                    
                    Spacer()
                    
                    // Count badge
                    if let count = signalCount(for: signalType), count > 0 {
                        Text("\(count)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(signalType.color.opacity(0.2))
                            .foregroundStyle(signalType.color)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 180)
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
        VStack(spacing: 0) {
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
                // Enhanced log list with better visual hierarchy
                List {
                    ForEach(viewModel.recentLogs, id: \.identifier) { log in
                        EnhancedLogEntryView(log: log)
                    }
                }
                .listStyle(.plain)
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
    
    private func formatTimestamp(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(timestamp) / 1_000_000_000)
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

struct EnhancedLogEntryView: View {
    let log: TelemetryLog
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                // Severity indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(log.severity.swiftUIColor)
                        .frame(width: 8, height: 8)
                    
                    Text(log.severity.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(log.severity.swiftUIColor)
                        .frame(width: 50, alignment: .leading)
                }
                
                // Service name if available
                if let serviceName = log.attributes["service.name"]?.displayValue {
                    Text(serviceName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                // Timestamp
                Text(formatLogTimestamp(log.timestamp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            
            // Log message
            Text(log.body)
                .font(.body)
                .lineLimit(isExpanded ? nil : 3)
                .textSelection(.enabled)
            
            // Attributes toggle
            if !log.attributes.isEmpty {
                Button(action: { isExpanded.toggle() }) {
                    HStack {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        Text("\(log.attributes.count) attributes")
                        Spacer()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                if isExpanded {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                        ForEach(Array(log.attributes.keys.sorted()), id: \.self) { key in
                            HStack {
                                Text(key)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(log.attributes[key]?.displayValue ?? "")
                                    .font(.caption2)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            
            // Trace ID if available
            if let traceId = log.traceId {
                Text("Trace: \(traceId.prefix(16))...")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 4)
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
        VStack(spacing: 0) {
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
                        GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)
                    ], spacing: 16) {
                        ForEach(viewModel.groupedMetrics) { group in
                            EnhancedMetricCard(group: group)
                        }
                    }
                    .padding()
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
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    
                    HStack {
                        Text(group.type.rawValue.uppercased())
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(metricTypeColor(group.type))
                            .clipShape(Capsule())
                        
                        if let latestValue = group.latestValue {
                            Text(formatMetricValue(latestValue))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                
                Spacer()
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
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 40)
                    .overlay(
                        Text("Insufficient data for trend")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    )
            }
            
            // Labels
            if !group.labels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(group.labels.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                            Text("\(key):\(value)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.gray.opacity(0.1))
                                .foregroundStyle(.secondary)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .padding()
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
        NavigationSplitView {
            // Trace list
            VStack(spacing: 0) {
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
                    List(viewModel.traceHierarchies, id: \.spans.first?.traceId, selection: $selectedTrace) { hierarchy in
                        EnhancedTraceRowView(hierarchy: hierarchy)
                            .tag(hierarchy)
                    }
                    .listStyle(.sidebar)
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
        .navigationSplitViewStyle(.balanced)
    }
}

struct EnhancedTraceRowView: View {
    let hierarchy: TraceHierarchy
    
    private var rootSpan: TelemetrySpan? {
        hierarchy.rootSpans.first
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rootSpan?.serviceName ?? "Unknown Service")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(rootSpan?.operationName ?? "Unknown Operation")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(hierarchy.spans.count) spans")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text(formatDuration(hierarchy.duration))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(durationColor(hierarchy.duration))
                }
            }
            
            // Duration bar
            HStack {
                Rectangle()
                    .fill(durationColor(hierarchy.duration))
                    .frame(height: 3)
                    .clipShape(Capsule())
                
                Spacer()
            }
            
            if let rootSpan = rootSpan {
                Text(formatTimestamp(rootSpan.startTime))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(hierarchy.spans, id: \.spanId) { span in
                    TraceSpanRowView(
                        span: span,
                        hierarchy: hierarchy,
                        expandedSpans: $expandedSpans
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Trace Details")
    }
}

struct TraceSpanRowView: View {
    let span: TelemetrySpan
    let hierarchy: TraceHierarchy
    @Binding var expandedSpans: Set<String>
    
    private var depth: Int {
        calculateDepth(span: span, in: hierarchy.spans)
    }
    
    private var isExpanded: Bool {
        expandedSpans.contains(span.spanId)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // Indentation for hierarchy
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: CGFloat(depth * 16))
                
                // Duration bar
                GeometryReader { geometry in
                    let totalDuration = hierarchy.duration
                    let spanDuration = span.duration
                    let barWidth = max(4, Double(spanDuration) / Double(totalDuration) * Double(geometry.size.width))
                    
                    HStack {
                        Rectangle()
                            .fill(durationColor(span.duration))
                            .frame(width: barWidth, height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                        Spacer()
                    }
                }
                .frame(height: 20)
                .frame(maxWidth: 200)
                
                // Span info
                VStack(alignment: .leading, spacing: 2) {
                    Text(span.operationName ?? "Unknown Operation")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        if let serviceName = span.serviceName {
                            Text(serviceName)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                        
                        Text(formatDuration(span.duration))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                    }
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isExpanded {
                    expandedSpans.remove(span.spanId)
                } else {
                    expandedSpans.insert(span.spanId)
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                        .padding(.leading, CGFloat(depth * 16 + 8))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        LabeledContent("Span ID", value: span.spanId.prefix(16) + "...")
                        LabeledContent("Trace ID", value: span.traceId.prefix(16) + "...")
                        if let parentId = span.parentSpanId {
                            LabeledContent("Parent ID", value: parentId.prefix(16) + "...")
                        }
                        LabeledContent("Start Time", value: formatTimestamp(span.startTime))
                        LabeledContent("Duration", value: formatDuration(span.duration))
                    }
                    .font(.caption)
                    .padding(.leading, CGFloat(depth * 16 + 16))
                }
                .background(.background.secondary.opacity(0.5))
            }
        }
        .padding(.vertical, 2)
    }
    
    private func calculateDepth(span: TelemetrySpan, in spans: [TelemetrySpan]) -> Int {
        var depth = 0
        var currentParentId = span.parentSpanId
        
        while let parentId = currentParentId {
            if let parent = spans.first(where: { $0.spanId == parentId }) {
                depth += 1
                currentParentId = parent.parentSpanId
            } else {
                break
            }
        }
        
        return depth
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

#Preview {
    TelemetryView(collectorManager: CollectorManager())
}