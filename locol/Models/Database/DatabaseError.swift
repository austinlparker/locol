import Foundation

enum DatabaseError: Error {
    case connectionFailed
    case queryFailed(String)
    case appenderFailedToInitialize(reason: String?)
    case appenderFailedToAppendItem(reason: String?)
    
    var localizedDescription: String {
        switch self {
        case .connectionFailed:
            return "Failed to establish database connection"
        case .queryFailed(let reason):
            return "Query execution failed: \(reason)"
        case .appenderFailedToInitialize(let reason):
            return "Failed to initialize appender: \(reason ?? "unknown reason")"
        case .appenderFailedToAppendItem(let reason):
            return "Failed to append item: \(reason ?? "unknown reason")"
        }
    }
} 