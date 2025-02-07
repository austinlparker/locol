import SwiftUI
import TabularData

// MARK: - Table Configurations

enum Tab: String, CaseIterable {
    case resources, query
    
    var systemImage: String {
        switch self {
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
            ResourceExplorerView(dataExplorer: dataExplorer)
                .tabItem {
                    Label("Resources", systemImage: Tab.resources.systemImage)
                }
                .tag(Tab.resources)
            
            // Query tab
            ExplorerQueryView(dataExplorer: dataExplorer)
                .tabItem {
                    Label("Query", systemImage: Tab.query.systemImage)
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

            ToolbarItem(placement: .status) {
                Text("Port: \(dataExplorer.serverPort)")
                    .foregroundStyle(.secondary)
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
