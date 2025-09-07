import XCTest
@testable import locol

final class TelemetryViewerTests: XCTestCase {
    actor FakeStorage: TelemetryStorageProtocol {
        private(set) var lastSQL: String = ""
        var statsToReturn: [CollectorStats] = []
        func storeSpans(_ spans: [StoredSpan]) async throws {}
        func storeMetrics(_ metrics: [StoredMetric]) async throws {}
        func storeLogs(_ logs: [StoredLog]) async throws {}
        func executeQuery(_ sql: String) async throws -> QueryResult {
            lastSQL = sql
            return QueryResult(columns: [], rows: [])
        }
        func getDatabaseStats() async throws -> [CollectorStats] { statsToReturn }
        func clearData(for collectorName: String) async throws {}
    }

    func testCollectorFilterInjection() async throws {
        let storage = FakeStorage()
        let viewer = await MainActor.run { TelemetryViewer(storage: storage) }

        await MainActor.run { viewer.selectedCollector = "my-collector" }
        await viewer.executeQuery("SELECT * FROM spans ORDER BY start_time_nanos DESC LIMIT 10")

        let lastSQL = await storage.lastSQL
        XCTAssertTrue(lastSQL.lowercased().contains("where collector_name = 'my-collector'"))
        XCTAssertTrue(lastSQL.lowercased().contains("order by"))
    }
}

