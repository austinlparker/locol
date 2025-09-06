import Foundation
import os
import os.signpost

// MARK: - LoggableComponent Protocol

/// Protocol for components that need standardized logging capabilities
@MainActor
protocol LoggableComponent {
    /// The logger instance for this component (each component specifies its own)
    var logger: Logger { get }
    
    /// Optional signposter for performance tracking
    var signposter: OSSignposter? { get }
    
    /// Optional component name for more specific logging context
    var componentName: String? { get }
}

extension LoggableComponent {
    /// Default component name based on type
    var componentName: String? { String(describing: type(of: self)) }
    
    /// Default signposter (nil unless overridden)
    var signposter: OSSignposter? { nil }
    
    /// Default logger (fallback to app logger)
    var logger: Logger { .app }
}

// MARK: - Logging Convenience Methods

extension LoggableComponent {
    /// Log method entry with automatic function name
    func logEntry(function: String = #function, parameters: [String: Any] = [:]) {
        LoggingUtils.logMethodEntry(logger, function: function, parameters: parameters)
    }
    
    /// Log method exit with automatic function name
    func logExit(function: String = #function, result: Any? = nil) {
        LoggingUtils.logMethodExit(logger, function: function, result: result)
    }
    
    /// Execute and log a timed operation
    func logTimed<T>(
        operation: String,
        work: @Sendable () throws -> T
    ) rethrows -> T {
        return try LoggingUtils.logTimed(
            logger,
            operation: operation,
            signposter: signposter,
            work: work
        )
    }
    
    /// Execute and log a timed async operation
    func logTimedAsync<T>(
        operation: String,
        work: @Sendable () async throws -> T
    ) async rethrows -> T {
        return try await LoggingUtils.logTimedAsync(
            logger,
            operation: operation,
            signposter: signposter,
            work: work
        )
    }
}

// MARK: - ErrorHandler Utility

/// Centralized error handling utility with standardized logging and optional user notification
struct ErrorHandler {
    private let logger: Logger
    private let componentName: String?
    
    init(logger: Logger = Logger.app, componentName: String? = nil) {
        self.logger = logger
        self.componentName = componentName
    }
    
    /// Handle an error with standardized logging
    /// - Parameters:
    ///   - error: The error to handle
    ///   - operation: Description of the operation that failed
    ///   - level: The log level (default: error)
    ///   - additionalInfo: Additional context information
    func handle(
        _ error: Error,
        operation: String,
        level: OSLogType = .error,
        additionalInfo: [String: Any] = [:]
    ) {
        let prefix = componentName.map { "[\($0)] " } ?? ""
        let context = additionalInfo.isEmpty ? "" : " Context: \(additionalInfo)"
        
        logger.log(level: level, "\(prefix)Failed to \(operation): \(error.localizedDescription)\(context)")
    }
    
    /// Handle an error and return a standardized result
    /// - Parameters:
    ///   - error: The error to handle
    ///   - operation: Description of the operation that failed
    ///   - defaultValue: Default value to return
    /// - Returns: The default value
    func handleAndReturn<T>(
        _ error: Error,
        operation: String,
        defaultValue: T
    ) -> T {
        handle(error, operation: operation)
        return defaultValue
    }
    
    /// Handle an error and execute a recovery action
    /// - Parameters:
    ///   - error: The error to handle
    ///   - operation: Description of the operation that failed
    ///   - recovery: Recovery action to perform
    func handleWithRecovery(
        _ error: Error,
        operation: String,
        recovery: () -> Void
    ) {
        handle(error, operation: operation)
        recovery()
    }
}

// MARK: - LoggableComponent + ErrorHandler Extension

extension LoggableComponent {
    /// Convenience property for error handling
    var errorHandler: ErrorHandler {
        ErrorHandler(logger: logger, componentName: componentName)
    }
}