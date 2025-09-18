import XCTest
@testable import locol

final class ConfigSerializerOverlayTests: XCTestCase {
    func testTelemetryOverlayInjection() throws {
        var cfg = CollectorConfiguration(version: "v0.100.0")
        // Add minimal component definitions and instances so service exists
        let recvDef = Component(
            id: 1,
            name: "otlp",
            type: .receiver,
            description: nil,
            version: "v0.100.0"
        )
        let expDef = Component(
            id: 2,
            name: "debug",
            type: .exporter,
            description: nil,
            version: "v0.100.0"
        )
        let recv = ComponentInstance(component: recvDef, name: "otlp")
        let exp = ComponentInstance(component: expDef, name: "debug")
        cfg.receivers = [recv]
        cfg.exporters = [exp]
        cfg.pipelines = [PipelineConfiguration(name: "traces", receivers: [recv], processors: [], exporters: [exp])]

        let settings = OverlaySettings(
            grpcEndpoint: "127.0.0.1:4317",
            tracesEnabled: true,
            metricsEnabled: true,
            logsEnabled: true
        )
        let yaml = try ConfigSerializer.generateYAML(from: cfg, overlayTelemetryFor: "alpha", settings: settings)
        
        // Verify that the overlay content is present
        XCTAssertTrue(yaml.contains("service:"))
        XCTAssertTrue(yaml.contains("telemetry:"))
        XCTAssertTrue(yaml.contains("collector-name: alpha"))
        XCTAssertTrue(yaml.contains("endpoint: 127.0.0.1:4317"))
    }
}
