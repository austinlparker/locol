import SwiftUI
import DuckDB

struct DataTable: View {
    let result: ResultSet
    
    private var columnData: [(name: String, values: [String])] {
        (0..<Int(result.columnCount)).map { colIndex in
            let name = result.columnName(at: UInt64(colIndex))
            let values = result.column(at: UInt64(colIndex)).cast(to: String.self)
            return (name: name, values: (0..<Int(result.rowCount)).map { rowIndex in
                values[UInt64(rowIndex)] ?? "null"
            })
        }
    }
    
    var body: some View {
        if result.rowCount == 0 {
            ContentUnavailableView {
                Label("No Results", systemImage: "magnifyingglass")
            } description: {
                Text("No results found")
            }
        } else {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 20) {
                    ForEach(Array(columnData.enumerated()), id: \.0) { _, column in
                        VStack(alignment: .leading) {
                            Text(column.name)
                                .font(.headline)
                            ForEach(Array(column.values.enumerated()), id: \.0) { _, value in
                                Text(value)
                                    .textSelection(.enabled)
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }
} 
