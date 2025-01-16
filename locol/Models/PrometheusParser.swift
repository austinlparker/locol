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
        var currentHistogramType: MetricType? = nil
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty { continue }
            
            if trimmedLine.starts(with: "# HELP") {
                // Store previous metric if exists
                if let metric = currentMetric {
                    try validateAndAddMetric(metric, to: &metrics)
                }
                
                // Start new metric
                let parts = trimmedLine.components(separatedBy: " ")
                guard parts.count >= 3 else {
                    throw MetricError.malformedMetricLine(trimmedLine)
                }
                let name = parts[2]
                guard isValidMetricName(name) else {
                    throw MetricError.invalidMetricName(name)
                }
                let help = parts.dropFirst(3).joined(separator: " ")
                currentMetric = (name: name, help: help, type: nil, values: [])
                
            } else if trimmedLine.starts(with: "# TYPE") {
                let parts = trimmedLine.components(separatedBy: " ")
                guard parts.count >= 4 else {
                    throw MetricError.malformedMetricLine(trimmedLine)
                }
                let name = parts[2]
                let typeStr = parts[3]
                
                if currentMetric == nil || currentMetric?.name != name {
                    guard isValidMetricName(name) else {
                        throw MetricError.invalidMetricName(name)
                    }
                    currentMetric = (name: name, help: nil, type: nil, values: [])
                }
                
                // Update type and store histogram type for components
                if let type = MetricType(rawValue: typeStr) {
                    currentMetric?.type = type
                    if type == .histogram {
                        currentHistogramType = type
                    }
                }
                
            } else if let metric = currentMetric {
                // Parse metric value line
                do {
                    if let (labels, value) = try parseMetricLine(trimmedLine) {
                        currentMetric?.values.append((labels: labels, value: value))
                    }
                } catch {
                    logger.error("Failed to parse metric line: \(error.localizedDescription)")
                    throw error
                }
            } else {
                // Handle histogram components without their own TYPE
                do {
                    if let (labels, value) = try parseMetricLine(trimmedLine) {
                        let name = trimmedLine.components(separatedBy: [" ", "{"]).first ?? ""
                        if name.hasSuffix("_bucket") || name.hasSuffix("_sum") || name.hasSuffix("_count"),
                           let baseType = currentHistogramType {
                            let metric: MetricTuple = (name: name, help: nil, type: baseType, values: [(labels: labels, value: value)])
                            try validateAndAddMetric(metric, to: &metrics)
                        }
                    }
                } catch {
                    logger.error("Failed to parse metric line: \(error.localizedDescription)")
                    throw error
                }
            }
        }
        
        // Add last metric
        if let metric = currentMetric {
            try validateAndAddMetric(metric, to: &metrics)
        }
        
        return metrics
    }
    
    private static func validateAndAddMetric(_ metric: (name: String, help: String?, type: MetricType?, values: [(labels: [String: String], value: Double)]), to metrics: inout [PrometheusMetric]) throws {
        guard isValidMetricName(metric.name) else {
            throw MetricError.invalidMetricName(metric.name)
        }
        
        // For histograms, validate bucket ordering
        if metric.type == .histogram {
            try validateHistogramBuckets(metric)
        }
        
        metrics.append(PrometheusMetric(
            name: metric.name,
            help: metric.help,
            type: metric.type,
            values: metric.values
        ))
    }
    
    private static func validateHistogramBuckets(_ metric: (name: String, help: String?, type: MetricType?, values: [(labels: [String: String], value: Double)])) throws {
        var buckets: [(le: Double, count: Double)] = []
        
        // Collect bucket values
        for value in metric.values {
            if let le = value.labels["le"] {
                let upperBound = parseHistogramBucket(le) ?? Double.infinity
                buckets.append((le: upperBound, count: value.value))
            }
        }
        
        // Sort buckets by le value
        buckets.sort { $0.le < $1.le }
        
        // Validate monotonic increase
        for i in 1..<buckets.count {
            if buckets[i].count < buckets[i-1].count {
                throw MetricError.invalidHistogramBuckets(metric.name)
            }
        }
        
        // Ensure +Inf bucket exists
        guard buckets.last?.le == Double.infinity else {
            throw MetricError.invalidHistogramBuckets(metric.name)
        }
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
            let labels = try parseLabels(from: nameAndLabels, originalLine: line)
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
                    if value.isEmpty {
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
    
    private static func parseHistogramBucket(_ value: String) -> Double {
        if value == "+Inf" {
            return Double.infinity
        }
        return Double(value) ?? Double.infinity
    }
} 