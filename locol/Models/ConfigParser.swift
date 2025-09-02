import Foundation
import Yams

// Configuration parser that extracts relevant logging configuration
struct ConfigParser {
    // Configuration info for log parsing
    struct LoggingConfig {
        let hasDebugExporter: Bool
        let debugExporterVerbosity: DebugExporterVerbosity
        let exporters: [String]
    }
    
    enum DebugExporterVerbosity: String, CaseIterable {
        case basic = "basic"
        case normal = "normal" 
        case detailed = "detailed"
    }
    
    static func parseConfig(at path: String) throws -> LoggingConfig {
        let configContent = try String(contentsOfFile: path, encoding: .utf8)
        let yaml = try Yams.load(yaml: configContent) as? [String: Any] ?? [:]
        
        // Check exporters section
        guard let exporters = yaml["exporters"] as? [String: Any] else {
            return LoggingConfig(
                hasDebugExporter: false,
                debugExporterVerbosity: .normal,
                exporters: []
            )
        }
        
        // Check if debug exporter is present
        guard let debugConfig = exporters["debug"] as? [String: Any] else {
            return LoggingConfig(
                hasDebugExporter: false,
                debugExporterVerbosity: .normal,
                exporters: Array(exporters.keys)
            )
        }
        
        // Parse debug exporter verbosity
        let verbosityString = debugConfig["verbosity"] as? String ?? "normal"
        let verbosity = DebugExporterVerbosity(rawValue: verbosityString) ?? .normal
        
        return LoggingConfig(
            hasDebugExporter: true,
            debugExporterVerbosity: verbosity,
            exporters: Array(exporters.keys)
        )
    }
}