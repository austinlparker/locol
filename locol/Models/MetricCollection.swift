import Foundation
import os

struct MetricCollection {
    let histograms: [TimeSeriesData]
    let regular: [TimeSeriesData]
    private let logger = Logger(subsystem: "io.aparker.locol", category: "MetricCollection")
    
    init(metrics: [String: TimeSeriesData]) {
        let totalCount = metrics.count
        logger.debug("Creating MetricCollection with \(totalCount) metrics")
        
        let filtered = metrics.values.filter { !MetricFilter.isExcluded($0.name) }
        let filteredCount = filtered.count
        logger.debug("After exclusion filter: \(filteredCount) metrics")
        
        // Group metrics by their base name
        var histogramGroups: [String: TimeSeriesData] = [:]
        var histogramBaseNames = Set<String>()
        
        // First pass: identify all histogram base names
        for metric in filtered {
            let baseName = MetricFilter.getBaseName(metric.name)
            if let type = metric.definition?.type, type == .histogram {
                histogramBaseNames.insert(baseName)
            }
        }
        
        logger.debug("Found histogram base names: \(histogramBaseNames)")
        
        // Second pass: collect histogram metrics
        for metric in filtered {
            let baseName = MetricFilter.getBaseName(metric.name)
            if histogramBaseNames.contains(baseName) {
                // For histograms, we want to store the base metric without the le label
                var baseLabels = metric.labels
                baseLabels.removeValue(forKey: "le")
                
                // Create a new TimeSeriesData with the base labels
                let baseMetric = TimeSeriesData(
                    name: baseName,
                    labels: baseLabels,
                    values: metric.values,
                    definition: MetricDefinition(
                        name: baseName,
                        description: metric.definition?.description ?? "Histogram metric",
                        type: .histogram
                    )
                )
                
                let key = MetricKeyGenerator.generateKey(name: baseName, labels: baseLabels)
                logger.debug("Processing histogram metric: \(baseName)")
                logger.debug("- Original labels: \(metric.labels)")
                logger.debug("- Base labels: \(baseLabels)")
                logger.debug("- Key: \(key)")
                
                histogramGroups[key] = baseMetric
            }
        }
        
        // Now separate into histograms and regular metrics
        let histogramMetrics = histogramGroups.values.sorted { $0.name < $1.name }
        
        let regularMetrics = filtered.filter { metric in
            let baseName = MetricFilter.getBaseName(metric.name)
            return !histogramBaseNames.contains(baseName)
        }.sorted { $0.name < $1.name }
        
        self.histograms = histogramMetrics
        self.regular = regularMetrics
        
        let histogramCount = histogramMetrics.count
        let regularCount = regularMetrics.count
        logger.debug("Final counts - Histograms: \(histogramCount), Regular: \(regularCount)")
    }
} 