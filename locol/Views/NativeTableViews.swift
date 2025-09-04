import SwiftUI
import AppKit

// MARK: - LogsTableView

struct LogsTableView: NSViewRepresentable {
    let logs: [TelemetryLog]
    let searchText: String
    @Binding var selectedLog: TelemetryLog?
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let tableView = NSTableView()
        
        // Configure table view
        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.allowsColumnResizing = true
        tableView.allowsColumnSelection = false
        tableView.allowsEmptySelection = true
        tableView.allowsMultipleSelection = false
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.rowHeight = 28 // Fixed height for performance
        tableView.floatsGroupRows = false
        
        // Create columns
        let severityColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("severity"))
        severityColumn.title = "Level"
        severityColumn.width = 60
        severityColumn.minWidth = 60
        severityColumn.maxWidth = 80
        tableView.addTableColumn(severityColumn)
        
        let serviceColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("service"))
        serviceColumn.title = "Service"
        serviceColumn.width = 100
        serviceColumn.minWidth = 80
        serviceColumn.maxWidth = 150
        tableView.addTableColumn(serviceColumn)
        
        let messageColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("message"))
        messageColumn.title = "Message"
        messageColumn.width = 400
        messageColumn.minWidth = 200
        tableView.addTableColumn(messageColumn)
        
        let timestampColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("timestamp"))
        timestampColumn.title = "Time"
        timestampColumn.width = 120
        timestampColumn.minWidth = 100
        timestampColumn.maxWidth = 140
        tableView.addTableColumn(timestampColumn)
        
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        
        context.coordinator.tableView = tableView
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.logs = filteredLogs
        context.coordinator.selectedLog = $selectedLog
        if let tableView = nsView.documentView as? NSTableView {
            tableView.reloadData()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(logs: filteredLogs, selectedLog: $selectedLog)
    }
    
    private var filteredLogs: [TelemetryLog] {
        if searchText.isEmpty {
            return Array(logs.prefix(1000)) // Limit for performance
        } else {
            return Array(logs.filter { log in
                log.body.localizedCaseInsensitiveContains(searchText) ||
                log.severity.displayName.localizedCaseInsensitiveContains(searchText) ||
                (log.attributes["service.name"]?.displayValue.localizedCaseInsensitiveContains(searchText) ?? false)
            }.prefix(1000))
        }
    }
    
    class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var logs: [TelemetryLog]
        var selectedLog: Binding<TelemetryLog?>
        weak var tableView: NSTableView?
        
        init(logs: [TelemetryLog], selectedLog: Binding<TelemetryLog?>) {
            self.logs = logs
            self.selectedLog = selectedLog
        }
        
        // MARK: - NSTableViewDataSource
        
        func numberOfRows(in tableView: NSTableView) -> Int {
            return logs.count
        }
        
        // MARK: - NSTableViewDelegate
        
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row < logs.count else { return nil }
            
            let log = logs[row]
            let identifier = tableColumn?.identifier
            
            let cellView = NSTextField()
            cellView.isBordered = false
            cellView.backgroundColor = .clear
            cellView.font = NSFont.systemFont(ofSize: 13)
            
            switch identifier?.rawValue {
            case "severity":
                cellView.stringValue = log.severity.displayName
                cellView.textColor = severityColor(log.severity)
                cellView.font = NSFont.systemFont(ofSize: 11, weight: .medium)
                
            case "service":
                cellView.stringValue = log.attributes["service.name"]?.displayValue ?? ""
                cellView.textColor = .systemBlue
                cellView.font = NSFont.systemFont(ofSize: 11)
                
            case "message":
                cellView.stringValue = log.body
                cellView.textColor = .labelColor
                cellView.lineBreakMode = .byTruncatingTail
                
            case "timestamp":
                cellView.stringValue = formatTimestamp(log.timestamp)
                cellView.textColor = .secondaryLabelColor
                cellView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
                
            default:
                cellView.stringValue = ""
            }
            
            return cellView
        }
        
        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let tableView = notification.object as? NSTableView else { return }
            
            if tableView.selectedRow >= 0 && tableView.selectedRow < logs.count {
                selectedLog.wrappedValue = logs[tableView.selectedRow]
            } else {
                selectedLog.wrappedValue = nil
            }
        }
        
        // MARK: - Helper Methods
        
        private func severityColor(_ severity: LogSeverity) -> NSColor {
            switch severity {
            case .trace, .debug:
                return .secondaryLabelColor
            case .info:
                return .systemBlue
            case .warn:
                return .systemOrange
            case .error, .fatal:
                return .systemRed
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
}

// MARK: - TracesTableView

struct TracesTableView: NSViewRepresentable {
    let traces: [TraceHierarchy]
    @Binding var selectedTrace: TraceHierarchy?
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let tableView = NSTableView()
        
        // Configure table view
        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.allowsColumnResizing = true
        tableView.allowsColumnSelection = false
        tableView.allowsEmptySelection = true
        tableView.allowsMultipleSelection = false
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.rowHeight = 32 // Fixed height for performance
        tableView.floatsGroupRows = false
        
        // Create columns
        let serviceColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("service"))
        serviceColumn.title = "Service"
        serviceColumn.width = 150
        serviceColumn.minWidth = 100
        tableView.addTableColumn(serviceColumn)
        
        let operationColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("operation"))
        operationColumn.title = "Operation"
        operationColumn.width = 200
        operationColumn.minWidth = 150
        tableView.addTableColumn(operationColumn)
        
        let spansColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("spans"))
        spansColumn.title = "Spans"
        spansColumn.width = 60
        spansColumn.minWidth = 50
        spansColumn.maxWidth = 80
        tableView.addTableColumn(spansColumn)
        
        let durationColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("duration"))
        durationColumn.title = "Duration"
        durationColumn.width = 80
        durationColumn.minWidth = 70
        durationColumn.maxWidth = 100
        tableView.addTableColumn(durationColumn)
        
        let timestampColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("timestamp"))
        timestampColumn.title = "Time"
        timestampColumn.width = 120
        timestampColumn.minWidth = 100
        timestampColumn.maxWidth = 140
        tableView.addTableColumn(timestampColumn)
        
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        
        context.coordinator.tableView = tableView
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.traces = displayedTraces
        context.coordinator.selectedTrace = $selectedTrace
        if let tableView = nsView.documentView as? NSTableView {
            tableView.reloadData()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(traces: displayedTraces, selectedTrace: $selectedTrace)
    }
    
    private var displayedTraces: [TraceHierarchy] {
        Array(traces.prefix(500)) // Limit for performance
    }
    
    class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var traces: [TraceHierarchy]
        var selectedTrace: Binding<TraceHierarchy?>
        weak var tableView: NSTableView?
        
        init(traces: [TraceHierarchy], selectedTrace: Binding<TraceHierarchy?>) {
            self.traces = traces
            self.selectedTrace = selectedTrace
        }
        
        // MARK: - NSTableViewDataSource
        
        func numberOfRows(in tableView: NSTableView) -> Int {
            return traces.count
        }
        
        // MARK: - NSTableViewDelegate
        
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row < traces.count else { return nil }
            
            let trace = traces[row]
            let rootSpan = trace.rootSpans.first
            let identifier = tableColumn?.identifier
            
            let cellView = NSTextField()
            cellView.isBordered = false
            cellView.backgroundColor = .clear
            cellView.font = NSFont.systemFont(ofSize: 13)
            
            switch identifier?.rawValue {
            case "service":
                cellView.stringValue = rootSpan?.serviceName ?? "Unknown"
                cellView.textColor = .labelColor
                cellView.font = NSFont.systemFont(ofSize: 13, weight: .medium)
                
            case "operation":
                cellView.stringValue = rootSpan?.operationName ?? "Unknown"
                cellView.textColor = .secondaryLabelColor
                cellView.lineBreakMode = .byTruncatingTail
                
            case "spans":
                cellView.stringValue = "\(trace.spans.count)"
                cellView.textColor = .secondaryLabelColor
                cellView.font = NSFont.systemFont(ofSize: 11)
                cellView.alignment = .center
                
            case "duration":
                cellView.stringValue = formatDuration(trace.duration)
                cellView.textColor = durationColor(trace.duration)
                cellView.font = NSFont.systemFont(ofSize: 11, weight: .medium)
                
            case "timestamp":
                if let rootSpan = rootSpan {
                    cellView.stringValue = formatTimestamp(rootSpan.startTime)
                    cellView.textColor = .secondaryLabelColor
                    cellView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
                }
                
            default:
                cellView.stringValue = ""
            }
            
            return cellView
        }
        
        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let tableView = notification.object as? NSTableView else { return }
            
            if tableView.selectedRow >= 0 && tableView.selectedRow < traces.count {
                selectedTrace.wrappedValue = traces[tableView.selectedRow]
            } else {
                selectedTrace.wrappedValue = nil
            }
        }
        
        // MARK: - Helper Methods
        
        private func formatDuration(_ duration: Int64) -> String {
            if duration > 1_000_000_000 {
                return String(format: "%.1fs", Double(duration) / 1_000_000_000)
            } else if duration > 1_000_000 {
                return String(format: "%.1fms", Double(duration) / 1_000_000)
            } else {
                return String(format: "%.1fμs", Double(duration) / 1_000)
            }
        }
        
        private func durationColor(_ duration: Int64) -> NSColor {
            if duration > 5_000_000_000 { return .systemRed }
            else if duration > 1_000_000_000 { return .systemOrange }
            else if duration > 100_000_000 { return .systemYellow }
            else { return .systemGreen }
        }
        
        private func formatTimestamp(_ timestamp: Int64) -> String {
            let date = Date(timeIntervalSince1970: Double(timestamp) / 1_000_000_000)
            let formatter = DateFormatter()
            formatter.timeStyle = .medium
            formatter.dateStyle = .none
            return formatter.string(from: date)
        }
    }
}

// MARK: - MetricsTableView (Compact Design)

struct MetricsTableView: NSViewRepresentable {
    let metrics: [TelemetryMetricGroup]
    @Binding var selectedMetric: TelemetryMetricGroup?
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let tableView = NSTableView()
        
        // Configure table view
        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.allowsColumnResizing = true
        tableView.allowsColumnSelection = false
        tableView.allowsEmptySelection = true
        tableView.allowsMultipleSelection = false
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.rowHeight = 36 // Compact row height
        tableView.floatsGroupRows = false
        
        // Create columns
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Metric Name"
        nameColumn.width = 200
        nameColumn.minWidth = 150
        tableView.addTableColumn(nameColumn)
        
        let typeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        typeColumn.title = "Type"
        typeColumn.width = 80
        typeColumn.minWidth = 60
        typeColumn.maxWidth = 100
        tableView.addTableColumn(typeColumn)
        
        let valueColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("value"))
        valueColumn.title = "Latest Value"
        valueColumn.width = 120
        valueColumn.minWidth = 100
        tableView.addTableColumn(valueColumn)
        
        let labelsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("labels"))
        labelsColumn.title = "Labels"
        labelsColumn.width = 200
        labelsColumn.minWidth = 150
        tableView.addTableColumn(labelsColumn)
        
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        
        context.coordinator.tableView = tableView
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.metrics = displayedMetrics
        context.coordinator.selectedMetric = $selectedMetric
        if let tableView = nsView.documentView as? NSTableView {
            tableView.reloadData()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(metrics: displayedMetrics, selectedMetric: $selectedMetric)
    }
    
    private var displayedMetrics: [TelemetryMetricGroup] {
        Array(metrics.prefix(1000)) // Higher limit for table performance
    }
    
    class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var metrics: [TelemetryMetricGroup]
        var selectedMetric: Binding<TelemetryMetricGroup?>
        weak var tableView: NSTableView?
        
        init(metrics: [TelemetryMetricGroup], selectedMetric: Binding<TelemetryMetricGroup?>) {
            self.metrics = metrics
            self.selectedMetric = selectedMetric
        }
        
        // MARK: - NSTableViewDataSource
        
        func numberOfRows(in tableView: NSTableView) -> Int {
            return metrics.count
        }
        
        // MARK: - NSTableViewDelegate
        
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row < metrics.count else { return nil }
            
            let metric = metrics[row]
            let identifier = tableColumn?.identifier
            
            let cellView = NSTextField()
            cellView.isBordered = false
            cellView.backgroundColor = .clear
            cellView.font = NSFont.systemFont(ofSize: 13)
            
            switch identifier?.rawValue {
            case "name":
                cellView.stringValue = metric.name
                cellView.textColor = .labelColor
                cellView.font = NSFont.systemFont(ofSize: 13, weight: .medium)
                cellView.lineBreakMode = .byTruncatingTail
                
            case "type":
                cellView.stringValue = metric.type.rawValue.uppercased()
                cellView.textColor = metricTypeColor(metric.type)
                cellView.font = NSFont.systemFont(ofSize: 10, weight: .bold)
                cellView.alignment = .center
                
            case "value":
                if let latestValue = metric.latestValue {
                    cellView.stringValue = formatMetricValue(latestValue)
                } else {
                    cellView.stringValue = "—"
                }
                cellView.textColor = .labelColor
                cellView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
                cellView.alignment = .right
                
            case "labels":
                let labelStrings = metric.labels.map { "\($0.key)=\($0.value)" }
                cellView.stringValue = labelStrings.joined(separator: ", ")
                cellView.textColor = .secondaryLabelColor
                cellView.font = NSFont.systemFont(ofSize: 11)
                cellView.lineBreakMode = .byTruncatingTail
                
            default:
                cellView.stringValue = ""
            }
            
            return cellView
        }
        
        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let tableView = notification.object as? NSTableView else { return }
            
            if tableView.selectedRow >= 0 && tableView.selectedRow < metrics.count {
                selectedMetric.wrappedValue = metrics[tableView.selectedRow]
            } else {
                selectedMetric.wrappedValue = nil
            }
        }
        
        // MARK: - Helper Methods
        
        private func metricTypeColor(_ type: TelemetryMetric.MetricType) -> NSColor {
            switch type {
            case .counter: return .systemBlue
            case .gauge: return .systemGreen
            case .histogram: return .systemPurple
            case .summary: return .systemOrange
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
}

// MARK: - TraceWaterfallOutlineView

struct TraceWaterfallOutlineView: NSViewRepresentable {
    let hierarchy: TraceHierarchy
    @Binding var expandedSpans: Set<String>
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let outlineView = NSOutlineView()
        
        // Configure outline view
        outlineView.dataSource = context.coordinator
        outlineView.delegate = context.coordinator
        outlineView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        outlineView.allowsColumnResizing = true
        outlineView.allowsColumnSelection = false
        outlineView.allowsEmptySelection = true
        outlineView.allowsMultipleSelection = false
        outlineView.intercellSpacing = NSSize(width: 0, height: 0)
        outlineView.rowHeight = 28
        outlineView.indentationPerLevel = 16
        outlineView.floatsGroupRows = false
        
        // Create columns
        let operationColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("operation"))
        operationColumn.title = "Operation"
        operationColumn.width = 250
        operationColumn.minWidth = 200
        outlineView.addTableColumn(operationColumn)
        outlineView.outlineTableColumn = operationColumn
        
        let serviceColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("service"))
        serviceColumn.title = "Service"
        serviceColumn.width = 120
        serviceColumn.minWidth = 100
        serviceColumn.maxWidth = 150
        outlineView.addTableColumn(serviceColumn)
        
        let durationColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("duration"))
        durationColumn.title = "Duration"
        durationColumn.width = 100
        durationColumn.minWidth = 80
        durationColumn.maxWidth = 120
        outlineView.addTableColumn(durationColumn)
        
        let startTimeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("startTime"))
        startTimeColumn.title = "Start Time"
        startTimeColumn.width = 120
        startTimeColumn.minWidth = 100
        startTimeColumn.maxWidth = 140
        outlineView.addTableColumn(startTimeColumn)
        
        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        
        context.coordinator.outlineView = outlineView
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.hierarchy = hierarchy
        context.coordinator.expandedSpans = $expandedSpans
        if let outlineView = nsView.documentView as? NSOutlineView {
            outlineView.reloadData()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(hierarchy: hierarchy, expandedSpans: $expandedSpans)
    }
    
    class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
        var hierarchy: TraceHierarchy
        var expandedSpans: Binding<Set<String>>
        weak var outlineView: NSOutlineView?
        
        init(hierarchy: TraceHierarchy, expandedSpans: Binding<Set<String>>) {
            self.hierarchy = hierarchy
            self.expandedSpans = expandedSpans
        }
        
        // MARK: - NSOutlineViewDataSource
        
        func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            if item == nil {
                // Root level - return root spans
                return hierarchy.rootSpans.count
            }
            
            if let span = item as? TelemetrySpan {
                return childSpans(for: span).count
            }
            
            return 0
        }
        
        func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            if item == nil {
                // Root level
                return hierarchy.rootSpans[index]
            }
            
            if let span = item as? TelemetrySpan {
                return childSpans(for: span)[index]
            }
            
            return NSNull()
        }
        
        func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
            if let span = item as? TelemetrySpan {
                return !childSpans(for: span).isEmpty
            }
            return false
        }
        
        // MARK: - NSOutlineViewDelegate
        
        func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
            guard let span = item as? TelemetrySpan else { return nil }
            
            let identifier = tableColumn?.identifier
            
            let cellView = NSTextField()
            cellView.isBordered = false
            cellView.backgroundColor = .clear
            cellView.font = NSFont.systemFont(ofSize: 13)
            
            switch identifier?.rawValue {
            case "operation":
                cellView.stringValue = span.operationName ?? "Unknown Operation"
                cellView.textColor = .labelColor
                cellView.font = NSFont.systemFont(ofSize: 13, weight: .medium)
                cellView.lineBreakMode = .byTruncatingTail
                
            case "service":
                cellView.stringValue = span.serviceName ?? ""
                cellView.textColor = .systemBlue
                cellView.font = NSFont.systemFont(ofSize: 11)
                cellView.lineBreakMode = .byTruncatingTail
                
            case "duration":
                cellView.stringValue = formatDuration(span.duration)
                cellView.textColor = durationColor(span.duration)
                cellView.font = NSFont.systemFont(ofSize: 11, weight: .medium)
                cellView.alignment = .right
                
            case "startTime":
                cellView.stringValue = formatTimestamp(span.startTime)
                cellView.textColor = .secondaryLabelColor
                cellView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
                
            default:
                cellView.stringValue = ""
            }
            
            return cellView
        }
        
        func outlineView(_ outlineView: NSOutlineView, shouldExpandItem item: Any) -> Bool {
            if let span = item as? TelemetrySpan {
                expandedSpans.wrappedValue.insert(span.spanId)
            }
            return true
        }
        
        func outlineView(_ outlineView: NSOutlineView, shouldCollapseItem item: Any) -> Bool {
            if let span = item as? TelemetrySpan {
                expandedSpans.wrappedValue.remove(span.spanId)
            }
            return true
        }
        
        // MARK: - Helper Methods
        
        private func childSpans(for parent: TelemetrySpan) -> [TelemetrySpan] {
            return hierarchy.spans.filter { $0.parentSpanId == parent.spanId }
                .sorted(by: { $0.startTime < $1.startTime })
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
        
        private func durationColor(_ duration: Int64) -> NSColor {
            if duration > 5_000_000_000 { return .systemRed }
            else if duration > 1_000_000_000 { return .systemOrange }
            else if duration > 100_000_000 { return .systemYellow }
            else { return .systemGreen }
        }
        
        private func formatTimestamp(_ timestamp: Int64) -> String {
            let date = Date(timeIntervalSince1970: Double(timestamp) / 1_000_000_000)
            let formatter = DateFormatter()
            formatter.timeStyle = .medium
            formatter.dateStyle = .none
            return formatter.string(from: date)
        }
    }
}