import Foundation

// MARK: - Telemetry Storage Abstraction

protocol TelemetryStorageProtocol: Sendable {
    func storeSpans(_ spans: [StoredSpan]) async throws
    func storeMetrics(_ metrics: [StoredMetric]) async throws
    func storeLogs(_ logs: [StoredLog]) async throws
    func executeQuery(_ sql: String) async throws -> QueryResult
    func getDatabaseStats() async throws -> [CollectorStats]
    func clearData(for collectorName: String) async throws
}

// MARK: - OTLP Server Abstraction

@available(macOS 15.0, *)
protocol OTLPServerProtocol: Sendable {
    func start() async throws
    func stop() async
    func restart() async throws
    func isRunning() async -> Bool
    func getStatistics() async -> ServerStatistics
    func resetStatistics() async
    func incrementTraces(by count: Int) async
    func incrementMetrics(by count: Int) async
    func incrementLogs(by count: Int) async
    func autoStartIfEnabled() async
    func stopOnAppTermination() async
}

// MARK: - Config Snippet Manager Abstraction

@MainActor
protocol ConfigSnippetManaging: AnyObject {
    // Loaded snippets grouped by type
    var snippets: [SnippetType: [ConfigSnippet]] { get }
    // Active config state
    var currentConfig: [String: Any]? { get }
    var previewConfig: String? { get }
    var defaultTemplate: String { get }
    // Load/preview/merge/save config
    func loadConfig(from path: String)
    func previewSnippetMerge(_ snippet: ConfigSnippet, into config: [String: Any]) -> String
    func mergeSnippet(_ snippet: ConfigSnippet) throws
    func saveConfig(to path: String) throws
    // CRUD for user-managed snippets stored in Application Support
    func createSnippet(_ snippet: ConfigSnippet) throws
    func updateSnippet(_ snippet: ConfigSnippet) throws
    func deleteSnippet(_ snippet: ConfigSnippet) throws
    func reloadSnippets()
}
