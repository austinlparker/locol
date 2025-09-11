import XCTest
@testable import locol

final class CollectorStoreTests: XCTestCase {
    private func makeTempDBURL() -> URL {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("locol-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return tmp.appendingPathComponent("telemetry.db")
    }

    func testCreateListAndConfigVersioning() async throws {
        let dbURL = makeTempDBURL()
        let store = CollectorStore(databaseURL: dbURL)

        // Given a default typed config
        let defaultConfig = CollectorConfiguration(version: "v0.100.0")

        // When creating a collector
        let (collectorId, versionId) = try await store.createCollector(
            name: "alpha",
            version: "v0.100.0",
            binaryPath: "/usr/local/bin/otelcol",
            defaultConfig: defaultConfig
        )

        // Then it appears in the listing
        let list = try await store.listCollectors()
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list.first?.name, "alpha")
        XCTAssertEqual(list.first?.isRunning, false)

        // And current config can be fetched
        let current = try await store.getCurrentConfig(collectorId)
        XCTAssertNotNil(current)
        XCTAssertEqual(current?.versionId, versionId)

        // Saving a new version increments rev and does not change current automatically
        var updated = defaultConfig
        // no-op change; we just want a new version row
        let newVersionId = try await store.saveConfigVersion(collectorId, config: updated, autosave: false)
        let versions = try await store.getConfigVersions(collectorId)
        XCTAssertEqual(versions.count, 2)
        XCTAssertTrue(versions.contains { $0.id == newVersionId && $0.rev == 2 })

        // Switch current to the new version
        try await store.setCurrentConfig(collectorId, versionId: newVersionId)
        let current2 = try await store.getCurrentConfig(collectorId)
        XCTAssertEqual(current2?.versionId, newVersionId)

        // Mark running and then stopped
        try await store.markRunning(collectorId, start: Date())
        var rec = try await store.getCollector(collectorId)
        XCTAssertEqual(rec?.isRunning, true)
        try await store.markStopped(collectorId)
        rec = try await store.getCollector(collectorId)
        XCTAssertEqual(rec?.isRunning, false)

        // Update flags
        try await store.updateFlags(collectorId, flags: "--set foo=bar")
        rec = try await store.getCollector(collectorId)
        XCTAssertEqual(rec?.flags, "--set foo=bar")

        // Delete
        try await store.deleteCollector(collectorId)
        let listAfterDelete = try await store.listCollectors()
        XCTAssertTrue(listAfterDelete.isEmpty)
    }
}

