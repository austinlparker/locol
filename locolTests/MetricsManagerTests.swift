import XCTest
import Combine
@testable import locol

class MockURLSession: URLSession {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?
    
    override func dataTask(with url: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        return MockURLSessionDataTask {
            completionHandler(self.mockData, self.mockResponse, self.mockError)
        }
    }
}

class MockURLSessionDataTask: URLSessionDataTask {
    private let closure: () -> Void
    
    init(closure: @escaping () -> Void) {
        self.closure = closure
    }
    
    override func resume() {
        closure()
    }
}

class TestMetricsManager: MetricsManager {
    var mockSession: URLSession
    
    init(session: URLSession) {
        self.mockSession = session
        super.init()
    }
    
    override var urlSession: URLSession {
        return mockSession
    }
}

final class MetricsManagerTests: XCTestCase {
    var manager: TestMetricsManager!
    var mockSession: MockURLSession!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
        manager = TestMetricsManager(session: mockSession)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        manager.stopScraping()
        cancellables = nil
        mockSession = nil
        manager = nil
        super.tearDown()
    }
    
    func testMetricKeyGeneration() {
        let key = manager.metricKey(name: "test_metric", labels: ["label1": "value1", "label2": "value2"])
        XCTAssertEqual(key, "test_metric{label1=\"value1\",label2=\"value2\"}")
        
        let keyNoLabels = manager.metricKey(name: "test_metric", labels: [:])
        XCTAssertEqual(keyNoLabels, "test_metric")
    }
    
    func testRateCalculation() {
        let expectation = XCTestExpectation(description: "Rate should be calculated")
        
        // Set up mock response for first scrape
        let firstMetrics = """
            # HELP test_counter Test counter
            # TYPE test_counter counter
            test_counter 100
            """
        mockSession.mockData = firstMetrics.data(using: .utf8)
        mockSession.mockResponse = HTTPURLResponse(url: URL(string: "http://localhost:8888/metrics")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        // Manually trigger first scrape
        manager.processMetrics(firstMetrics)
        
        // Wait a second and do second scrape
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let secondMetrics = """
                # HELP test_counter Test counter
                # TYPE test_counter counter
                test_counter 150
                """
            
            // Manually trigger second scrape
            self.manager.processMetrics(secondMetrics)
            
            // Check rate after a small delay to allow processing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let key = self.manager.metricKey(name: "test_counter", labels: [:])
                if let rate = self.manager.getRate(for: key, timeWindow: 2) {
                    XCTAssertEqual(rate, 50.0, accuracy: 5.0)
                    expectation.fulfill()
                } else {
                    XCTFail("Failed to calculate rate")
                }
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testErrorHandling() {
        let expectation = XCTestExpectation(description: "Error should be published")
        
        mockSession.mockError = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error"])
        mockSession.mockResponse = HTTPURLResponse(url: URL(string: "http://localhost:8888/metrics")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        manager.$lastError
            .dropFirst()
            .sink { error in
                XCTAssertNotNil(error)
                XCTAssertTrue(error?.contains("Network error") ?? false)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        manager.startScraping()
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testMetricProcessing() {
        let expectation = XCTestExpectation(description: "Metrics should be processed")
        
        let metricsData = """
            # HELP test_gauge Test gauge
            # TYPE test_gauge gauge
            test_gauge{label="value"} 42
            
            # HELP test_counter Test counter
            # TYPE test_counter counter
            test_counter 100
            """
        
        mockSession.mockData = metricsData.data(using: .utf8)
        mockSession.mockResponse = HTTPURLResponse(url: URL(string: "http://localhost:8888/metrics")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        manager.startScraping()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let gaugeKey = self.manager.metricKey(name: "test_gauge", labels: ["label": "value"])
            let counterKey = self.manager.metricKey(name: "test_counter", labels: [:])
            
            XCTAssertNotNil(self.manager.metrics[gaugeKey])
            XCTAssertNotNil(self.manager.metrics[counterKey])
            XCTAssertEqual(self.manager.metrics[gaugeKey]?.last?.value, 42)
            XCTAssertEqual(self.manager.metrics[counterKey]?.last?.value, 100)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testHistogramProcessing() throws {
        let expectation = XCTestExpectation(description: "Histogram should be processed")
        
        let metricsData = """
            # HELP request_duration Request duration
            # TYPE request_duration histogram
            request_duration_bucket{le="0.1"} 1
            request_duration_bucket{le="0.5"} 4
            request_duration_bucket{le="1.0"} 5
            request_duration_bucket{le="+Inf"} 6
            request_duration_sum 8.35
            request_duration_count 6
            """
        
        // Process metrics and wait for async processing
        try manager.processMetrics(metricsData)
        Thread.sleep(forTimeInterval: 0.5)  // Increased wait time
        
        let key = manager.metricKey(name: "request_duration", labels: [:])
        let metrics = manager.metrics[key]
        
        XCTAssertNotNil(metrics, "Metrics should not be nil")
        XCTAssertFalse(metrics?.isEmpty ?? true, "Metrics should not be empty")
        
        guard let lastMetric = metrics?.last else {
            XCTFail("No metrics found")
            return
        }
        
        XCTAssertEqual(lastMetric.type, .histogram, "Metric should be a histogram")
        
        guard let histogram = lastMetric.histogram else {
            XCTFail("Histogram data should not be nil")
            return
        }
        
        XCTAssertEqual(histogram.buckets.count, 4, "Should have 4 buckets")
        XCTAssertEqual(histogram.sum, 8.35, "Sum should be 8.35")
        XCTAssertEqual(histogram.count, 6, "Count should be 6")
        
        // Test quantile calculations
        XCTAssertEqual(histogram.p50, 0.5, accuracy: 0.1, "50th percentile should be around 0.5")
        XCTAssertEqual(histogram.p95, 1.0, accuracy: 0.1, "95th percentile should be around 1.0")
        XCTAssertEqual(histogram.average, 8.35/6, accuracy: 0.01, "Average should be sum/count")
        
        // Verify bucket values
        let sortedBuckets = histogram.buckets.sorted(by: { $0.upperBound < $1.upperBound })
        XCTAssertEqual(sortedBuckets[0].count, 1, "First bucket should have count 1")
        XCTAssertEqual(sortedBuckets[1].count, 4, "Second bucket should have count 4")
        XCTAssertEqual(sortedBuckets[2].count, 5, "Third bucket should have count 5")
        XCTAssertEqual(sortedBuckets[3].count, 6, "Inf bucket should have count 6")
        
        expectation.fulfill()
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testHistogramProcessingWithLabels() throws {
        let expectation = XCTestExpectation(description: "Labeled histogram should be processed")
        
        let metricsData = """
            # HELP http_request_duration_seconds HTTP request duration in seconds
            # TYPE http_request_duration_seconds histogram
            http_request_duration_seconds_bucket{method="GET",path="/api/v1/users",le="0.1"} 10
            http_request_duration_seconds_bucket{method="GET",path="/api/v1/users",le="0.5"} 25
            http_request_duration_seconds_bucket{method="GET",path="/api/v1/users",le="1.0"} 35
            http_request_duration_seconds_bucket{method="GET",path="/api/v1/users",le="+Inf"} 40
            http_request_duration_seconds_sum{method="GET",path="/api/v1/users"} 23.5
            http_request_duration_seconds_count{method="GET",path="/api/v1/users"} 40
            """
        
        try manager.processMetrics(metricsData)
        
        let key = manager.metricKey(name: "http_request_duration_seconds", labels: ["method": "GET", "path": "/api/v1/users"])
        let metrics = manager.metrics[key]
        
        XCTAssertNotNil(metrics, "Metrics should not be nil")
        XCTAssertFalse(metrics?.isEmpty ?? true, "Metrics should not be empty")
        
        guard let lastMetric = metrics?.last else {
            XCTFail("No metrics found")
            return
        }
        
        XCTAssertEqual(lastMetric.type, .histogram, "Metric should be a histogram")
        
        guard let histogram = lastMetric.histogram else {
            XCTFail("Histogram data should not be nil")
            return
        }
        
        XCTAssertEqual(histogram.buckets.count, 4, "Should have 4 buckets")
        XCTAssertEqual(histogram.sum, 23.5, "Sum should be 23.5")
        XCTAssertEqual(histogram.count, 40, "Count should be 40")
        
        // Test bucket values
        let buckets = histogram.buckets.sorted(by: { $0.upperBound < $1.upperBound })
        XCTAssertEqual(buckets[0].count, 10, "First bucket should have count 10")
        XCTAssertEqual(buckets[1].count, 25, "Second bucket should have count 25")
        XCTAssertEqual(buckets[2].count, 35, "Third bucket should have count 35")
        XCTAssertEqual(buckets[3].count, 40, "Inf bucket should have count 40")
        
        // Test quantile calculations
        XCTAssertEqual(histogram.p50, 0.5, accuracy: 0.1, "50th percentile should be around 0.5")
        XCTAssertEqual(histogram.average, 23.5/40, accuracy: 0.01, "Average should be sum/count")
        
        expectation.fulfill()
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testHTTPErrorHandling() {
        let expectation = XCTestExpectation(description: "HTTP error should be handled")
        
        mockSession.mockResponse = HTTPURLResponse(url: URL(string: "http://localhost:8888/metrics")!, statusCode: 404, httpVersion: nil, headerFields: nil)
        
        manager.$lastError
            .dropFirst()
            .sink { error in
                XCTAssertNotNil(error)
                XCTAssertTrue(error?.contains("HTTP error 404") ?? false)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        manager.startScraping()
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testInvalidDataHandling() {
        let expectation = XCTestExpectation(description: "Invalid data should be handled")
        
        mockSession.mockData = "Invalid metrics data".data(using: .utf8)
        mockSession.mockResponse = HTTPURLResponse(url: URL(string: "http://localhost:8888/metrics")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        manager.$lastError
            .dropFirst()
            .sink { error in
                XCTAssertNotNil(error)
                XCTAssertTrue(error?.contains("Error parsing metrics") ?? false)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        manager.startScraping()
        
        wait(for: [expectation], timeout: 1.0)
    }
} 