import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SQLQueryView: View {
    let collectorName: String
    @State private var currentQuery = ""
    @State private var selectedTemplate: QueryTemplate?
    @State private var showingTemplates = false
    @State private var showingExportDialog = false
    @State private var exportFormat: ExportFormat = .csv
    private let viewer = TelemetryViewer.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Query toolbar
            HStack {
                Text("Collector: \(viewer.selectedCollector)")
                    .font(.headline)
                
                Spacer()
                
                // Templates button
                Button {
                    showingTemplates.toggle()
                } label: {
                    Label("Templates", systemImage: "doc.text.below.ecg")
                }
                .popover(isPresented: $showingTemplates) {
                    templatesPopover
                }
                
                // Export button
                Button {
                    showingExportDialog.toggle()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(viewer.lastQueryResult == nil)
                .fileExporter(
                    isPresented: $showingExportDialog,
                    document: SQLResultDocument(result: viewer.lastQueryResult, format: exportFormat),
                    contentType: exportFormat == .csv ? .commaSeparatedText : .json,
                    defaultFilename: "query_result"
                ) { result in
                    switch result {
                    case .success(let url):
                        print("Exported to: \(url)")
                    case .failure(let error):
                        print("Export failed: \(error)")
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Query input area
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("SQL Query")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("Collector: \(viewer.selectedCollector)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $currentQuery)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                    
                    if currentQuery.isEmpty {
                        Text("Enter your SQL query here...")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 16)
                            .padding(.leading, 12)
                            .allowsHitTesting(false)
                    }
                }
                .frame(height: 120)
                
                HStack {
                    Button("Execute Query") {
                        Task {
                            await viewer.executeQuery(currentQuery)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(currentQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewer.isExecutingQuery)
                    
                    if viewer.isExecutingQuery {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Executing...")
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Clear Results") {
                        // Clear the current result
                    }
                    .disabled(viewer.lastQueryResult == nil)
                }
            }
            .padding()
            
            Divider()
            
            // Results area
            if let error = viewer.lastQueryError {
                VStack(spacing: 8) {
                    Label("Query Error", systemImage: "exclamationmark.triangle")
                        .font(.headline)
                        .foregroundStyle(.red)
                    
                    Text(error.localizedDescription)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if let result = viewer.lastQueryResult {
                queryResultsView(result)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "tablecells")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    
                    Text("No query results")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    
                    Text("Enter and execute a SQL query to see results here")
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("SQL Query")
        .onAppear {
            viewer.selectedCollector = collectorName
            Task {
                await viewer.refreshCollectorStats()
            }
        }
    }
    
    private var templatesPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Query Templates")
                .font(.headline)
                .padding(.bottom, 4)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(viewer.queryTemplates, id: \.id) { template in
                        Button {
                            currentQuery = template.sql
                            selectedTemplate = template
                            showingTemplates = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(template.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text(template.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                    
                                    Text("Category: \(template.category.rawValue)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 8)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .frame(height: 200)
        }
        .padding()
        .frame(width: 350)
    }
    
    private func queryResultsView(_ result: QueryResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Query Results")
                    .font(.headline)
                
                Spacer()
                
                Text("\(result.rows.count) rows")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top)
            
            if result.columns.isEmpty {
                Text("Query executed successfully (no results)")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                queryResultsTable(result)
            }
        }
    }
    
    private func queryResultsTable(_ result: QueryResult) -> some View {
        NativeTableView(result: result)
    }
    
    private func queryPreview(_ query: String) -> String {
        let lines = query.components(separatedBy: .newlines)
        let firstLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return firstLine.count > 50 ? String(firstLine.prefix(50)) + "..." : firstLine
    }
}

// MARK: - Export Support

struct SQLResultDocument: FileDocument {
    static let readableContentTypes: [UTType] = []
    
    let result: QueryResult?
    let format: ExportFormat
    
    init(result: QueryResult?, format: ExportFormat) {
        self.result = result
        self.format = format
    }
    
    init(configuration: ReadConfiguration) throws {
        self.result = nil
        self.format = .csv
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let result = result else {
            throw CocoaError(.fileWriteNoPermission)
        }
        
        let content: String
        switch format {
        case .csv:
            content = exportAsCSV(result)
        case .json:
            content = exportAsJSON(result)
        }
        
        return FileWrapper(regularFileWithContents: Data(content.utf8))
    }
    
    private func exportAsCSV(_ result: QueryResult) -> String {
        var csv = result.columns.joined(separator: ",") + "\n"
        
        for row in result.rows {
            let escapedRow = row.map { value in
                if value.contains(",") || value.contains("\"") || value.contains("\n") {
                    return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
                }
                return value
            }
            csv += escapedRow.joined(separator: ",") + "\n"
        }
        
        return csv
    }
    
    private func exportAsJSON(_ result: QueryResult) -> String {
        let jsonArray = result.rows.map { row in
            Dictionary(uniqueKeysWithValues: zip(result.columns, row))
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonArray, options: [.prettyPrinted])
            return String(data: jsonData, encoding: .utf8) ?? "[]"
        } catch {
            return "[]"
        }
    }
}