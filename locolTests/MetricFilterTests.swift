import XCTest
@testable import locol

final class MetricFilterTests: XCTestCase {
    
    func testExcludedMetrics() {
        XCTAssertTrue(MetricFilter.isExcluded("target_metadata"))
        XCTAssertTrue(MetricFilter.isExcluded("target_info"))
        XCTAssertFalse(MetricFilter.isExcluded("http_requests_total"))
        XCTAssertFalse(MetricFilter.isExcluded("process_cpu_seconds"))
    }
    
    func testHistogramComponentDetection() {
        XCTAssertTrue(MetricFilter.isHistogramComponent("http_request_duration_bucket"))
        XCTAssertTrue(MetricFilter.isHistogramComponent("http_request_duration_sum"))
        XCTAssertTrue(MetricFilter.isHistogramComponent("http_request_duration_count"))
        XCTAssertFalse(MetricFilter.isHistogramComponent("http_requests_total"))
        XCTAssertFalse(MetricFilter.isHistogramComponent("process_bucket_value")) // Should not match partial suffixes
    }
    
    func testBaseNameExtraction() {
        XCTAssertEqual(MetricFilter.getBaseName("http_request_duration_bucket"), "http_request_duration")
        XCTAssertEqual(MetricFilter.getBaseName("http_request_duration_sum"), "http_request_duration")
        XCTAssertEqual(MetricFilter.getBaseName("http_request_duration_count"), "http_request_duration")
        XCTAssertEqual(MetricFilter.getBaseName("http_requests_total"), "http_requests_total")
        XCTAssertEqual(MetricFilter.getBaseName("process_bucket_value"), "process_bucket_value")
    }
    
    func testHistogramMetricDetection() {
        XCTAssertTrue(MetricFilter.isHistogramMetric("request_latency_bucket"))
        XCTAssertTrue(MetricFilter.isHistogramMetric("request_latency_sum"))
        XCTAssertTrue(MetricFilter.isHistogramMetric("request_latency_count"))
        XCTAssertFalse(MetricFilter.isHistogramMetric("request_latency"))
        XCTAssertFalse(MetricFilter.isHistogramMetric("bucket_value"))
    }
    
    func testHistogramComponentIdentification() {
        XCTAssertEqual(MetricFilter.getHistogramComponent("request_latency_bucket"), "bucket")
        XCTAssertEqual(MetricFilter.getHistogramComponent("request_latency_sum"), "sum")
        XCTAssertEqual(MetricFilter.getHistogramComponent("request_latency_count"), "count")
        XCTAssertNil(MetricFilter.getHistogramComponent("request_latency"))
        XCTAssertNil(MetricFilter.getHistogramComponent("bucket_value"))
    }
    
    func testIsHistogramTimeSeriesData() {
        let histogramMetric = TimeSeriesData(
            name: "request_duration",
            labels: [:],
            values: [],
            definition: MetricDefinition(name: "request_duration", description: "", type: .histogram)
        )
        
        let counterMetric = TimeSeriesData(
            name: "requests_total",
            labels: [:],
            values: [],
            definition: MetricDefinition(name: "requests_total", description: "", type: .counter)
        )
        
        let undefinedMetric = TimeSeriesData(
            name: "undefined_metric",
            labels: [:],
            values: [],
            definition: nil
        )
        
        XCTAssertTrue(MetricFilter.isHistogram(histogramMetric))
        XCTAssertFalse(MetricFilter.isHistogram(counterMetric))
        XCTAssertFalse(MetricFilter.isHistogram(undefinedMetric))
    }
} 