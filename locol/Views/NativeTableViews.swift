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

// MARK: - MetricsCollectionView

struct MetricsCollectionView: NSViewRepresentable {
    let metrics: [TelemetryMetricGroup]
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let collectionView = NSCollectionView()
        
        // Configure collection view for grid layout
        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.itemSize = NSSize(width: 280, height: 160)
        flowLayout.minimumInteritemSpacing = 16
        flowLayout.minimumLineSpacing = 16
        flowLayout.sectionInset = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        
        collectionView.collectionViewLayout = flowLayout
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.backgroundColors = [.controlBackgroundColor]
        
        // Register the item class
        collectionView.register(MetricCardItem.self, forItemWithIdentifier: NSUserInterfaceItemIdentifier("MetricCard"))
        
        scrollView.documentView = collectionView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        
        context.coordinator.collectionView = collectionView
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.metrics = displayedMetrics
        if let collectionView = nsView.documentView as? NSCollectionView {
            collectionView.reloadData()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(metrics: displayedMetrics)
    }
    
    private var displayedMetrics: [TelemetryMetricGroup] {
        Array(metrics.prefix(200)) // Limit for performance
    }
    
    class Coordinator: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate {
        var metrics: [TelemetryMetricGroup]
        weak var collectionView: NSCollectionView?
        
        init(metrics: [TelemetryMetricGroup]) {
            self.metrics = metrics
        }
        
        // MARK: - NSCollectionViewDataSource
        
        func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
            return metrics.count
        }
        
        func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
            let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier("MetricCard"), for: indexPath) as! MetricCardItem
            if indexPath.item < metrics.count {
                item.configure(with: metrics[indexPath.item])
            }
            return item
        }
    }
}

// MARK: - MetricCardItem

class MetricCardItem: NSCollectionViewItem {
    private let titleLabel = NSTextField()
    private let valueLabel = NSTextField()
    private let typeLabel = NSTextField()
    private let containerView = NSView()
    
    override func loadView() {
        view = NSView()
        setupViews()
    }
    
    private func setupViews() {
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        containerView.layer?.cornerRadius = 8
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.backgroundColor = .clear
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        valueLabel.isEditable = false
        valueLabel.isBordered = false
        valueLabel.backgroundColor = .clear
        valueLabel.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        typeLabel.isEditable = false
        typeLabel.isBordered = false
        typeLabel.backgroundColor = .clear
        typeLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        typeLabel.textColor = .white
        typeLabel.alignment = .center
        typeLabel.wantsLayer = true
        typeLabel.layer?.cornerRadius = 8
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(valueLabel)
        containerView.addSubview(typeLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            typeLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            typeLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            typeLabel.widthAnchor.constraint(equalToConstant: 60),
            typeLabel.heightAnchor.constraint(equalToConstant: 20),
            
            titleLabel.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            
            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            valueLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            valueLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
        ])
    }
    
    func configure(with metric: TelemetryMetricGroup) {
        titleLabel.stringValue = metric.name
        
        if let latestValue = metric.latestValue {
            valueLabel.stringValue = formatMetricValue(latestValue)
        } else {
            valueLabel.stringValue = "—"
        }
        
        typeLabel.stringValue = metric.type.rawValue.uppercased()
        typeLabel.layer?.backgroundColor = metricTypeColor(metric.type).cgColor
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
    
    private func metricTypeColor(_ type: TelemetryMetric.MetricType) -> NSColor {
        switch type {
        case .counter: return .systemBlue
        case .gauge: return .systemGreen
        case .histogram: return .systemPurple
        case .summary: return .systemOrange
        }
    }
}