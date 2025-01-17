import Foundation
import Combine

class MetricsViewModel: ObservableObject {
    @Published private(set) var groupedMetrics: (regular: [(String, [Metric])], histograms: [(String, [Metric])])
    private var cancellables = Set<AnyCancellable>()
    private let metricsManager: MetricsManager
    
    init(metricsManager: MetricsManager = .shared) {
        self.metricsManager = metricsManager
        self.groupedMetrics = (regular: [], histograms: [])
        
        // Subscribe to metrics changes
        metricsManager.$metrics
            .map { metrics in
                // Split metrics by type
                let regular = metrics.filter { _, values in
                    guard let type = values.first?.type else { return false }
                    return type == .counter || type == .gauge
                }
                
                let histograms = metrics.filter { _, values in
                    guard let type = values.first?.type else { return false }
                    return type == .histogram
                }
                
                return (
                    regular: regular.sorted(by: { $0.key < $1.key }),
                    histograms: histograms.sorted(by: { $0.key < $1.key })
                )
            }
            .assign(to: &$groupedMetrics)
    }
    
    func getRate(for key: String) -> Double? {
        metricsManager.getRate(for: key)
    }
    
    func startScraping() {
        metricsManager.startScraping()
    }
    
    func stopScraping() {
        metricsManager.stopScraping()
    }
} 