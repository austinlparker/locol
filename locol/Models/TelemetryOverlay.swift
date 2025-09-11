import Foundation

// Strongly-typed overlay model for service.telemetry emitted into collector YAML.
// We keep this separate from component/pipeline models because the telemetry
// section is not part of the component graph.

struct TelemetryHeader {
    let name: String
    let value: String
}

struct OTLPTelemetryExporter {
    let endpoint: String
    let insecure: Bool
    let protocolName: String // e.g. "grpc" or "http/protobuf"
    let headers: [TelemetryHeader]

    func asDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "endpoint": endpoint,
            "insecure": insecure,
            // Collector requires an array of {key,value} pairs
            "headers": headers.map { ["name": $0.name, "value": $0.value] }
        ]
        dict["protocol"] = protocolName
        return dict
    }
}

struct TelemetryTraces {
    // processors: [ { batch: { exporter: { otlp: {...} } } } ]
    let processors: [[String: Any]]

    func asDictionary() -> [String: Any] {
        [ "processors": processors ]
    }
}

struct TelemetryLogs {
    // processors: [ { batch: { exporter: { otlp: {...} } } } ]
    let processors: [[String: Any]]

    func asDictionary() -> [String: Any] {
        [ "processors": processors ]
    }
}

struct TelemetryMetrics {
    let level: String?
    // readers: [ { periodic: { exporter: { otlp: {...} } } } ]
    let readers: [[String: Any]]

    func asDictionary() -> [String: Any] {
        var dict: [String: Any] = ["readers": readers]
        if let level { dict["level"] = level }
        return dict
    }
}

struct TelemetryOverlayModel {
    let traces: TelemetryTraces?
    let metrics: TelemetryMetrics?
    let logs: TelemetryLogs?

    func asDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let traces { dict["traces"] = traces.asDictionary() }
        if let metrics { dict["metrics"] = metrics.asDictionary() }
        if let logs { dict["logs"] = logs.asDictionary() }
        return dict
    }
}
