import Foundation
import os
import os.signpost

// MARK: - Centralized Logging Configuration

extension Logger {
    /// The main subsystem identifier for the application
    private static let subsystem = "io.aparker.locol"
    
    // MARK: - Category-Specific Loggers
    
    /// General application lifecycle and startup events
    static let app = Logger(subsystem: subsystem, category: "app")
    
    /// Collector management, process lifecycle, and binary operations
    static let collectors = Logger(subsystem: subsystem, category: "collectors")
    
    /// Telemetry data processing, database operations, and queries
    static let telemetry = Logger(subsystem: subsystem, category: "telemetry")
    
    /// Network requests, HTTP operations, and connectivity
    static let networking = Logger(subsystem: subsystem, category: "networking")
    
    /// Database operations, SQLite queries, and data persistence
    static let database = Logger(subsystem: subsystem, category: "database")
    
    /// User interface events, view updates, and user interactions
    static let ui = Logger(subsystem: subsystem, category: "ui")
    
    /// gRPC services, protobuf operations, and OTLP receiver
    static let grpc = Logger(subsystem: subsystem, category: "grpc")
    
    /// File system operations, downloads, and archive extraction
    static let fileSystem = Logger(subsystem: subsystem, category: "filesystem")
    
    /// Configuration management and YAML processing
    static let config = Logger(subsystem: subsystem, category: "config")
}

// MARK: - Performance Signposting

extension OSSignposter {
    /// The main subsystem identifier for signposting
    private static let subsystem = "io.aparker.locol"
    
    // MARK: - Category-Specific Signposters
    
    /// Performance signposts for telemetry operations
    static let telemetry = OSSignposter(subsystem: subsystem, category: "telemetry")
    
    /// Performance signposts for database operations  
    static let database = OSSignposter(subsystem: subsystem, category: "database")
    
    /// Performance signposts for network operations
    static let networking = OSSignposter(subsystem: subsystem, category: "networking")
    
    /// Performance signposts for collector processes
    static let collectors = OSSignposter(subsystem: subsystem, category: "collectors")
    
    /// Performance signposts for gRPC operations
    static let grpc = OSSignposter(subsystem: subsystem, category: "grpc")
    
    /// Performance signposts for file system operations
    static let fileSystem = OSSignposter(subsystem: subsystem, category: "filesystem")
}

// MARK: - Logging Utilities

/// Utility functions for common logging patterns
enum LoggingUtils {
    
    /// Log a method entry with optional parameters
    /// - Parameters:
    ///   - logger: The logger to use
    ///   - function: The function name (automatically filled by #function)
    ///   - parameters: Optional parameters to include
    static func logMethodEntry(
        _ logger: Logger,
        function: String = #function,
        parameters: [String: Any] = [:]
    ) {
        if parameters.isEmpty {
            logger.debug("→ \(function)")
        } else {
            let paramString = parameters.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            logger.debug("→ \(function) (\(paramString))")
        }
    }
    
    /// Log a method exit with optional result
    /// - Parameters:
    ///   - logger: The logger to use
    ///   - function: The function name (automatically filled by #function)
    ///   - result: Optional result to include
    static func logMethodExit(
        _ logger: Logger,
        function: String = #function,
        result: Any? = nil
    ) {
        if let result = result {
            logger.debug("← \(function) → \(String(describing: result))")
        } else {
            logger.debug("← \(function)")
        }
    }
    
    /// Log an operation with timing
    /// - Parameters:
    ///   - logger: The logger to use
    ///   - operation: Description of the operation
    ///   - signposter: Optional signposter for performance tracking
    ///   - work: The work to perform
    /// - Returns: The result of the work
    static func logTimed<T>(
        _ logger: Logger,
        operation: String,
        signposter: OSSignposter? = nil,
        work: @Sendable () throws -> T
    ) rethrows -> T {
        let startTime = DispatchTime.now()
        _ = signposter?.makeSignpostID()
        // Note: OSSignposter doesn't support dynamic strings well, so we'll skip it for now
        // Signposting disabled for now
        
        logger.debug("Starting \(operation)")
        
        defer {
            let endTime = DispatchTime.now()
            let nanoTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
            let timeInterval = Double(nanoTime) / 1_000_000_000.0
            
            logger.debug("Completed \(operation) in \(String(format: "%.3f", timeInterval))s")
            
            // Signposting disabled for now due to dynamic string limitations
        }
        
        return try work()
    }
    
    /// Log an async operation with timing
    /// - Parameters:
    ///   - logger: The logger to use
    ///   - operation: Description of the operation
    ///   - signposter: Optional signposter for performance tracking
    ///   - work: The async work to perform
    /// - Returns: The result of the work
    static func logTimedAsync<T>(
        _ logger: Logger,
        operation: String,
        signposter: OSSignposter? = nil,
        work: @Sendable () async throws -> T
    ) async rethrows -> T {
        let startTime = DispatchTime.now()
        _ = signposter?.makeSignpostID()
        // Note: OSSignposter doesn't support dynamic strings well, so we'll skip it for now
        // Signposting disabled for now
        
        logger.debug("Starting \(operation)")
        
        defer {
            let endTime = DispatchTime.now()
            let nanoTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
            let timeInterval = Double(nanoTime) / 1_000_000_000.0
            
            logger.debug("Completed \(operation) in \(String(format: "%.3f", timeInterval))s")
            
            // Signposting disabled for now due to dynamic string limitations
        }
        
        return try await work()
    }
}
