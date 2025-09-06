import SwiftUI
import Charts
import UniformTypeIdentifiers

struct TelemetryView: View {
    let collectorManager: CollectorManager?
    @State private var selectedSignalType: SignalType = .traces
    @State private var viewMode: TelemetryViewMode = .visual
    private let viewer = TelemetryViewer.shared
    
    init(collectorManager: CollectorManager) {
        self.collectorManager = collectorManager
        
        // Set initial collector if available
        let runningCollector = collectorManager.collectors.first(where: { $0.isRunning })?.name
        let firstCollector = collectorManager.collectors.first?.name
        let initialCollector = runningCollector ?? firstCollector ?? "all"
        
        Task { @MainActor in
            TelemetryViewer.shared.selectedCollector = initialCollector
        }
    }
    
    init(collectorName: String) {
        self.collectorManager = nil
        
        Task { @MainActor in
            TelemetryViewer.shared.selectedCollector = collectorName
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Unified toolbar
            unifiedToolbar
            
            // Content area based on view mode
            Group {
                switch viewMode {
                case .visual:
                    visualModeContent
                case .sql:
                    SQLQueryView(collectorName: viewer.selectedCollector)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("OTLP Telemetry")
    }
    
    private var unifiedToolbar: some View {
        VStack(spacing: 8) {
            // Top row: Mode toggle and collector selector
            HStack {
                // View mode toggle
                Picker("View Mode", selection: $viewMode) {
                    ForEach(TelemetryViewMode.allCases, id: \.self) { mode in
                        Label(mode.title, systemImage: mode.iconName)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                
                Spacer()
                
                // Collector selection (only show when collectorManager is available)
                if collectorManager != nil {
                    Menu {
                        Button("All Collectors") {
                            viewer.selectedCollector = "all"
                        }
                        
                        if !viewer.collectorStats.isEmpty {
                            Divider()
                            ForEach(viewer.collectorStats, id: \.collectorName) { stat in
                                Button(stat.collectorName) {
                                    viewer.selectedCollector = stat.collectorName
                                }
                            }
                        }
                    } label: {
                        Label("Collector: \(viewer.selectedCollector)", systemImage: "server.rack")
                    }
                }
            }
            
            // Second row: Visual mode controls (only show in visual mode)
            if viewMode == .visual {
                HStack {
                    // Signal type picker
                    Picker("Signal Type", selection: $selectedSignalType) {
                        ForEach(SignalType.allCases, id: \.self) { signalType in
                            Label {
                                Text(signalType.title)
                            } icon: {
                                Image(systemName: signalType.iconName)
                            }
                            .tag(signalType)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Spacer()
                    
                    // Refresh button
                    Button("Refresh Stats", action: {
                        Task {
                            await viewer.refreshCollectorStats()
                        }
                    })
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(.background.secondary)
    }
    
    
    private var visualModeContent: some View {
        detailContent
    }
    
    
    @ViewBuilder
    private var detailContent: some View {
        switch selectedSignalType {
        case .traces:
            EnhancedTracesView()
        case .metrics:
            EnhancedMetricsView()
        case .logs:
            EnhancedLogsView()
        }
    }
    
}

// MARK: - Signal Types

// MARK: - View Modes

enum TelemetryViewMode: CaseIterable, Hashable {
    case visual
    case sql
    
    var title: String {
        switch self {
        case .visual: return "Visual"
        case .sql: return "SQL"
        }
    }
    
    var iconName: String {
        switch self {
        case .visual: return "chart.xyaxis.line"
        case .sql: return "terminal"
        }
    }
}

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
    @State private var queryTemplate: QueryTemplate?
    private let viewer = TelemetryViewer.shared
    
    var body: some View {
        VStack {
            // Template selector
            HStack {
                Picker("Query Template", selection: $queryTemplate) {
                    Text("Select a template...")
                        .tag(nil as QueryTemplate?)
                    
                    ForEach(viewer.queryTemplates.filter { $0.category == .logs }, id: \.id) { template in
                        Text(template.name)
                            .tag(template as QueryTemplate?)
                    }
                }
                .pickerStyle(.menu)
                
                Spacer()
                
                Button("Execute") {
                    if let template = queryTemplate {
                        Task {
                            await viewer.executeQuery(template.sql)
                        }
                    }
                }
                .disabled(queryTemplate == nil || viewer.isExecutingQuery)
            }
            .padding()
            
            // Results
            if viewer.isExecutingQuery {
                ProgressView("Executing query...")
            } else if let result = viewer.lastQueryResult {
                QueryResultView(result: result)
            } else if let error = viewer.lastQueryError {
                ContentUnavailableView {
                    Label("Query Failed", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error.localizedDescription)
                }
            } else {
                ContentUnavailableView {
                    Label("No Query Executed", systemImage: "doc.text")
                } description: {
                    Text("Select a log template and click Execute")
                }
            }
        }
        .navigationTitle("Logs")
    }
}


struct EnhancedMetricsView: View {
    @State private var queryTemplate: QueryTemplate?
    private let viewer = TelemetryViewer.shared
    
    var body: some View {
        VStack {
            // Template selector
            HStack {
                Picker("Query Template", selection: $queryTemplate) {
                    Text("Select a template...")
                        .tag(nil as QueryTemplate?)
                    
                    ForEach(viewer.queryTemplates.filter { $0.category == .metrics }, id: \.id) { template in
                        Text(template.name)
                            .tag(template as QueryTemplate?)
                    }
                }
                .pickerStyle(.menu)
                
                Spacer()
                
                Button("Execute") {
                    if let template = queryTemplate {
                        Task {
                            await viewer.executeQuery(template.sql)
                        }
                    }
                }
                .disabled(queryTemplate == nil || viewer.isExecutingQuery)
            }
            .padding()
            
            // Results
            if viewer.isExecutingQuery {
                ProgressView("Executing query...")
            } else if let result = viewer.lastQueryResult {
                QueryResultView(result: result)
            } else if let error = viewer.lastQueryError {
                ContentUnavailableView {
                    Label("Query Failed", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error.localizedDescription)
                }
            } else {
                ContentUnavailableView {
                    Label("No Query Executed", systemImage: "chart.line.uptrend.xyaxis")
                } description: {
                    Text("Select a metrics template and click Execute")
                }
            }
        }
        .navigationTitle("Metrics")
    }
}

struct EnhancedTracesView: View {
    @State private var queryTemplate: QueryTemplate?
    private let viewer = TelemetryViewer.shared
    
    var body: some View {
        VStack {
            // Template selector
            HStack {
                Picker("Query Template", selection: $queryTemplate) {
                    Text("Select a template...")
                        .tag(nil as QueryTemplate?)
                    
                    ForEach(viewer.queryTemplates.filter { $0.category == .traces || $0.category == .analysis }, id: \.id) { template in
                        Text(template.name)
                            .tag(template as QueryTemplate?)
                    }
                }
                .pickerStyle(.menu)
                
                Spacer()
                
                Button("Execute") {
                    if let template = queryTemplate {
                        Task {
                            await viewer.executeQuery(template.sql)
                        }
                    }
                }
                .disabled(queryTemplate == nil || viewer.isExecutingQuery)
            }
            .padding()
            
            // Results
            if viewer.isExecutingQuery {
                ProgressView("Executing query...")
            } else if let result = viewer.lastQueryResult {
                QueryResultView(result: result)
            } else if let error = viewer.lastQueryError {
                ContentUnavailableView {
                    Label("Query Failed", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error.localizedDescription)
                }
            } else {
                ContentUnavailableView {
                    Label("No Query Executed", systemImage: "point.3.connected.trianglepath.dotted")
                } description: {
                    Text("Select a trace template and click Execute")
                }
            }
        }
        .navigationTitle("Traces")
    }
}

struct QueryResultView: View {
    let result: QueryResult
    
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    ForEach(result.columns.indices, id: \.self) { index in
                        Text(result.columns[index])
                            .font(.headline)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(minWidth: 100, alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor))
                            .overlay(
                                Rectangle()
                                    .frame(width: 1, height: nil, alignment: .trailing)
                                    .foregroundStyle(.separator),
                                alignment: .trailing
                            )
                    }
                }
                
                // Data rows
                ForEach(result.rows.indices, id: \.self) { rowIndex in
                    HStack(spacing: 0) {
                        ForEach(result.columns.indices, id: \.self) { colIndex in
                            let value = rowIndex < result.rows.count && colIndex < result.rows[rowIndex].count 
                                ? result.rows[rowIndex][colIndex] 
                                : ""
                            
                            Text(value)
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .frame(minWidth: 100, alignment: .leading)
                                .background(rowIndex % 2 == 0 ? Color(NSColor.controlBackgroundColor) : Color(NSColor.alternatingContentBackgroundColors[1]))
                                .overlay(
                                    Rectangle()
                                        .frame(width: 1, height: nil, alignment: .trailing)
                                        .foregroundStyle(.separator),
                                    alignment: .trailing
                                )
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button("Export as CSV") {
                        exportResult(format: .csv)
                    }
                    Button("Export as JSON") {
                        exportResult(format: .json)
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }
        }
    }
    
    private func exportResult(format: ExportFormat) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format == .csv ? .commaSeparatedText : .json]
        panel.nameFieldStringValue = "query_result.\(format.fileExtension)"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try TelemetryViewer.shared.exportResult(to: url, format: format)
                } catch {
                    // Handle error - could show an alert
                    print("Export failed: \(error)")
                }
            }
        }
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