import SwiftUI
import DuckDB

struct QueryView: View {
    let dataExplorer: DataExplorerProtocol
    @State private var queryText: String = ""
    @State private var queryResult: ResultSet?
    @State private var error: String?
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Query Input
            HStack {
                TextField("Enter SQL query...", text: $queryText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                
                Button {
                    executeQuery()
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
            
            // Results or Error
            if let error = error {
                Text(error)
                    .foregroundStyle(.red)
            } else if let result = queryResult {
                DataTable(result: result)
            }
        }
        .padding()
    }
    
    private func executeQuery() {
        guard !queryText.isEmpty else { return }
        
        Task {
            isLoading = true
            queryResult = nil
            error = nil
            
            do {
                try await Task.sleep(for: .milliseconds(100))
                queryResult = try await dataExplorer.executeQuery(queryText)
                isLoading = false
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
} 