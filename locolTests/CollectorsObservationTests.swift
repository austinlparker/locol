import XCTest
@testable import locol

final class CollectorsObservationTests: XCTestCase {
    private func makeTempDBURL() -> URL {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("locol-tests-obs-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return tmp.appendingPathComponent("telemetry.db")
    }

    func testObserveCollectorsEmitsOnChange() async throws {
        let dbURL = makeTempDBURL()
        let store = CollectorStore(databaseURL: dbURL)

        // Start observation and obtain an iterator
        let stream = await store.observeCollectors()
        var iterator = stream.makeAsyncIterator()

        // Consume initial emission (may be empty)
        _ = await iterator.next()

        // Create a collector to trigger a change emission
        _ = try await store.createCollector(
            name: "obs-alpha",
            version: "v0.1.0",
            binaryPath: "/tmp/otelcol",
            defaultConfig: CollectorConfiguration(version: "v0.1.0")
        )

        // Next emission should include the new collector
        let next = await iterator.next()
        XCTAssertNotNil(next)
        XCTAssertTrue(next?.contains(where: { $0.name == "obs-alpha" }) == true)
    }
}
