import Foundation
import DuckDB

struct DateUtils {
    static func convertDate(_ duckDate: DuckDB.Date?) -> Foundation.Date? {
        guard let duckDate = duckDate else { return nil }
        // DuckDB.Date stores microseconds since Unix epoch
        return Foundation.Date(duckDate)
    }
    
    static func formatDate(_ date: Foundation.Date) -> String {
        date.formatted()
    }
} 