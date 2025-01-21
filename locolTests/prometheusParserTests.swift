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
        http_request_duration_seconds_bucket{le="0.005"} 2
        http_request_duration_seconds_bucket{le="0.01"} 4
        http_request_duration_seconds_bucket{le="0.025"} 7
        http_request_duration_seconds_bucket{le="0.05"} 11
        http_request_duration_seconds_bucket{le="0.1"} 15
        http_request_duration_seconds_bucket{le="0.25"} 18
        http_request_duration_seconds_bucket{le="0.5"} 20
        http_request_duration_seconds_bucket{le="1"} 22
        http_request_duration_seconds_bucket{le="2.5"} 24
        http_request_duration_seconds_bucket{le="5"} 25
        http_request_duration_seconds_bucket{le="10"} 26
        http_request_duration_seconds_bucket{le="+Inf"} 27
        http_request_duration_seconds_sum 23.47
        http_request_duration_seconds_count 27
        """
        
        let metrics = try PrometheusParser.parse(input)
        
        XCTAssertEqual(metrics.count, 1)
        let metric = metrics[0]
        XCTAssertEqual(metric.name, "http_request_duration_seconds")
        XCTAssertEqual(metric.help, "Request duration histogram")
        XCTAssertEqual(metric.type, .histogram)
        
        // Verify all histogram components are present
        let buckets = metric.values.filter { $0.labels["le"] != nil }
        XCTAssertEqual(buckets.count, 12, "Should have 12 buckets")
        
        let sortedBuckets = buckets.sorted { 
            let le1 = Double($0.labels["le"]!.replacingOccurrences(of: "+Inf", with: "inf")) ?? 0
            let le2 = Double($1.labels["le"]!.replacingOccurrences(of: "+Inf", with: "inf")) ?? 0
            return le1 < le2
        }
        
        // Test a few key bucket values
        XCTAssertEqual(sortedBuckets[0].value, 2, "0.005 bucket should have count 2")
        XCTAssertEqual(sortedBuckets[4].value, 15, "0.1 bucket should have count 15")
        XCTAssertEqual(sortedBuckets[11].value, 27, "+Inf bucket should have count 27")
        
        // Verify bucket values are monotonically increasing
        for i in 1..<sortedBuckets.count {
            XCTAssertGreaterThanOrEqual(
                sortedBuckets[i].value,
                sortedBuckets[i-1].value,
                "Bucket values must be monotonically increasing"
            )
        }
        
        // Verify sum and count values
        let sumValue = metric.values.first(where: { 
            $0.labels["__name__"] == "http_request_duration_seconds_sum" 
        })
        XCTAssertNotNil(sumValue, "Sum should be present")
        XCTAssertEqual(sumValue?.value, 23.47, "Sum should be 23.47")
        
        let countValue = metric.values.first(where: { 
            $0.labels["__name__"] == "http_request_duration_seconds_count" 
        })
        XCTAssertNotNil(countValue, "Count should be present")
        XCTAssertEqual(countValue?.value, 27, "Count should match highest bucket value")
        XCTAssertEqual(countValue?.value, sortedBuckets.last?.value, "Count should match +Inf bucket")
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
        valid_metric{label="value",} 10
        """
        
        XCTAssertThrowsError(try PrometheusParser.parse(input)) { error in
            XCTAssertEqual(error as? MetricError, .malformedMetricLine("valid_metric{label=\"value\",} 10"))
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