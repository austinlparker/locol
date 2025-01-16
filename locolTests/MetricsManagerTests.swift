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
            XCTAssertEqual(self.manager.metrics[gaugeKey]?.values.last?.value, 42)
            XCTAssertEqual(self.manager.metrics[counterKey]?.values.last?.value, 100)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testHistogramProcessing() {
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
        
        // Directly process metrics instead of using scraping
        manager.processMetrics(metricsData)
        
        // Check results after a small delay to allow processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let key = self.manager.metricKey(name: "request_duration", labels: [:])
            
            XCTAssertNotNil(self.manager.histogramData[key], "Histogram data should not be nil")
            XCTAssertEqual(self.manager.histogramData[key]?.count, 1, "Should have one histogram")
            
            let histogram = self.manager.histogramData[key]?.first
            XCTAssertEqual(histogram?.buckets.count, 4, "Should have 4 buckets")
            XCTAssertEqual(histogram?.sum, 8.35, "Sum should be 8.35")
            XCTAssertEqual(histogram?.count, 6, "Count should be 6")
            
            expectation.fulfill()
        }
        
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
                XCTAssertTrue(error?.contains("Error processing metrics") ?? false)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        manager.startScraping()
        
        wait(for: [expectation], timeout: 1.0)
    }
} 