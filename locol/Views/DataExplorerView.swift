import SwiftUI
import TabularData

// MARK: - Table Configurations

struct ResourceAttributeGroup: Identifiable, Hashable {
    let id = UUID()
    let key: String
    let value: String
    let resourceIds: [String]
    var count: Int { resourceIds.count }
    
    var displayName: String {
        if key == "service.name" {
            return value
        } else {
            return "\(key): \(value)"
        }
    }
    
    // Implement Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(key)
        hasher.combine(value)
    }
    
    // Implement Equatable (required by Hashable)
    static func == (lhs: ResourceAttributeGroup, rhs: ResourceAttributeGroup) -> Bool {
        lhs.key == rhs.key && lhs.value == rhs.value
    }
    
    init(key: String, value: String, resourceIds: [String]) {
        self.key = key
        self.value = value
        self.resourceIds = resourceIds
    }
    
    init(from model: DataExplorer.ResourceAttributeGroup) {
        self.key = model.key
        self.value = model.value
        self.resourceIds = model.resourceIds
    }
}

enum Tab: String, CaseIterable {
    case metrics, logs, traces, resources, query
    
    var systemImage: String {
        switch self {
        case .metrics: return "chart.xyaxis.line"
        case .logs: return "text.alignleft"
        case .traces: return "point.3.connected.trianglepath.dotted"
        case .resources: return "square.3.layers.3d"
        case .query: return "terminal"
        }
    }
    
    var title: String {
        rawValue.capitalized
    }
}

struct DataExplorerView: View {
    let dataExplorer: DataExplorer
    @State private var selectedTab = Tab.resources
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Resources tab
            ExplorerResourcesView(dataExplorer: dataExplorer)
                .tabItem {
                    Label("Resources", systemImage: "square.3.layers.3d")
                }
                .tag(Tab.resources)
            
            // Metrics tab
            VStack(spacing: 0) {
                HStack {
                    Text("All Metrics")
                        .font(.headline)
                        .padding()
                    Spacer()
                }
                
                if dataExplorer.metrics.isEmpty {
                    ContentUnavailableView {
                        Label("No Metrics", systemImage: "chart.xyaxis.line")
                    } description: {
                        Text("Waiting for metrics data...")
                    }
                } else {
                    Table(dataExplorer.metrics.enumerated().map { index, row in
                        MetricRowIdentifiable(id: index, row: row)
                    }) {
                        TableColumn("Time") { item in
                            Text(item.row.time.formatted())
                        }
                        TableColumn("Name") { item in
                            Text(item.row.name)
                        }
                        TableColumn("Description") { item in
                            Text(item.row.description_p)
                        }
                        TableColumn("Value") { item in
                            Text(String(format: "%.6f", item.row.value))
                        }
                        TableColumn("Unit") { item in
                            Text(item.row.unit)
                        }
                    }
                }
            }
            .tabItem {
                Label("Metrics", systemImage: "chart.xyaxis.line")
            }
            .tag(Tab.metrics)
            
            // Spans tab
            VStack(spacing: 0) {
                HStack {
                    Text("All Spans")
                        .font(.headline)
                        .padding()
                    Spacer()
                }
                
                if dataExplorer.spans.isEmpty {
                    ContentUnavailableView {
                        Label("No Spans", systemImage: "point.3.connected.trianglepath.dotted")
                    } description: {
                        Text("Waiting for spans data...")
                    }
                } else {
                    Table(dataExplorer.spans.enumerated().map { index, row in
                        SpanRowIdentifiable(id: index, row: row)
                    }) {
                        TableColumn("Start Time") { item in
                            Text(item.row.startTime.formatted())
                        }
                        TableColumn("Name") { item in
                            Text(item.row.name)
                        }
                        TableColumn("Duration") { item in
                            Text(formatDuration(item.row.endTime.timeIntervalSince(item.row.startTime)))
                        }
                        TableColumn("Trace ID") { item in
                            Text(item.row.traceId)
                        }
                        TableColumn("Span ID") { item in
                            Text(item.row.spanId)
                        }
                        TableColumn("Parent Span ID") { item in
                            Text(item.row.parentSpanId)
                        }
                    }
                }
            }
            .tabItem {
                Label("Spans", systemImage: "point.3.connected.trianglepath.dotted")
            }
            .tag(Tab.traces)
            
            // Logs tab
            VStack(spacing: 0) {
                HStack {
                    Text("All Logs")
                        .font(.headline)
                        .padding()
                    Spacer()
                }
                
                if dataExplorer.logs.isEmpty {
                    ContentUnavailableView {
                        Label("No Logs", systemImage: "text.alignleft")
                    } description: {
                        Text("Waiting for logs data...")
                    }
                } else {
                    Table(dataExplorer.logs.enumerated().map { index, row in
                        LogRowIdentifiable(id: index, row: row)
                    }) {
                        TableColumn("Time") { item in
                            Text(item.row.timestamp.formatted())
                        }
                        TableColumn("Severity") { item in
                            Text(item.row.severityText)
                        }
                        TableColumn("Level") { item in
                            Text(String(item.row.severityNumber))
                        }
                        TableColumn("Message") { item in
                            Text(item.row.body)
                        }
                    }
                }
            }
            .tabItem {
                Label("Logs", systemImage: "text.alignleft")
            }
            .tag(Tab.logs)
            
            // Query tab
            ExplorerQueryView(dataExplorer: dataExplorer)
                .tabItem {
                    Label("Query", systemImage: "terminal")
                }
                .tag(Tab.query)
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if dataExplorer.isRunning {
                    Button {
                        Task {
                            await dataExplorer.stop()
                        }
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else {
                    Button {
                        Task {
                            try? await dataExplorer.start()
                        }
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            ToolbarItem(placement: .status) {
                if dataExplorer.isRunning {
                    Label("Running on port \(dataExplorer.serverPort)", systemImage: "antenna.radiowaves.left.and.right")
                        .foregroundStyle(.secondary)
                } else {
                    Label("Stopped", systemImage: "antenna.radiowaves.left.and.right.slash")
                        .foregroundStyle(.secondary)
                }
            }
            
            if let error = dataExplorer.error {
                ToolbarItem(placement: .status) {
                    Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

// MARK: - Helper Functions

private func formatDuration(_ duration: TimeInterval) -> String {
    if duration < 1 {
        return String(format: "%.2fms", duration * 1000)
    } else {
        return String(format: "%.2fs", duration)
    }
}

// MARK: - Helper Types

struct MetricRowIdentifiable: Identifiable {
    let id: Int
    let row: DataExplorer.MetricRow
}

struct LogRowIdentifiable: Identifiable {
    let id: Int
    let row: DataExplorer.LogRow
}

struct SpanRowIdentifiable: Identifiable {
    let id: Int
    let row: DataExplorer.SpanRow
}

// MARK: - Query Views

private struct QueryTableView: View {
    let data: [String: [Any]]
    
    private func formatValue(_ value: Any?) -> String {
        guard let value = value else { return "null" }
        
        switch value {
        case let date as Foundation.Date:
            return date.formatted()
        case let double as Double:
            return String(format: "%.6f", double)
        case let int as Int32:
            return String(int)
        case let int64 as Int64:
            return String(int64)
        case let decimal as Decimal:
            return String(describing: decimal)
        case let bool as Bool:
            return String(bool)
        case let string as String:
            return string
        default:
            return String(describing: value)
        }
    }
    
    var body: some View {
        if data.isEmpty {
            ContentUnavailableView {
                Label("No Results", systemImage: "magnifyingglass")
            } description: {
                Text("No results found")
            }
        } else {
            let columnNames = Array(data.keys).sorted()
            let rowCount = data[columnNames[0]]?.count ?? 0
            
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header row
                    HStack(spacing: 8) {
                        ForEach(columnNames, id: \.self) { name in
                            Text(name)
                                .font(.headline)
                                .frame(minWidth: 100, alignment: .leading)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 4)
                                .background(Color.gray.opacity(0.1))
                        }
                    }
                    
                    // Data rows
                    ForEach(0..<rowCount, id: \.self) { rowIndex in
                        HStack(spacing: 8) {
                            ForEach(columnNames, id: \.self) { columnName in
                                if let columnData = data[columnName],
                                   rowIndex < columnData.count {
                                    Text(formatValue(columnData[rowIndex]))
                                        .frame(minWidth: 100, alignment: .leading)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 4)
                                        .textSelection(.enabled)
                                } else {
                                    Text("null")
                                        .frame(minWidth: 100, alignment: .leading)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 4)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        Divider()
                    }
                }
                .padding()
            }
        }
    }
}

struct QueryRowIdentifiable: Identifiable {
    let id: Int
    let row: DataFrame.Row
}

private struct QueryInputView: View {
    @Binding var queryText: String
    let isLoading: Bool
    let onExecute: () -> Void
    
    var body: some View {
        HStack {
            TextField("Enter SQL query...", text: $queryText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            
            Button {
                onExecute()
            } label: {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Run")
                }
            }
            .disabled(queryText.isEmpty || isLoading)
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct ExplorerQueryView: View {
    let dataExplorer: DataExplorer
    @State private var queryText: String = ""
    @State private var queryResult: [String: [Any]]?
    @State private var error: String?
    @State private var isLoading = false
    
    private func executeQuery() {
        guard !queryText.isEmpty else { return }
        
        Task {
            isLoading = true
            queryResult = nil
            error = nil
            
            do {
                try await Task.sleep(for: .milliseconds(100))
                let result = try await dataExplorer.executeQuery(queryText)
                
                await MainActor.run {
                    queryResult = result
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            QueryInputView(
                queryText: $queryText,
                isLoading: isLoading,
                onExecute: executeQuery
            )
            
            if let error = error {
                Text(error)
                    .foregroundStyle(.red)
            } else if let result = queryResult {
                QueryTableView(data: result)
            }
        }
    }
}

// MARK: - Resource Views

private struct ExplorerResourcesView: View {
    let dataExplorer: DataExplorer
    @State private var searchText = ""
    @State private var selectedResource: DataExplorer.ResourceRow?
    @State private var selectedTab = Tab.metrics
    
    var filteredResources: [DataExplorer.ResourceRow] {
        if searchText.isEmpty {
            return dataExplorer.resources
        }
        return dataExplorer.resources.filter { resource in
            resource.attributes.contains { attr in
                attr.key.localizedCaseInsensitiveContains(searchText) ||
                attr.value.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        HSplitView {
            // Left side: Filterable resource list
            VStack {
                TextField("Filter resources...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                
                List(filteredResources, selection: $selectedResource) {
                    Text($0.id)
                }
                .listStyle(.inset)
            }
            .frame(minWidth: 250)
            
            // Right side: Signal tabs
            if let resource = selectedResource {
                TabView(selection: $selectedTab) {
                    MetricsTabView(
                        selectedResource: resource,
                        dataExplorer: dataExplorer
                    )
                    .tabItem {
                        Label("Metrics", systemImage: Tab.metrics.systemImage)
                    }
                    .tag(Tab.metrics)
                    
                    SpansTabView(
                        selectedResource: resource,
                        dataExplorer: dataExplorer
                    )
                    .tabItem {
                        Label("Spans", systemImage: Tab.traces.systemImage)
                    }
                    .tag(Tab.traces)
                    
                    LogsTabView(
                        selectedResource: resource,
                        dataExplorer: dataExplorer
                    )
                    .tabItem {
                        Label("Logs", systemImage: Tab.logs.systemImage)
                    }
                    .tag(Tab.logs)
                }
            } else {
                ContentUnavailableView {
                    Label("No Resource Selected", systemImage: "square.3.layers.3d")
                } description: {
                    Text("Select a resource to view its telemetry data")
                }
            }
        }
    }
}

// MARK: - Tab Views

private struct MetricsTabView: View {
    let selectedResource: DataExplorer.ResourceRow?
    let dataExplorer: DataExplorer
    @State private var metrics: [DataExplorer.MetricRow] = []
    
    var filteredMetrics: [DataExplorer.MetricRow] {
        if let selectedResource = selectedResource {
            return metrics.filter { $0.resourceId == selectedResource.id }
        }
        return metrics
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Metrics for \(selectedResource?.id ?? "this attribute")")
                    .font(.headline)
                Spacer()
            }
            .padding()
            
            if filteredMetrics.isEmpty {
                ContentUnavailableView {
                    Label("No Metrics", systemImage: "chart.xyaxis.line")
                } description: {
                    if selectedResource != nil {
                        Text("No metrics found for this resource")
                    } else {
                        Text("No metrics found for this attribute")
                    }
                }
            } else {
                List(filteredMetrics) { metric in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(metric.name)
                                .font(.headline)
                            Spacer()
                            Text(metric.time.formatted())
                                .font(.caption)
                        }
                        if !metric.description_p.isEmpty {
                            Text(metric.description_p)
                                .font(.subheadline)
                        }
                        HStack {
                            Text(String(format: "%.6f", metric.value))
                            if !metric.unit.isEmpty {
                                Text(metric.unit)
                            }
                        }
                        .font(.system(.body, design: .monospaced))
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .task {
            if let resourceId = selectedResource?.id {
                metrics = await dataExplorer.getMetrics(forResourceIds: [resourceId])
            } else {
                metrics = []
            }
        }
    }
}

private struct SpansTabView: View {
    let selectedResource: DataExplorer.ResourceRow?
    let dataExplorer: DataExplorer
    @State private var spans: [DataExplorer.SpanRow] = []
    
    var filteredSpans: [DataExplorer.SpanRow] {
        if let selectedResource = selectedResource {
            return spans.filter { $0.resourceId == selectedResource.id }
        }
        return spans
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Spans for \(selectedResource?.id ?? "this attribute")")
                    .font(.headline)
                Spacer()
            }
            .padding()
            
            if filteredSpans.isEmpty {
                ContentUnavailableView {
                    Label("No Spans", systemImage: "point.3.connected.trianglepath.dotted")
                } description: {
                    if selectedResource != nil {
                        Text("No spans found for this resource")
                    } else {
                        Text("No spans found for this attribute")
                    }
                }
            } else {
                List(filteredSpans) { span in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(span.name)
                                .font(.headline)
                            Spacer()
                            Text(formatDuration(span.endTime.timeIntervalSince(span.startTime)))
                                .font(.caption)
                        }
                        Text("Trace: \(span.traceId)")
                            .font(.system(.caption, design: .monospaced))
                        if !span.parentSpanId.isEmpty {
                            Text("Parent: \(span.parentSpanId)")
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .task {
            if let resourceId = selectedResource?.id {
                spans = await dataExplorer.getSpans(forResourceIds: [resourceId])
            } else {
                spans = []
            }
        }
    }
}

private struct LogsTabView: View {
    let selectedResource: DataExplorer.ResourceRow?
    let dataExplorer: DataExplorer
    @State private var logs: [DataExplorer.LogRow] = []
    
    var filteredLogs: [DataExplorer.LogRow] {
        if let selectedResource = selectedResource {
            return logs.filter { $0.resourceId == selectedResource.id }
        }
        return logs
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Logs for \(selectedResource?.id ?? "this attribute")")
                    .font(.headline)
                Spacer()
            }
            .padding()
            
            if filteredLogs.isEmpty {
                ContentUnavailableView {
                    Label("No Logs", systemImage: "text.alignleft")
                } description: {
                    if selectedResource != nil {
                        Text("No logs found for this resource")
                    } else {
                        Text("No logs found for this attribute")
                    }
                }
            } else {
                List(filteredLogs) { log in
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
        .task {
            if let resourceId = selectedResource?.id {
                logs = await dataExplorer.getLogs(forResourceIds: [resourceId])
            } else {
                logs = []
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
