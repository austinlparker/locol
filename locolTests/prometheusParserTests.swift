import XCTest
@testable import locol

final class PrometheusParserTests: XCTestCase {
    
    func testValidMetricParsing() throws {
        let input = """
        # HELP http_requests_total The total number of HTTP requests.
        # TYPE http_requests_total counter
        http_requests_total{method="post",code="200"} 1027
        http_requests_total{method="get",code="200"} 345
        """
        
        let metrics = try PrometheusParser.parse(input)
        
        XCTAssertEqual(metrics.count, 1)
        XCTAssertEqual(metrics[0].name, "http_requests_total")
        XCTAssertEqual(metrics[0].help, "The total number of HTTP requests.")
        XCTAssertEqual(metrics[0].type, .counter)
        XCTAssertEqual(metrics[0].values.count, 2)
        
        let firstValue = metrics[0].values[0]
        XCTAssertEqual(firstValue.labels["method"], "post")
        XCTAssertEqual(firstValue.labels["code"], "200")
        XCTAssertEqual(firstValue.value, 1027)
        
        let secondValue = metrics[0].values[1]
        XCTAssertEqual(secondValue.labels["method"], "get")
        XCTAssertEqual(secondValue.labels["code"], "200")
        XCTAssertEqual(secondValue.value, 345)
    }
    
    func testHistogramMetricParsing() throws {
        let input = """
        # HELP http_request_duration_seconds Request duration histogram
        # TYPE http_request_duration_seconds histogram
        http_request_duration_seconds_bucket{le="0.1"} 1
        http_request_duration_seconds_bucket{le="0.5"} 4
        http_request_duration_seconds_bucket{le="1.0"} 5
        http_request_duration_seconds_bucket{le="+Inf"} 6
        http_request_duration_seconds_sum 8.35
        http_request_duration_seconds_count 6
        """
        
        let metrics = try PrometheusParser.parse(input)
        
        XCTAssertEqual(metrics.count, 1)
        let metric = metrics[0]
        XCTAssertEqual(metric.name, "http_request_duration_seconds")
        XCTAssertEqual(metric.type, .histogram)
        
        // Verify histogram components
        let buckets = metric.values.filter { $0.labels["le"] != nil }
        XCTAssertEqual(buckets.count, 4, "Should have 4 buckets")
        
        // Verify bucket values
        let sortedBuckets = buckets.sorted { 
            let le1 = Double($0.labels["le"]!.replacingOccurrences(of: "+Inf", with: "inf")) ?? 0
            let le2 = Double($1.labels["le"]!.replacingOccurrences(of: "+Inf", with: "inf")) ?? 0
            return le1 < le2
        }
        XCTAssertEqual(sortedBuckets[0].value, 1, "First bucket should have count 1")
        XCTAssertEqual(sortedBuckets[1].value, 4, "Second bucket should have count 4")
        XCTAssertEqual(sortedBuckets[2].value, 5, "Third bucket should have count 5")
        XCTAssertEqual(sortedBuckets[3].value, 6, "Fourth bucket should have count 6")
        
        // Verify sum and count
        let sum = metric.values.first { $0.labels.isEmpty && metric.name.hasSuffix("_sum") }
        XCTAssertEqual(sum?.value, 8.35, "Sum should be 8.35")
        
        let count = metric.values.first { $0.labels.isEmpty && metric.name.hasSuffix("_count") }
        XCTAssertEqual(count?.value, 6, "Count should be 6")
    }
    
    func testInvalidMetricName() {
        let input = """
        # HELP 1invalid_name Invalid metric name
        # TYPE 1invalid_name counter
        1invalid_name 10
        """
        
        XCTAssertThrowsError(try PrometheusParser.parse(input)) { error in
            XCTAssertEqual(error as? MetricError, .invalidMetricName("1invalid_name"))
        }
    }
    
    func testMalformedMetricLine() {
        let input = """
        # HELP valid_metric Valid metric
        # TYPE valid_metric counter
        valid_metric{label=} 10
        """
        
        XCTAssertThrowsError(try PrometheusParser.parse(input)) { error in
            XCTAssertEqual(error as? MetricError, .malformedMetricLine("valid_metric{label=} 10"))
        }
    }
    
    func testInvalidHistogramBuckets() {
        let input = """
        # HELP duration_seconds Duration histogram
        # TYPE duration_seconds histogram
        duration_seconds_bucket{le="0.1"} 2
        duration_seconds_bucket{le="0.5"} 1
        duration_seconds_bucket{le="+Inf"} 3
        """
        
        XCTAssertThrowsError(try PrometheusParser.parse(input)) { error in
            XCTAssertEqual(error as? MetricError, .invalidHistogramBuckets("duration_seconds"))
        }
    }
    
    func testValidMetricNames() {
        XCTAssertTrue(PrometheusParser.isValidMetricName("valid_name"))
        XCTAssertTrue(PrometheusParser.isValidMetricName("valid:name"))
        XCTAssertTrue(PrometheusParser.isValidMetricName("_valid_name"))
        XCTAssertFalse(PrometheusParser.isValidMetricName("1invalid"))
        XCTAssertFalse(PrometheusParser.isValidMetricName("-invalid"))
        XCTAssertFalse(PrometheusParser.isValidMetricName("invalid!name"))
    }
    
    func testEmptyInput() throws {
        let metrics = try PrometheusParser.parse("")
        XCTAssertTrue(metrics.isEmpty)
    }
    
    func testMultipleMetrics() throws {
        let input = """
        # HELP metric1 First metric
        # TYPE metric1 counter
        metric1 10
        
        # HELP metric2 Second metric
        # TYPE metric2 gauge
        metric2 20
        """
        
        let metrics = try PrometheusParser.parse(input)
        
        XCTAssertEqual(metrics.count, 2)
        XCTAssertEqual(metrics[0].name, "metric1")
        XCTAssertEqual(metrics[0].type, .counter)
        XCTAssertEqual(metrics[1].name, "metric2")
        XCTAssertEqual(metrics[1].type, .gauge)
    }
}