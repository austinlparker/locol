import XCTest
@testable import locol

final class MetricCollectionTests: XCTestCase {
    
    func testEmptyCollection() {
        let collection = MetricCollection(metrics: [:])
        XCTAssertTrue(collection.histograms.isEmpty)
        XCTAssertTrue(collection.regular.isEmpty)
    }
    
    func testRegularMetricsCollection() {
        var metrics: [String: TimeSeriesData] = [:]
        
        // Add some regular metrics
        let counter = TimeSeriesData(
            name: "http_requests_total",
            labels: ["method": "GET"],
            values: [(timestamp: Date(), value: 100, labels: ["method": "GET"])],
            definition: MetricDefinition(name: "http_requests_total", description: "", type: .counter)
        )
        
        let gauge = TimeSeriesData(
            name: "memory_usage",
            labels: ["type": "heap"],
            values: [(timestamp: Date(), value: 1024, labels: ["type": "heap"])],
            definition: MetricDefinition(name: "memory_usage", description: "", type: .gauge)
        )
        
        metrics[MetricKeyGenerator.generateKey(name: counter.name, labels: counter.labels)] = counter
        metrics[MetricKeyGenerator.generateKey(name: gauge.name, labels: gauge.labels)] = gauge
        
        let collection = MetricCollection(metrics: metrics)
        
        XCTAssertTrue(collection.histograms.isEmpty)
        XCTAssertEqual(collection.regular.count, 2)
        XCTAssertTrue(collection.regular.contains { $0.name == "http_requests_total" })
        XCTAssertTrue(collection.regular.contains { $0.name == "memory_usage" })
    }
    
    func testHistogramCollection() {
        var metrics: [String: TimeSeriesData] = [:]
        
        // Create histogram components
        let histogramBucket1 = TimeSeriesData(
            name: "request_duration_bucket",
            labels: ["le": "0.1"],
            values: [(timestamp: Date(), value: 10, labels: ["le": "0.1"])],
            definition: MetricDefinition(name: "request_duration", description: "", type: .histogram)
        )
        
        let histogramBucket2 = TimeSeriesData(
            name: "request_duration_bucket",
            labels: ["le": "0.5"],
            values: [(timestamp: Date(), value: 20, labels: ["le": "0.5"])],
            definition: MetricDefinition(name: "request_duration", description: "", type: .histogram)
        )
        
        let histogramSum = TimeSeriesData(
            name: "request_duration_sum",
            labels: [:],
            values: [(timestamp: Date(), value: 15.5, labels: [:])],
            definition: MetricDefinition(name: "request_duration", description: "", type: .histogram)
        )
        
        let histogramCount = TimeSeriesData(
            name: "request_duration_count",
            labels: [:],
            values: [(timestamp: Date(), value: 30, labels: [:])],
            definition: MetricDefinition(name: "request_duration", description: "", type: .histogram)
        )
        
        // Add metrics to the map
        metrics[MetricKeyGenerator.generateKey(name: histogramBucket1.name, labels: histogramBucket1.labels)] = histogramBucket1
        metrics[MetricKeyGenerator.generateKey(name: histogramBucket2.name, labels: histogramBucket2.labels)] = histogramBucket2
        metrics[MetricKeyGenerator.generateKey(name: histogramSum.name, labels: histogramSum.labels)] = histogramSum
        metrics[MetricKeyGenerator.generateKey(name: histogramCount.name, labels: histogramCount.labels)] = histogramCount
        
        let collection = MetricCollection(metrics: metrics)
        
        XCTAssertEqual(collection.histograms.count, 1)
        XCTAssertTrue(collection.regular.isEmpty)
        
        let histogram = collection.histograms.first
        XCTAssertEqual(histogram?.name, "request_duration")
        XCTAssertEqual(histogram?.definition?.type, .histogram)
    }
    
    func testMixedMetricsCollection() {
        var metrics: [String: TimeSeriesData] = [:]
        
        // Add regular metric
        let counter = TimeSeriesData(
            name: "requests_total",
            labels: [:],
            values: [(timestamp: Date(), value: 100, labels: [:])],
            definition: MetricDefinition(name: "requests_total", description: "", type: .counter)
        )
        
        // Add histogram components
        let histogramBucket = TimeSeriesData(
            name: "latency_bucket",
            labels: ["le": "0.1"],
            values: [(timestamp: Date(), value: 10, labels: ["le": "0.1"])],
            definition: MetricDefinition(name: "latency", description: "", type: .histogram)
        )
        
        let histogramSum = TimeSeriesData(
            name: "latency_sum",
            labels: [:],
            values: [(timestamp: Date(), value: 5.5, labels: [:])],
            definition: MetricDefinition(name: "latency", description: "", type: .histogram)
        )
        
        let histogramCount = TimeSeriesData(
            name: "latency_count",
            labels: [:],
            values: [(timestamp: Date(), value: 15, labels: [:])],
            definition: MetricDefinition(name: "latency", description: "", type: .histogram)
        )
        
        // Add excluded metric
        let excludedMetric = TimeSeriesData(
            name: "target_info",
            labels: [:],
            values: [(timestamp: Date(), value: 1, labels: [:])],
            definition: MetricDefinition(name: "target_info", description: "", type: .gauge)
        )
        
        metrics[MetricKeyGenerator.generateKey(name: counter.name, labels: counter.labels)] = counter
        metrics[MetricKeyGenerator.generateKey(name: histogramBucket.name, labels: histogramBucket.labels)] = histogramBucket
        metrics[MetricKeyGenerator.generateKey(name: histogramSum.name, labels: histogramSum.labels)] = histogramSum
        metrics[MetricKeyGenerator.generateKey(name: histogramCount.name, labels: histogramCount.labels)] = histogramCount
        metrics[MetricKeyGenerator.generateKey(name: excludedMetric.name, labels: excludedMetric.labels)] = excludedMetric
        
        let collection = MetricCollection(metrics: metrics)
        
        XCTAssertEqual(collection.histograms.count, 1)
        XCTAssertEqual(collection.regular.count, 1)
        
        XCTAssertTrue(collection.regular.contains { $0.name == "requests_total" })
        XCTAssertTrue(collection.histograms.contains { $0.name == "latency" })
        XCTAssertFalse(collection.regular.contains { $0.name == "target_info" })
    }
    
    func testHistogramWithLabels() {
        var metrics: [String: TimeSeriesData] = [:]
        
        // Create histogram components with additional labels
        let histogramBucket1 = TimeSeriesData(
            name: "request_duration_bucket",
            labels: ["service": "api", "endpoint": "/users", "le": "0.1"],
            values: [(timestamp: Date(), value: 10, labels: ["service": "api", "endpoint": "/users", "le": "0.1"])],
            definition: MetricDefinition(name: "request_duration", description: "", type: .histogram)
        )
        
        let histogramBucket2 = TimeSeriesData(
            name: "request_duration_bucket",
            labels: ["service": "api", "endpoint": "/users", "le": "0.5"],
            values: [(timestamp: Date(), value: 20, labels: ["service": "api", "endpoint": "/users", "le": "0.5"])],
            definition: MetricDefinition(name: "request_duration", description: "", type: .histogram)
        )
        
        metrics[MetricKeyGenerator.generateKey(name: histogramBucket1.name, labels: histogramBucket1.labels)] = histogramBucket1
        metrics[MetricKeyGenerator.generateKey(name: histogramBucket2.name, labels: histogramBucket2.labels)] = histogramBucket2
        
        let collection = MetricCollection(metrics: metrics)
        
        XCTAssertEqual(collection.histograms.count, 1)
        let histogram = collection.histograms.first
        XCTAssertEqual(histogram?.name, "request_duration")
        XCTAssertEqual(histogram?.labels["service"], "api")
        XCTAssertEqual(histogram?.labels["endpoint"], "/users")
        XCTAssertNil(histogram?.labels["le"]) // "le" label should be removed
    }
} 