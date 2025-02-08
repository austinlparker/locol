import Foundation
import DuckDB

protocol DataExplorerProtocol {
    var isRunning: Bool { get }
    var error: Error? { get }
    var serverPort: UInt16 { get }
    
    // Model data
    var metrics: [MetricRow] { get }
    var logs: [LogRow] { get }
    var spans: [SpanRow] { get }
    var resources: [ResourceRow] { get }
    
    // Helper computed properties
    var metricColumns: [String] { get }
    var logColumns: [String] { get }
    var spanColumns: [String] { get }
    var resourceColumns: [String] { get }
    
    // Server control
    func start() async throws
    func stop() async
    
    // Data access
    func getResourceGroups() async -> [ResourceAttributeGroup]
    func getResourceIds(forGroup group: ResourceAttributeGroup) async -> [String]
    func getMetrics(forResourceIds resourceIds: [String]) async -> [MetricRow]
    func getLogs(forResourceIds resourceIds: [String]) async -> [LogRow]
    func getSpans(forResourceIds resourceIds: [String]) async -> [SpanRow]
    
    // Query execution
    func executeQuery(_ query: String) async throws -> ResultSet
} 