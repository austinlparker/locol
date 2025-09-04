import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SQLQueryView: View {
    let collectorName: String
    @State private var queryExecutor = SQLQueryExecutor()
    @State private var currentQuery = ""
    @State private var selectedTemplate: SQLQueryTemplate?
    @State private var showingTemplates = false
    @State private var showingHistory = false
    @State private var showingExportDialog = false
    @State private var exportFormat: ExportFormat = .csv
    
    var body: some View {
        VStack(spacing: 0) {
            // Query toolbar
            HStack {
                // Templates button
                Button {
                    showingTemplates.toggle()
                } label: {
                    Label("Templates", systemImage: "doc.text.below.ecg")
                }
                .popover(isPresented: $showingTemplates) {
                    templatesPopover
                }
                
                // History button
                Button {
                    showingHistory.toggle()
                } label: {
                    Label("History", systemImage: "clock")
                }
                .popover(isPresented: $showingHistory) {
                    historyPopover
                }
                
                Spacer()
                
                // Export button
                Button {
                    showingExportDialog.toggle()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(queryExecutor.lastResult == nil)
                .fileExporter(
                    isPresented: $showingExportDialog,
                    document: SQLResultDocument(result: queryExecutor.lastResult, format: exportFormat),
                    contentType: exportFormat == .csv ? .commaSeparatedText : .json,
                    defaultFilename: "query_result.\(exportFormat.fileExtension)"
                ) { result in
                    if case .failure(let error) = result {
                        print("Export failed: \(error)")
                    }
                }
                
                // Execute button
                Button {
                    executeQuery()
                } label: {
                    Label("Execute", systemImage: queryExecutor.isExecuting ? "stop.circle" : "play.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(currentQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.return, modifiers: [.command])
            }
            .padding()
            .background(.background.secondary)
            
            HSplitView {
                // Query editor (left side)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("SQL Query")
                            .font(.headline)
                        
                        Spacer()
                        
                        if queryExecutor.isExecuting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    
                    // Query editor
                    SQLQueryEditor(text: $currentQuery)
                        .frame(minHeight: 200)
                    
                    // Query info
                    if let result = queryExecutor.lastResult {
                        HStack {
                            Text("\(result.rowCount) rows")
                            Text("•")
                            Text("\(String(format: "%.2f", result.executionTime))s")
                            Spacer()
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    if let error = queryExecutor.lastError {
                        Text(error.localizedDescription)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .frame(minWidth: 300, idealWidth: 400)
                .padding()
                
                // Results table (right side)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Results")
                            .font(.headline)
                        
                        Spacer()
                        
                        if queryExecutor.lastResult != nil {
                            Picker("Export Format", selection: $exportFormat) {
                                ForEach(ExportFormat.allCases, id: \.self) { format in
                                    Text(format.rawValue).tag(format)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 120)
                        }
                    }
                    
                    if let result = queryExecutor.lastResult {
                        SQLResultsTable(result: result)
                    } else {
                        ContentUnavailableView {
                            Label("No Results", systemImage: "tablecells")
                        } description: {
                            Text("Execute a query to see results here")
                        }
                    }
                }
                .frame(minWidth: 400)
                .padding()
            }
        }
        .navigationTitle("SQL Query - \(collectorName)")
    }
    
    private var templatesPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Query Templates")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(SQLQueryCategory.allCases, id: \.self) { category in
                        if category != .custom {
                            templateSection(for: category)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(width: 400, height: 300)
        }
        .padding(.vertical)
    }
    
    private func templateSection(for category: SQLQueryCategory) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(category.rawValue)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            ForEach(templatesForCategory(category), id: \.name) { template in
                Button {
                    currentQuery = template.query
                    showingTemplates = false
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(template.name)
                            .fontWeight(.medium)
                        Text(template.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func templatesForCategory(_ category: SQLQueryCategory) -> [SQLQueryTemplate] {
        SQLQueryTemplate.templates.filter { $0.category == category }
    }
    
    private var historyPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Query History")
                    .font(.headline)
                
                Spacer()
                
                Button("Clear") {
                    queryExecutor.clearHistory()
                }
                .font(.caption)
            }
            .padding(.horizontal)
            
            if queryExecutor.queryHistory.isEmpty {
                Text("No queries in history")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(queryExecutor.queryHistory.enumerated()), id: \.offset) { index, query in
                            Button {
                                currentQuery = query
                                showingHistory = false
                            } label: {
                                Text(query)
                                    .font(.caption)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(width: 350, height: 200)
            }
        }
        .padding(.vertical)
    }
    
    private func executeQuery() {
        Task {
            await queryExecutor.executeQuery(currentQuery, collectorName: collectorName)
        }
    }
}

// MARK: - SQL Query Editor

struct SQLQueryEditor: NSViewRepresentable {
    @Binding var text: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        textView.isEditable = true
        textView.isSelectable = true
        textView.usesFindPanel = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = .textColor
        textView.backgroundColor = .controlBackgroundColor
        textView.string = text
        
        textView.delegate = context.coordinator
        
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .bezelBorder
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        if textView.string != text {
            textView.string = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: SQLQueryEditor
        
        init(_ parent: SQLQueryEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

// MARK: - SQL Results Table

struct SQLResultsTable: NSViewRepresentable {
    let result: SQLQueryResult
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let tableView = NSTableView()
        
        // Configure table view
        tableView.headerView = NSTableHeaderView()
        tableView.rowSizeStyle = .small
        tableView.allowsMultipleSelection = false
        tableView.usesAlternatingRowBackgroundColors = true
        
        // Add columns
        for (index, column) in result.columns.enumerated() {
            let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "column_\(index)"))
            tableColumn.title = column
            tableColumn.minWidth = 100
            tableView.addTableColumn(tableColumn)
        }
        
        // Set data source
        let dataSource = ResultsDataSource(result: result)
        tableView.dataSource = dataSource
        tableView.delegate = dataSource
        
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .bezelBorder
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tableView = nsView.documentView as? NSTableView else { return }
        tableView.reloadData()
    }
}

// MARK: - Results Data Source

class ResultsDataSource: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    let result: SQLQueryResult
    
    init(result: SQLQueryResult) {
        self.result = result
        super.init()
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        result.rows.count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard let columnId = tableColumn?.identifier.rawValue,
              let columnIndex = Int(columnId.replacingOccurrences(of: "column_", with: "")),
              row < result.rows.count,
              columnIndex < result.rows[row].count else {
            return nil
        }
        
        return result.rows[row][columnIndex]
    }
}

// MARK: - Export Document

struct SQLResultDocument: FileDocument {
    let result: SQLQueryResult?
    let format: ExportFormat
    
    static var readableContentTypes: [UTType] = []
    
    init(result: SQLQueryResult?, format: ExportFormat) {
        self.result = result
        self.format = format
    }
    
    init(configuration: ReadConfiguration) throws {
        self.result = nil
        self.format = .csv
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let result = result else {
            throw SQLQueryError.noResultToExport
        }
        
        let content: String
        switch format {
        case .csv:
            content = formatAsCSV(result)
        case .json:
            content = try formatAsJSON(result)
        }
        
        let data = content.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
    
    private func formatAsCSV(_ result: SQLQueryResult) -> String {
        var lines: [String] = []
        
        // Header
        lines.append(result.columns.joined(separator: ","))
        
        // Rows
        for row in result.rows {
            let escapedRow = row.map { value in
                if value.contains(",") || value.contains("\"") || value.contains("\n") {
                    return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
                } else {
                    return value
                }
            }
            lines.append(escapedRow.joined(separator: ","))
        }
        
        return lines.joined(separator: "\n")
    }
    
    private func formatAsJSON(_ result: SQLQueryResult) throws -> String {
        var jsonRows: [[String: String]] = []
        
        for row in result.rows {
            var jsonRow: [String: String] = [:]
            for (index, column) in result.columns.enumerated() {
                if index < row.count {
                    jsonRow[column] = row[index]
                }
            }
            jsonRows.append(jsonRow)
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: jsonRows, options: .prettyPrinted)
        return String(data: jsonData, encoding: .utf8) ?? ""
    }
}

#Preview {
    SQLQueryView(collectorName: "test-collector")
}