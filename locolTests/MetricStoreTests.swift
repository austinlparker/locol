import XCTest
@testable import locol

final class MetricStoreTests: XCTestCase {
    var store: MetricStore!
    
    override func setUp() {
        super.setUp()
        store = MetricStore()
    }
    
    override func tearDown() {
        store = nil
        super.tearDown()
    }
    
    func testStoreRegularMetric() throws {
        let metric = PrometheusMetric(
            name: "test_metric",
            help: "Test metric help",
            type: .gauge,
            values: [
                (labels: ["label1": "value1"], value: 42.0),
                (labels: ["label1": "value2"], value: 24.0)
            ]
        )
        
        try store.store(metric)
        
        let key1 = MetricKeyGenerator.generateKey(name: "test_metric", labels: ["label1": "value1"])
        let key2 = MetricKeyGenerator.generateKey(name: "test_metric", labels: ["label1": "value2"])
        
        XCTAssertNotNil(store.metrics[key1])
        XCTAssertNotNil(store.metrics[key2])
        XCTAssertEqual(store.metrics[key1]?.values.last?.value, 42.0)
        XCTAssertEqual(store.metrics[key2]?.values.last?.value, 24.0)
        XCTAssertEqual(store.metrics[key1]?.definition?.type, .gauge)
        XCTAssertEqual(store.metrics[key1]?.definition?.description, "Test metric help")
    }
    
    func testCounterRate() throws {
        let now = Date()
        let metric = PrometheusMetric(
            name: "test_counter",
            help: "Test counter",
            type: .counter,
            values: [(labels: [:], value: 100.0)]
        )
        
        try store.store(metric)
        
        // Simulate passage of time and counter increase
        Thread.sleep(forTimeInterval: 1)
        
        let updatedMetric = PrometheusMetric(
            name: "test_counter",
            help: "Test counter",
            type: .counter,
            values: [(labels: [:], value: 150.0)]
        )
        
        try store.store(updatedMetric)
        
        let key = MetricKeyGenerator.generateKey(name: "test_counter", labels: [:])
        let rate = store.getRate(for: key, timeWindow: 2)
        
        XCTAssertNotNil(rate)
        // Rate should be approximately 50 per second
        XCTAssertEqual(rate!, 50.0, accuracy: 5.0)
    }
    
    func testHistogramProcessing() throws {
        // Create a histogram metric directly
        let metric = PrometheusMetric(
            name: "http_request_duration_seconds",
            help: "Request duration histogram",
            type: .histogram,
            values: [
                (labels: ["le": "0.1"], value: 1),
                (labels: ["le": "0.5"], value: 4),
                (labels: ["le": "1.0"], value: 5),
                (labels: ["le": "+Inf"], value: 6),
                (labels: [:], value: 8.35),  // sum
                (labels: [:], value: 6)      // count
            ]
        )
        
        try store.store(metric)
        
        let key = MetricKeyGenerator.generateKey(name: "http_request_duration_seconds", labels: [:])
        let storedMetric = store.metrics[key]
        
        XCTAssertNotNil(storedMetric, "Metric should be stored")
        XCTAssertEqual(storedMetric?.definition?.type, .histogram, "Metric should be a histogram")
        
        let histogram = storedMetric?.values.last?.histogram
        XCTAssertNotNil(histogram, "Histogram data should be assembled")
        XCTAssertEqual(histogram?.buckets.count, 4, "Should preserve all buckets")
        XCTAssertEqual(histogram?.sum, 8.35, "Should preserve sum")
        XCTAssertEqual(histogram?.count, 6, "Should preserve count")
    }
    
    func testInvalidHistogramBuckets() throws {
        let input = """
        # HELP duration_seconds Duration histogram
        # TYPE duration_seconds histogram
        duration_seconds_bucket{le="0.1"} 2
        duration_seconds_bucket{le="0.5"} 1
        duration_seconds_bucket{le="+Inf"} 3
        duration_seconds_sum 5.0
        duration_seconds_count 3
        """
        
        let metrics = try PrometheusParser.parse(input)
        XCTAssertThrowsError(try metrics.forEach { try store.store($0) }) { error in
            XCTAssertEqual(error as? MetricError, .invalidHistogramBuckets("duration_seconds"))
        }
    }
    
    func testCounterReset() throws {
        let metric1 = PrometheusMetric(
            name: "test_counter",
            help: "Test counter",
            type: .counter,
            values: [(labels: [:], value: 100.0)]
        )
        
        try store.store(metric1)
        
        let metric2 = PrometheusMetric(
            name: "test_counter",
            help: "Test counter",
            type: .counter,
            values: [(labels: [:], value: 50.0)] // Reset to lower value
        )
        
        try store.store(metric2)
        
        let key = MetricKeyGenerator.generateKey(name: "test_counter", labels: [:])
        XCTAssertEqual(store.metrics[key]?.values.count, 2)
        XCTAssertEqual(store.metrics[key]?.values.last?.value, 50.0)
    }
    
    func testMultipleLabelCombinations() throws {
        let metrics = [
            PrometheusMetric(
                name: "test_metric",
                help: "Test metric with multiple labels",
                type: .gauge,
                values: [
                    (labels: ["env": "prod", "region": "us-west", "service": "api"], value: 1.0),
                    (labels: ["env": "prod", "region": "us-east", "service": "api"], value: 2.0),
                    (labels: ["env": "staging", "region": "us-west", "service": "web"], value: 3.0),
                    (labels: ["env": "dev"], value: 4.0),
                    (labels: [:], value: 5.0)
                ]
            )
        ]
        
        try metrics.forEach { try store.store($0) }
        
        // Check each combination
        let key1 = MetricKeyGenerator.generateKey(name: "test_metric", labels: ["env": "prod", "region": "us-west", "service": "api"])
        let key2 = MetricKeyGenerator.generateKey(name: "test_metric", labels: ["env": "prod", "region": "us-east", "service": "api"])
        let key3 = MetricKeyGenerator.generateKey(name: "test_metric", labels: ["env": "staging", "region": "us-west", "service": "web"])
        let key4 = MetricKeyGenerator.generateKey(name: "test_metric", labels: ["env": "dev"])
        let key5 = MetricKeyGenerator.generateKey(name: "test_metric", labels: [:])
        
        XCTAssertEqual(store.metrics[key1]?.values.last?.value, 1.0)
        XCTAssertEqual(store.metrics[key2]?.values.last?.value, 2.0)
        XCTAssertEqual(store.metrics[key3]?.values.last?.value, 3.0)
        XCTAssertEqual(store.metrics[key4]?.values.last?.value, 4.0)
        XCTAssertEqual(store.metrics[key5]?.values.last?.value, 5.0)
    }
    
    func testSpecialNumericValues() throws {
        let metrics = [
            PrometheusMetric(
                name: "test_special_values",
                help: "Test metric with special numeric values",
                type: .gauge,
                values: [
                    (labels: ["type": "very_small"], value: 0.000000001),
                    (labels: ["type": "very_large"], value: 1_000_000_000.0),
                    (labels: ["type": "negative"], value: -42.5),
                    (labels: ["type": "zero"], value: 0.0)
                ]
            )
        ]
        
        try metrics.forEach { try store.store($0) }
        
        let key1 = MetricKeyGenerator.generateKey(name: "test_special_values", labels: ["type": "very_small"])
        let key2 = MetricKeyGenerator.generateKey(name: "test_special_values", labels: ["type": "very_large"])
        let key3 = MetricKeyGenerator.generateKey(name: "test_special_values", labels: ["type": "negative"])
        let key4 = MetricKeyGenerator.generateKey(name: "test_special_values", labels: ["type": "zero"])
        
        XCTAssertEqual(store.metrics[key1]?.values.last?.value, 0.000000001)
        XCTAssertEqual(store.metrics[key2]?.values.last?.value, 1_000_000_000.0)
        XCTAssertEqual(store.metrics[key3]?.values.last?.value, -42.5)
        XCTAssertEqual(store.metrics[key4]?.values.last?.value, 0.0)
    }
    
    func testHistogramAssemblyFromComponents() throws {
        // Test histogram assembly from individual components (Prometheus format)
        let bucketMetrics = [
            PrometheusMetric(
                name: "http_request_duration_seconds_bucket",
                help: "Request duration histogram",
                type: .histogram,
                values: [(labels: ["le": "0.1"], value: 1)]
            ),
            PrometheusMetric(
                name: "http_request_duration_seconds_bucket",
                help: "Request duration histogram",
                type: .histogram,
                values: [(labels: ["le": "0.5"], value: 4)]
            ),
            PrometheusMetric(
                name: "http_request_duration_seconds_bucket",
                help: "Request duration histogram",
                type: .histogram,
                values: [(labels: ["le": "+Inf"], value: 6)]
            )
        ]
        
        let sumMetric = PrometheusMetric(
            name: "http_request_duration_seconds_sum",
            help: "Request duration histogram",
            type: .histogram,
            values: [(labels: [:], value: 8.35)]
        )
        
        let countMetric = PrometheusMetric(
            name: "http_request_duration_seconds_count",
            help: "Request duration histogram",
            type: .histogram,
            values: [(labels: [:], value: 6)]
        )
        
        // Store components in order
        try bucketMetrics.forEach { try store.store($0) }
        try store.store(sumMetric)
        try store.store(countMetric)
        
        let key = MetricKeyGenerator.generateKey(name: "http_request_duration_seconds", labels: [:])
        let storedMetric = store.metrics[key]
        
        XCTAssertNotNil(storedMetric, "Metric should be stored")
        XCTAssertEqual(storedMetric?.definition?.type, .histogram, "Metric should be a histogram")
        
        let histogram = storedMetric?.values.last?.histogram
        XCTAssertNotNil(histogram, "Histogram data should be assembled")
        XCTAssertEqual(histogram?.buckets.count, 3, "Should have 3 buckets")
        XCTAssertEqual(histogram?.sum, 8.35, "Should preserve sum")
        XCTAssertEqual(histogram?.count, 6, "Should preserve count")
    }
    
    func testHistogramAssemblyFromComplete() throws {
        // Test histogram assembly from a complete histogram metric
        let metric = PrometheusMetric(
            name: "http_request_duration_seconds",
            help: "Request duration histogram",
            type: .histogram,
            values: [
                (labels: ["le": "0.1"], value: 1),
                (labels: ["le": "0.5"], value: 4),
                (labels: ["le": "+Inf"], value: 6),
                (labels: [:], value: 8.35),  // sum
                (labels: [:], value: 6)      // count
            ]
        )
        
        try store.store(metric)
        
        let key = MetricKeyGenerator.generateKey(name: "http_request_duration_seconds", labels: [:])
        let storedMetric = store.metrics[key]
        
        XCTAssertNotNil(storedMetric, "Metric should be stored")
        XCTAssertEqual(storedMetric?.definition?.type, .histogram, "Metric should be a histogram")
        
        let histogram = storedMetric?.values.last?.histogram
        XCTAssertNotNil(histogram, "Histogram data should be assembled")
        XCTAssertEqual(histogram?.buckets.count, 3, "Should have 3 buckets")
        XCTAssertEqual(histogram?.sum, 8.35, "Should preserve sum")
        XCTAssertEqual(histogram?.count, 6, "Should preserve count")
    }
    
    func testHistogramWithLabels() throws {
        // Test histogram assembly with labels
        let bucketMetrics = [
            PrometheusMetric(
                name: "request_duration_bucket",
                help: "Request duration by service",
                type: .histogram,
                values: [(labels: ["service": "api", "endpoint": "/users", "le": "0.1"], value: 10)]
            ),
            PrometheusMetric(
                name: "request_duration_bucket",
                help: "Request duration by service",
                type: .histogram,
                values: [(labels: ["service": "api", "endpoint": "/users", "le": "0.5"], value: 20)]
            ),
            PrometheusMetric(
                name: "request_duration_bucket",
                help: "Request duration by service",
                type: .histogram,
                values: [(labels: ["service": "api", "endpoint": "/users", "le": "+Inf"], value: 30)]
            )
        ]
        
        let sumMetric = PrometheusMetric(
            name: "request_duration_sum",
            help: "Request duration by service",
            type: .histogram,
            values: [(labels: ["service": "api", "endpoint": "/users"], value: 15.5)]
        )
        
        let countMetric = PrometheusMetric(
            name: "request_duration_count",
            help: "Request duration by service",
            type: .histogram,
            values: [(labels: ["service": "api", "endpoint": "/users"], value: 30)]
        )
        
        // Store components
        try bucketMetrics.forEach { try store.store($0) }
        try store.store(sumMetric)
        try store.store(countMetric)
        
        let key = MetricKeyGenerator.generateKey(
            name: "request_duration",
            labels: ["service": "api", "endpoint": "/users"]
        )
        
        let storedMetric = store.metrics[key]
        XCTAssertNotNil(storedMetric, "Metric should be stored")
        XCTAssertEqual(storedMetric?.definition?.type, .histogram, "Metric should be a histogram")
        
        let histogram = storedMetric?.values.last?.histogram
        XCTAssertNotNil(histogram, "Histogram data should be assembled")
        XCTAssertEqual(histogram?.buckets.count, 3, "Should have 3 buckets")
        XCTAssertEqual(histogram?.sum, 15.5, "Should preserve sum")
        XCTAssertEqual(histogram?.count, 30, "Should preserve count")
        
        // Verify labels are preserved correctly
        XCTAssertEqual(storedMetric?.labels["service"], "api")
        XCTAssertEqual(storedMetric?.labels["endpoint"], "/users")
        XCTAssertNil(storedMetric?.labels["le"], "le label should not be in base labels")
    }
    
    func testLabelCharacterEscaping() throws {
        let metric = PrometheusMetric(
            name: "test_escaping",
            help: "Test metric with special characters in labels",
            type: .gauge,
            values: [
                (labels: ["path": "/api/v1/users/123", "query": "name=test&type=user"], value: 1.0),
                (labels: ["user-agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"], value: 2.0),
                (labels: ["special": "hello,world;test=true"], value: 3.0)
            ]
        )
        
        try store.store(metric)
        
        let key1 = MetricKeyGenerator.generateKey(name: "test_escaping", labels: ["path": "/api/v1/users/123", "query": "name=test&type=user"])
        let key2 = MetricKeyGenerator.generateKey(name: "test_escaping", labels: ["user-agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"])
        let key3 = MetricKeyGenerator.generateKey(name: "test_escaping", labels: ["special": "hello,world;test=true"])
        
        XCTAssertEqual(store.metrics[key1]?.values.last?.value, 1.0)
        XCTAssertEqual(store.metrics[key2]?.values.last?.value, 2.0)
        XCTAssertEqual(store.metrics[key3]?.values.last?.value, 3.0)
    }
    
    func testMetricNamespaces() throws {
        let metrics = [
            PrometheusMetric(
                name: "app_requests_total",
                help: "Total requests",
                type: .counter,
                values: [(labels: [:], value: 100)]
            ),
            PrometheusMetric(
                name: "app:requests:failed",
                help: "Failed requests",
                type: .counter,
                values: [(labels: [:], value: 5)]
            ),
            PrometheusMetric(
                name: "app_subsystem_component_value",
                help: "Component value",
                type: .gauge,
                values: [(labels: [:], value: 42)]
            )
        ]
        
        try metrics.forEach { try store.store($0) }
        
        let key1 = MetricKeyGenerator.generateKey(name: "app_requests_total", labels: [:])
        let key2 = MetricKeyGenerator.generateKey(name: "app:requests:failed", labels: [:])
        let key3 = MetricKeyGenerator.generateKey(name: "app_subsystem_component_value", labels: [:])
        
        XCTAssertEqual(store.metrics[key1]?.values.last?.value, 100)
        XCTAssertEqual(store.metrics[key2]?.values.last?.value, 5)
        XCTAssertEqual(store.metrics[key3]?.values.last?.value, 42)
    }
} 
