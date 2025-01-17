import Foundation
import os

enum MetricError: Error, Equatable {
    case invalidMetricName(String)
    case malformedMetricLine(String)
    case invalidHistogramBuckets(String)
    case counterReset(String)
    
    static func == (lhs: MetricError, rhs: MetricError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidMetricName(let l), .invalidMetricName(let r)): return l == r
        case (.malformedMetricLine(let l), .malformedMetricLine(let r)): return l == r
        case (.invalidHistogramBuckets(let l), .invalidHistogramBuckets(let r)): return l == r
        case (.counterReset(let l), .counterReset(let r)): return l == r
        default: return false
        }
    }
}

struct PrometheusMetric {
    let name: String
    let help: String?
    let type: MetricType?
    let values: [(labels: [String: String], value: Double)]
}

class PrometheusParser {
    private static let logger = Logger(subsystem: "io.aparker.locol", category: "PrometheusParser")
    
    private typealias MetricTuple = (name: String, help: String?, type: MetricType?, values: [(labels: [String: String], value: Double)])
    
    static func parse(_ metricsString: String) throws -> [PrometheusMetric] {
        logger.debug("Parsing metrics string of length: \(metricsString.count)")
        
        let lines = metricsString.components(separatedBy: .newlines)
        var metrics: [PrometheusMetric] = []
        var currentMetric: MetricTuple? = nil
        var samples: [(labels: [String: String], value: Double)] = []
        
        for (i, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty { continue }
            
            var lineMetric: String? = nil
            var lineHelp: String? = nil
            var lineType: MetricType? = nil
            var lineSample: (labels: [String: String], value: Double)? = nil
            
            if trimmedLine.starts(with: "# ") {
                // Process metadata lines
                let lineData = String(trimmedLine.dropFirst(2))
                
                if lineData.starts(with: "HELP ") {
                    let parts = lineData.dropFirst(5).components(separatedBy: " ")
                    guard !parts.isEmpty else { throw MetricError.malformedMetricLine(trimmedLine) }
                    lineMetric = parts[0]
                    lineHelp = parts.dropFirst().joined(separator: " ")
                } else if lineData.starts(with: "TYPE ") {
                    let parts = lineData.dropFirst(5).components(separatedBy: " ")
                    guard parts.count == 2 else { throw MetricError.malformedMetricLine(trimmedLine) }
                    lineMetric = parts[0]
                    lineType = MetricType(rawValue: parts[1])
                }
            } else {
                // Process sample lines
                if let (labels, value) = try parseMetricLine(trimmedLine) {
                    lineSample = (labels: labels, value: value)
                    lineMetric = trimmedLine.components(separatedBy: [" ", "{"]).first
                }
            }
            
            // Validate metric name
            if let metric = lineMetric {
                guard isValidMetricName(metric) else {
                    throw MetricError.invalidMetricName(metric)
                }
            }
            
            // For histogram metrics, normalize the name to remove _bucket, _sum, _count suffixes
            if let metric = lineMetric {
                let isHistogramComponent = metric.hasSuffix("_bucket") || 
                                         metric.hasSuffix("_sum") || 
                                         metric.hasSuffix("_count")
                if isHistogramComponent {
                    let baseName = metric.replacingOccurrences(of: "_bucket", with: "")
                                       .replacingOccurrences(of: "_sum", with: "")
                                       .replacingOccurrences(of: "_count", with: "")
                    lineMetric = baseName
                    if currentMetric?.type == nil {
                        lineType = .histogram
                    }
                }
            }
            
            // Check if we need to start a new metric family
            let isNewMetric = lineMetric != nil && 
                            currentMetric != nil && 
                            lineMetric != currentMetric?.name
            let isLastLine = i + 1 == lines.count
            
            if isNewMetric || isLastLine {
                // Process and store current metric if exists
                if let current = currentMetric {
                    // For histograms, validate samples
                    if current.type == .histogram {
                        try validateHistogramSamples(samples, metricName: current.name)
                    }
                    
                    // Add the last sample if it belongs to the current metric
                    if isLastLine && lineMetric == current.name {
                        if let sample = lineSample {
                            samples.append(sample)
                        }
                    }
                    
                    metrics.append(PrometheusMetric(
                        name: current.name,
                        help: current.help,
                        type: current.type,
                        values: samples
                    ))
                }
                
                // Start new metric family if this isn't the last line
                if !isLastLine {
                    if let metric = lineMetric {
                        currentMetric = (
                            name: metric,
                            help: lineHelp,
                            type: lineType,
                            values: []
                        )
                        samples = []
                        // Add the current sample to the new metric
                        if let sample = lineSample {
                            samples.append(sample)
                        }
                    }
                }
            } else {
                // Update current metric if same name
                if let metric = lineMetric {
                    if currentMetric == nil {
                        currentMetric = (
                            name: metric,
                            help: lineHelp,
                            type: lineType,
                            values: []
                        )
                    } else {
                        if let help = lineHelp {
                            currentMetric?.help = help
                        }
                        if let type = lineType {
                            currentMetric?.type = type
                        }
                    }
                }
                
                // Add sample if exists
                if let sample = lineSample {
                    samples.append(sample)
                }
            }
        }
        
        return metrics
    }
    
    private static func validateHistogramSamples(_ samples: [(labels: [String: String], value: Double)], metricName: String) throws {
        var buckets: [(le: Double, count: Double)] = []
        
        // Collect bucket values
        for sample in samples {
            if let le = sample.labels["le"] {
                let upperBound = parseHistogramBucket(le) ?? Double.infinity
                buckets.append((le: upperBound, count: sample.value))
            }
        }
        
        // Skip validation if no buckets
        if buckets.isEmpty {
            logger.debug("No buckets found for histogram \(metricName)")
            return
        }
        
        // Sort buckets by le value
        buckets.sort { $0.le < $1.le }
        
        // Debug logging
        logger.debug("Validating histogram buckets for \(metricName):")
        for bucket in buckets {
            logger.debug("  le: \(bucket.le), count: \(bucket.count)")
        }
        
        // Validate monotonic increase
        var lastCount = buckets[0].count
        for bucket in buckets.dropFirst() {
            if bucket.count < lastCount {
                logger.error("Non-monotonic bucket detected in \(metricName): previous count \(lastCount), current count \(bucket.count)")
                throw MetricError.invalidHistogramBuckets(metricName)
            }
            lastCount = bucket.count
        }
        
        // Ensure +Inf bucket exists
        guard buckets.last?.le == Double.infinity else {
            logger.error("Missing +Inf bucket in \(metricName). Last bucket: le=\(buckets.last?.le ?? -1), count=\(buckets.last?.count ?? -1)")
            throw MetricError.invalidHistogramBuckets(metricName)
        }
        
        logger.debug("Successfully validated histogram buckets for \(metricName)")
    }
    
    private static func parseHistogramBucket(_ le: String) -> Double? {
        if le == "+Inf" || le == "inf" {
            return Double.infinity
        }
        if let value = Double(le) {
            return value
        }
        logger.error("Failed to parse histogram bucket value: \(le)")
        return nil
    }
    
    static func isValidMetricName(_ name: String) -> Bool {
        let pattern = "^[a-zA-Z_:][a-zA-Z0-9_:]*$"
        return name.range(of: pattern, options: .regularExpression) != nil
    }
    
    private static func parseMetricLine(_ line: String) throws -> (labels: [String: String], value: Double)? {
        let parts = line.components(separatedBy: " ")
        guard parts.count >= 2,
              let value = Double(parts[parts.count - 1]) else {
            throw MetricError.malformedMetricLine(line)
        }
        
        let nameAndLabels = parts[0]
        do {
            var labels = try parseLabels(from: nameAndLabels, originalLine: line)
            // Add the metric name as a special label
            labels["__name__"] = nameAndLabels.components(separatedBy: ["{", " "]).first
            return (labels: labels, value: value)
        } catch {
            throw MetricError.malformedMetricLine(line)
        }
    }
    
    private static func parseLabels(from nameAndLabels: String, originalLine: String) throws -> [String: String] {
        var labels: [String: String] = [:]
        
        if let openBrace = nameAndLabels.firstIndex(of: "{"),
           let closeBrace = nameAndLabels.lastIndex(of: "}"),
           openBrace < closeBrace {
            let labelsPart = nameAndLabels[nameAndLabels.index(after: openBrace)..<closeBrace]
            let labelPairs = labelsPart.components(separatedBy: ",")
            for pair in labelPairs {
                let keyValue = pair.components(separatedBy: "=")
                if keyValue.count == 2 {
                    let key = keyValue[0].trimmingCharacters(in: .whitespaces)
                    var value = keyValue[1].trimmingCharacters(in: .whitespaces)
                    if value.hasPrefix("\"") && value.hasSuffix("\"") {
                        value = String(value.dropFirst().dropLast())
                    }
                    // Empty values are valid in Prometheus format
                    if key.isEmpty {
                        throw MetricError.malformedMetricLine(originalLine)
                    }
                    labels[key] = value
                } else {
                    throw MetricError.malformedMetricLine(originalLine)
                }
            }
        }
        
        return labels
    }
} 