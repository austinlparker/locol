import SwiftUI

/// SwiftUI wrapper that displays query results using the high‑performance NSTableView wrapper
/// This avoids SwiftUI Table's current limitations with dynamic columns.
struct QueryResultTable: View {
    let result: QueryResult

    var body: some View {
        if result.rows.isEmpty {
            ContentUnavailableView(
                "No Results",
                systemImage: "tablecells",
                description: Text("The query returned no rows.")
            )
        } else {
            NativeTableView(result: result)
        }
    }
}

#Preview {
    let sampleResult = QueryResult(
        columns: ["ID", "Name", "Value", "Timestamp"],
        rows: [
            ["1", "Sample Row 1", "100.5", "2024-01-01 10:00:00"],
            ["2", "Sample Row 2", "200.7", "2024-01-01 10:01:00"],
            ["3", "Sample Row 3", "300.2", "2024-01-01 10:02:00"],
        ]
    )

    QueryResultTable(result: sampleResult)
        .frame(width: 600, height: 400)
}
